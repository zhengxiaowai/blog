---
title: 《Python 高级编程》读书笔记
date: 2015-08-01 16:54:46
categories: 
- 读书笔记
tags:
---

## 列表推导

在Python中总是要透着一种极简主义，这样才能显示出Python牛逼哄哄。所以Python语法中总是能写的短就写的短，这是Python的精髓。

列表推导就是为了简化列表生成，换一种说法就是用一行代码生成复杂的列表。

在C语言中你要生成一个0~100中偶数构成的数组你只能这么写：

```c
int array[50] = {};
for(int i = 0; i < 100; i++)
{
    if(0 == i % 2)
        array[i] = i;
}
```
一共用了5行，当然更多时候是6行。

Python也有这种土逼的写法，当然也有更牛逼的写法，你可以这样写：

```python
[i for i in xrange(100) if (i % 2) is 0]

```

Python的enmuerate内建函数十分有用，不仅能取元素还可以取序号
```python
>>> l = ['a', 'b', 'c', 'd']
>>> for i, e in enumerate(l):
...   print "{0} : {1}".format(i,e)
... 
0 : a
1 : b
2 : c
3 : d
>>> 

```

结合列表推导，可以写出很简洁的代码：
```python
>>> def handle_something(pos, elem):
...     return "{0} : {1}".format(pos, elem)
... 
>>> something = ["one", "two", "three", "four"]
>>> [handle_something(p, e) for p, e in enumerate(something)]
['0 : one', '1 : two', '2 : three', '3 : four']
>>>
```
**当要对序列中的内容进行循环处理时， 就应该尝试使用List comprehensions**

----

## 迭代器和生成器

迭代器是一种高效率的迭代方式，基于两个方法
- next  返回容器的下一个项目
- \_\_iter\_\_  返回迭代器本身

```python
>>> i = iter("abc")
>>> i.next()
'a'
>>> i.next()
'b'
>>> i.next()
'c'
>>> i.next()
Traceback (most recent call last):
  File "", line 1, in 
StopIteration
>>> 

```

在迭代器的最后，也就是没有对象可以返回的时候，就会抛出StopIteration异常，这个异常会被for捕获用作停止的条件。


要实现一个自定义的类迭代器，必须实现上面的两个两个方法，next用于遍历，\_\_iter\_\_用于返回。

```python
>>> class MyIterator(object):
...   def __init__(self, step):
...     self.step = step
...   def next(self):
...     if self.step == 0:
...         raise StopIteration
...     self.step -= 1
...     return self.step
...   def __iter__(self):
...     return self
... 
>>> for el in MyIterator(4):
...     print el
... 
3
2
1
0
>>> 

```
书中没有对这段程序详细说明，以下是我的理解
>流程是这样子的：
1. 首先初始化类传入4这个参数
2. 调用next方法， step - 1,返回 3，输出
3. 调用\_\_iter\_\_方法，返回self，也就是把self.step当作参数传入
4. 如此循环

### 2.2.1 生成器

对于yield的使用可以是程序更简单、高效。yield指令可以暂停一个函数返回结果，保存现场，下次需要时候继续执行。这个有点像函数的入栈和出栈的过程。但只是形式上相同罢了。

```python
>>> def fibonacii():
...     a, b = 0, 1
...     while True:
...         yield b
...         a, b = b, a + b
... 
>>> fib = fibonacii()
>>> fib.next()
1
>>> fib.next()
1
>>> fib.next()
2
>>> fib.next()
3
>>> [fib.next() for i in range(10)]
[5, 8, 13, 21, 34, 55, 89, 144, 233, 377]
>>> 
```
带有yield的函数不再是一个普通的函数，而是一个generator对象，可以保存环境，每次生成序列中的下一个元素。

>1. 书中没有说明生成器的原理，网上也没有很确定的说法，查阅资料后，个人理解是：当带有yield的函数生成的同时也会生成一个协程，这个协程用于保存yield的上下文，当再次代用该函数时候，切换到协程中取值。
>2. 书中提到“不必须提供使函数可停止的方法”，事实上说的也就是return。在yield函数中只能是**return**而且立马抛出StopIteration，不能是**return a**这样子的，否则抛出SyntaxError

这是抛出SyntaxError：

```python
>>> def thorwstop():
...     a = 0
...     while True:
...         if a == 3:
...             return a
...         a += 1
...         yield b
... 
  File "", line 7
SyntaxError: 'return' with argument inside generator

```

这是抛出StopIteration：

