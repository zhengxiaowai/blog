---
title: 「译」5 种方法构建安全的 Django Admin
date: 2017-06-17 16:10:01
categories: 
- 翻译
tags:
- Python
- Django
---

[原文地址](https://hackernoon.com/5-ways-to-make-django-admin-safer-eb7753698ac8)

拥有越大权限，往往也就责任也越大。Django Admin 在拥有修改权限的同时应该要更加注意安全。

本文提供了 5 种方法来保护 Django Admin 避免来自认为的错误或者攻击者的攻击。

<!--more-->

![](https://static.zhengxiaowai.cc/ipic/2017-06-17-052316.jpg) 

## 改变 URL

每种框架都有自己的特殊标识，Django 也不例外。经验丰富的开发者、黑客、用户都可以通过查看 Cookie 和 Auth URL 来识别 Django Admin 的站点。

**一旦网站被识别出是 Django 构建的，攻击者很有可能尝试从 `/admin` 登录。**

为了增加获取访问权限的难度，推荐把 URL 改成更难猜到的地址。

在 url.py 中修改 admin 的 URL 地址。

```python
urlpatterns += i18n_patterns(
    url(r’^super-secret/’, admin.site.urls, name=’admin’),
)
```

把 `super-secert` 修改成你和你团队可以记住的地址。这就完成了第一步，虽然不是唯一的防御措施，但是确实一个好的开始。

## 从视觉上区分环境

用户和管理员不可避免的会犯错误。当有多种环境时候可以避免管理员在正式的环境中执行破坏性的操作，你可以有 development、QA、staging、production 等多种不同的环境。

为了减少发生错误的机会，可以在 admin 中清楚的显示不同的环境。

![](https://static.zhengxiaowai.cc/ipic/2017-06-17-053859.jpg)

首先你需要知道当前的环境是什么。可以在部署期间使用一个名为 `ENVIRONMENT_NAME` 的环境变量。再添加一个 `ENVIRONMENT_COLOR` 的环境变量来区分颜色。

将以上两个环境变量添加到 admin 的每个页面中，覆盖原先的基本模板。

```python
# app/templates/admin/base_site.html

{% extends "admin/base_site.html" %}
{% block extrastyle %}
<style type="text/css">
    body:before {
        display: block;
        line-height: 35px;
        text-align: center;
        font-weight: bold;
        text-transform: uppercase;
        color: white;
        content: "{{ ENVIRONMENT_NAME }}";
        background-color: {{ ENVIRONMENT_COLOR }};
    }
</style>
{% endblock %}
```

从 `settings.py` 中获取 `ENVIRONMENT` 变量，在模板的上下文处理中使用它们。 

```python
# app/context_processors.py
from django.conf import settings
def from_settings(request):
    return {
        'ENVIRONMENT_NAME': settings.ENVIRONMENT_NAME,
        'ENVIRONMENT_COLOR': settings.ENVIRONMENT_COLOR,
    }
```

在 `settings.py` 中注册上下文处理器。

```python
TEMPLATES = [{
    …
    'OPTIONS': {
        'context_processors': [
            …
            'app.context_processors.from_settings',
        ],
    …
    },
}]
```

现在打开 Django admin 时，应该可以看到顶部的指示器。

## 命名 admin 站点

如果拥有多个 Django 服务，admin 看起来全部是一样的，这很容易导致困惑。为了区分不同的 admin 可以修改标题：

```python
# urls.py

from django.contrib import admin
admin.site.site_header = ‘Awesome Inc. Administration’
admin.site.site_title = ‘Awesome Inc. Administration’
```

你会看到如下内容：

![](https://static.zhengxiaowai.cc/ipic/2017-06-17-055348.jpg)

更多的配置可以在 [文档](https://docs.djangoproject.com/en/1.11/ref/contrib/admin/#adminsite-attributes) 中查找。

## 从主站从分离 Django Admin

使用相同的代码，可以部署 Django 应用程序的两个实例，一个仅用于 admin，一个仅适用于其余的应用程序。

这个是有争议的，不像提示那样容易。实现往往取决于配置（例如，使用 gunicorn 或者 uwsgi），所以不做详细的介绍。

以下可能是想把 Django admin 分离出来的原因：

- **在 VPN（virtual private network）中部署 Django admin** —— 如果 admin 仅在内部使用，同时拥有 VPN，这会是一种很好的做法。
- **从主站中删除不必要的组件** —— 例如，在 Django admin 中使用了消息框架，但是在主站中没有使用。你可删除这个中间件。另一个认证的例子是，如果主站使用的基于 token 的认证 API 后端，则可以删除大量的模板配置，session 的 middleware 等，也可以删除从请求到响应中不必要的部分。
- **更强大的身份认证** —— 如果要加强 Django admin 安全性，可能会需要添加不同的身份认证机制。在不同的实例下使用不用配置会更加容易。

把 admin 从主站从分离出来，不干扰内部应用程序。把 admin 掺杂在其中只会是的部署更加复杂，对加强安全性没有好处。

## 添加双重方式认证（2FA）

双重方式认证现在非常受欢迎，很多网站开始使用这种选项。2FA 基于两种方式认证：

- **你知道什么** —— 通常是一个密码。
- **你有什么** —— 通常是移动应用程序每 30 秒生成一个随机数（如 Google 的 Authenticator）。

第一次注册时候通常会要求使用身份认证应用程序扫描某种条码，完成注册后会生成一次性的代码。

通常不推荐使用第三方包，但是在几个月前开始使用 [django-otp](https://pypi.python.org/pypi/django-otp) 在 admin 中实现了 2FA。它在 Bitbucket 上托管，所以你可能错过了。

我们可以很方便的使用：

```shell
pip install django-otp
pip install qrcode
```

将 django-otp 添加到已安装的应用程序和中间件中：

```python
# settings.py
INSTALLED_APPS = (
   ...
   ‘django_otp’,
   ‘django_otp.plugins.otp_totp’,
   ...
)
...
MIDDLEWARE = (
   ...
   ‘django.contrib.auth.middleware.AuthenticationMiddleware’,
   ‘django_otp.middleware.OTPMiddleware’,
   ...
)
```

命名发行人 - 这是用户在认证时候看到的名称，可以通过这个区分。

```python
# settings.py

OTP_TOTP_ISSUER = ‘Awesome Inc.’
```

将 2FA 身份验证添加到管理站点：

```python
# urls.py

from django_otp.admin import OTPAdminSite
admin.site.__class__ = OTPAdminSite
```

现在你有如下所示安全的管理页面：

![](https://static.zhengxiaowai.cc/ipic/2017-06-17-063229.jpg)

需要添加新用户时，从 Django admin 从创建一个「TOTP 设备」。点击完成 QR 链接后，将会看到如下屏幕：

![](https://static.zhengxiaowai.cc/ipic/2017-06-17-063411.jpg)

可以使用用户的个人认证设备扫描二维码，每个 30 秒回生成一个新的代码。

## 最后的话

构建一个安全的 Django admin 只需要多多注意，文中的一些提示很容易实现，但是还有很多需要去做的。
