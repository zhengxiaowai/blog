---
title: 设计模式 —— 工厂方法
date: 2016-12-03 16:37:36
categories: 
- 总结
tags:
---

工厂方法是处理不指定对象具体类型情况下创建对象的问题。

>定义一个创建对象的接口，但让实现这个接口的类来决定实例化哪个类。工厂方法让类的实例化推迟到子类中进行。

<!--more-->

在面向对象程序设计中，工厂是一个用来创建对象的对象，是构造方法的抽象。

工厂对象一般拥有多个创建对象的方法，工厂对象可以通过参数动态创建类，可以针对不同的创建对象，进行特殊的配置。

>下列情况可以考虑使用工厂方法模式：
- 创建对象需要大量重复的代码。
- 创建对象需要访问某些信息，而这些信息不应该包含在复合类中。
- 创建对象的生命周期必须集中管理，以保证在整个程序中具有一致的行为。

```python
def create_win_button(button_name):
    # do something for win
    return '{} win button created'.format(button_name)


def create_mac_button(button_name):
    # do something for mac
    return '{} mac button created'.format(button_name)


class ButtonFactory(object):
    def create(self, button_name):
        raise NotImplementedError


class WinButtonFactory(ButtonFactory):
    def create(self, button_name):
        return create_win_button(button_name)


class MacButtonFactory(ButtonFactory):
    def create(self, button_name):
        return create_mac_button(button_name)


if __name__ == '__main__':
    win_button_factory = WinButtonFactory()
    mac_button_factory = MacButtonFactory()

    show_button_on_win = win_button_factory.create('show')
    close_button_on_mac = win_button_factory.create('close')

    print(show_button_on_win, close_button_on_mac)
```

创建实例过程不一定使用单独的创建类，通常可以使用静态方法。当使用这种方式时，构造方法经常被设置成私有的，强制使用工厂方法的对象。

> Python 中没有私有的概念，一般用下划线表示私有

```python
from collections import namedtuple
from math import cos, sin, pi

# 禁止「构造函数 _create()」导出
__all__ = [
    'ComplexCreator'
]

Complex = namedtuple('Complex', 'x y')


def _create(a, b):
    return Complex(a, b)


class ComplexCreator(object):
    @staticmethod
    def from_cartesian_factory(real, imaginary):
        return _create(real, imaginary)

    @staticmethod
    def from_polar_factory(modulus, angle):
        return _create(modulus * cos(angle), angle * sin(modulus))


if __name__ == '__main__':
    cartesian_complex = ComplexCreator.from_cartesian_factory(3, 4)
    polar_complex = ComplexCreator.from_polar_factory(5, pi)

    print(cartesian_complex, polar_complex)
```

也可以利用动态语言 Function First 的特点，在工厂中根据合适的信息创建需要的对象。

```python
__all__ = [
    "image_reader_factory"
]


def gif_reader(image_file_path):
    return 'gif reader created'


def jpeg_reader(image_file_path):
    return 'jpeg reader created'


def image_reader_factory(image_file_path):
    reader = None
    if image_file_path.endswith('gif'):
        reader = gif_reader(image_file_path)
    elif image_file_path.endswith('jpeg'):
        reader = jpeg_reader(image_file_path)
    else:
        raise ValueError('invalid image type')

    return reader

if __name__ == '__main__':
    gif = image_reader_factory('hexiangyu.gif')
    jpeg = image_reader_factory('zhengxiaowai.jpeg')

    print(gif, jpeg)
```

工厂方法有三个局限性：

1. 重构会破坏客户端代码，因为会把标准创建类设置为私有的不允许调用
2. 工厂方法所实例化的类具有私有的构造方法（Python没这个问题）
3. 如果扩展工厂类，那么子类必须有自己的一套实现，否则会调用父类的方法


## Reference
- 维基百科 [工厂方法](https://zh.wikipedia.org/wiki/%E5%B7%A5%E5%8E%82%E6%96%B9%E6%B3%95)