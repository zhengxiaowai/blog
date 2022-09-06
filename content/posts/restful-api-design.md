---
title: 设计 RESTful API 指南
date: 2016-01-05 16:53:23
categories: 
- 总结
tags:
---


如今的 web 应用前后端相对的独立了，后端接收和返回一些交互数据，前后端也就这点联系了。。。

那么重点来了，其中的核心就是**怎么交互更合理、更方便，更简单**。

以前数据交互无非就是 SOAP 和 XML 两种形式，这两个东西写起来和HTML似的一堆标签，看了就恶心。牛逼的 JSON 能和操作字典一样操作数据，省时、省心、省力。所以 REST 使用 JSON 作为数据交互的标准是很合理的。

REST 的全称为 Representational State Transfer， 即是资源的**表现层状态转化**。作为一种协议而非标准，其强大的结构清晰、符合标准、易于理解、扩展方便的特点得到了广泛的使用。

**REST**的核心在于**资源**和**转化**，就是如何把资源进行转化，去设计API接口。一种资源例如 ** /image ** ，可以使用不同的 HTTP 方发对资源进行转化。HTTP 中有GET、POST、PUT、PATCH、DELETE、OPTION、HEAD等方法。利用这些方法对资源进行配置。

## 同一种资源

REST 设计中最核心莫过于**同一种资源** 。例如**/image**，在浏览器中可以通过**www.domain.com/image**访问该资源。

通过不同的请求方法实现增删改查

### 获取

通过GET方法获取图片: 

```
GET www.domain.com/image
```

### 删除

通过DELETE方法删除图片

```
DELETE www.domain.com/image
```

### 添加

通过POST方法在数据库中添加一个图片:

``` 
POST www.domain.com/image

Request (application/json)
    {
        "imageName" : "xxx.png",
        "imageData" : "base64 Code"
    }

Response 200 (application/json)
    {
        "imageId" : 1
    }
```

### 修改

```
PATCH www.domain.com/image

Request (application/json)
    {
        "imageId" : 1,
        "imageData" : "new base64 Code"
    }

Response 200 (application/json)
    {
        "isOK" : true
    }
```

## URL设计

URL 作为互联网中对服务器的唯一入口，一个好的 URL 可以很明确定位出这个 URL 是干嘛用的。

API接口单独放。

```
www.api.domain.com

wwww.domain.com/api
```

RESTful 的 URL 有讲究：

- 使用名词
- 尽量短
- 表达明确
- 可扩展
- 程序员体验度高



<br />

**名词、名词、名词的复数**。杜绝使用动词，动作全部靠 HTTP 方法完成

```
POST /addImage   ×

POST /images   √
```

冗余 URL 是十分排斥的，老子写程序本来就苦逼了，每次调试还有那么长的URL。

```
GET /images?imageID=1  ×

GET /images/1   √
```

表达明确，每次只表示一个资源

```
POST /imageAndTexts  ×

POST /images √
```

留给其他程序员一条后路，很重要。。。在一个评价信息中有N条具体的评价。

```
POST /reviewDetails   ×

POST /reviews  √
POST /details  √
```

## HTTP 方法不够用怎么办？

HTTP 方法毕竟有限，但是我们的需求又是千奇百怪。

假如需要一次性删除100条记录, 怎么办？

```
DELETE /records/{1...100}
```

这未免也太土了，连续请求100次也不合理。

对于这种情况可以使用 **/Resources/actions/actionName** 的格式，来满足。

```
POST /records/actions/delete100
```

## 错误返回

错误返回需要错误码和错误信息

```
{
    "code" : 1，
    "error" : "i am a error"
}
```



# 参考文章

- [理解RESTful架构](http://www.ruanyifeng.com/blog/2011/09/restful)
- [RESTful API 设计指南](http://www.ruanyifeng.com/blog/2011/09/restful)
- [RESTful API 设计最佳实践](http://blog.jobbole.com/41233/)

