---
title: 真正的 Tornado 异步非阻塞
date: 2017-01-29 16:26:41
categories: 
- 总结
tags:
---

其中 **Tornado** 的定义是 Web 框架和异步网络库，其中他具备有异步非阻塞能力，能解决他两个框架请求阻塞的问题，在需要并发能力时候就应该使用 **Tornado**。

但是在实际使用过程中很容易把 **Tornado** 使用成异步阻塞框架，这样对比其他两大框架没有任何优势而言，本文就如何实现真正的异步非阻塞记录。

<!--more-->

> 以下使用的 Python 版本为 2.7.13
>
> 平台为 Macbook Pro 2016

## 使用 gen.coroutine 异步编程

在 Tornado 中两个装饰器：

- tornado.web.asynchronous
- tornado.gen.coroutine

asynchronous 装饰器是让请求变成长连接的方式，必须手动调用 `self.finish()` 才会响应

```python
class MainHandler(tornado.web.RequestHandler):
    @tornado.web.asynchronous
    def get(self):
        # bad 
        self.write("Hello, world")
```

asynchronous 装饰器不会自动调用`self.finish()` ，如果没有没有指定结束，该长连接会一直保持直到 pending 状态。

![peding](https://static.zhengxiaowai.cc/ipic/2017-01-24-160529.jpg)

所以正确是使用方式是使用了 asynchronous 需要手动 finish

```python
class MainHandler(tornado.web.RequestHandler):
    @tornado.web.asynchronous
    def get(self):
        self.write("Hello, world")
        self.finish()
```

coroutine 装饰器是指定改请求为协程模式，说明白点就是能使用 `yield` 配合 Tornado 编写异步程序。

Tronado 为协程实现了一套自己的协议，不能使用 Python 普通的生成器。

在使用协程模式编程之前要知道如何编写 Tornado 中的异步函数，Tornado 提供了多种的异步编写形式：回调、Future、协程等，其中以协程模式最是简单和用的最多。

编写一个基于协程的异步函数同样需要 coroutine 装饰器

```python
@gen.coroutine
def sleep(self):
    yield gen.sleep(10)
    raise gen.Return([1, 2, 3, 4, 5])
```

这就是一个异步函数，Tornado 的协程异步函数有两个特点：

- 需要使用 coroutine 装饰器
- 返回值需要使用 `raise gen.Return()` 当做异常抛出

返回值作为异常抛出是因为在 Python 3.2 之前生成器是不允许有返回值的。

使用过 Python 生成器应该知道，想要启动生成器的话必须手动执行 `next()` 方法才行，所以这里的 coroutine 装饰器的其中一个作用就是在调用这个异步函数时候自动执行生成器。

使用 coroutine 方式有个很明显是缺点就是严重依赖第三方库的实现，如果库本身不支持 Tornado 的异步操作再怎么使用协程也是白搭依然会是阻塞的，放个例子感受一下。

```python
import time
import logging
import tornado.ioloop
import tornado.web
import tornado.options
from tornado import gen

tornado.options.parse_command_line()

class MainHandler(tornado.web.RequestHandler):
    @tornado.web.asynchronous
    def get(self):
        self.write("Hello, world")
        self.finish()


class NoBlockingHnadler(tornado.web.RequestHandler):
    @gen.coroutine
    def get(self):
        yield gen.sleep(10)
        self.write('Blocking Request')


class BlockingHnadler(tornado.web.RequestHandler):
    def get(self):
        time.sleep(10)
        self.write('Blocking Request')
        
def make_app():
    return tornado.web.Application([
        (r"/", MainHandler),
        (r"/block", BlockingHnadler),
        (r"/noblock", NoBlockingHnadler),
    ], autoreload=True)

if __name__ == "__main__":
    app = make_app()
    app.listen(8000)
    tornado.ioloop.IOLoop.current().start()
```

> 为了显示更明显设置了 10 秒

当我们使用 `yield gen.sleep(10)` 这个异步的 sleep 时候其他请求是不阻塞的。

![noblock](https://static.zhengxiaowai.cc/ipic/2017-01-24-noblock.gif)

当使用 `time.sleep(10)` 时候会阻塞其他的请求。

![block](https://static.zhengxiaowai.cc/ipic/2017-01-24-block.gif)

这里的异步非阻塞是针对另一请求来说的，本次的请求该是阻塞的仍然是阻塞的。

`gen.coroutine` 在 Tornado 3.1 后会自动调用 `self.finish()` 结束请求，可以不使用 `asynchronous` 装饰器。

所以这种实现异步非阻塞的方式需要依赖大量的基于 Tornado 协议的异步库，使用上比较局限，好在还是有一些可以用的[异步库](https://github.com/tornadoweb/tornado/wiki/Links)

## 基于线程的异步编程

使用 `gen.coroutine` 装饰器编写异步函数，如果库本身不支持异步，那么响应任然是阻塞的。

 在 Tornado 中有个装饰器能使用 `ThreadPoolExecutor` 来让阻塞过程编程非阻塞，其原理是在 Tornado 本身这个线程之外另外启动一个线程来执行阻塞的程序，从而让 Tornado 变得阻塞。

>futures 在 Python3 是标准库，但是在 Python2 中需要手动安装
>
>pip install futures

```python
import time
import logging
import tornado.ioloop
import tornado.web
import tornado.options
from tornado import gen
from tornado.concurrent import run_on_executor
from concurrent.futures import ThreadPoolExecutor

tornado.options.parse_command_line()

class MainHandler(tornado.web.RequestHandler):
    @tornado.web.asynchronous
    def get(self):
        self.write("Hello, world")
        self.finish()


class NoBlockingHnadler(tornado.web.RequestHandler):
    executor = ThreadPoolExecutor(4)
    
    @run_on_executor
    def sleep(self, second):
        time.sleep(second)
        return second
    
    @gen.coroutine
    def get(self):
        second = yield self.sleep(5)
        self.write('noBlocking Request: {}'.format(second))
        
def make_app():
    return tornado.web.Application([
        (r"/", MainHandler),
        (r"/noblock", NoBlockingHnadler),
    ], autoreload=True)

if __name__ == "__main__":
    app = make_app()
    app.listen(8000)
    tornado.ioloop.IOLoop.current().start()
```

`ThreadPoolExecutor` 是对标准库中的 threading 的高度封装，利用线程的方式让阻塞函数异步化，解决了很多库是不支持异步的问题。

![](https://static.zhengxiaowai.cc/ipic/2017-01-25-threadnoblock.gif)

但是与之而来的问题是，如果大量使用线程化的异步函数做一些高负载的活动，会导致该 Tornado 进程性能低下响应缓慢，这只是从一个问题到了另一个问题而已。

所以在处理一些小负载的工作，是能起到很好的效果，让 Tornado 异步非阻塞的跑起来。

但是明明知道这个函数中做的是高负载的工作，那么你应该采用另一种方式，使用 Tornado 结合 Celery 来实现异步非阻塞。

## 基于 Celery 的异步编程

> Celery 是一个简单、灵活且可靠的，处理大量消息的分布式系统，专注于实时处理的任务队列，同时也支持任务调度。

Celery 并不是唯一选择，你可选择其他的任务队列来实现，但是 Celery 是 Python 所编写，能很快的上手，同时 Celery 提供了优雅的接口，易于与 Python Web 框架集成等特点。

与 Tornado 的配合可以使用 [`tornado-celery`](https://github.com/mher/tornado-celery) ，该包已经把 Celery 封装到 Tornado 中，可以直接使用。

> 实际测试中，由于 tornado-celery 很久没有更新，导致请求会一直阻塞，不会返回
>
> 解决办法是：
>
> 1.  把 celery 降级到 3.1 `pip install celery==3.1`
> 2.  把 pika 降级到 0.9.14 `pip install pika==0.9.14`

```python
import time
import logging
import tornado.ioloop
import tornado.web
import tornado.options
from tornado import gen

import tcelery, tasks

tornado.options.parse_command_line()
tcelery.setup_nonblocking_producer()


class MainHandler(tornado.web.RequestHandler):
    @tornado.web.asynchronous
    def get(self):
        self.write("Hello, world")
        self.finish()


class CeleryHandler(tornado.web.RequestHandler):
    @gen.coroutine
    def get(self):
        response = yield gen.Task(tasks.sleep.apply_async, args=[5])
        self.write('CeleryBlocking Request: {}'.format(response.result))
    
            
def make_app(): 
    return tornado.web.Application([
        (r"/", MainHandler),
        (r"/celery-block", CeleryHandler),
    ], autoreload=True)

if __name__ == "__main__":
    app = make_app()
    app.listen(8000)
    tornado.ioloop.IOLoop.current().start()
```

```python
import os
import time
from celery import Celery
from tornado import gen

celery = Celery("tasks", broker="amqp://")
celery.conf.CELERY_RESULT_BACKEND = os.environ.get('CELERY_RESULT_BACKEND', 'amqp')

@celery.task
def sleep(seconds):
    time.sleep(float(seconds))
    return seconds

if __name__ == "__main__":
    celery.start()
```

![](https://static.zhengxiaowai.cc/ipic/2017-01-26-celeryblock.gif)

Celery 的 Worker 运行在另一个进程中，独立于 Tornado 进程，不会影响 Tornado 运行效率，在处理复杂任务时候比进程模式更有效率。

## 总结

| 方法            | 优点    | 缺点       | 可用性   |
| ------------- | ----- | -------- | ----- |
| gen.coroutine | 简单、优雅 | 需要异步库支持  | ★★☆☆☆ |
| 线程            | 简单    | 可能会影响性能  | ★★★☆☆ |
| Celery        | 性能好  | 操作复杂、版本低 | ★★★☆☆ |

目前没有找到最佳的异步非阻塞的编程模式，可用的异步库比较局限，只有经常用的，个人编写异步库比较困难。

推荐使用线程和 Celery 的模式进行异步编程，轻量级的放在线程中执行，复杂的放在 Celery 中执行。当然如果有异步库使用那最好不过了。

Python 3 中可以把 Tornado 设置为 asyncio 的模式，这样就使用 兼容 asyncio 模式的库，这应该是日后的方向。

# Reference

- http://www.tornadoweb.org/en/stable/
- https://github.com/mher/tornado-celery
- https://github.com/tornadoweb/tornado/wiki/Links