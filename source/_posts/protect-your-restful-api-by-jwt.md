---
title: 使用 JWT 让你的 RESTful API 更安全
date: 2016-11-26 16:46:42
categories: 
- 总结
tags:
---

传统的 cookie-session 机制可以保证的接口安全，在没有通过认证的情况下会跳转至登入界面或者调用失败。

在如今 RESTful 化的 API 接口下，cookie-session 已经不能很好发挥其余热保护好你的 API 。

更多的形式下采用的基于 Token 的验证机制，JWT 本质的也是一种 Token，但是其中又有些许不同。

<!--more-->

## 什么是 JWT ？

JWT 及时 JSON Web Token，它是基于 [RFC 7519](https://tools.ietf.org/html/rfc7519) 所定义的一种在各个系统中传递***紧凑***和***自包含***的 JSON 数据形式。

- ***紧凑（Compact）*** ：由于传送的数据小，JWT 可以通过GET、POST 和 放在 HTTP 的 header 中，同时也是因为小也能传送的更快。
- ***自包含（self-contained）*** :  Payload 中能够包含用户的信息，避免数据库的查询。



JSON Web Token 由三部分组成使用 ```.``` 分割开：

- Header
- Payload
- Signature

一个 JWT 形式上类似于下面的样子：

```
xxxxx.yyyy.zzzz
```

### Header

Header 一般由两个部分组成：

- alg
- typ

alg 是是所使用的 hash 算法例如 HMAC SHA256 或 RSA，typ 是 Token 的类型自然就是 JWT。

```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

然后使用 Base64Url 编码成第一部分。

```jwt
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.<second part>.<third part>
```

### Payload

这一部分是 JWT 主要的信息存储部分，其中包含了许多种的声明（claims）。



Claims 的实体一般包含用户和一些元数据，这些 claims 分成三种类型：*reserved*, *public*, 和 *private* claims。



- ***（保留声明）reserved claims***  ：预定义的 [一些声明](http://www.iana.org/assignments/jwt/jwt.xhtml)，并不是强制的但是推荐，它们包括 **iss** (issuer), **exp** (expiration time), **sub** (subject),**aud** (audience) 等。

  > 这里都使用三个字母的原因是保证 JWT 的紧凑

- ***（公有声明）public claims*** : 这个部分可以随便定义，但是要注意和 [IANA JSON Web Token](http://www.iana.org/assignments/jwt/jwt.xhtml) 冲突。

- ***（私有声明）private claims*** : 这个部分是共享被认定信息中自定义部分。



一个 Pyload 可以是这样子的：

```json
{
  "sub": "1234567890",
  "name": "John Doe",
  "admin": true
}
```

这部分同样使用 Base64Url 编码成第二部分。

```jwt
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWV9.<third part>
```

### Signature

在创建该部分时候你应该已经有了 编码后的 Header 和 Payload 还需要一个一个秘钥，这个加密的算法应该 Header 中指定。



一个使用  HMAC SHA256 的例子如下:

```jet
HMACSHA256(
  base64UrlEncode(header) + "." +
  base64UrlEncode(payload),
  secret)
```

这个 signature 是用来验证发送者的 JWT 的同时也能确保在期间不被篡改。

所以，做后你的一个完整的 JWT 应该是如下形式：

```jwt
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWV9.TJVA95OrM7E2cBab30RMHrHDcEfxjoYZgeFONFh7HgQ
```

> 注意被 ```.``` 分割开的三个部分

## JSON Web Token 的工作流程

在用户使用证书或者账号密码登入的时候一个 JSON Web Token 将会返回，同时可以把这个 JWT 存储在local storage、或者 cookie 中，用来替代传统的在服务器端创建一个 session 返回一个 cookie。

![](https://static.zhengxiaowai.cc/ipic/2017-01-21-165643.jpg)
当用户想要使用受保护的路由时候，应该要在请求得时候带上 JWT ，一般的是在 header 的 **Authorization** 使用 **Bearer** 的形式，一个包含的 JWT 的请求头的 Authorization 如下：

```
Authorization: Bearer <token>
```

这是一中无状态的认证机制，用户的状态从来不会存在服务端，在访问受保护的路由时候回校验 HTTP header 中 Authorization 的  JWT，同时 JWT 是会带上一些必要的信息，不需要多次的查询数据库。



这种无状态的操作可以充分的使用数据的 APIs，甚至是在下游服务上使用，这些 APIs 和哪服务器没有关系，因此，由于没有 cookie 的存在，所以在不存在跨域（CORS, Cross-Origin Resource Sharing）的问题。

## 在 Flask 和 Express 中使用 JSON Web Token

JWT 在各个 Web 框架中都有 JWT 的包可以直接使用，下面使用 Flask 和 Express 作为例子演示。

- [Flask-JWT](https://pythonhosted.org/Flask-JWT/)
- ​

下面会使用 [httpie](https://github.com/jkbrzt/httpie) 作为演示工具：

```shell
HTTPie: HTTP client, a user-friendly cURL replacement.

- Download a URL to a file:
    http -d example.org

- Send form-encoded data:
    http -f example.org name='bob' profile-picture@'bob.png'

- Send JSON object:
    http example.org name='bob'

- Specify an HTTP method:
    http HEAD example.org

- Include an extra header:
    http example.org X-MyHeader:123

- Pass a user name and password for server authentication:
    http -a username:password example.org

- Specify raw request body via stdin:
    cat data.txt | http PUT example.org
```

### Flask 中使用 JSON Web Token

这里的演示是 ```Flask-JWT``` 的 Quickstart内容。

安装必要的软件包：

```shell
pip install flask
pip install Flask-JWT
```

一个简单的 DEMO：

```python
from flask import Flask
from flask_jwt import JWT, jwt_required, current_identity
from werkzeug.security import safe_str_cmp

class User(object):
    def __init__(self, id, username, password):
        self.id = id
        self.username = username
        self.password = password

    def __str__(self):
        return "User(id='%s')" % self.id

users = [
    User(1, 'user1', 'abcxyz'),
    User(2, 'user2', 'abcxyz'),
]

username_table = {u.username: u for u in users}
userid_table = {u.id: u for u in users}

def authenticate(username, password):
    user = username_table.get(username, None)
    if user and safe_str_cmp(user.password.encode('utf-8'), password.encode('utf-8')):
        return user

def identity(payload):
    user_id = payload['identity']
    return userid_table.get(user_id, None)

app = Flask(__name__)
app.debug = True
app.config['SECRET_KEY'] = 'super-secret'

jwt = JWT(app, authenticate, identity)

@app.route('/protected')
@jwt_required()
def protected():
    return '%s' % current_identity

if __name__ == '__main__':
    app.run()
```

首先需要获取用户的 JWT：

```shell
% http POST http://127.0.0.1:5000/auth username='user1' password='abcxyz'             ~
HTTP/1.0 200 OK
Content-Length: 193
Content-Type: application/json
Date: Sun, 21 Aug 2016 03:48:41 GMT
Server: Werkzeug/0.11.10 Python/2.7.10

{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZGVudGl0eSI6MSwiaWF0IjoxNDcxNzUxMzIxLCJuYmYiOjE0NzE3NTEzMjEsImV4cCI6MTQ3MTc1MTYyMX0.S0825N6IliQb65QoJfUXb3IGq-j9OVJpHBh-bcUz_gc"
}
```

使用 ```@jwt_required()``` 装饰器来保护你的 API

```python
@app.route('/protected')
@jwt_required()
def protected():
    return '%s' % current_identity
```

这时候你需要在 HTTP 的 header 中使用 ```Authorization: JWT <token>``` 才能获取数据

```shell
% http http://127.0.0.1:5000/protected Authorization:"JWT eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZGVudGl0eSI6MSwiaWF0IjoxNDcxNzUxMzIxLCJuYmYiOjE0NzE3NTEzMjEsImV4cCI6MTQ3MTc1MTYyMX0.S0825N6IliQb65QoJfUXb3IGq-j9OVJpHBh-bcUz_gc"
HTTP/1.0 200 OK
Content-Length: 12
Content-Type: text/html; charset=utf-8
Date: Sun, 21 Aug 2016 03:51:20 GMT
Server: Werkzeug/0.11.10 Python/2.7.10

User(id='1')
```

不带 JWT 的时候会返回如下信息：

```shell
% http http://127.0.0.1:5000/protected                                                ~
HTTP/1.0 401 UNAUTHORIZED
Content-Length: 125
Content-Type: application/json
Date: Sun, 21 Aug 2016 03:49:51 GMT
Server: Werkzeug/0.11.10 Python/2.7.10
WWW-Authenticate: JWT realm="Login Required"

{
    "description": "Request does not contain an access token",
    "error": "Authorization Required",
    "status_code": 401
}
```

### Express 中使用 JSON Web Token

Auth0 提供了 express-jwt 这个包，在 express 可以很容易的集成。

```shell
npm install express --save
npm install express-jwt --save
npm install body-parser --save
npm install jsonwebtoken --save
npm install shortid --save
```

本例子中只是最简单的使用方法，更多使用方法参看 [express-jwt](https://github.com/auth0/express-jwt)

```javascript
var express = require('express');
var expressJwt = require('express-jwt');
var bodyParser = require('body-parser');
var jwt = require('jsonwebtoken');
var shortid = require('shortid');

var app = express();

app.use(bodyParser.json());
app.use(expressJwt({secret: 'secret'}).unless({path: ['/login']}));
app.use(function (err, req, res, next) {
  if (err.name === 'UnauthorizedError') {
    res.status(401).send('invalid token');
  }
});


app.post('/login', function(req, res) {
  var username = req.body.username;
  var password = req.body.password;

  if (!username) {
    return res.status(400).send('username require');
  }
  if (!password) {
    return res.status(400).send('password require');
  }

  if (username != 'admin' && password != 'password') {
    return res.status(401).send('invaild password');
  }
  
  var authToken = jwt.sign({username: username}, 'secret');
  res.status(200).json({token: authToken});

});

app.post('/user', function(req, res) {
  var username = req.body.username;
  var password = req.body.password;
  var country = req.body.country;
  var age = req.body.age;

  if (!username) {
    return res.status(400).send('username require');
  }
  if (!password) {
    return res.status(400).send('password require');
  }
  if (!country) {
    return res.status(400).send('countryrequire');
  }
  if (!age) {
    return res.status(400).send('age require');
  }

  res.status(200).json({
    id: shortid.generate(),
    username: username,
    country: country,
    age: age
  })
})

app.listen(3000);
```

 ```express-jwt``` 作为 express 的一个中间件，需要设置 ```secret``` 作为秘钥，unless 可以排除某个接口。

默认的情况下，解析 JWT 失败会抛出异常，可以通过以下设置来处理该异常。

```javascript
app.use(expressJwt({secret: 'secret'}).unless({path: ['/login']}));
app.use(function (err, req, res, next) {
  if (err.name === 'UnauthorizedError') {
    res.status(401).send('invalid token');
  }
});
```

```/login``` 忽略的 JWT 认证，通过这个接口获取某个用户的 JWT

```javascript
% http POST http://localhost:3000/login username='admin' password='password' country='CN' age=22  
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 143
Content-Type: application/json; charset=utf-8
Date: Sun, 21 Aug 2016 06:57:42 GMT
ETag: W/"8f-iMzAS1K5StDQgtNnVSvqtQ"
X-Powered-By: Express

{
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwiaWF0IjoxNDcxNzYyNjYyfQ.o5RFJB4GiR28HzXbSptU6MsPwW1tSXSDIjlzn7erG0M"
}

```

不使用 JWT 的时候

```javascript
% http POST http://localhost:3000/user username='hexiangyu' password='password'       ~
HTTP/1.1 401 Unauthorized
Connection: keep-alive
Content-Length: 13
Content-Type: text/html; charset=utf-8
Date: Sun, 21 Aug 2016 07:00:02 GMT
ETag: W/"d-j0viHsPPu6FaNJ6cXoiFeQ"
X-Powered-By: Express

invalid token

```

使用 JWT 就可以成功调用

```javascript
% http POST http://localhost:3000/user Authorization:"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwiaWF0IjoxNDcxNzYyNjYyfQ.o5RFJB4GiR28HzXbSptU6MsPwW1tSXSDIjlzn7erG0M" username='hexiangyu' password='password' country='CN' age=22
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 66
Content-Type: application/json; charset=utf-8
Date: Sun, 21 Aug 2016 07:04:34 GMT
ETag: W/"42-YnGYuyDLxpVUexEGEcQj1g"
X-Powered-By: Express

{
    "age": "22",
    "country": "CN",
    "id": "r1sFMCUc",
    "username": "hexiangyu"
}

```

## Reference

- [JSON Web Token Introduction](https://jwt.io/introduction/)
- [IANA JSON Web Token](http://www.iana.org/assignments/jwt/jwt.xhtml)
- [Flask-JWT](https://pythonhosted.org/Flask-JWT/)
- [express-jwt](https://github.com/auth0/express-jwt) 