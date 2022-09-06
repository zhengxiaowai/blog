---
title: Rocksdb WAL 流程分析
date: 2022-06-12 19:46:44
categories:
- Rocksdb
tags:
---

WAL(Write Ahead Log) 可以将 memtable 的操作做为日志写入磁盘，在发生故障后可以通过 WAL 重建 memtable，恢复到故障前的状态。当 memtable 刷到磁盘上后，这部分 WAL 会被归档，过一段时间后删除。

## LOG 格式

一个 LOG 文件由 N 个固定长度的 Block 组成，每个 Block 长度是 kBlockSize(32k)。每个 Block 中由 0 到 N 个Record 组成，如果一个 Record 不足 kBlockSize 会用 null 填充，超过一个 kBlockSize 会用 Type 表示出来。

```
       +-----+-------------+--+----+----------+------+-- ... ----+
 File  | r0  |        r1   |P | r2 |    r3    |  r4  |           |
       +-----+-------------+--+----+----------+------+-- ... ----+
       <--- kBlockSize ------>|<-- kBlockSize ------>|

  rn = variable size records
  P = Padding
```

Record 有两种格式一种是 Legacy 另一种的 Recyclable。

**Legacy Record Format**

```
+---------+-----------+-----------+--- ... ---+
|CRC (4B) | Size (2B) | Type (1B) | Payload   |
+---------+-----------+-----------+--- ... ---+

CRC = 32bit hash computed over the payload using CRC
Size = Length of the payload data
Type = Type of record
       (kZeroType, kFullType, kFirstType, kLastType, kMiddleType )
       The type is used to group a bunch of records together to represent
       blocks that are larger than kBlockSize
Payload = Byte stream as long as specified by the payload size
```

正常的 Record 由 4 部分组成：CRC、Size、Type、Payload。其中前面三部分都是固定长度，Payload 是可变长度由 Size 表示具体的长度。

kZeroType 表示空数据理论上不应该出现 ，kFullType 表示 Record 处于当前 Block 中，kFirstType, kLastType, kMiddleType 可以表示当前 Record 是不是跨越 Block 的 Record。

一个 Record 最小需要 4 + 2 + 1 = 7B 来表示，所以当一个 Block 只剩下 6B 时候就不太合适，需要在读取时候跳过这 6B。假如剩下的正好是 7B，这那么这个 Record 就可以就会被拆分至少两部分：

1. 位于 Block 尾部，Type 是 kFirstType，Size 等于 0 的 Record
2. 位于下一个 Block 的头部，类型为 kMiddleType/kLastType 的 Record

> 一个 Record 如果很大可以跨越多个 Block，用 kFirstType, kLastType, kMiddleType 来表示范围

**Recyclable Record Format**

```
+---------+-----------+-----------+----------------+--- ... ---+
|CRC (4B) | Size (2B) | Type (1B) | Log number (4B)| Payload   |
+---------+-----------+-----------+----------------+--- ... ---+
Same as above, with the addition of
Log number = 32bit log file number, so that we can distinguish between
records written by the most recent log writer vs a previous one.
```

Recyclable 的 Record 表示已经被归档可以被回收，在 Legacy Record 基础上多了一个 Log number 以区分出是不是当前的 Record。

## 读写流程

### 新建

WAL 被 Rocksdb 抽象成 log_writer 和 log_reader，对应到实际文件就是 <log_number>.log，WAL 意味着 memtable 中的数据，一旦 memtable 被创建销毁对应的 LOG 文件也随之创建销毁。

在 DBImpl 内部维护着一个 logs_ 的双端队列，这个 log 队列存储着未完全 flush 和当前的 log 文件。

```c++
class DBImpl : public DB {
...
private:
    struct LogWriterNumber {
      // pass ownership of _writer
      LogWriterNumber(uint64_t _number, log::Writer* _writer)
          : number(_number), writer(_writer) {}
      ...
    };
    
    std::deque<LogWriterNumber> logs_;
...
}
```

logs_ 队列的第一个 LogWriterNumber 来自于 DB open 时候，这时候如果未发生手动 Flush 或者 memtable 写满，所有的 log 都是写入这个 log_writer。

