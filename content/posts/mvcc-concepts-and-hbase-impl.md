---
title: MVCC Concepts and HBase Implementation
date: 2022-07-10 22:27:56
categories:
- HBase
- Database
tags:
---

Multi-Version Concurrency Control 包含两个部分：

1. Multi-Version：存储多个版本数据，使得读写可以不冲突
2. Concurrency Control：并发控制，使执行过程可串行化

数据对象在物理上存储多个版本，但是在逻辑上表示为一个对象。当写入时候创建一个新版本的对象，当读取时候读取一个存在的最新对象。

| T1     | T2     |      | Version | Value | Begin | End  |
| ------ | ------ | ---- | ------- | ----- | ----- | ---- |
| BEGIBN |        |      | A0      | 123   | 0     | -    |
| R(A)   |        |      |         |       |       |      |
|        | BEGIBN |      |         |       |       |      |
|        | W(A)   |      | A0      | 123   | 0     | 2    |
|        |        |      | A1      | 456   | 2     | -    |
| R(A)   |        |      |         |       |       |      |
| COMMIT |        |      |         |       |       |      |
|        | COMMIT |      |         |       |       |      |

1. 初始版本为 A0，值为 123，可见范围是 0 ～ ∞
2. T1 的 R(A) 因为 0 < 1 < ∞，读取的值为 123
3. T2 的 W(A) 写入新版 A1，可见范围是 2 ～ ∞，A0 可见范围变为 0 ～ 2
4. T1 的第二次 R(A) 因为 0 < 1 < 2(A0 版本的 End 是 2)，读取的值为 123

| T1     | T2     |      | Version | Value | Begin | End  |
| ------ | ------ | ---- | ------- | ----- | ----- | ---- |
| BEGIBN |        |      | A0      | 123   | 0     | -    |
| R(A)   |        |      |         |       |       |      |
| W(A)   | BEGIBN |      | A0      | 123   | 0     | 1    |
|        | R(A)   |      | A1      | 456   | 1     | -    |
|        | W(A)   |      |         |       |       |      |
| R(A)   |        |      | A0      | 123   | 0     | 1    |
| COMMIT |        |      | A1      | 456   | 1     | 2    |
|        | COMMIT |      | A2      | 789   | 2     | -    |

1. T1-R(A) 读取 A0 版本数据
2. T1-W(A) 写入 A1 版本，Begin 是 1，修改 A0 版本的 End 为 2
3. T2-R(A) 读取 A0 版本，因为 A1 版本还没提交（读已提交）
4. T2-W(A) 发生 WW 冲突，需要阻塞到 T1 事务完成
5. T1-R(A) 读取 A1 数据，同一事务写入的版本
6. T1-Commit 事务 T1 完成事务
7. T2-W(A) 创建新版本 A2 Begin 为 2，同时修改 A1 的 End 为 2

# 并发控制（Concurrency Control Protocol）

> 参考其他并发控制的方式，MVCC 自身不能并发控制

- MV-2PL
- MV-TO
- MV-OCC

# 多版本存储（Version Storage）

## Append-Only Storage

所有的版本都存储在一张表中，不同版本之前之间使用类似链表的方式链接起来。遇到更新只需要追加一个新版，同时修改版本链表。

| Version | Value | Pointer | New-Pointer |
| ------- | ----- | ------- | ----------- |
| A0      | 111   | A1      |             |
| A1      | 222   | -       | A2          |
| B1      | 10    | -       |             |
|         |       |         |             |
| A2      | 333   | -       |             |

添加一个 A2 版本的数据需要的步骤，使用链表串联 A0->A1->A2：

1. 找到上一个版本 A1
2. Copy 一份 A1 的版本到 A2 同时修改 A2 的变更字段
3. 修改 A1 的 Pointer 指向 A2

 

采用链表管理不同的版本，也有两种方式 **oldest-to-newest**  和 **newest-to-oldest。**

