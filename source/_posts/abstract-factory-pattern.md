---
title: 设计模式 —— 抽象工厂模式 
date: 2016-12-18 16:30:35
categories: 
- 总结
tags:
---

抽象工厂模式的实质是提供「接口」，子类通过实现这些接口来定义具体的操作。

这些通用的接口如同协议一样，协议本身定义了一系列方法去描述某个类，子类通过实现这些方法从而实现了该类。

子类中不用关心这个类该是什么样子的，这些都有抽象类去定义，这就区分设计类和实现类两个过程，实现过程的解耦。

<!--more-->

## 代码描述

描述一个这样的过程：有一个 GUIFactory，GUI 有 Mac 和 Windows 两种风格，现在需要创建两种不同风格的 Button，显示在 Application 中。

```python
class GUIFactory(object):
    def __init__(self):
        self.screen = None

    def set_screen(self):
        raise NotImplementedError

    def get_size_from_screen(self, screen):
        if self.screen == 'retina':
            return '2560 x 1600'

        elif self.screen == 'full_hd':
            return '1920 x 1080'
```

定义 Mac 和 Windows 两种风格的 GUI。

```python
class MacGUIFactory(GUIFactory):
    def __init__(self):
        super(MacGUIFactory, self).__init__()

    def set_screen(self):
        self.screen = 'retina' 

    def set_attributes(*args, **kwargs):
        raise NotImplementedError


class WinGUIFactory(GUIFactory):
    def __init__(self):
        super(WinGUIFactory, self).__init__()

    def set_screen(self):
        self.screen = 'full_hd' 

    def set_attributes(*args, **kwargs):
        raise NotImplementedError
```

所有 GUI 都需要设置屏幕的类型，否则在调用时候会抛出 `NotImplementedError` 的异常，抽象了设置 Button 属性的方法，让子类必须实现。 

```python
class MacButton(MacGUIFactory):
    def __init__(self):
        super(MacButton, self).__init__()
        self.set_screen()
        self.color = 'black'
    
    def set_attributes(self, *args, **kwargs):
        if 'color' in kwargs:
            self.color = kwargs.get('color') 

    def verbose(self):
        size = self.get_size_from_screen(self.screen) 
        print('''i am the {color} button of mac on {size} screen'''.format(
            color=self.color, size=size))


class WinButton(WinGUIFactory):
    def __init__(self):
        super(WinButton, self).__init__()
        self.set_screen()
        self.color = 'black'
    
    def set_attributes(self, *args, **kwargs):
        if 'color' in kwargs:
            self.color = kwargs.get('color') 

    def verbose(self):
        size = self.get_size_from_screen(self.screen) 
        print('''i am the {color} button of win on {size} screen'''.format(
            color=self.color, size=size))
```

实现创建不同平台 Button 的方法， 需要根据屏幕的大小创建不同尺寸的 Button，才能有更好的显示效果。

这样就分别实现了两种不同 Button 的创建，还可以封装一个 Button 类来管理这两个不同的 Button。

```python
class Button(object):
    @staticmethod
    def create(platform, *args, **kwargs):
        if platform.lower() == 'mac':
            return MacButton()        
        elif platform.lower() == 'win':
            return WinButton()
```

创建两个不同平台的 Button，并且设置颜色属性

```python
win_button = Button.create('win')
mac_button = Button.create('mac')

win_button.set_attributes(color='red')
mac_button.set_attributes(color='blue')

win_button.verbose()
# >> i am the red button of win on 1920 x 1080 screen
mac_button.verbose()
# >> i am the blue button of mac on 2560 x 1600 screen
```

## 适用范围

以下情况可以适用抽象工厂模式：

- 独立于系统的模块
- 系统中各大类的模块
- 需要强调设计和实现分离的时候
- 只想显示接口并不想实现的时候

## 优缺点

优点：

- 具体产品从客户代码中被分离出来
- 容易改变产品的系列
- 将一个系列的产品族统一到一起创建

缺点：

- 在产品族中扩展新的产品是很困难的，它需要修改抽象工厂的接口

## Reference

- [维基百科·中文版,抽象工厂模式](https://zh.wikipedia.org/wiki/%E6%8A%BD%E8%B1%A1%E5%B7%A5%E5%8E%82)


