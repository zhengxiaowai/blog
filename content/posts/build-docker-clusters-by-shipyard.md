---
title: 使用 Shipyard 搭建 Docker 集群
date: 2016-01-26 16:47:44
categories: 
- 容器
tags:
---

Shipyard 是 docker web ui 的一种，能够可视化操作 docker，可以使用脚本一键搭建，这里主要的问题的 docker hub 被墙的问题。
Shipyard 的安装安装脚本能够自动部署节点和主机连接，方便搭建 docker 的集群环境。

<!--more-->

# Shipyard 的安装
[Shipyard](https://shipyard-project.com/) 主页中有 Shipyard 简单介绍，在 [部署](https://shipyard-project.com/docs/deploy/) 这节中有我们需要的内容。
Shipyard 的安装方式有：

- 自动安装
- 手动安装

先进入手动安装页面，找出并拉取需要的 images

```shell
# 这里使用 [daocloud](https://www.daocloud.io/) 的 docker hub缓存服务
$ dao pull rethinkdb
$ dao pull microbox/etcd
$ dao pull shipyard/docker-proxy
$ dao pull swarm 
$ dao pull shipyard/shipyard
```
拉取 images 完成后才能使用脚本一键安装（墙太厚）。

```shell
$ curl -sSL https://shipyard-project.com/deploy | bash -s
```
会自动安装，默认会在 8080 端口启动 Shipyard，使用 http://IP:8080 即可访问，假如想修改启动的端口可以设置 ```PORT``` 环境变量。

```shell
$ curl -sSL https://shipyard-project.com/deploy | PORT=6969 bash -s
```

接着配置你的 Nginx 让他有个吊炸天的域名

```nginx
server{
        listen 80;

        server_name www.docker.domain .cc;
        server_name docker.domain.cc;

        access_log /var/log/nginx/docker.domain.com.access.log;
        error_log /var/log/nginx/docker.domain.com.error.log;

        gzip on;
        gzip_min_length 10k;
        gzip_buffers 16 64k;
        gzip_http_version 1.1;
        gzip_comp_level 6;
        gzip_types text/plain application/x-javascript text/css application/xml application/javascript;
        gzip_vary on;

        location / {
            proxy_set_header host $host;
            proxy_pass http://localhost:8080;

        }
}
```
打开你最心爱的浏览器，输入你的域名或者 IP:HOST 既能看见登入页面了，默认的账号的 ```admin``` 密码是 ```shipyard```

![2016-07-07_00:53:08.jpg](http://7xtq0y.com1.z0.glb.clouddn.com/2016-07-07_00:53:08.jpg)

![2016-07-07_00:54:49.jpg](http://7xtq0y.com1.z0.glb.clouddn.com/2016-07-07_00:54:49.jpg)

![2016-07-07_00:56:04.jpg](http://7xtq0y.com1.z0.glb.clouddn.com/2016-07-07_00:56:04.jpg)


# 节点的部署

最终的目的的集群，Shipyard 的集群 swarm 这个官方的工具来实现的，在前面除了这个主要的工具意外，还有一个必要的服务发现

Shipyard 所支持的服务发现有 etcd、consul、zookeeper 三种，默认使用的是 etcd

部署节点还是使用刚刚的那些东西，一点也没有改变

找一台新机器，当然你有多个云主机那就更好了，没有的话使用虚拟机也是可以的，但是需要注意的 iptables 的配置

一样拉取前面的 images 到本地

```shell
$ dao pull microbox/etcd
$ dao pull shipyard/docker-proxy
$ dao pull swarm 
$ dao pull alpine
```
在这里搭建时候我使用在线脚本会找不到服务发现的主节点，但是把脚本下载下来就能正常安装。

```shell 
$ curl -sSL https://shipyard-project.com/deploy > docker.sh
$ export ACTION=node DISCOVERY=etcd://121.42.29.28:4001 && bash docker.sh                                                                                                       ~
```
这里的 ACTION 是指定脚本的安装方式为 node 安装，指定服务发现程序和 ip、port

运行成功后，我们还需要查看容器中得 log 看看成功注册

需要查看的是 NAMES 为 shipyard-swarm-manage 的容器

![2016-07-07_01:11:28.jpg](http://7xtq0y.com1.z0.glb.clouddn.com/2016-07-07_01:11:28.jpg)

如果出现如下信息说明成功注册上了

![2016-07-07_01:13:29.jpg](http://7xtq0y.com1.z0.glb.clouddn.com/2016-07-07_01:13:29.jpg)

好了打开你的 Shipyard 中 NODES 的面板你是不是发现了两个主机

![2016-07-07_01:14:58.jpg](http://7xtq0y.com1.z0.glb.clouddn.com/2016-07-07_01:14:58.jpg)

----

OK 结束了