```python
>>> def thorwstop():
...     a = 0
...     while True:
...         if a == 3:
...             return
...         yield a
...         a += 1
>>>
>>> ts = thorwstop()
>>> ts.next()
0
>>> ts.next()
1
>>> ts.next()
2
>>> ts.next()
Traceback (most recent call last):
  File "", line 1, in 
StopIteration
>>> 
```

yield最大的用处的就要提供一个值的时候，不必事前得到全部元素，这样的好处不言而喻，省内存，效率高。这看起来和迭代器有些类似，但是要明确两点：

1. 迭代器必须要知道下一个迭代的对象是谁，也就是迭代的是一个已经知道的值
2. yield每次返回的可以是我们不知道的值，这个值可能是通过某个函数计算得出的


现在有这么一个应用场景：现在正在写一个股票软件，要获取某一只股票实时状态，涨了多少，跌了多少。这都是无法事先知道的，要通过函数实时获取，然后绘制的一个图上。
```python
>>> from random import randint
>>> def get_info():
...     while True:
...         a = randint(0, 100)
...         yield a
... 
>>> def plot(values):
...     for value in values:
...         value = str(value) + "%"
...         yield value
... 
>>> p = plot(get_info())
>>> p.next()
'88%'
>>> p.next()
'61%'
>>> p.next()
'0%'
>>> p.next()
'7%'
>>> p.next()
'6%'
>>> p.next()
'19%'
>>>
```

yield不仅能传出也可以传入，程序也是停在yield出等待参数传入，使用send方法可以传入：

```python
>>> def send_gen():
...     while True:
...         str = (yield)
...         print str
... 
>>> sg = send_gen()
>>> sg.next()
>>> sg.send("hello")
hello
>>> sg.send("python")
python
>>> sg.send("generator")
generator
>>> 
```

>send机制和next一样，但是yield将编程能够返回的传入的值。因而，这个函数可以根据客服端代码来改变行为。同时还添加了throw和close两个函数，以完成该行为。它们将向生成器抛出一个错误：
-  throw允许客户端代码传入要抛出的任何类型的异常
-  close的工作方式是相同的，但是会抛出一个特定的GeneratorExit

一个生成器模版应该由try、except、finally组成：
```python
>>> def fuck_generator():
...     try:
...         i = 0
...         while True:
...             yield "fuck {0}".format(i)
...             i += 1
...     except ValueError:
...         yield "catch your error"
...     finally:
...         print "fuck everthing, bye-bye"
... 
>>> gen = fuck_generator()
>>> gen.next()
'fuck 0'
>>> gen.next()
'fuck 1'
>>> gen.next()
'fuck 2'
>>> gen.throw(ValueError("fuck, fuck, fuck"))
'catch your error'
>>> gen.close()
fuck everthing, bye-bye
>>> gen.next()
Traceback (most recent call last):
  File "", line 1, in 
StopIteration
>>> 

```
----
### 协同程序
没看懂

----
### 生成器表达式

生成器表达式就是用列表推导的语法来替代yield，把[]替换成()。

```python
>>> iter = (i for i in range(10) if i % 2 == 0)
>>> iter.next()
0
>>> iter.next()
2
>>> iter.next()
4
>>> iter.next()
6
>>> iter.next()
8
>>> iter.next()
Traceback (most recent call last):
  File "", line 1, in 
StopIteration
>>> 

```
对于创建简单的生成器，使用生成器表达式，可以减少代码量。

----
### itertools模块

#### islice：窗口迭代器

返回一个子序列的迭代器，超出范围不执行。


>**itertools.islice(iterable, [start,] stop[, step])**
- iterable一个可迭代对象
- start开始位置
- stop结束位置
- step步长


```python
>>> from itertools import islice
>>> def fuck_by_step():
...   str = "fuck"
...   for c in islice(str, 1, None):
...     yield c
... 
>>> fuck = fuck_by_step()
>>> fuck.next()
'u'
>>> fuck.next()
'c'
>>> fuck.next()
'k'
>>> fuck.next()
Traceback (most recent call last):
  File "", line 1, in 
StopIteration
>>> 
```
islice函数就是从特定位置开始迭代，可以指定结束位置，范围为[), 可以指定步长。

#### tee： 往返式的迭代器

书中的例子，不能清楚表示tee的作用，有点看不懂的感觉。其实就是tee可以返回同一个迭代对象的多个迭代器，默认的2个。