```c++
Status DBImpl::Open(const DBOptions& db_options, const std::string& dbname,
                    const std::vector<ColumnFamilyDescriptor>& column_families,
                    std::vector<ColumnFamilyHandle*>* handles, DB** dbptr,
                    const bool seq_per_batch, const bool batch_per_txn) {
...
    {
      InstrumentedMutexLock wl(&impl->log_write_mutex_);
      impl->logfile_number_ = new_log_number;
      const auto& listeners = impl->immutable_db_options_.listeners;
      std::unique_ptr<WritableFileWriter> file_writer(
          new WritableFileWriter(std::move(lfile), log_fname, opt_env_options,
                                 nullptr /* stats */, listeners));
      impl->logs_.emplace_back(
          new_log_number,
          new log::Writer(
              std::move(file_writer), new_log_number,
              impl->immutable_db_options_.recycle_log_file_num > 0,
              impl->immutable_db_options_.manual_wal_flush));
    }
...
}
```

除了第一次在 Open 时候会创建第一个 log，后续的还有 4 个场景会涉及到切换新 log：

1. wal 文件大小超过 max_total_wal_size
2. 所有 cf 的 memtable（包括 active + immutable） 大小超过 db_write_buffer_size
3. 单个 memtable 超过 write_buffer_size
4. 手动触发了 flush

除了情况 1，情况 2 和 3 都是触发了 flush 导致 WAL 切换到新 log。

### 写入

WAL 的写入一般只发生在 Write 操作当中，也就是在写入 memtable 之前。

```c++
Status DBImpl::WriteToWAL(const WriteThread::WriteGroup& write_group,
                          log::Writer* log_writer, uint64_t* log_used,
                          bool need_log_sync, bool need_log_dir_sync,
                          SequenceNumber sequence) {
    WriteBatch* merged_batch = MergeBatch(write_group, &tmp_batch_, &write_with_wal, &to_be_cached_state);
    
    status = WriteToWAL(*merged_batch, log_writer, log_used, &log_size);

    for (auto& log : logs_) {
      status = log.writer->file()->Sync(immutable_db_options_.use_fsync);
      if (!status.ok()) {
        break;
      }
    }
    if (status.ok() && need_log_dir_sync) {
      status = directories_.GetWalDir()->Fsync();
    }
}
```

WriteToWAL 函数做了三个操作：merge batch、把 batch 写入 WAL、根据情况 flush WAL。

```c++
Status DBImpl::WriteToWAL(const WriteBatch& merged_batch,
                          log::Writer* log_writer, uint64_t* log_used,
                          uint64_t* log_size) {
  assert(log_size != nullptr);
  Slice log_entry = WriteBatchInternal::Contents(&merged_batch);
  *log_size = log_entry.size();
 

  if (UNLIKELY(needs_locking)) {
    log_write_mutex_.Lock();
  }
  Status status = log_writer->AddRecord(log_entry);
  if (UNLIKELY(needs_locking)) {
    log_write_mutex_.Unlock();
  }
  if (log_used != nullptr) {
    *log_used = logfile_number_;
  }
  total_log_size_ += log_entry.size();

  alive_log_files_.back().AddSize(log_entry.size());
  log_empty_ = false;
  return status;
}
```

重点放在这个 WriteToWAL 函数里的 WriteToWAL 中，在这个函数中核心操作就是把 merged_batch 变成 log_entry 然后调用 log_writer 的 AddRecord 写入。

```c++
Status Writer::AddRecord(const Slice& slice) {
  const char* ptr = slice.data();
  size_t left = slice.size();

  const int header_size =
      recycle_log_files_ ? kRecyclableHeaderSize : kHeaderSize;

  Status s;
  bool begin = true;
  do {
    const int64_t leftover = kBlockSize - block_offset_;
    assert(static_cast<int64_t>(kBlockSize - block_offset_) >= header_size);

    const size_t avail = kBlockSize - block_offset_ - header_size;
    const size_t fragment_length = (left < avail) ? left : avail;

    RecordType type;
    const bool end = (left == fragment_length);
    if (begin && end) {
      type = recycle_log_files_ ? kRecyclableFullType : kFullType;
    } else if (begin) {
      type = recycle_log_files_ ? kRecyclableFirstType : kFirstType;
    } else if (end) {
      type = recycle_log_files_ ? kRecyclableLastType : kLastType;
    } else {
      type = recycle_log_files_ ? kRecyclableMiddleType : kMiddleType;
    }

    s = EmitPhysicalRecord(type, ptr, fragment_length);
    ptr += fragment_length;
    left -= fragment_length;
    begin = false;
  } while (s.ok() && left > 0);
  return s;
}
```

