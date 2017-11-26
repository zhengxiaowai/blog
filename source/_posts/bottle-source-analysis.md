---
title: Bottle 源码分析
date: 2017-05-21 16:20:12
categories: 
- 源码分析
tags:
---

Bottle 是一个快速，简单和轻量级的 WSGI 微型 Web 框架的 Python。它作为单个文件模块分发，除了 Python 标准库之外没有依赖关系。

选择源码分析的版本是 Release 于 2009 年 7 月 11 日的 0.4.10 （这是我能找到的最早的发布版本了）。

<!--more-->

为什么要分析 Bottle 这个比较冷门的框架？

- Bottle 从发布至今一直贯彻的微型 Web 框架的理念。
- Bottle 一直坚持单文件发布，也就是只有一个 bottle.py 文件。
- 除了 Python 标准库之外没有依赖关系。
- 与 Flask、Django 都遵循 PEP-3333 的 WSGI 协议。
- 0.4.10 版本代码量小，加上大量注释也只有不到 1000 行的代码。

所以，抛开框架的高级功能，单单从一个 Web 框架怎么处理请求的角度来看，Bottle 是最佳的选择。

> Flask 从第一版开始就是依赖于 werkzeug 实现，更多的实现细节需要从 werkzeug 中查找。
>
> Django 是个重型框架，不适合整体代码阅读，各个组件看看就可以。
>
> Tornado 是个异类，和 WSGI 没有什么关系。