```python
>>> from itertools import tee
>>> iter_fuck = [1, 2, 3, 4]
>>> fuck_a, fuck_b = tee(iter_fuck)
>>> fuck_a.next()
1
>>> fuck_a.next()
2
>>> fuck_a.next()
3
>>> fuck_a.next()
4
>>> fuck_a.next()
Traceback (most recent call last):
  File "", line 1, in 
StopIteration
>>> fuck_b.next()
1
>>> fuck_b.next()
2
>>> fuck_b.next()
3
>>> fuck_b.next()
4
>>> fuck_b.next()
Traceback (most recent call last):
  File "", line 1, in 
StopIteration
>>> 
```
----
#### groupby：uniq迭代器

groupby是对可迭代对象重复元素进行分组。

>itertools.groupby(iterable[, key])
- iterable一个可迭代的对象
- key处理函数，默认为标识处理

```python
>>>from itertools import groupby

>>>def compress(data):
...    return ((len(list(group)), name) for name, group in groupby(data))
...
>>>def combainator(iter_data):
...    string = ""
...    for t in iter_data:
...        string = string + str(t[0]) + str(t[1])
...    return string
...
>>>raw_str = "get uuuuuuuuuuuuup"
>>>com_str = combainator(compress(raw_str))
>>>print com_str
1g1e1t1 13u1p
>>>
```

## 装饰器
书缺一页。。。。

### 2.3.1 如何编写装饰器

无参数的通用模式：

```python
def mydecorator(function):
    def _mydecorator(**args, **kw):
        #do something
     
        res = function(*args, **kw)
        
        #do something
        return res
    return _mydecorator
```

有参数的通用模式：

```python
def mydecorator(arg1, arg2):
    def _mydecorator(function):
        def __mydecorator(*args, **kw)
            #do something
     
            res = function(*args, **kw)
        
            #do something
            return res
        return  __mydecorator
    return _mydecorator
```

#### 参数检查

```python
from itertools import izip

def check_args(in_=(), out=(type(None),)):
    def _check_args(function):
        def _check_in(in_args):
            chk_in_args = in_args
            if len(chk_in_args) != len(in_):
                raise  TypeError("argument(in) count is wrong")
            
            for type1, type2 in izip(chk_in_args, in_) :
                if type(type1) != type2:
                    raise TypeError("argument's(in) type is't matched")
        
        def _chech_out(out_args):
            if type(out_args) == tuple:
                if len(out_args) != len(out):
                    raise TypeError("argument(out) count is wrong")
            else:
                if len(out) != 1:
                    raise TypeError("argument(out) count is wrong")
                if not type(out_args) in out:
                    raise TypeError("argument's(out) type is't matched")        
        def __chech_args(*args):
            
            _check_in(args)
            
            res = function(*args)
            
            _chech_out(res)
            
            return res
        return __chech_args
    return _check_args


@check_args((int, int), )
def meth1(i, j):
    print i,j
 
@check_args((str, list), (dict, ))    
def meth2(v_str, v_list):
    return {v_str : 1}
if __name__ == "__main__":
    
    meth1(1, 1)
    meth2("1", [1,2,3])
```

#### 缓存

没看懂

```python
import time
import hashlib
import pickle


cache = {}

def is_obssolete(entry, duration):
    return time.time() - entry["time"] > duration

def compute_key(function, args, kw):
    key = pickle.dumps(function.func_name, args, kw)
    return hashlib.sha1(key).hexdigest()

def memoize(duration=10):
    def _memoize(function):
        def __memoize(*args, **kw):
            key = compute_key(function, args, kw)
            
            if(key in cache and not is_obssolete(cache[key], duration)):
                print "we got a winner"
                return cache[key]["value"]
            
            result =  function(*args, **kw)
        
            cache[key] = {"value":result,
                          "time":time.time()}
            
            return result
        return __memoize
    return _memoize

```

#### 代理

```python
#!/usr/bin/env python
# -*- coding: UTF-8 -*-

class User(object):
    def __init__(self, roles):
        self.roles = roles

class Unauthorized(Exception):
    pass
        

def protect(role):
    def _protect(function):
        def __protect(*args, **kw):
            
            user = globals().get("user")
            if user is None or role not in user.roles:
                raise Unauthorized("I won't tell you")
            return function(*args, **kw)
        return __protect
    return _protect        

@protect("admin")
def premession():
    print "premession ok"

if __name__ == '__main__':

    jack = User(("admin", "user"))
    bill = User(("user",))
```

#### 上下文提供者

在函数运行前后执行一些其他的代码，例如：写一个线程安全的程序。