AddRecord 函数中先根据预定义好的 BlockSize 和实际和 offset 计算出实际的 fragment 个数和长度，调用 EmitPhysicalRecord 构建 Record 写入 log 中。

至此 WAL 写入流程结束，回到第一个 WriteToWAL 中，还需要根据情况是否把调用 Sync 强制落盘。

### 读取

WAL 的读取一般发生在执行 Recover 时候，而 Recover 实在 Open 时候被调用，也就是说打开一个存在的 DB 时候会尝试给所有的 cf 执行一次 Recover 操作，用于重建 cf 的 memtable。

```c++
Status DBImpl::Recover(
    const std::vector<ColumnFamilyDescriptor>& column_families, bool read_only,
    bool error_if_log_file_exist, bool error_if_data_exists_in_logs) {
    ...
    if (!logs.empty()) {
      // Recover in the order in which the logs were generated
      std::sort(logs.begin(), logs.end());
      s = RecoverLogFiles(logs, &next_sequence, read_only);
      if (!s.ok()) {
        // Clear memtables if recovery failed
        for (auto cfd : *versions_->GetColumnFamilySet()) {
          cfd->CreateNewMemtable(*cfd->GetLatestMutableCFOptions(),
                                 kMaxSequenceNumber);
        }
      }
    }
    ...
｝
```

Recover 函数中经过各种检查后，如果存在可用的 log 就会调用 RecoverLogFiles 函数，读取 log 中的 Records 恢复 memtable，如果失败就重建一个空的 memtable。

RecoverLogFiles 的流程很长，这里先关注 reader.ReadRecord 函数。

```c++
bool Reader::ReadRecord(Slice* record, std::string* scratch,
                        WALRecoveryMode wal_recovery_mode) {
  scratch->clear();
  record->clear();
  bool in_fragmented_record = false;
  uint64_t prospective_record_offset = 0;

  Slice fragment;
  while (true) {
    uint64_t physical_record_offset = end_of_buffer_offset_ - buffer_.size();
    size_t drop_size = 0;
    const unsigned int record_type = ReadPhysicalRecord(&fragment, &drop_size);
    switch (record_type) {
      case kFullType:
      case kRecyclableFullType:
        prospective_record_offset = physical_record_offset;
        scratch->clear();
        *record = fragment;
        last_record_offset_ = prospective_record_offset;
        return true;

      case kFirstType:
      case kRecyclableFirstType:
        prospective_record_offset = physical_record_offset;
        scratch->assign(fragment.data(), fragment.size());
        in_fragmented_record = true;
        break;

      case kMiddleType:
      case kRecyclableMiddleType:
        scratch->append(fragment.data(), fragment.size());
        break;

      case kLastType:
      case kRecyclableLastType:
        scratch->append(fragment.data(), fragment.size());
        *record = Slice(*scratch);
        last_record_offset_ = prospective_record_offset;
        return true;
        break;
      ...
    }
  }
  return false;
}
```

这部分是根据 Record 的 Type 读取一个完整的 Record，在 kFirstType 和 kMiddleType 的时候都把 fragment 暂存在 scratch 中，同时没有 return 而是 break 后继续读取下一个 fragment，直到 *kLastType 为止。*

> 不同的 wal_recovery_mode 会导致不同情况下的错误，这里省略了这些错误。

ReadPhysicalRecord 函数主要就是根据 Record 格式读取内容，逻辑比较少也比较简单。

## Recovery

| kTolerateCorruptedTailRecords | 忽略文件末尾的发生的错误，系统无法区分文件末尾的数据损坏和不完全写入 |
| ----------------------------- | ------------------------------------------------------------ |
| kAbsoluteConsistency          | 任何 IO 错误都被视为数据损坏，适用于不能接受丢失任何数据，而且有方法恢复未提交的数据 |
| kSkipAnyCorruptedRecords      | 发生 IO 错误时，会停止 recover，系统恢复到一个一致性的时间点上，适用于有从集群可以恢复数据 |
| kSkipAnyCorruptedRecords      | 忽略任何错误，适用于尽可能恢复更多的数据                     |

这里接着 Reader::ReadRecord 中 switch-case 的异常分支。