|                  | Head | 更新                                               | 查找               |
| ---------------- | ---- | -------------------------------------------------- | ------------------ |
| oldest-to-newest | 最旧 | 添加一条记录 修改次新到最新的指针                  | 遍历存在的所有版本 |
| newest-to-oldest | 最新 | 添加一条记录 修改次新到最新的指针 修改 Head 到最新 | 只遍历可用版本     |

## Time-Travel Storage

数据存储在 main table 和 time-travel 表中，main table 存储最新版本，time-travel 存储历史版本。

Main table

| Version | Value | Pointer     |
| ------- | ----- | ----------- |
| A2      | 333   | TT table-A1 |

Time-travel table

| Version | Value | Pointer |
| ------- | ----- | ------- |
| A0      | 111   | -       |
| A1      | 222   | A0      |

- 新增：在 main table 中新增一条记录
- 更新：
  - 在 main table 中找到 A1，发现 Pointer 指向 time-travel table 中的 A0
  - copy main table A1 到 time-travel table 中
  - 修改 time-travel table 中 A1 的 Pointer 为 A0
  - 修改 main table 中的 A 版本为 A2，Pointer 为 A1

>  time-travel table 也有 oldest-to-newest 和 newest-to-oldest 的问题

## Delta Storage 

前面两种方式在只修改少数字段时候，都需要 copy 一份完整的数据作为新版本，会浪费更多的存储空间和 IO。delta storage 只存储变更记录，通过变更记录回溯版本。

Main table

| Version | Value | Pointer |
| ------- | ----- | ------- |
| A3      | 333   | dss-A2  |
| B1      | 10    |         |

Delta Storage Segment

| Version | Delta       | Pointer |
| ------- | ----------- | ------- |
| A1      | $value->111 | -       |
| A2      | $value->222 | A1      |

整体形式上和 time-travel table 类似，只不过这里存储的不再是一份完整的数据，而是 delta 内容。假如这时候需要版本 A1，那么只需要通过 A3-value 和 A2-delta、A1-delta 就可以获取 A1 的内容。

# 垃圾回收（Garbage Collection）

一般来说，随着时间的推移总是有一些版本不可能再被看到，过多的版本对写入和读取都会造成影响，所以需要回收那些用不到的版本。

- 活跃的事务看不到的版本
- 被 abortd 的事务创建的版本



设计上还有两个额外的问题：

- 如何找出过期的版本？
- 如何确定在回收时候是安全？

## Tuple-Level

直接遍历发现老版本

### Background Vacuuming

通常是一个独立线程，适用于任何存储方式

| Version | Begin | End  |
| ------- | ----- | ---- |
| A100    | 1     | 9    |
| B100    | 1     | 9    |
| B101    | 10    | 20   |

假设有 Thread #1 和 #2，分别执行 T12 和 T25，其中 A100 和 B 100 都处于不可见的版本，所以它们可以被回收。通常这种操作需要全表扫描，可以使用 bitmap 来表示 Dirty Block，减少扫描的范围。

### Cooperative Cleaning

如果不使用独立线程定时扫描旧版本，可以在遍历路径上发现旧版本，标记成 deleted 同时修改 Head。

| Version | Begin | End  |         |
| ------- | ----- | ---- | ------- |
| A0      | 1     | 5    | deleted |
| A1      | 5     | 10   | deleted |
| A2      | 10    | 20   |         |
| A3      | 20    | -    |         |

T12 执行 Get(A) 操作中需要遍历 version chain，发现路径上有两个过期版本标记成 deleted，这里 version chain 必须是 **oldest-to-newest** 不然永远无法发现旧版本。

## Transaction-Level

每个事务都维护自己的读写集合，可能仍然需要通过多线程来加快删除。

| Version | Begin | End  |
| ------- | ----- | ---- |
| A2      | 1     | -    |
| B6      | 8     | -    |
|         |       |      |
| A2      | 1     | 10   |
| B6      | 8     | 10   |
| A3      | 10    | -    |
| B7      | 10    | -    |