```python
#!/usr/bin/env python
# -*- coding: UTF-8 -*-

from threading import RLock
lock = RLock()
def synchronized(function):
    def _synchronized(*args, **kw):
        lock.acquire()
        try:
            return function(*args, **kw)
        finally:
            lock.release()
    return _synchronized

if __name__ == '__main__':
    pass
```
----

## with 和 contextlib

程序中很多地方使用try...except...finally来实现异常安全和一些清理代码，应用场景有：
>- 关闭一个文件
- 释放一个锁
- 创建一个烂事的代码补丁
- 在特殊的环境中运行受保护的代码

with语句覆盖和这些场景，可以完美替代try...except...finally。

with协议中依赖的是**\_\_enter\_\_**和**\_\_exit\_\_**两个方法，任何类都一个实现with协议。

```python
#!/usr/bin/env python
# -*- coding: UTF-8 -*-

class File(object):
    def __init__(self, filename, mode):
        self.filename = filename
        self.mode = mode
    
    def __enter__(self):
        print 'entering this File class'
        self.fd = open(self.filename, self.mode)
        return self.fd
    
    def __exit__(self, exception_type, 
                 exception_value, 
                 exception_traceback):
        if exception_type is None:
            print 'without error'
        else:
            print "with a error({0})".format(exception_value) 
            
        self.fd.close()
        print 'exiting this File class'

```
**\_\_enter\_\_**和**\_\_exit\_\_**分别对应进入和退出时候的方法，**\_\_exit\_\_**还可以对异常进行捕捉，和try...except...finally的功能一模一样。

```python
if __name__ == '__main__':
    with File("1.txt", 'r') as f:
        print "Hello World"
```

输出信息为：

```python
'''
entering this File class
Hello World
without error
exiting this File class
'''
```

加上异常：

```python
if __name__ == '__main__':
    with File("1.txt", 'r') as f:
        print "Hello World"
        raise TypeError("i'm a bug")
```

输出信息为：

```
'''
entering this File class
Hello World
with a error(i'm a bug)
exiting this File class
Traceback (most recent call last):
  File "E:\mycode\Python\ѧϰ\src\with.py", line 28, in 
    raise TypeError("i'm a bug")
TypeError: i'm a bug
'''
```

**as**的值关键字取决于**\_\_enter\_\_**的返回值，例子中也就是打开的文件描述符。

### contextlib模块

标准库中contextlib模块就是用来增强with的上下文管理。其中最有用的是contextmanager，
这是一个装饰器，被该装饰器修饰的必须是以yield语句分开的**\_\_enter\_\_**和**\_\_exit\_\_**两部分的生成器。
yield之前的是**\_\_enter\_\_**中的内容，之后是**\_\_exit\_\_**中的内容。

```python
#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import contextlib

@contextlib.contextmanager
def talk():
    print "entering"
    try:
        yield 
    except Exception, e:
        print e;
    finally:
        print "leaving"


if __name__ == '__main__':
    with talk():
        print "do something."
        print "do something.."
        print "do something..."
```

输出是：

```python
'''
entering
do something.
do something..
do something...
leaving
'''
```

如果要使用**as**关键字，那么yield要返回一个值，就和**\_\_enter\_\_**的返回值一样。

在contextlib模块还有closing和nested：
有些函数或者类不支持with协议，句柄之类的并不会自己关闭，可以使用contextlib模块中的closing方法，自动调用close()方法

```python
#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import contextlib

class Work(object):
    def __init__(self):
        print "start to work"
    def close(self):
        print "close and stop to work"

if __name__ == '__main__':
    print "没有异常"
    with contextlib.closing(Work()) as w:
        print "working"
    
    print '-'*30
    print "有异常"
    try:
        with contextlib.closing(Work()) as w:
            print "working"
            raise RuntimeError('error message')
    except Exception, e:
        print e
```

输出为:

```python
'''
没有异常
start to work
working
close and stop to work
------------------------------
有异常
start to work
working
close and stop to work
error message
'''
```
可以看出无论是否执行成功都会调用close()方法。

nested的作用是可以同时打开多个with协议的语法。

在2.7之前：

```python
with contextlib.nested(open('fileToRead.txt', 'r'),
                       open('fileToWrite.txt', 'w')) as (reader, writer):
    writer.write(reader.read())
```

在2.7之后可以直接使用：

```python
with open('fileToRead.txt', 'r') as reader, \
        open('fileToWrite.txt', 'w') as writer:
        writer.write(reader.read())
```