```c++
case kBadHeader:
  if (wal_recovery_mode == WALRecoveryMode::kAbsoluteConsistency) {
    ReportCorruption(drop_size, "truncated header");
  }
  FALLTHROUGH_INTENDED;
case kEof:
  if (in_fragmented_record) {
    if (wal_recovery_mode == WALRecoveryMode::kAbsoluteConsistency) {
      ReportCorruption(scratch->size(), "error reading trailing data");
    }
    scratch->clear();
  }
  return false;
case kOldRecord:
  if (wal_recovery_mode != WALRecoveryMode::kSkipAnyCorruptedRecords) {

    if (in_fragmented_record) {
      if (wal_recovery_mode == WALRecoveryMode::kAbsoluteConsistency) {
        ReportCorruption(scratch->size(), "error reading trailing data");
      }
      scratch->clear();
    }
    return false;
  }
  FALLTHROUGH_INTENDED;
case kBadRecord:
  if (in_fragmented_record) {
    ReportCorruption(scratch->size(), "error in middle of record");
    in_fragmented_record = false;
    scratch->clear();
  }
  break;
```

可以看出只有当数据真正损坏或者遇到最严格的 kAbsoluteConsistency 的时候才会 report 数据损坏。

```c++
status = WriteBatchInternal::InsertInto(
    &batch, column_family_memtables_.get(), &flush_scheduler_, true,
    log_number, this, false /* concurrent_memtable_writes */,
    next_sequence, &has_valid_writes, seq_per_batch_, batch_per_txn_);
```

Reader::ReadRecord 读出一个 Record 以后就可以用 WriteBatchInternal::InsertInto 插入 memtable。

```c++
if (!status.ok()) {
  if (status.IsNotSupported()) {
    return status;
  }
  if (immutable_db_options_.wal_recovery_mode ==
      WALRecoveryMode::kSkipAnyCorruptedRecords) {
    // We should ignore all errors unconditionally
    status = Status::OK();
  } else if (immutable_db_options_.wal_recovery_mode ==
             WALRecoveryMode::kPointInTimeRecovery) {
    // We should ignore the error but not continue replaying
    status = Status::OK();
    stop_replay_for_corruption = true;
    corrupted_log_number = log_number;
    ROCKS_LOG_INFO(immutable_db_options_.info_log,
                   "Point in time recovered to log #%" PRIu64
                   " seq #%" PRIu64,
                   log_number, *next_sequence);
  } else {
    assert(immutable_db_options_.wal_recovery_mode ==
               WALRecoveryMode::kTolerateCorruptedTailRecords ||
           immutable_db_options_.wal_recovery_mode ==
               WALRecoveryMode::kAbsoluteConsistency);
    return status;
  }
}
```

根据 recovery mode 的定义会接着处理这些插入失败的 Record，可以看出如果是 *kSkipAnyCorruptedRecords* 就会直接返回 Status::OK()，如果是 kPointInTimeRecovery 就停止回放 WAL同时返回 Status::OK()。

```c++
if (stop_replay_for_corruption == true &&
    (immutable_db_options_.wal_recovery_mode ==
         WALRecoveryMode::kPointInTimeRecovery ||
     immutable_db_options_.wal_recovery_mode ==
         WALRecoveryMode::kTolerateCorruptedTailRecords)) {
  for (auto cfd : *versions_->GetColumnFamilySet()) {
    if (cfd->GetLogNumber() > corrupted_log_number) {
      ROCKS_LOG_ERROR(immutable_db_options_.info_log,
                      "Column family inconsistency: SST file contains data"
                      " beyond the point of corruption.");
      return Status::Corruption("SST file is ahead of WALs");
    }
  }
```

kPointInTimeRecovery 和 kTolerateCorruptedTailRecords 还需要判断发生损坏的 log 是不是在当前 log 之前，如果是需要打印包含 log 信息的错误日志。 

```c++
if (flushed || !immutable_db_options_.avoid_flush_during_recovery) {
  status = WriteLevel0TableForRecovery(job_id, cfd, cfd->mem(), edit);
  if (!status.ok()) {
    // Recovery failed
    break;
  }
  flushed = true;

  cfd->CreateNewMemtable(*cfd->GetLatestMutableCFOptions(),
                         versions_->LastSequence());
}
```

如果需要 flush 会调用 WriteLevel0TableForRecovery 把数据刷到 L0，同时修改了 VersionEdit。

```c++
versions_->MarkFileNumberUsed(max_log_number + 1);
status = versions_->LogAndApply(cfd, *cfd->GetLatestMutableCFOptions(),
                                edit, &mutex_);
```

最后调用 LogAndApply 把 VersionEdit 持久化到 MANIFEST 完成整个 recover 流程。