1. 事务 T Begin 10 开始事务
2. 更新数据 A，A2 版本称为老版本被 T 记录
3. 更新数据 B，A6 版本称为老版本被 T 记录
4. T Commit 后 < 10 的成为老版本可以被回收

# 索引管理（Index Management）

- Primary Index：指向 version chain 的 Head
- Secondary Indexes：
  - Physical Pointers
  - Logical Pointers

## Physical Pointers

Secondary Indexes#N -> A100 -> A99 -> A98 -> A97

二级索引可能存在很多个，一旦某一个二级索引更新了 Head 那么所有的都需要被更新

## Logical Pointers

1. 所有的二级索引指向主索引
2. 在 tuple id 和 Head 之间用一个 hash table 管理对应关系
   1. 假如二级索引更新某个 tuple，那么就修改 hash table 中 tuple id 对应的 head 

# HBase MVCC

> org/apache/hadoop/hbase/regionserver/MultiVersionConcurrencyControl.java

HBase 只能支持 region 级别的行事务，所以 MVCC 也是对于一个 region 来说，在每个 HRegion 类中都有一个 `private final MultiVersionConcurrencyControl mvcc;` 用于处理并发控制。

1. final AtomicLong readPoint = new AtomicLong(0);
2. final AtomicLong writePoint = new AtomicLong(0);
3. private final LinkedList<WriteEntry> writeQueue = new LinkedList<>();

类中主要是维护 readPoint 和 writePoint 这两个变量。除了这两个变量以外还有这几个核心的方法：

1. tryAdvanceTo(long newStartPoint, long expected)：设置 readPoint 和 writePoint
2. begin()：基于当前最新的 writePoint 开启一个写事务，并添加到当前的队列 writeQueue 中
3. complete(WriteEntry writeEntry)：
   1. 循环同步从 writeQueue 取 First WriteEntry 判断是否完成，完成后移除
   2. writeQueue 被取空以后，把 WriteEntry 的 WriteNumber 设置成 readPoint
   3. 判断 readPoint 是否大于等于 writeEntry，意味着 complete 返回是 true 还是 false
4. waitForRead(WriteEntry e)：同步阻塞提升 readPoint 到 e.getWriteNumber() 之后



正常的写流程操作都会调用 `doMiniBatchMutate` 在流程的第 5 步和第 6 步，会处理 mvcc 相关的操作。

```Java
private void doMiniBatchMutate(BatchOperation<?> batchOp) throws IOException {
    try {
        ......
         
        // STEP 5. Write back to memStore
        // NOTE: writeEntry can be null here
        writeEntry = batchOp.writeMiniBatchOperationsToMemStore(miniBatchOp, writeEntry);
        
        // STEP 6. Complete MiniBatchOperations: If required calls postBatchMutate() CP hook and
        // complete mvcc for last writeEntry
        batchOp.completeMiniBatchOperations(miniBatchOp, writeEntry);
        writeEntry = null;
        success = true;
    } finally {
          // Call complete rather than completeAndWait because we probably had error if walKey != null
          if (writeEntry != null) mvcc.complete(writeEntry);
          
          ......
    }
｝
```

writeMiniBatchOperationsToMemStore 方法把 writeEntry apply 到 memstore 以后，调用 completeMiniBatchOperations 提升 readpoint，如果期间发生错误，对于已经构造完成的 writeEntry 仍然需要利用它提升 region 的 readpoint。

在读取流程中会构造 RegionScannerImpl 对象，RegionScannerImpl 会在初始化时候设置 scanner 的 readpoint。