## 子类化内建类型

内建类型object是所有内建类型的公共祖先。

当需要实现一个与内建类型十分类似的类时，可以使用例如**list、tuple、dict**这样的内建类型进行子类化。

可以继承父类中的方法在子类中使用，可以让内建类型适用在更多场景下,例如下面这个不能有重复元素的list：

```python
In [17]: class ListError(Exception):
   ....:     pass
   ....: 

In [18]: class SingleList(list):
   ....:     def append(self, elem):
   ....:         if elem in self:
   ....:             raise ListError("{0} aleady in SingleList")
   ....:         else:
   ....:             super(SingleList, self).append(elem)
   ....:             

In [19]: sl = SingleList()

In [20]: sl.append('a')

In [21]: sl.append('b')

In [22]: sl.append('c')

In [23]: sl.append('a')
-----------------------------------------------------------------------
ListError                                 Traceback (most recent call l
 in ()
----> 1 sl.append('a')

 in append(self, elem)
      2     def append(self, elem):
      3         if elem in self:
----> 4             raise ListError("{0} aleady in SingleList")
      5         else:
      6             super(SingleList, self).append(elem)

ListError: {0} aleady in SingleList
```

----

## 访问超类中的方法

**super**是一个内建类型，用来访问属于某个对象的超类中的特性(attribute)

访问父类的方法有两种：
>1. super(子类名, self) . 父类方法()
2. 父类名 . 父类方法(self)

暂且称为super法和self法

先定义一个父类**Animal**

```python
In [35]: class Animal(object):
   ....:     def walk(self):
   ....:         print "Animal can walk"
   ....:     
```


**super**使用父类方法

```python
In [36]: class People(Animal):
   ....:     def fly(self):
   ....:         super(People, self).walk()
   ....:         print "People can fly"
   ....:         

In [37]: person = People()

In [38]: person.fly()
Animal can walk
People can fly

```

**self**

```python
In [40]: class People(Animal):
   ....:     def run(self):
   ....:         Animal.walk(self)
   ....:         print "People can run"
   ....:         

In [41]: person = People()

In [42]: person.run()
Animal can walk
People can run

```

其中super是新方法，对比下两种方法，关键的不同之处在于调用时候**self法使用父类名字，super法使用子类名字**。这就使得在多继承的时候super变的极其难用。

### 理解Python中方法解析顺序（MRO）

>Python2.3中添加了基于Dylan构建的MRO，即C3的一个新的MRO，它描述了C3构建一个类的线性化（也称优先级，即祖先的一个排序列表）的方法。这个列表被用于特性的查找


书中描述的很理论化，这个本身就是可很理想的假设，因为没有人会这么设计。

说白了，以前的MRO是深度优先，现在的是广度优先。

### super的缺陷

在Python中子类不会自动调用父类的**\_\_init\_\_**，所以手动的调用。

#### 混用super和传统调用

定义两个基类A、B：

```python
In [1]: class A(object):
   ...:     def __init__(self):
   ...:         print 'A'
   ...:         super(A, self).__init__()
   ...:         

In [2]: class B(object):
   ...:     def __init__(self):
   ...:         print 'B'
   ...:         super(B, self).__init__()
   ...:         

```

定义一个C类继承A、B：

```python
In [3]: class C(A, B):
   ...:     def __init__(self):
   ...:         print 'C'
   ...:         A.__init__(self)
   ...:         B.__init__(self)
   ...:   

```

这里在C类中使用super和基类使用传统调用，输出结果

```python
In [4]: print "MRO", [x.__name__ for x in C.__mro__]
MRO ['C', 'A', 'B', 'object']

In [5]: C()
C
A
B
B
Out[5]: <__main__.C at 0x7fd2457df810>

In [6]: 

```

输出了两次B，这不是我们想要的。把C类中改成super方法后就正常了

```python
In [6]: class C(A, B):
   ...:     def __init__(self):
   ...:         print 'C'
   ...:         super(C, self).__init__()
   ...:         

In [7]: print "MRO", [x.__name__ for x in C.__mro__]
MRO ['C', 'A', 'B', 'object']

In [8]: C()
C
A
B
Out[8]: <__main__.C at 0x7fd2457df390>

In [9]: 

```

#### 不同类型的参数

super的一个缺陷是，每个基类\_\_init\_\_的参数个数不同的话，怎么办？

