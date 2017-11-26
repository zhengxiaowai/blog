---
title: 玩玩微信小程序
date: 2016-10-05 16:42:50
categories: 
- 其他
tags:
---

微信小程序的一次简单尝试——一个[小程序版的 github](https://github.com/zhengxiaowai/weapp-github)

<!--more-->

主要实现了以下功能：
- Trending
- 你 start 过的 repo
- 个人信息和你自己的 repo
- 基于 basic 的登录

实现的 Trending 和官方的 Trending 不一样，因为 github 没有开放该接口，这里只是使用搜索功能做的一个在一周内创建同时 start 数量最多项目。

关于登录问题，由于小程序不能跳转外部链接，所以没法做 OAuth2 认证

starts 做了两分钟缓存

## 一些想说的

此次微信终于放出了小程序这个玩意，总体开发感觉还可以，就是 IDE 时不时崩溃几次。

整体代码写起来的感觉，和 React 差不多，没看过源码，不知道具体是怎么样子的。

在这个代码中，我使用了传统布局和 flex 两种方法，对 flex 支持还是很好了，布局起来也没什么难度。

有原生的 fetch 和 和 Promise 感觉棒棒哒

感觉需要改进的地方：

1. 增加对第三方库的支持，原生的 JS 功能有点弱
2. 无法跳转外部链接，这个比较麻烦了，说白了只能和微信对接，那就无法替代 H5 了
3. 文档还可可以的，但是最好要有一个不支持某某东西的列表

好吧，我只是一个后端 Python 工程师，客串一下小程序开发~~



## 目前还有的问题

1. 小程序的 picker 组件只能筛选 4 个，不知道程序 bug 还是组件本身的 bug bug
2. 在 starts 页面中使用语言筛选功能，只能对已经加载出来的筛选，同时 loading 也存在

## 截个图看看

gif 图片太大了，就用静态的看吧

这个是 Trending 页面的图

![](http://7xtq0y.com1.z0.glb.clouddn.com/2016-10-04-18%3A49%3A32.jpg)


这个是登录界面

![](http://7xtq0y.com1.z0.glb.clouddn.com/2016-10-04-18%3A50%3A35.jpg)

这个是个人信息和 repos 的图，请原谅我把私有的马赛克了

![](http://7xtq0y.com1.z0.glb.clouddn.com/2016-10-04-18%3A52%3A56.jpg)

这个是 startsstarts 页面的图，支持拉下更多

![](http://7xtq0y.com1.z0.glb.clouddn.com/2016-10-04-18%3A54%3A21.jpg)

## LICENSE

MIT