```Java
// synchronize on scannerReadPoints so that nobody calculates
// getSmallestReadPoint, before scannerReadPoints is updated.
IsolationLevel isolationLevel = scan.getIsolationLevel();
long mvccReadPoint = PackagePrivateFieldAccessor.getMvccReadPoint(scan);
synchronized (scannerReadPoints) {
  if (mvccReadPoint > 0) {
    this.readPt = mvccReadPoint;
  } else if (nonce == HConstants.NO_NONCE || rsServices == null
      || rsServices.getNonceManager() == null) {
    this.readPt = getReadPoint(isolationLevel);
  } else {
    this.readPt = rsServices.getNonceManager().getMvccFromOperationContext(nonceGroup, nonce);
  }
  scannerReadPoints.put(this, this.readPt);
}
```

HBase 只支持 READ_COMMITTED 和 READ_UNCOMMITTED 两个隔离级别，没有指定隔离级别或者是 READ_UNCOMMITTED，这里的 readpoint 就会被设置成 Long.MAX_VALUE，表示未写入完成可以被读到。

```Java
public long getReadPoint(IsolationLevel isolationLevel) {
  if (isolationLevel != null && isolationLevel == IsolationLevel.READ_UNCOMMITTED) {
    // This scan can read even uncommitted transactions
    return Long.MAX_VALUE;
  }
  return mvcc.getReadPoint();
}
```

RegionScannerImpl 构造完成后，需要对 KeyValueScanner 初始化，scanner 包含 memstore、StoreFiles、snapshot，可以看出无论是那个 scanner 都需要使用 readPt 来决定可见范围。

```Java
public StoreScanner(HStore store, ScanInfo scanInfo, Scan scan, NavigableSet<byte[]> columns,
  long readPt) throws IOException {
    scanners = selectScannersFrom(store,
      store.getScanners(cacheBlocks, scanUsePread, false, matcher, scan.getStartRow(),
        scan.includeStartRow(), scan.getStopRow(), scan.includeStopRow(), this.readPt));
  ｝
```

在 scan 操作时候，也就是对 KeyValueScanner 执行 next 方法，也就是调用 StoreFileScanner 的 next 方法，可以发现如果有 MVCC 信息，是需要根据 ReadPoint 跳过一些数据。

```Java
@Override
public Cell next() throws IOException {
  Cell retKey = cur;

  try {
    // only seek if we aren't at the end. cur == null implies 'end'.
    if (cur != null) {
      hfs.next();
      setCurrentCell(hfs.getCell());
      if (hasMVCCInfo || this.reader.isBulkLoaded()) {
        skipKVsNewerThanReadpoint();
      }
    }
  } catch (FileNotFoundException e) {
    throw e;
  } catch (IOException e) {
    throw new IOException("Could not iterate " + this, e);
  }
  return retKey;
}
```

skipKVsNewerThanReadpoint 方法中，不断的对 cell 执行 next 操作，直到找一个 SequenceId 小于等于 readpoint 的 cell，cell 的 SequenceId 就是 writepoint，当 mvcc 的 complate 后就会变成 region 的 readpoint

```Java
protected boolean skipKVsNewerThanReadpoint() throws IOException {
  // We want to ignore all key-values that are newer than our current
  // readPoint
  Cell startKV = cur;
  while (enforceMVCC && cur != null && (cur.getSequenceId() > readPt)) {
    boolean hasNext = hfs.next();
    setCurrentCell(hfs.getCell());
    if (
      hasNext && this.stopSkippingKVsIfNextRow && getComparator().compareRows(cur, startKV) > 0
    ) {
      return false;
    }
  }

  if (cur == null) {
    return false;
  }

  return true;
}
```

# 参考

- https://15445.courses.cs.cmu.edu/fall2021/notes/18-multiversioning.pdf
- [一篇讲透如何理解数据库并发控制（纯干货）](https://zhuanlan.zhihu.com/p/127274032)
- [Paper Reading：聊一聊MVCC](https://jiekun.dev/posts/mvcc/)
- [思辨|基于MVCC的分布式事务简介 - 墨天轮](https://www.modb.pro/db/394162)
