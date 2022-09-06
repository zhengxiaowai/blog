---
title: OrderedDict —— 双向循环列表的最佳实践
date: 2016-12-01 16:41:26
categories: 
- 源码分析
tags:
---


Python 字典插入操作是无序的，当需要一个有序的字典时需要使用 `OrderedDict`。

`OrderedDict` 是继承自 `dict` 的子类，它具有普通字典的一模一样操作（包括时间复杂度），同时在内部还维护一个 **双向循环链表** 作为有序化的基础。内部方法中除了，`__getitem__`, `__len__`, `__contains__` 和 `get` 之外方法都是具有顺序的。

## 初始化递归结构和哨兵节点


```python
def __init__(*args, **kwds):
    '''初始化一个有序字典，这个签名方法和普通字典一样，但是关键子参数是不被推荐的，
    这时候的插入将会是任意的。
    '''
    if not args:
        raise TypeError("descriptor '__init__' of 'OrderedDict' object "
                        "needs an argument")
    self = args[0]
    args = args[1:]
    if len(args) > 1:
        raise TypeError('expected at most 1 arguments, got %d' % len(args))
    try:
        self.__root
    except AttributeError:
        self.__root = root = []                     # 哨兵节点
        root[:] = [root, root, None]
        self.__map = {}
    self.__update(*args, **kwds)
```

不要使用关键字参数初始化，将无法保证顺序。

`OrderedDict` 中使用递归的的方式创建双向循环链表，`root[:] = [root, root, None]` 初始化
递归结构。

```python
>>> from pprint import pprint
>>>
>>> __root = root = []
>>> root[:] = [root, root, None]
>>>
>>> pprint(root)
[<Recursion on list with id=139932667492400>,
 <Recursion on list with id=139932667492400>,
 None]
>>> print id(root)
139932667492400
```
从代码中可以看出 id 在列表中递归存在，作为一个哨兵节点是开始和结束的标志，`self.__map = {}` 存储的将要插入的 KEY 和 VALUE。

## 添加双向链表元素

```python
def __setitem__(self, key, value, dict_setitem=dict.__setitem__):
    'od.__setitem__(i, y) <==> od[i]=y'
    # 创建一个新的元素插入在末尾,
    # 使用内部继承的字典更新键值对.
    if key not in self:
        root = self.__root
        last = root[0]
        last[1] = root[0] = self.__map[key] = [last, root, key]
    return dict_setitem(self, key, value)
```
递归的双向循环列表和普通的链表的插入操作区别不大，同时使用了哨兵节点，简化了插入操作
![](http://7xtq0y.com1.z0.glb.clouddn.com/rynsaF6Mg.png)

链表只维护 KEY 的顺序，仍然使用普通的字典存储，`__map` 存储每个节点的元素，该元素包括三个部分 PREV、NEXT、KEY。

## 删除双向链表元素

```python
def __delitem__(self, key, dict_delitem=dict.__delitem__):
    'od.__delitem__(y) <==> del od[y]'
    # 删除从 __map 中存在的 KEY
    # 删除节点，并且更新前置节点和后继节点的链接
    dict_delitem(self, key)
    link_prev, link_next, _ = self.__map.pop(key)
    link_prev[1] = link_next                        # update link_prev[NEXT]
    link_next[0] = link_prev                        # update link_next[PREV]
```

删除时候和普通链表一样把后继的和前驱的 NEXT 接上，把前驱和后继的 PREV接上
![](http://7xtq0y.com1.z0.glb.clouddn.com/S1wATK6fe.png)

## 遍历双向链表元素

双向循环的链表的遍历由于有递归的存在变得很简单，哨兵元素是开始和结束的标志

```python
def __iter__(self):
    'od.__iter__() <==> iter(od)'
    # 顺序遍历
    root = self.__root
    curr = root[1]                                  # 从第一元素开始
    while curr is not root:
        yield curr[2]                               # yield the curr[KEY]
        curr = curr[1]                              # 移动到后一个元素

def __reversed__(self):
    'od.__reversed__() <==> reversed(od)'
    # 逆序遍历.
    root = self.__root
    curr = root[0]                                  # 从最后一个元素开始
    while curr is not root:
        yield curr[2]                               # yield the curr[KEY]
        curr = curr[0]                              # 移动到前一个元素
```

`__iter__` 和 `__reversed__` 是顺序遍历和逆序遍历，遍历到一个节点后把当前元素指向下一个（前一个），直到哨兵元素位置为止。

## END

以上是 `OrderedDict` 的核心代码分析，其余的代码都是封装操作，和普通的 dict 相同，在调用的时候会触发以上的几个魔法方法，来维护一个双向循环列表保证其顺序。