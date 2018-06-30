---
title: Python 如何传递运算表达式
date: 2018-04-02 23:54:25
categories: 
- 总结
tags:
---

首先要说明的一下，所描述的是 Python 中的 **运算表达式** 的部分，不是 Python 表达式的部分。

关于什么是 Python 中的运算表达式，可以参考 Python 文档 [10.3.1. Mapping Operators to Functions](https://docs.python.org/3/library/operator.html#mapping-operators-to-functions) 部分，所需要传递的就是这部分运算表达式。

<!--more-->

## 一个简单的问题

题目如下:

> 给定一个实数列表和区间，找出区间部分。

这个问题中有 2 个变量，一个是实数列表，一个区间。其中区间包含几种情况：

- 左开右开
- 左开右闭
- 左闭右开
- 左开右开

由于区间存在多种情况，无法通过一种固定的形式去描述这个区间。

假设左边界是 a，右边界是 b，列表中某个变量是 x，那么转换成区间关系就是：

- (a, b)：a < x < b
- (a, b]：a < x <= b
- [a, b)：a <= x < b
- [a, b]：a <= x <=b

那么如何使用一种优雅的方式获取这种运算关系，就是要解决的一个问题。

## 典型的应用

传递运算表达式在 Python 中最典型的应用在 ORM 上。

Python 调用关系型数据库基本上都是通过 [Database API](https://www.python.org/dev/peps/pep-0249/) 来实现的，查询数据依赖于 SQL，ORM 最大方便之一就是能生成查询所用的 SQL。

 非关系型数据库中有的 query 语句也支持条件查询，比如 AWS 的 Dynamodb。那么如何通过 ORM 来生成 query 语句也是一直重要的地方。

在 peewee 文档的 [Query operators](http://docs.peewee-orm.com/en/latest/peewee/querying.html#query-operators) 中可以看到这个 ORM 支持常用的操作符来表示字段和字段之间的关系。

> 文档中还用通过函数来表达关系，他们实质上是一样的，但是这个不在讨论范围之类

```python
# Find the user whose username is "charlie".
User.select().where(User.username == 'charlie')

# Find the users whose username is in [charlie, huey, mickey]
User.select().where(User.username << ['charlie', 'huey', 'mickey'])
```

从上面代码中可以看出用 `==` 来表示相等，用 `<<` 表示 IN。

## 解决方案

中心思想非常简单：**存储还原操作符与参数**

Python 所支持的操作符都可以通过重写魔法方法来重新实现逻辑，所以在魔法方法中已经可以拿到操作符和参数。

> 一元操作符和二元操作符都是如此。

所以，最开始那个问题可以分为两个步骤来完成。

第一步，存储操作符和参数，可以采用一个类重写相关操作符完成。

```python
class Expression:
    def __eq__(self, other):
        return Operator('==', other)

    def __lt__(self, other):
        return Operator('<', other)

    def __le__(self, other):
        return Operator('<=', other)

    def __gt__(self, other):
        return Operator('>', other)

    def __ge__(self, other):
        return Operator('>=', other)
```

第二步，还原操作符和参数。在 Operator 类中完成从操作符转化为函数的过程。

```python
import operator

class Operator:
    def __init__(self, operator_, rhs):
        self._operator = operator_
        self._rhs = rhs 
        self._operator_map = {
            '==': operator.eq,
            '<': operator.lt,
            '<=': operator.le,
            '>': operator.gt,
            '>=': operator.ge
        }

    @property
    def value(self):
        return self._rhs 

    @property
    def operator(self):
        return self._operator_map[self._operator]
```

一个 Operator 的实例就是一个运算表达式，可以自己定义操作符和函数的关系，来完成一些特殊的操作。

所以，有了 Expression 和 Operator，就能很优雅地解出最开始问题的答案

```python
def pick_range(data, left_exp, right_exp):
    lvalue = left_exp.value
    rvalue = right_exp.value
    
    loperator = left_exp.operator
    roperator = right_exp.operator
    
    return [item for item in data if loperator(item, lvalue) and roperator(item, rvalue)]
```

最后来几个测试用例

```Python
>>> exp = Expression()
>>> data = [1, 3, 4, 5, 6, 8, 9]
>>> pick_range(data, 1 < exp, exp < 6)
[3, 4, 5]
>>> pick_range(data, 1 <= exp, exp < 6)
[1, 3, 4, 5]
>>> pick_range(data, 1 < exp, exp <= 6)
[3, 4, 5, 6]
>>> pick_range(data, 1 <= exp, exp <= 6)
[1, 3, 4, 5, 6]
>>>
```

## 总结

关于传递运算表达式，知道的人会觉得简单，不知道的人一时间摸不着头脑。

Python 强大神秘，简约的逻辑中总是有复杂的背后支持，深入 Python 才能明白 Python 之美。

