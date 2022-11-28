---
title: "CMU 15-445/645 Lecture 5: Buffer Pool"
date: 2022-11-28T10:39:27+08:00
draft: false
---

![img](/images/cmu-15-445-lecture5/0001.jpg)

Buffer pool 是由一组固定大小的 page 组成的内存区域，每个组成项称为 **frame** 。当 DBMS 想要获取一个 page 时候，会把这个 page 的副本填充到 frame。

如果 frame 中的 page 是不存在，需要先从 disk 中读取再填充到 frame。

![img](/images/cmu-15-445-lecture5/0002.jpg)

Page table 本质是一个 hash table 用于记录 page_id 和 buffer pool 中 page 的映射关系，也要维护每个 page 的一些额外元数据。

- Dirty flag：用于记录那些 page 已经被修改过

- Pin/Reference Counter：pin 可以暂时把 buffer pool 中相关的 page 不被移除，reference 记录着当前被使用的次数

- Latch：可能不止一个请求要获取 page，从 disk 加载到 buffer pool 中需要上锁，保证不被其他操作干扰

![img](/images/cmu-15-445-lecture5/0003.jpg)

从数据库角度来看 Locks 是高级抽象原语，可以暴露给用户使用，可以在事务等情况下使用，一般是具有回滚语意。Latches 是底层抽象原语言，用在维护数据库内部数据结构，数据操作等，一般不具有回滚语意。Latches 对于操作系统来说就是 Mutex，使用上也经常把 Mutex 当作 Latches 使用。

![img](/images/cmu-15-445-lecture5/0004.jpg)

**page directory** 是 page id 到 page 在数据库文件位置的映射，所有的改变必须要持久化到硬盘。**page table** 是 page id 到 buffer pool 中 frame 的映射，这是一个内存数据结构，不需要持久化到硬盘。

![img](/images/cmu-15-445-lecture5/0005.jpg)

内存分配策略可以分为全局策略和局部策略。全局策略针对所有查询生效，局部只针对特定查询生效，大多数系统都会有这两个策略，可以针对不同的查询做优化。

![img](/images/cmu-15-445-lecture5/0006.jpg)

优化 buffer pool 可以有这四种方式：

- Multiple buffer pools

- Pre-Fetching

- Scan Sharing

- Buffer Pool Bypass

![img](/images/cmu-15-445-lecture5/0007.jpg)

多个 buffer pool 可以方便做局部策略的控制，也可以避免 latch 竞争的情况以改善性能。

Approach #1: Object Id

- Record id = <ObjectId, PageId, SlotId>

- 通过嵌入 Record id 维护与对个 buffer pool 的映射关系

Approach #2: Hash

- Hash(page_id) % n 确定 buffer pool

这两种方式都很高效，代价也很低

![img](/images/cmu-15-445-lecture5/0008.jpg)

为了减少 buffer pool 从磁盘读取数据的过程，需要对在 buffer pool 中做 pre-fetching 操作，当 buffer pool 读取到 index-page1，同时又知道想要的 page 是 index-page3 和 index-page5 就可以提前读取放入 buffer pool 中。做这些都是有需要记录额外的信息去跟踪一个查询，OS 无法帮助我们完成（OS 虽然可以做，但是拿到的不是我们想要的），但是我们自己直到想要的 page 是哪些，就要根据记录的信息去识别出我需要的 page 以及相邻的 page 是哪些。

![img](/images/cmu-15-445-lecture5/0009.jpg)

如果两个 scan 需要扫过相同的数据部分，后来 scan 的 cursor 可以直接复用前一个 scan 的 cursor，被称为 scan sharing

![img](/images/cmu-15-445-lecture5/0010.jpg)

Q1 需要扫描全表求和，但是 cursor 到 page 3 时候 Q2 开始 scan 求全表的平均数。这时候 Q1 的 cursor 停在 page3，Q2 可以和 Q1 共享一个 cursor，page0-2 先暂时跳过先从 page3-5 中获取。这样就避免了短时间内多次从 disk 获取 page 的过程。 

当多个 scan 有可以复用的 page，采用 scan sharing 可以避免 buffer pool 中频繁淘汰需要的 page，对相同的 page 频繁从 disk 获取的过程。但是这种技术得失查询变得非常复杂，需要记录需要许多额外的信息，目前只有少数商业数据库有实现。

![img](/images/cmu-15-445-lecture5/0011.jpg)

大范围顺序 scan 时候会频繁淘汰 buffer pool 中 pages，这样会污染 buffer pool，也会带来不必要的开销。

![img](/images/cmu-15-445-lecture5/0012.jpg)

大多数对 disk 的操作都是通过 OS API，OS 对文件系统有自己的缓存机制。