```python
class A(object):
     def __init__(self):
         print 'A'
         super(A, self).__init__()
   
 class B(object):
     def __init__(self, arg):
         print 'B'
         super(B, self).__init__()        

class C(A, B):
     def __init__(self, arg):
         print 'C'
         super(C, self).__init__(arg)         
In [12]: c = C(10)
C
```

```
---------------------------------------------------------------------------
TypeError                                 Traceback (most recent call last)
 in ()
----> 1 c = C(10)

 in __init__(self, arg)
      2     def __init__(self, arg):
      3         print 'C'
----> 4         super(C, self).__init__(arg)
      5 

TypeError: __init__() takes exactly 1 argument (2 given)

```

从报出的错误中可以看出是多了一个参数，导致**\_\_init\_\_**调用失败。

一个妥协的方法就是使用\*args和\*\*kw,这样无论是一个还是两个，还是没有参数，都可以成功。但是这么做导致代码变的脆落。另一个解决的办法就是使用传统的**\_\_init\_\_**，这又会导致第一个问题。

```python
#!/usr/bin/env python
# -*- coding: UTF-8 -*-

class Base(object):
    def __init__(self, *args, **kw):
        print 'Base'
        super(Base, self).__init__()

class A(Base):
    def __init__(self, *args, **kw):
        print 'A'
        super(A, self).__init__(*args, **kw)
class B(Base):
    def __init__(self, *args, **kw): 
        print 'B'
        super(B, self).__init__(*args, **kw)
class C(A , B):
    def __init__(self, arg):
        print 'C'
        super(C, self).__init__(arg)

if __name__ == '__main__':
    C(10)

---------------------------------------
C
A
B
Base
```

书中的例子已经不能运行成功了，可能是版本更新的原因, object的\_\_init\_\_必须为空，否则会报出参数不对的错误。

## 最佳实践

- 应该避免多重继承， 使用一些设计模式替代
- super的使用必须一致， 在类层次结构中， 应该在所有地方使用super或者彻底不使用它。混用super和传统调用是一种混乱的方法， 人们倾向于避免使用super， 这样使代码更清晰。
- 不要混用老式和新式的类， 两者都具备的代码库将导致不同的MRO表现。
- 调用父类时必须检查类层次， 避免出现任何代码问题， 每次调用父类时， 必须查看一下所涉及的MRO（使用__mro__）

## 描述符和属性

Python没有private的关键字， 最接近的概念是“name mangling”， 就是在变量或者函数前面加上“\_\_”时，它就重命名。

```python
In [18]: class Class(object):
   ....:     __private_value = 1
   ....:     

In [19]: c = Class()

In [20]: c.__private_value
---------------------------------------------------------------------------
AttributeError                            Traceback (most recent call last)
 in ()
----> 1 c.__private_value

AttributeError: 'Class' object has no attribute '__private_value'

```
这样就和private很相似，找不到这个attribute。

查看一下该类的属性：

```python
In [21]: dir(Class)
Out[21]: 
['_Class__private_value',
 '__class__',
 '__delattr__',
 '__dict__',
 '__doc__',
 '__format__',
 '__getattribute__',
 '__hash__',
 '__init__',
 '__module__',
 '__new__',
 '__reduce__',
 '__reduce_ex__',
 '__repr__',
 '__setattr__',
 '__sizeof__',
 '__str__',
 '__subclasshook__',
 '__weakref__']

```

属性有有**'\_Class\_\_private_value'**这么一项。和原来的属性类似。

```python
In [22]: c._Class__private_value
Out[22]: 1

In [23]: c._Class__private_value = 2

In [24]: c._Class__private_value
Out[24]: 2

```
依旧可以访问，修改，所以这个只是换了一个名字而已。它的真正作用是用来避免继承带来的命名冲突，特性被重命名为带有类名前缀的名称。

在实际中从不使用"\_\_",而是使用"\_"替代。这个不会改变任何东西，只是标明这是私有的而已。

### 描述符

描述符用来自定义在引用一个对象上的特性时所应该完成的事情。它们是定义一个另一个类特性可能的访问方式的类。换句话硕，一个类可以委托另一个类来管理其特性。

描述符基于三个必须实现的特殊方法：

>- \_\_set\_\_    在任何特性被设置的时候调用，在后面是实例中，将其称为setter；
- \_\_get\_\_    在任何特性被读取的时调用（被称为getter）
- \_\_delete\_\_    在特性请求del时调用

>这些方法在\_\_dict\_\_特性之前被调用。