在阅读之前最好从 Github 上下载一份 [0.4.10 版本的 Bottle](https://github.com/bottlepy/bottle/archive/0.4.10.zip) 的源码，边看边阅读本文。

阅读本文你需要有如下技能：

- 熟悉 Python 的语法
- 熟悉 HTTP 协议
- 至少使用过一种 WSGI 的框架
- 了解 CGI
- 看得懂中文

##  流程结构分析

代码虽然不多，但是毫无目的的看难免思绪混乱，会看的心烦意乱，甚至会有产生「写的这是什么鬼？」的想法。

一个 Web 框架最核心也是最基本的功能就是处理 **请求** 和 **响应**。

但是在这之前，需要先创建一个 Server，才能开始处理啊！

所以大体的流程如下：

1. 怎么创建一个 WSGI 的 Server 。
2. 怎么处理到来的请求。
3. 怎么处理响应。

## 创建 WSGI Server 

在 Bottle 中关于创建一个**标准**的 WSGI Server 涉及的类或者方法只有 3 个。

> 注意，这里只关心一个标准的 WSGI，和核心功能。包括注释、错误处理、参数处理，会统统删除。

从文档中可以看到 Bottle 是通过一个 run 方法启动的。

```python
def run(server=WSGIRefServer, host='127.0.0.1', port=8080, optinmize = False, **kargs):
    server = server(host=host, port=port, **kargs)
    server.run(WSGIHandler) 
```

WSGIRefServer 继承自 ServerAdapter，并且覆盖了 run 方法。

```python
class ServerAdapter(object):
    def __init__(self, host='127.0.0.1', port=8080, **kargs):
        self.host = host
        self.port = int(port)
        self.options = kargs

    def __repr__(self):
        return "%s (%s:%d)" % (self.__class__.__name__, self.host, self.port)

    def run(self, handler):
        pass

class WSGIRefServer(ServerAdapter):
    def run(self, handler):
        from wsgiref.simple_server import make_server
        srv = make_server(self.host, self.port, handler)
        srv.serve_forever()
```

这个 run 方法本身也是很简单，通过 Python 标准库中的 make_server 创建了一个 WSGI Server 然后跑了起来。

注意在 run 方法中的 WSGIHandler 和 WSGIRefServer.run 中的 handler 参数，这个就是如何处理一次请求和响应的关键所在。

在这之前，还需要先看看 Bottle 对 Request 和 Respouse 的定义。

##  Request 定义

Bottle 为每次请求都会把一些参数保存在当前的线程中，通过继承 `threading.local` 实现线程安全。

```python
class Request(threading.local):
    pass # 省略其他方法
```

Request 是由一个方法和 8 个属性构成。

```python
def bind(self, environ):
    """ 绑定当前请求到 handler 中 """
    self._environ = environ
    self._GET = None
    self._POST = None
    self._GETPOST = None
    self._COOKIES = None
    self.path = self._environ.get('PATH_INFO', '/').strip()
    if not self.path.startswith('/'):
        self.path = '/' + self.path
```

bind 方法除了初始化一些变量以外，还添加 environ 到本次请求当中，environ 是一个字典包含了 CGI 的环境变量，更多 environ 内容参考[PEP-3333 中 environ Variables 部分](https://www.python.org/dev/peps/pep-3333/#id24)。

```python
@property
def method(self):
    ''' 返回请求方法 (GET,POST,PUT,DELETE 等) '''
    return self._environ.get('REQUEST_METHOD', 'GET').upper()

@property
def query_string(self):
    ''' QUERY_STRING 的内容 '''
    return self._environ.get('QUERY_STRING', '')

@property
def input_length(self):
    ''' Content 的长度 '''
    try:
        return int(self._environ.get('CONTENT_LENGTH', '0'))
    except ValueError:
        return 0
```

这三个属性比较简单，只是从 _environ 中取出了CGI 的某个环境变量。

```python
@property
def GET(self):
    """ 返回字典类型的 GET 参数 """
    if self._GET is None:
        raw_dict = parse_qs(self.query_string, keep_blank_values=1)
        self._GET = {}
        for key, value in raw_dict.items():
            if len(value) == 1:
                self._GET[key] = value[0]
            else:
                self._GET[key] = value
    return self._GET
```

GET 属性把 query_string 解析成字典放入当前请求的变量中，所以在请求中获取 GET 方法的参数可以使用 `requst.GET['xxxx']` 这样子的用法。

```python
@property
def POST(self):
    """返回字典类型的 POST 参数"""
    if self._POST is None:
        raw_data = cgi.FieldStorage(
            fp=self._environ['wsgi.input'], environ=self._environ)
        self._POST = {}
        if raw_data:
            for key in raw_data:
                if isinstance(raw_data[key], list):
                    self._POST[key] = [v.value for v in raw_data[key]]
                elif raw_data[key].filename:
                    self._POST[key] = raw_data[key]
                else:
                    self._POST[key] = raw_data[key].value
    return self._POST
```

POST 属性从 wsgi.input 中获取内容（也就是表单提交的内容）放入当前请求的变量中，可以通过 `request.POST['xxxx']` 来获取数据。

从 GET 和 POST 这两属性的使用来看，包括 Flask 和 Django 都实现了类似的方法，这方法属性拥有一样的步骤就是获取数据，然后转换成标准的字典格式，实现上来看没什么复杂的，就是普通的字符串处理而已。

```python
@property
def params(self):
    ''' 返回 GET 和 POST 的混合数据，POST 会覆盖 GET '''
    if self._GETPOST is None:
        self._GETPOST = dict(self.GET)
        self._GETPOST.update(dict(self.POST))
    return self._GETPOST
```

params 属性提供了一个便利访问数据的方法。

```python
@property
def COOKIES(self):
    """Returns a dict with COOKIES."""
    if self._COOKIES is None:
        raw_dict = Cookie.SimpleCookie(self._environ.get('HTTP_COOKIE',''))
        self._COOKIES = {}
        for cookie in raw_dict.values():
            self._COOKIES[cookie.key] = cookie.value
     return self._COOKIES
```

Bottle 的 COOKIES 管理比较简单，只是单纯的从 CGI 中获取请求的 Cookie，如果存在的话直接返回。

以上就是 Bottle 的请求定义的内容。

简单总结来看，Request 从 CGI 中获取数据并且做一些数据处理，然后绑定到变量上。

## Response 定义

整体结构和 Resquest 大致一样。

```python
def bind(self):
    """ 清除旧数据并创建一个全新的响应对象 """
    self._COOKIES = None

    self.status = 200
    self.header = HeaderDict()
    self.content_type = 'text/html'
    self.error = None
```

bind 方法只是初始化了一些变量。其中比较有意思的是 HeaderDict。

```python
class HeaderDict(dict):
    def __setitem__(self, key, value):
        return dict.__setitem__(self,key.title(), value)
    def __getitem__(self, key):
        return dict.__getitem__(self,key.title())
    def __delitem__(self, key):
        return dict.__delitem__(self,key.title())
    def __contains__(self, key):
        return dict.__contains__(self,key.title())

    def items(self):
        """ 返回 (key, value) 形式的元组列表 """
        for key, values in dict.items(self):
            if not isinstance(values, list):
                values = [values]
            for value in values:
                yield (key, str(value))
                
    def add(self, key, value):
        """ 添加一个新 header，而不删除旧 header """
        if isinstance(value, list):
            for v in value:
                self.add(key, v)
        elif key in self:
            if isinstance(self[key], list):
                self[key].append(value)
            else:
                self[key] = [self[key], value]
        else:
          self[key] = [value]
```

这是一个扩展于 dict 的字典，转化成大小写无关的 Title key ，还可以以列表方式添加多个成员。这个 HeaderDict 有意思的地方有两个：

- 与大小无关的 Ttile key，也就是会吧 key 转成以大写头其他小写的 key
- 存储重复 kv 值时候 values 会以 list 形式存储。如果 values 是多层 list，会自动解析成一层数据。
- 重写 items 方法，以二元元组方式返回数据，包括多值数据。

```python
>>> h = HeaderDict()
>>> h.add('mytest', [['Test', ['test1', ['test2']]], {'name':'two'}])
>>> h
{'Mytest': ['Test', 'test1', 'test2', {'name': 'two'}]}
>>> print list(h.items())
[('Mytest', 'Test'), ('Mytest', 'test1'), ('Mytest', 'test2'), ('Mytest', "{'name': 'two'}")]
>>> 
```

```python
@property
def COOKIES(self):
    if not self._COOKIES:
        self._COOKIES = Cookie.SimpleCookie()
    return self._COOKIES

def set_cookie(self, key, value, **kargs):
    """ 设置 Cookie """
    self.COOKIES[key] = value
    for k in kargs:
        self.COOKIES[key][k] = kargs[k]
```

Response 对 Cookie 的初始化，并且提供了设置的方法。

```python
def get_content_type(self):
    return self.header['Content-Type']

def set_content_type(self, value):
    self.header['Content-Type'] = value
        
content_type = property(
    get_content_type,
    set_content_type,
    None,
    get_content_type.__doc__)
```

为 content_type 属性提供了 set 和 get 方法，针对的是 Header 中的  Content-Type。

## 添加路由和 handler

这部分由一个装饰器和三个方法组成。

- compile_route：路由正则
- add_route：添加路由
- route：路由装饰器

```python
def route(url, **kargs):
    def wrapper(handler):
        add_route(url, handler, **kargs)
        return handler
    return wrapper
```

路由装饰器，简化 add_route 的调用。

```python
def add_route(route, handler, method='GET', simple=False):
    method = method.strip().upper()
    if re.match(r'^/(\w+/)*\w*$', route) or simple:
        ROUTES_SIMPLE.setdefault(method, {})[route] = handler
    else:
        route = compile_route(route)
        ROUTES_REGEXP.setdefault(method, []).append([route, handler])
```

ROUTES_SIMPLE 和 ROUTES_REGEXP 是两个全局字典，用于存储路由相关数据（方法，参数，地址）。

简单路由放入 ROUTES_SIMPLE，以 method 为 key ，在 method 中再以路由地址为 key，处理函数 handler 为 value 存储。

复杂路由放入 ROUTES_REGEXP，以 method 为 key，以 route 和 handler 组成的元组列表存储。

## 处理请求和响应

根据 PEP-3333 文档需要为编写一个可调用对象（可以是函数，或者是具有 \_\_call\_\_ 方法的类）。

Bottle 中的 WSGIHandler 正是这么一个可调用对象。

```python
def WSGIHandler(environ, start_response):
    # 全局 request、response，每个线程独立
    global request
    global response
    
    # bind 当前 environ 数据
    request.bind(environ) 
    response.bind()
    try:
        # 根据 path 和 method 找到处理方法和参数
        handler, args = match_url(request.path, request.method)
        if not handler:
            raise HTTPError(404, "Not found")
        # 执行返回 output 数据
        output = handler(**args)
    except BreakTheBottle, shard:
        # Bottle 错误产生的输出
        output = shard.output
    except Exception, exception:
        # 处理内部错误，500 错误
        response.status = getattr(exception, 'http_status', 500)
        errorhandler = ERROR_HANDLER.get(response.status, error_default)
        try:
            output = errorhandler(exception)
        except:
            output = "Exception within error handler! Application stopped."

        if response.status == 500:
            request._environ['wsgi.errors'].write("Error (500) on '%s': %s\n" % (request.path, exception))

    db.close() # DB cleanup
	
    # 如果是文件，则发送文件
    if hasattr(output, 'read'):
        fileoutput = output
        if 'wsgi.file_wrapper' in environ:
            output = environ['wsgi.file_wrapper'](fileoutput)
        else:
            output = iter(lambda: fileoutput.read(8192), '')
    elif isinstance(output, str):
        output = [output]
	
    # 根据 response 的 cookie 添加 Set-Cookie 的 header
    for c in response.COOKIES.values():
        response.header.add('Set-Cookie', c.OutputString())

    # 完成本次处理
    status = '%d %s' % (response.status, HTTP_CODES[response.status])
    start_response(status, list(response.header.items()))
    return output
```

为了和代码契合度高，分析已经注释在当中。

处理流程如下：

1. 拿到线程独立的 request 和 response
2. bind environ 数据
3. 根据 match_url 找到处理的 handler 和参数，执行
   1. 处理 Bottle 错误
   2. 处理内部错误
4. 如果是文件则发送文件，不是的话正常返回字符串
5. 设置 Set-Cookie header
6. 结束

## 结束

Bottle 0.4.10 版本的核心内容就差么多，其他都是一些错误处理之类的。

该版本的 Bottle 以简单的过程，描述出了一个基于 WSGI 的 Web 框架是怎么样处理请求和响应的过程，完全基于 Python 标准库实现。

好哒，么么哒~~~，Python 大法好啊，Python 大法好啊，Python 大法好啊。