当读取一个 page 时候，OS 会先放入 OS Page Cache，然后 DMBS 又会放入自己的 buffer pool 中，OS Page Cache 在这个场景下显得比较多余，大多数数据库选择自己的管理 Page，使用 direct I/O 可以绕过 OS Page Cache，更灵活的控制内存。

PostgreSQL 是个例外，虽然也有 buffer pool 但是比较小，他们选择让 OS 来管理 Page Cache，虽然会降低一点性能，他们认为这样可以减少对内存的维护。另一方面 MySQL、Oracle 会使用系统的所有内存，但是 PostgreSQL 不会。 

![img](/images/cmu-15-445-lecture5/0013.jpg)

当 buffer pool 装满以后，有新的 page 需要进来就必须逐出一些 page 腾出空间，这就是 buffer pool 的置换策略要做的事情，目标是：

1. 正确性：page 没有被用完不应该逐出

1. 准确性：被逐出的 page 是未来不太会被用的 page

1. 高效性：操作时候会由 latch，并不想使用复杂的算法找出被逐出的 page

1. 元数据过多：只记录必要的元数据，避免元数据比数据本身还大

![img](/images/cmu-15-445-lecture5/0014.jpg)

LRU 机制是最简单的一种机制，维护每个 page 访问的时间戳，使用时间戳对 page 进行排序移除时间最早的 page，比如可以使用一个 queue，每次访问后移动到队尾，每次空间不够逐出队首。

![img](/images/cmu-15-445-lecture5/0015.jpg)

CLOCK 是一种近似 LRU 的机制，但是不需要有时间戳，每个 page 有一个 reference bit，如果被访问过就设置成 1。

![img](/images/cmu-15-445-lecture5/0016.jpg)

所有的 page 被组成在一个带有旋转指针的圆形的 buffer 中，旋转过后检查 page 的 reference bit 是否被设置成 1，如果有就设置成 0，没有就逐出。

CLOCK 在某些时间内与 LRU 类似，但是整体上来看 CLOCK 的逐出机制比 LRU 激进，只要是在扫描周期内没有被访问过就被逐出，这对于点查的操作会更友好。

![img](/images/cmu-15-445-lecture5/0017.jpg)

无论是 LRU 还是 CLOCK 都有 sequential flooding 的问题：

1. 一个顺序 scan 会读取每一个 page

1. 每一个 page 又只能被使用一次

在这种场景下最近使用的 page 反而是最不需要

![img](/images/cmu-15-445-lecture5/0018.jpg)

Q1 查询把 page0 放入 buffer pool，Q2 顺序 scan 把 page1 和 page2 放入 buffer pool 但是到 page3 时候发现空间不够，于是把 page0 从 buffer pool 中移除，放入 page3。Q3 需要把 page 0 放入于是就移除了 page1。这里就发现最近使用的策略不太友好，对于 Q3 这样的查询需要不断地从 disk 中读取page。

![img](/images/cmu-15-445-lecture5/0019.jpg)

记录历史访问次数到达 K 次以后才会被缓存，移除时候查看第 K 次访问距离当前时间最远的那个。历史访问需要使用额外的数据结构来记录，历史访问记录也需要由相应的淘汰策略。

![img](/images/cmu-15-445-lecture5/00020.jpg)

使用私有 buffer pool 不影响全局的 buffer pool，PostgreSQL 维护了一个小型的 ring buffer 给 query 使用。

![img](/images/cmu-15-445-lecture5/0021.jpg)

频繁需要使用 page 应该提示 buffer pool 尽量不需要移除它们，它们大概率会被频繁使用，比如这里的 index-page0 和 index-page4。

![img](/images/cmu-15-445-lecture5/0022.jpg)

 如果改 page 被修改过就是 dirty page。

- FAST：如果不是 dirty page，可以直接从 buffer pool 中移除

- SLOW：如果是 dirty page，移除前必须要先写回磁盘确保被持久化了，才能移除

这里就需要有 trade-off，是要快速地为新来 page 提供空间，还是等待 dirty page 写回磁盘后让新 page 复用，如果等待 dirty page 写回那就最小需要两次 IO，一次写回一次读取。

![img](/images/cmu-15-445-lecture5/0023.jpg)

可以有一个后台线程不断地把 dirty page 写回 disk，然后标记它们为 clean，buffer pool 下次就可以直接移除它们，需要注意的是任何对 dirty page 的修改需要实现有一条日志记录。

![img](/images/cmu-15-445-lecture5/0024.jpg)

DBMS 中内存的使用不仅仅是 indexes 和 tuples，其他的 memory pool 根据实现的不同，不一定支持 disk 存储，比如：

- Sorting + Join Buffers 

- Query Caches 

- Maintenance Buffers 

- Log Buffers 

- Dictionary Caches

![img](/images/cmu-15-445-lecture5/0025.jpg)

总结，让 DBMS 管理内存会比 OS 管理的更好，可以针对不同的查询做出更好决策。