在类特性定义并且有一个getter和一个setter方法时，平常的包含一个对象的实例的所有元素的\_\_dict\_\_映射都将被劫持。

>- 实现了\_\_get\_\_ 和\_\_set\_\_ 的描述符被称作数据描述符
- 只实现了\_\_get\_\_的描述符被称为非数据描述符

在Python中，访问一个属性的优先级顺序按照如下顺序:
1. 类属性
2. 数据描述符
3. 实例属性
4. 非数据描述符
5. \_\_getattr\_\_()方法

下面先创建一个描述符，并实例一个：

```python
In [1]: class UpperString(object):
   ...:     def __init__(self):
   ...:         self._value = ''
   ...:     def __get__(self, object, type):
   ...:         return self._value
   ...:     def __set__(self, object, value):
   ...:         self._value = value.upper()
   ...:         

In [2]: class MyClass(object):
   ...:     attribute = UpperString()
   ...:     
```

类UpperString是一个数据描述符,通过它实例化了一个attribute，也就是说对attribute的get和set操作都会被UpperString描述符劫持。

```python
In [25]: mc = MyClass()

In [26]: mc.attribute
Out[26]: ''

In [27]: mc.attribute = "my value"

In [28]: mc.attribute
Out[28]: 'MY VALUE'
```

如果给实例子中添加一个新的特性，它将被保存在\_\_dict\_\_中

```python
In [29]: mc.new_att = 1

In [30]: mc.__dict__
Out[30]: {'new_att': 1}
```

数据描述符将优先于实例的\_\_dict\_\_

```python
In [35]: MyClass.new_att = UpperString()

In [36]: mc.__dict__
Out[36]: {'new_att': 1}

In [37]: mc.new_att
Out[37]: ''

In [38]: mc.new_att = "other value"

In [39]: mc.new_att
Out[39]: 'OTHER VALUE'

In [40]: mc.__dict__
Out[40]: {'new_att': 1}

```

对于非数据描述符，实例将优先于描述符

```python
class Whatever(object):
    def __get__(self, object, type):
        return "whatever"
    

MyClass.whatever = Whatever()

mc.__dict__
{'new_att': 1}

mc.whatever
'whatever'

mc.whatever = 1

mc.__dict__
{'new_att': 1, 'whatever': 1}
```

描述符除了隐藏类的内容以外还有：

- 内省描述符——这种描述符将检查宿主类签名，以计算一些信息
- 元描述符——这种描述符时类方法本身完成值计算

#### 内省描述符

内省描述符就是一种用于自我检查的通用描述符，也就是可以在多个不同的类使用的一种描述符，书中给的例子是类似dir方法的描述符，也就是列出类的属性。
这种描述符就是检查了类中有什么东西和没有什么东西。我也模仿书中例子，写一个类似dir的自省描述符。

```python
#!/usr/bin/env python
# -*- coding: UTF-8 -*-

class API(object):
    def __get__(self, obj, type):
        if obj is not None:
            return self._print_doc(obj)
        else:
            print "No method in {0}".format(obj)
        
    def _print_doc(self, obj):
        method_list = [method for method in dir(obj) if not method.startswith('_')]
        for m in method_list:
            print "{0} : {1}".format(m, m.__doc__)
            print '-'*50
        return "Thank you for looking API"

class MyClass():

    __doc__ = API()
    
    def __init__(self):
        ''' init MyClass '''
        pass
    
    def method1(self):
        '''print the msg for method1'''
        print "i'm method1"
    
    def method2(self):
        '''print the msg for method2'''
        print "i'm method2"
        
if __name__ == '__main__':
    mc = MyClass()
    print mc.__doc__
```

非数据描述符API只有一个\_\_get\_\_方法，用于获取。在非数据描述符API中的\_print\_doc方法中，过滤掉内置方法，打印出每个方法的doc。

```
"""
method1 : str(object='') -> string

Return a nice string representation of the object.
If the argument is a string, the return value is the same object.
--------------------------------------------------
method2 : str(object='') -> string

Return a nice string representation of the object.
If the argument is a string, the return value is the same object.
--------------------------------------------------
Thank you for looking API
"""
```
#### 元描述符

略难，看看即可

### 属性

> 属性（Propetry）提供了一个内建的描述符类型，它知道如何将一个特性链接到以组方法上。属性采用fget参数和3个可选参数——fset、fdel、和doc。最后一个参数可以提供用来定义一个链接到特性的docstring，就像是个方法一样。

这个propetry函数和前面的描述符基本类似，用参数来实现了描述符中的\__get__、\__set__、\__del__方法而已。

