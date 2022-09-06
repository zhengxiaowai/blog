---
title: "RocksDB WAL 单写者写入优化"
date: 2022-09-06T08:00:44+08:00
draft: false
---

# 背景

由于 WAL 需要有序写入，但是 RocksDB 的 DBImpl::Write 本身又是多线程并发，所以在调用 Write 时候有一个先后顺序的问题，一般的解决办法就是写入一个队列中，然后不断的从队列读取写入 WAL 中，这种方式比较低效，LevelDB 优化成把多个 Write 合并成一个 WriteBatch 写入 WAL 中，其他线程等待完成，RocksDB 使用自旋和自适应的 short-wait 进步一优化，使得 WAL 的写入效率进一步提高。

# LevelDB 实现

LevelDB 对这种情况做了一个简单优化，每次只有队头是真正的处理线程，对头会把队列中的其他待写入的内容合并成一个 WriteBatch 一次性写入 WAL 中，同时非对头线程会被 pthread_cond_wait 阻塞住，等待对头线程完成。

```c++
MutexLock l(&mutex_);
writers_.push_back(&w);
while (!w.done && &w != writers_.front()) {
  w.cv.Wait();
}
if (w.done) {
  return w.status;
}
```

完成了以后非队头只需要判断一下状态就可以返回了，这么一看确实提升了不少效率，每次 IO 对一个单点写入的来说都是比较重的操作，合并成一次写入极大解决的耗在 IO 的时间。

# pthread_cond_wait 存在的问题

虽然解决了 IO 的耗时，但是非队头线程会在各自的线程中 pthread_cond_wait 等待对头完成。几乎当前主流平台的 condition variable 都有虚假唤醒 （[Spurious wakeup](https://en.wikipedia.org/wiki/Spurious_wakeup)） 的问题，同样基于 futex 实现的 pthread_cond_wait 也有这个问题。

RocksDB 的 Contributor 测出从 FUTEX_WAIT 到 FUTEX_WAKE 的平均时间大约是 10 微妙左右，而且这个过程还没算上多次的虚假唤醒和上下文切换的时间，如果竞争激烈这个过程耗时还会增加，这对于非队头写入的等待线程来说会额外消耗不少的等待时间。

> 为什么会有虚假唤醒没有找到准确的答案，一种比较靠谱的说法就是如果一次唤醒过多的等待者，不如一口气全部唤醒，基本上 condition variable 的 wait 都被要求有额外的退出等待条件。

# RocksDB 实现

分析一下 pthread_cond_wait 有存在两个问题，锁唤醒需要时间和上下文切换需要时间。RocksDB 从这两方面入手分别使用 Busy Loop 解决锁和上下文切换的问题，如果 Busy Loop 解决不了就退化成 short-wait 解决锁的问题，最后的最后还是解决不了那就还是老方法直接等待。

## Busy Loop

刚进 `AwaitState` 函数就先阻塞 1 微妙，这里的 200 次是根据 Contributor 测出来的大致时间，跑在不同的机器上这个时间会有偏差。这里使用 `port::AsmVolatilePause()` 暂停当前线程，根据参考 1 中可以得知这段汇编一般使用在 spin-wait-loop 中，可以避免内存重排从而提高性能。

```C++
for (uint32_t tries = 0; tries < 200; ++tries) {
  state = w->state.load(std::memory_order_acquire);
  if ((state & goal_mask) != 0) {
    return state;
  }
  port::AsmVolatilePause();
}
```

每次循环都会检查一次状态是否完成，然后暂停一下再次检查。这个的手法就是利用阻塞行为不断的检查状态，这么做可以避免锁的问题和上下文切换，带来的副作用就是会增加 CPU 的使用率，利用较小的代价完成较重的操作。

## Short-Waits 

在第一步 Busy Loop 中很难保证所有的请求都被处理完成，就意味着需要更多的时间。第一步已经阻塞了线程调度，所以在第二步中需要使用 `std::this_thread::yield()` 主动让出线程的控制权，此时会发生上下文切换，但是不会有锁唤醒的问题。

实现上如果打开了参数 `max_yield_usec_` 就是 100，也就是说 short-wait 最多存在 100 微妙。同时第一次是否启用 short-wait  和 update_ctx 有关，第一次的 yield_credit 是 0，但是 update_ctx 有 1/256 之一为 true 依赖可以启用。如果再次拿回控制权时间大于 3 微妙被认为是耗时较多，3 次耗时较多以后会直接退出 short-wait。

```C++
if (max_yield_usec_ > 0) {
  // 1/256
  update_ctx = Random::GetTLSInstance()->OneIn(sampling_base);

  if (update_ctx || yield_credit.load(std::memory_order_relaxed) >= 0) {
    auto spin_begin = std::chrono::steady_clock::now();

    size_t slow_yield_count = 0;

    auto iter_begin = spin_begin;
    // 最长时间不超过 max_yield_usec_
    while ((iter_begin - spin_begin) <=
           std::chrono::microseconds(max_yield_usec_)) {
      // 让出线程使用权，阻塞在这里，再次获取控制权从这里开始
      std::this_thread::yield(); 

      state = w->state.load(std::memory_order_acquire);
      if ((state & goal_mask) != 0) {
        // success
        // would_spin_again 会增加 yield_credit
        would_spin_again = true;
        break;
      }

      auto now = std::chrono::steady_clock::now();
      if (now == iter_begin ||
          now - iter_begin >= std::chrono::microseconds(slow_yield_usec_)) {
        ++slow_yield_count;
        // kMaxSlowYieldsWhileSpinning = 3
        if (slow_yield_count >= kMaxSlowYieldsWhileSpinning) {
          update_ctx = true;
          break;
        }
      }
      iter_begin = now;
    }
  }
}
```

如果耗时真的就是比较长，short-wait 会导致超过 100 微妙失效，反而有了副作用，RocksDB 巧妙的实现为自适应的。下面的代码可以看出 yield_credit 被更新是条件是 update_ctx 为 true，update_ctx 只有在 slow_yield_count >= 3 时候或者 1/256 才会被设置为 true ，此时 yield_credit 才会更新。

```C++
if (update_ctx) {
  auto v = yield_credit.load(std::memory_order_relaxed);
  v = v - (v / 1024) + (would_spin_again ? 1 : -1) * 131072;
  yield_credit.store(v, std::memory_order_relaxed);
}
```

yield_credit 是一个成员变量，如果 short-wait 成功会增加 yield_credit 失败会减少 yield_credit，即使 yield_credit 为负数，还是会有 1/256 几率走 short-wait。

## Long-Waits

前面两种优化都不起作用的话，最后只能进行等锁了。short-wait 失败次数过多，也意味着耗时真的比较长，不如直接进行 long-wait 流程，等待锁的唤醒。

```C++
uint8_t WriteThread::BlockingAwaitState(Writer* w, uint8_t goal_mask) {
  w->CreateMutex();

  auto state = w->state.load(std::memory_order_acquire);
  assert(state != STATE_LOCKED_WAITING);
  if ((state & goal_mask) == 0 &&
      w->state.compare_exchange_strong(state, STATE_LOCKED_WAITING)) {
    std::unique_lock<std::mutex> guard(w->StateMutex());
    w->StateCV().wait(guard, [w] {
      return w->state.load(std::memory_order_relaxed) != STATE_LOCKED_WAITING;
    });
    state = w->state.load(std::memory_order_relaxed);
  }
  assert((state & goal_mask) != 0);
  return state;
}
```

# 参考

1. https://kernelmaker.github.io/Rocksdb_Study_1

1. http://mysql.taobao.org/monthly/2018/07/04/
