---
title: 搬瓦工 Shadowsocks 搭建
date: 2016-04-01 16:59:05
categories: 
- 其他
tags:
---
 
最近好像墙又厚了。。。
Shadowsocks 必须安利一下，利国利民的好东西。

<!--more-->

## 搬瓦工购买
登入搬瓦工[官网](https://bandwagonhost.com) ，目前搬瓦工有如下套餐：
![](http://7xtq0y.com1.z0.glb.clouddn.com/14623721191033.jpg)

如果只是搭建 Shadowsocks 推荐买最低配即可，有其他需要可按照自己的需求自行选配。
点击 **Order Now** 进入购买页面：
![](http://7xtq0y.com1.z0.glb.clouddn.com/14623725070706.jpg)
在 **Billing Cycle** 中可以选择购买服务器的时间，有一个月到一年，从 2.99\$ 到 19.9\$ 不等。
在 **Location** 中可以选择服务器的地址，推荐使用西海岸，因为海底光纤是连接到西海岸。
选择好以后点击 **Add to Cart**，如果没有账号登入会进入填写个人信息页面：
![](http://7xtq0y.com1.z0.glb.clouddn.com/14623725244726.jpg)
点击 **Complate Order** 或者是老用户的话会进入到付款页面：
![](http://7xtq0y.com1.z0.glb.clouddn.com/14623732805080.jpg)
点击 **Checkout** 会进入付款流程，其中可以选择支付宝支付，按照流程就可完成。

## 登入服务器
使用支付宝可以很方便的支付完成，购买完成以后点击 **Client Area** -> **Servers** -> **My Servers**，就可以看见你你购买的服务器。
![](http://7xtq0y.com1.z0.glb.clouddn.com/14624246868024.jpg)
图中红线位置就是你服务器的 IP 地址。
点击 **KiwiVM Control Panel** 进入控制面板。
![](http://7xtq0y.com1.z0.glb.clouddn.com/14624249109441.jpg)
默认的系统的 CentOS ，如果你就是 CentOS 的过可以跳过以下部分。
我 docker 在 CentOS 上表现不好，我需要把系统换成 Ubuntu 14.04。

换系统前需要在 **Main control** 中把实例 stop 掉。然后进入 **Install new OS** 中，选择新系统安装，等待两分钟即可，这时候会出现端口和密码记录下来。
![](http://7xtq0y.com1.z0.glb.clouddn.com/14624257591365.jpg)
到这里你就可以拿着 IP 地址、端口号、root 密码登入服务器了。

```shell
ssh root@ip -p 端口号
```

## 安装 Shadowsocks
>如果你使用的是默认的 CentOS 系统，找到控制面板的最下面，可以一键安装Shadowsocks。

以下是 Ubuntu 的教程。

```shell
apt-get update
apt-get install python-pip python-dev build-essential
pip install shadowsocks
```
假如使用使用配置文件启动 ```shadowsocks server``` 需要一个配置文件。

```shell
vim /etc/shadowsocks.conf
```

写入一下内容：

```json
{
    "server":"0.0.0.0",
    "server_port":50000,
    "local_port":1080,
    "password":"your password",
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open": false
}
```

```server_port``` 是连接的端口，可以指定你喜欢的。

启动 ```ssserver -c /etc/shadowsocks.conf -d start --log-file /var/log/shadowsocks.log```。

然后打开任意平台的 ```shadowsocks client ``` 连接即可，

使用 ```ssserver -d stop``` 可以停止。


如果你需要开放多个端口，配置文件需要这么写：

```json
{
    "server":"0.0.0.0",
    "local_port":1080,
    "port_password":{
         "20000":"your password",
         "20001":"your password",
         "20002":"your password",
         "20003":"your password",
         "20004":"your password"
    },
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open": false
}
```
## 加速你的 Shadowsocks
> 注意使用以下教程虽然会加速你的 Shadowsocks 但是会消耗双倍的流量，介意慎用

使用[net-speeder](https://github.com/snooda/net-speeder)在高延迟不稳定链路上优化单线程下载速度。

```shell
wget --no-check-certificate https://raw.githubusercontent.com/tennfy/debian_netspeeder_tennfy/master/debian_netspeeder_tennfy.sh 
bash debian_netspeeder_tennfy.sh
mvpeeder /usr/bin/
nohup /usr/bin/net_speeder venet0 "ip" >/dev/null 2>&1 &
```
OK 搞定

## 参考
- [新手用户搬瓦工VPS购买图文指导教程](http://banwagong.cn/gonglue.html)
- [搬瓦工教程之九：通过Net-Speeder为搬瓦工提升网速](http://banwagongvpn.lofter.com/post/1d541acc_7b4bfc0)