```python
#!/usr/bin/env python
# -*- coding: UTF-8 -*-

class MyClass(object):
    def __init__(self):
        print 'init a value = 10'
        self.value = 10;
    
    def get(self):
        print 'get a value'
        return self.value
    
    def set(self, value):
        print 'set value '
        self.value = value
    
    def ddel(self):
        print 'bye bye'
        self.value = 0

    my_value = property(get, set, ddel, "i'm a value")
    
if __name__ == '__main__':
    mc = MyClass()
    mc.my_value
    mc.set(50)
    del mc.my_value
```
输出为如下：
```
'''
init a value = 10
get a value
set value 
bye bye
'''
```

和之前的描述符的现象一模一样，property为描述符提供了简单的接口。
继承的时候会产生混乱，所创建的特性使用当前类创建，不应该在子类中重载。
```python
class Base(object):
    def _get_price(self):
        return "$ 500"
    price = property(_get_price)
    
class SubClass(Base):
    def _get_price(self):
        return "$ 20"
 
money = SubClass()
money.price
```
取得的是父类的方法，而不是子类的，这不是我们预期的。重载父类属性不是好的做法，重载自身属性更好一些。

```python
class Base(object):
    def _get_price(self):
        return "$ 500"
    price = property(_get_price)
    
class SubClass(Base):
    def _get_price(self):
        return "$ 20"
    price = property(_get_price)
    
money = SubClass()
money.price
```

## 槽

>几乎从未被开发人员使用过的一种有趣的特性是槽

嗯，没人用过

## 元编程

可以通过\__new__和\__metaclass__这两个特殊方法在运行时候修改类和对象的定义

### \__new__方法

\__new__是一个元构造程序，当一个对象被工厂类实例化时候调用。
```python
lass MyClass(object):
   def __new__(cls):
       print '__new__'
       return object.__new__(cls)
   def __init__(self):
       print '__init__'
  
nstance = MyClass()
```
>- \__new__方法是继承object中的\__new__方法，所以该类必须先继承object。
- \__new__的作用是返回一个实例化完成的类，就像程序中的instance，也可以是别的类。
- \__new__中的cls参数是要实例化的类，就是MyClass，也就是类中self
- \__new__的执行在\__init__之前

在实例化类之前，\__new__总是在\__init__之前执行完成更低层次的初始化工作，例如网络套接字或者数据库初始化应该在\__new__中为不是\__init__中控制。它在类的工作必须完成这个初始化以及必须被继承的时候通知我们。

### \__metaclass__方法

[廖雪峰关于元类的理解(ORM例子有点难)](http://www.liaoxuefeng.com/wiki/001374738125095c955c1e6d8bb493182103fac9270762a000/001386820064557c69858840b4c48d2b8411bc2ea9099ba000)
[深刻理解Python中的元类(metaclass)，强烈推荐](http://blog.jobbole.com/21351/)
元类提供了在类对象通过工厂方法在内存中创建时进行交互的能力，也就是动态的添加方法。内建类型type是内建的基本工厂，它用来生成指定名称、基类以及包含其特性的映射的任何类。

```python
klass = type('MyClass', (object,), {'method': method})

instance = klass()

instance.method()
```
Python中一切都是对象，包括创建对象的类，它实际上也是一个type对象。等价的类创建方法是：

```python

class MyClass(object):
    def method(self):
        return 1
    
instance = MyClass()
instance.method()
```

可以在类中显示的给__metaclass__赋值，所需要的是一个返回是type实例化后的类。如果某个类指定了__metaclass__，那么这个类将从__metaclass__中创建。
__metaclass__的特性必须被设置为:

- 接受和type相同的参数(类名， 一组基类，一个特性映射)
- 返回一个类对象

```python
def metaclass(classname, base_types, func_dicts):
    return type(classname, base_types, func_dicts)

class metaclass(object):
    __metaclass__ = metaclass
    def echo(self, str):
        print str

instance = MyClass()
instance.echo("Hello World")
```

元类的强大特性，可以动态的在已经实例化的类定义上创建许多不同的变化。原则上能不使用就不使用。


使用场景:

- 在框架级别，一个行为在许多类中是强制的时候
- 当一个特殊的行为被添加的目的不是诸如记录日志这样的类提供的功能交互时

引用一句话：
>当你需要动态修改类时，99%的时间里你最好使用上面这两种技术。当然了，其实在99%的时间里你根本就不需要动态修改类
 


 
