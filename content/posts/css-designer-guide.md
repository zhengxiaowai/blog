---
title: CSS 设计指南读书笔记
date: 2015-11-01 16:39:51
categories: 
- 读书笔记
tags:
---


## 剖析CSS规则

给文档添加样式的方法有三种：**行内样式**、**嵌入样式**、**链接样式**。

1. **行内样式**
    
    直接写在属性里：
    ```html
    <p style="font-size: 14px; color: red;">我是一个内容</p>    
    ```
    行内样式只能影响所在的标签，而且还会覆盖嵌入样式和链接样式。

2. **嵌入样式**
    
    写在 `style` 标签中：
    ```html
    <!DOCTYPE html>
    <html>
    <head>
        <title></title>
        <style type="text/css">
            h1 {font-size: 15px;}
            p {color: red;}
        </style>
    </head>
    <body>
        <h1>我是h1标签</h1>
        <p>我是p标签</p>
    </body>
    </html>
    ```
    嵌入样式只适用于当前页面，会覆盖链接样式，同时会被行内样式覆盖。

3. **链接样式**

    写在 `link` 标签中：
    ```html
    <link rel="stylesheet" type="text/css" href="css/style.css">
    ```
    链接样式适用于全部网站，前提是要把他引入。会被行内样式和嵌入样式覆盖，同时会被下一个链接样式覆盖。

### CSS命名规则

CSS的规则由**选择符**和**声明符**两部分组成。
```css
p {color: red;}
```

- `p` 是选择符，选择了`p`标签
- `{color: red;}` 是声明符

选择符可以有：
- 上下文选择符
- ID和类选择符
- 属性选择符

声明符由三部分组成：

1. `{ }` 花括号包围
2. `color` 标签的一个属性
3. `red` 属性的一个值

有三种使用方法：

- 一条规则多个声明
```css
p {
    color: red;
    font-size: 14px;
    font-weight: bold;
}
```

- 多个属性选择符共用某些属性
```css
h1 h2 h3 {
    color: red;
    font-size: 14px;
    font-weight: bold;
}
```

- 对一个属性设置多次
```css
h1 h2 h3 {
    color: red;
    font-size: 14px;
    font-weight: bold;
}
h3 {font-style: italic;}
```

### 上下文选择符

格式：标签1 标签2 {声明}

多个标签用空格分隔，而不是逗号分隔。

假如有下面设个代码片段：

```css
<body>
    <article>
        <h1>Contextual selectors are <em>very</em> selective</h1>
        <p>This example shows how to target a <em>specific</em> tag.</p>
    </article>
    <aside>
        <p>Contextual selectors are <em>very</em> useful!</p>
    </aside>
    <footer>
    &copy;2015
    </footer>
</body>
```

要想把 `article` 下所有的 `em` 变成红色:

```css
article em {
    color: red;
}
```
只要是在 `article` 下的所有 `em` 标签都会有影响，无论在什么地方。但是 `aside` 下的 `em` 标签没有影响。


#### 子选择器

格式： 标签1 > 标签2 > ... {声明}

```css
article > h1 > em {
    color: blue;
}
```
每级的标签必须有父子关系，就像 `article` 是 `h1` 的父元素，`h1是` 的 `em` 父元素。

#### 紧邻同胞选择器

格式：标签1 + 标签2 + ... {声明}

```css
h1 + p {
    color: blue;
}
```
只会影响 `article` 中的 `h1` 和 `p`, 因为他们是同胞元素而且 `p` 紧跟着 `h1`。

#### 一般同胞选择器

格式： 标签1 ~ 标签2 ~ ... {声明}

```css
article ~ footer{
    text-align: center;
}
```
`article` 和 `footer` 同胞元素就可以。

#### 通用选择符

`*` 代表所有元素

```css
* {
    padding: 0px;
    margin: 0px;
}
```
取消所有元素的内外边距。

```css
article * em {
    color:red;
}
```
只要 `em` 是祖父元素是 `article` 就会被设置成红色，无论父元素是什么。

### ID和类选择器

对于每个标签都可为它设置一个ID或者多个类。

#### 类属性

**格式： .类名**

```html
<h1 class="specialtext">
    This is a heading with the <span>same class</span> as the second paragraph.
</h1>

<p>
    This tag has no class.
</p>

<p class="specialtext featured"> 
    When a tag has a class attribute, you can target it <span>regardless</span> of its position in the hierarchy.
</p>
```

- 类选择符

```css
.specialtext {
    color: red;
}
```

选择 `class="specialtext"` 的标签设置前景色为红色。

- 标签带类选择符

```css
p.specialtext {
    color: blue;
}
```

选择所有类名为 `specialtext` 的p标签。

- 多类选择符

```css
.specialtext.featured {
    color: balck;
}
```
选择 类名同时为 `specialtext` 和 `featured` 的标签。

#### ID选择器

ID作为一个独一无二的存在，不能重复，使用方法了类选择器一样。例外，ID选择器可以作为页面内的跳转标记。

```html
<ul>
    <li><a href="#paragraph1">第一段</a></li>
    <li><a href="#paragraph2>第二段</a></li>
    <li><a href="#paragraph3>第三段</a></li>
</ul>
```
点击可以跳转到id为 `paragraph1` 的段落，`#`默认回到顶部。

#### 何时使用类选择器和ID选择器

- 给页面独一无二的元素使用ID选择器，比如一个主布局 `<div id="main"></div>`
- 拥有相同类型的元素使用类选择器，比如操作一个显示热门商品的列表。

### 属性选择器

**格式： 标签名[属性名]**

```html
<img src="images/yellow_flower.jpg" title="yellow flower" alt="yellow flower" />
```

可以选择拥有 `title` 属性的元素

```css
img[title] {border:4px solid green;}
```

也可以选择 `title` 的值为 `yellow flower` 的元素

```css
img[title="yellow flower"] {border:4px solid green;}
```

### 伪类

以下所有伪类只是常用的，更多伪类信息参考[点击这里] (http://www.stylinwithcss.com)

伪类分成两种

1. UI 伪类，在 HTML 元素处于某个状态下应用样式
2. 结构化伪类，在某种关系结构上应用样式

#### UI伪类

- 链接伪类

    1. :link：等待点击时候
    2. :visited：点击过之后
    3. :hover：鼠标悬停时候
    4. :active：正在被点击时候
    
    使用时候顺序以上顺序，要不然可能会因为特指度问题导致失败。

    可以应用到任何元素，不仅仅是 a 标签

- :focus 伪类

    当元素获取焦点时候，也就是鼠标点击的时候

    ```css
    input:focus{border: 1px solid blue;}
    ```

- :target 伪类

    当点击一个跳转到其他页面的链接，那个带有链接的元素就是 target,可以用伪伪类选中

    点击以下链接
    ```html
    <a href="#more_info">More Information</a>
    ```
    跳转到
    ```html
    <h2 id="more_info">This is the information you are looking for.</h2>
    ```
    使用伪类设置 target 的样式
    ```css
    #more_info:target {background:#eee;}
    ```

#### 结构化伪类

结构化伪类可以根据标签的结构来指定样式

- :first-child 和 last-chile

    把一组同胞元素的第一个和最后一个设置样式

    ```html
    <ol class="results">
        <li>My Fast Pony</li>
        <li>Steady Trotter</li>
        <li>Slow Ol' Nag</li>
    </ol>
    ```

    ```css
    ol.results li:last-child {color:red;}
    ```

    最后一个 li 被设置成红色

- :ntc-child(n)
    
    选择同胞元素中的第 n 个设置样式


#### 伪元素

- ::first-letter
    
    选择内容首字母，放大 3 倍
    
    ```css
    p::first-letter {font-size:300%;}
    ```

- :: first-line

    选择首段落与浏览器窗口大小有关，设置字体

    ```css
    p::first-line {font-variant:small-caps;}
    ```

- ::before 和 ::after

    在某个元素前后添加内容

    ```css
    p.age::before {content:"Age: ";}
    p.age::after {content:" years.";}
    ```




## 盒子模型

一个元素或者也可以叫一个盒子，是由四部分组成

- content
- padding
- border
- margin

它们由内而外分别是 **content->panding->border->margin** 

### 盒子的边框

盒子的边框位于 padding 和 margin 之间的分界线叫做 border。

border 有三个相关的属性

- border-width 用于设置宽度。有 thin、medium、thick等文本值，也可以使用除了百分比和负值之外的数值，
-  border-style 用于设置样式。有 none、dotted、dashed、solid、double、groove、ridge、inset和outset等文本值。
- border-color 用于设置颜色。可以使用 RGB、HSL、十六进制、关键字。
- border-radius 

border-width 中的的3个文本值会因为浏览器的不同而不同，border-style 中只有 soild 是 CSS 明确规定的。

### 盒子的内边距

盒子内边距位于 content 和 border 之前的区域。

相关属性有

- padding
- padding-top
- padding-right
- padding-bottom
- padding-left

四个属性都是设置内边距的宽度，可以指定 px、em等。

其中 padding 为可以简写模式，也可以非简写模式

```css
//简写模式，设置上下为10px，左右为5px
p {padding: 10px 5px;}
```

```css
//非简写模式，分别设置上右下左内边距（即顺时针）为 1px、2px、3px、4px
p {padding: 1px 2px 3px 4px;}
```

### 盒子的外边距

盒子的外边距位于 border 之外。

属性和使用方法和 padding 一模一样 使用 margin 替代 padding 即可。

盒子的外边距在 block 元素中会有叠加发生，inline 元素则不会有。

例如有两个 p 标签

```html
<p id="p1">i am p1</p>
<p id="p2">i am p2</p>
```

使用 CSS 设置他们的 margin

```css
p#p1 {margin: 10px 0px;}
p#p2 {margin: 5px 0px;}
```

这时 p1 和 p2 之间的距离是较大的那个外边距就是 10px，如果相同，那么就是那个值。

对于 inline 元素则完全不同，就是两个左或者右边距相加。

## 盒子有多大

世界上有两种盒子，一种是设置了 width 和 没有设置 width 的。

对于没有设置 width 的盒子 宽度默认是父元素的宽度。
有设置 width 的盒子，这里设置 width 只是设置了内容的宽度。

对没有 width 的盒子，给他添加左右 padding 和 margin 会使得内容区域变窄，盒子大小不变。
对于有 width 的盒子，添加左右 padding 和 margin 内容区域不变，盒子变大。

## 浮动与删除

让元素层叠的关键就是 float 属性，可以让元素浮动在其他元素之上，使用 clear 可以设置不允许有浮动元素层叠。

### 浮动

float 属性目的是实现文本围绕图片，同时也能做分栏。

#### 文本围绕图片

```html
    <img src="st3.png" height="50" width="130">
    <p>
        CSS3 Multi-column Layout Module 规定了如何用CSS 定义多栏布局。但在本书写作
    时，只有Opera 和IE10 支持相应属性。因此在可以预见的未来，float 属性仍然是
    创建多栏布局的最佳途径。
    </p>
```

这时候布局是上面是 img，在它下面是 p

想让文本包围 img

```css
img {float:left;}
```

#### 分栏

再次设置一次 float 并设置一下 p 的 width 属性。同时你的一行足够容纳下这些元素。

使用 float 时候必须设置 width ，图片有自己本身的 width 所有不用设置也可以。

### 围住浮动元素的三种方法

浮动了元素之后， 该元素脱离文本流，它的父元素找不到他了，自然也无法包围他。

1. 设置父元素属性 ```overflow:hidden;```
2. 设置父元素浮动 ```float:left; width:100%;```
3. 添加非浮动的清除元素

对于第三种方法是最好的方法，实现方式有两种

```html
<section>
    <img src="images/rubber_duck.jpg">
    <p>It's fun to float.</p>
    <div class="clear_me"></div>
</section>
```

添加一个空的 div 并设置 clear 
```css
.clear_me {clear:left;}
```

还有一种方式是不添加这个没有显示功能的 div，可以给父元素添加一个类

```html
<section class="clearfix">
    <img src="images/rubber_duck.jpg">
    <p>It's fun to float.</p>
</section>
```
然后设置 **.clearfix**

```css
.clearfix:after {
    content:".";
    display:block;
    height:0;
    visibility:hidden;
    clear:both;
}
```

这是 css 设置了最小内容 **.** 并设置高度为 0 让其不可见， 再使用 clear 清楚两边的浮动元素，这样所有的浮动元素有会到这个 div 的下方去。

三种方法不能应付的场景：

不能再下来拉菜单的顶级元素使用 **overflow:hidden** ，因为下拉框的下拉内容是显示在父元素的区域外，而这个属性设置的是不显示超出父元素的内容，这就导致下拉框不显示。

不能对已经靠自动外边距居中的元素使用“浮动父元素”技术，否则它就不会再居中，而是根据浮动值浮动到左边或右边了。

有时候清除浮动元素时候并没有父元素来强制包围。可以把 **.clearfix** 类添加到某个具体的元素上，强制这个元素清楚周围的浮动。

## 定位

css 的定位使用的 position 这个属性，这个属性有四个值 static、relative、absolute、fixed，默认值为static。通过定位可以对元素重新定位。

### 静态定位

静态定位是默认的方式，就是按照文本流 block 元素换行， inline 元素不换行，从头到尾排列。

### 相对定位

相对定位的相对，是相对于原来的位置。之后可以使用 top 、left 设置新的位置。

```css
p#specialpara {position:relative; top:25px; left:30px;}
```

原则上使用 top 和 left 就可以了，因为他们支持负数。元素移动出来的同时，空出来的位置会继续保留。

### 绝对定位

绝对定位和相对定位不同的是，空出来的区域被回收了，也就是说移动出来的元素，脱离了文本流。

定位的位置和**定位上下文**有关，默认的定位上下文的 body 元素。只要把父元素的 position 属性设置为  relative 那么个这个父元素就成了新的上下文。

### 固定定位

元素脱离文本流，固定在相对于屏幕的某个位置，随着浏览器滚动，这是元素始终在那个位置。这是功能可以用来做固定的导航。

## 显示属性

所有的元素都有 display 属性，大多数的默认值不是 block 就是 inline，还有其他很多属性。

让两个 block 元素并排显示可以设置

```css
p {
    display: inline;
}
```

让一个元素隐藏可以使用

```css
p {
    display: none;
}
```
被隐藏的元素包括他所在位置都会消失

```css
p {
    visibility: hidden;
}
```
但是这种方式，元素被隐藏但是空出来的位置还在。

## 背景

一个元素的展现可以分成3成，由里到外是

1. 文本或者图片
2. 背景图片
3. 背景颜色

### CSS 背景属性

- background-color
- background-image
- background-repeat
- background-position
- background-size
- background-attachment
- background（简写属性）

### 背景颜色

```css
body {background-color: #caebff;}
```

### 背景图片

设置方式需要这样： **background-image:url(图片路径/图片文件名)**

默认图片是重复的位置也是默认在左上角，图片会重左上角重复铺开，直到填满整个元素。

### 背景重复

控制背景重复方式的background-repeat 属性有4 个值。

- repeat （默认）
- repeat-x （只在水平方向重复）
- repeat-y （只在垂直方向上重复）
- no-repeat （背景图片显示一次）

### 背景位置
用于控制背景位置的是 background-position 属性

有五个关键字

- top
- left
- bottom
- right 
- center

background-position 属性同时设定元素和图片的原点

让一张图片居中不重复的方法

```css
div {
    height:150px;
    width:250px;
    border:2px solid #aaa;
    margin:20px auto;
    background-image:url(images/turq_spiral_150.png);
    background-repeat:no-repeat;
    background-position:50% 50%;
}
```

通过把 background-position 设定为50% 50%，把background-repeat 设定为no-repeat，实现了图片在背景区域内居中的效果。

### 背景尺寸

background-size 是CSS3 规定的属性，但却得到了浏览器很好的支持。

- 50% 缩放图片，使其填充背景区的一半。
- 100px 50px：把图片调整到100 像素宽，50 像素高。
- cover：拉大图片，使其完全填满背景区；保持宽高比。
- contain：缩放图片，使其恰好适合背景区；保持宽高比。

### 背景粘附

background-attachment 属性控制滚动元素内的背景图片是否随元素滚动而移动。

- scroll （默认） 滚动
- fixed 不滚动

###  简写背景属性

```css
body {background:url(images/watermark.png) center #fff no-repeat contain fixed;}
```

第一个路径，第二个是位置，第三个是背景色，第四个是重复方式，第五和是背景尺寸，都五个是是否滚动。

### 多背景图片

```css
p {
    height:150px;
    width:348px;
    border:2px solid #aaa;
    margin:20px auto;
    font:24px/150px helvetica, arial, sansserif;
    text-align:center;
    background:
    url(images/turq_spiral.png) 30px -10px no-repeat,
    url(images/pink_spiral.png) 145px 0px no-repeat,
    url(images/gray_spiral.png) 140px -30px no-repeat, #ffbd75;
}
```

CSS 规则中先列出的图片在上层。




## 字体

网页中字体的三个来源

- 用户机器安装的字体
- 第三方网站上的字体
- 储存在 web 服务器上字体

CSS 中有6个与字体有关的属性：font-family、font-size、font-style、font-weight、font-variant、font 

### 字体族

font-family 可以设置 字体族，也就是指定文本用什么字体，可以设置多个，排列在前面的优先级高

```css
body {font-family:"trebuchet ms", tahoma, sans-serif;}
```

带有空格的字体需要加上引号，前面的字体优先选择，如果找不到，选择下一个，一般最后一个是要设置一个通用字体。

-  serif ，也就是衬线字体，在每个字符笔画的末端会有一些装饰线；
-  sans-serif ，也就是无衬线字体，字符笔画的末端没有装饰线；
-  monospace ，也就是等宽字体，顾名思义，就是每个字符的宽度相等（也称代码体）；
-  cursive ，也就是草书体或手写体
-  fantasy ，不能归入其他类别的字体（一般都是奇形怪状的字体）

### 字体大小

每个 HTML 元素都设置默认字体大小，当在修改字体大小时候都是修改了默认值，同时也是可以继承的

```css
 h2 {font-size:18px;}
```
设置字体大小可以有绝对字体大小和相对字体大小

绝对字体大小不会随页面缩放不会继承父元素属性，一般使用 px 单位，也可以使用关键字 x-small 、medium 、x-large

相对字体大小会随着页面缩放会继续父元素的字体大小，再其基础上缩放。使用百分比、em、rem 作为单位。

rem 是相对根元素的的大小

### 字体样式

```css
h2 {font-style:italic;}
```

- normal 正常
- italic 斜体

### 字体粗细

font-weight 属性的两个值： bold 和 normal

### 字体变化

font-variant 属性除了 normal ，就只有一个值，即 small-caps 。这个值会导致所有
小写英文字母变成小型大写字母：

```css
h3 {font-variant:small-caps;}
```


## 文本属性

以下是几个最有用的 CSS文本属性：

-  text-indent
-  letter-spacing
-  word-spacing
-  text-decoration
-  text-align
-  line-height
-  text-transform
-  vertical-align

### 文本缩进

```css
 p {text-indent:3em;}
```

text-indent 属性设定行内盒子相对于包含元素的起点。默认情况下，这个起点就是包含元素的左上角。

正值向右，负值向左

text-indent 是可以被子元素继承的。但是继承的是最终的值。

>假设有一个 400 像素宽的 div，包含的文本缩进 5%，则缩进的距离是 20 像素（400 的 5%）。
在这个 div 中有一个 200 像素宽的段落。作为子元素，它继承父元素的 text-indent 值，所以
它包含的文本也缩进。但继承的缩进值是多少呢？不是 5%，而是 20 像素

### 字符间距

```css
p {letter-spacing:.2em;}
```
>letter-spacing 为正值时增大字符间距，为负值时缩小间距。无论设定字体大小时使用的是什么单位，设定字符间距一定要用相对单位，以便字间距能随字体大小同比例变化。

### 单词间距

```css
 p {word-spacing:.2em;}
```

### 文本装饰

```css
.retailprice {text-decoration:line-through;}
```

 值有：underline 、 overline 、 line-through 、 blink 、 none，其中 blink 不使用

### 文本对齐

```css
p {text-align:right;}
```

>text-align 属性只有 4 个值， left 、 right 、 center 和 justify ，控制着文本在水平方向对齐的方式。其中， center 值也可以用来在较大的元素中居中较小的固定宽度的元素或图片。

### 行高

```css
 p {line-height:1.5;}
```

值：任何数字值（不用指定单位）


### 文本转换

```css
 p {text-transform:capitalize;}
```

值： none 、 uppercase 、 lowercase 、 capitalize 。

### 垂直对齐

值：任意长度值以及 sub 、 super 、 top 、 middle 、 bottom 等。
```css
span {vertical-align:60%;} 。
```

>vertical-align 以基线为参照上下移动文本，但这个属性只影响行内元素。如果你想在垂直方向上对齐块级元素，必须把其 display 属性设定为 inline 。

 HTML 标签  sup 和 sub 有默认的上标和下标样式，但重新设定一下vertical-align 和 font-size 属性能得到更美观的效果。

### @font-face

```css
@font-face {
/*这就是将来在字体栈中引用的字体族的名字*/
font-family:'UbuntuTitlingBold';
src: url('UbuntuTitling-Bold-webfont.eot');
    src: url('UbuntuTitling-Bold-webfont.eot?#iefix')
        format('embedded-opentype'),
        url('UbuntuTitling-Bold-webfont.woff')
        format('woff'),
        url('UbuntuTitling-Bold-webfont.ttf')
        format('truetype'),
        url('UbuntuTitling-Bold-webfont.
        svg#UbuntuTitlingBold') format('svg');
font-weight: normal;
font-style: normal;
}
```

把以上代码添加到网页中之后，就可以使用 font-family 以常规方式引用该字体了。引用字体时要使用 @font-face 规则中 font-family 属性的值作为字体族的名字。




## 布局

多栏布局的三种基本实现方案：固定宽度、流动、弹性。

-   固定宽度不会随着页面的缩放而变化，一般选择固定宽度为 960 px，能被多种整数整除，实现多栏布局。
-   流动布局会随着浏览器的窗口大小变化而变化，这种布局能更好的适应大屏幕，但是文明本行的长度和页面的元素之间的位置关系可能会发生变化。
-   响应式设计利用媒体查询，为提供不同的 CSS 成为可能，使得不同的屏幕可以使用固定布局，正在替代流动布局。
-   弹性布局在浏览器大小发生变化时候，所有的元素和布局都会缩放，这种技术实现难度大。

**布局高度**一般要保持 auto ，这样在垂直方向上添加元素时候会自动向下拓展，如果设置的高度，那么元素可能会被剪掉，或者跑出元素外面去。

**布局宽度**需要精确的控制，在浏览器宽度合理变化时候提供合理的调整。必须要给定栏宽，其中的元素不需要给定宽度，使用默认行为填充满整个父元素的宽度。

## 三栏-固定布局

三栏布局中，需要计算出三栏的宽度等于父元素的宽度。

``` html
<div id="wrapper">
    <nav>
        <!-- 无序列表 -->
    </nav>
    <article>
        <!-- 这里是一些文本元素 -->
    </article>
    <aside>
        <!-- 文本 -->
    </aside>
</div>
```

三栏的元素分别是 nav、article、aside，假设 #wrapper 的宽度是 960px，那么这三个元素的宽度也要是 960px。

``` css
#wrapper {width:960px; margin:0 auto; border:1px solid;}
nav {
    width:150px;
    float:left;
    background:#dcd9c0;
}
nav li {
    list-style-type:none;
}
article {
    width:600px;
    float:left;
    background:#ffed53;
}
aside {
    width:210px;
    float:left;
    background:#3f7ccf;
    width:210px;
    float:left;
    background:#3f7ccf;
}
```

给这三个固定宽度元素添加内外边距时，由于被指定宽度的元素再添加内外边距时候元素会被扩大，会出现元素错位的情况，有三种方式可以解决。

-   计算元素宽度时候就把内外边距也考虑上，这样太麻烦，不推荐。
-   把这三个元素用 div 包起来，由于这个 div 是没有被设置宽度的，所以添加内外边距时大小不变
-   给三个元素使用 box-sizing:border-box 的属性，就不会导致给设定宽度的元素添加内外边距时，导致元素扩大，这个方法好。

## 三栏-中栏流动布局

目前而言 CSS 中的 table 属性是最简单、最容易实现的，但是在低于 IE7 的浏览器不被支持，也没有任何的替代方法。

CSS可以把一个 HTML元素的 display 属性设定为 table 、 table-row 和 table-cell 。

而通过 CSS把布局中的栏设定为 table-cell 有三个好处。

-   单元格（table-cell）不需要浮动就可以并排显示，而且直接为它们应用内边距也不会破坏布局。


-   默认情况下，一行中的所有单元格高度相同，因而也不需要人造的等高栏效果了。


-   任何没有明确设定宽度的栏都是流动的。

``` html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Document</title>
    <style type="text/css">
        #main{
            width: 960px;
            margin: auto auto;
        }
      nav {
        display: table-cell;
        width: 100px;
        background-color: red;
        padding: 20px 20px;
      } 
      article {
        display: table-cell;
        width: 600px;
        background-color: blue;
        padding: 20px 20px;
      } 
      aside {
        display: table-cell;
        width: 260px;
        background-color: yellow;
        padding: 20px 20px;
      }
    </style>
</head>
    <body>
        <div id='main'>
            <nav>
                <!-- 一些东西 -->
            </nav>
            <article>
                <!-- 一些东西 -->
            </article>
            <aside>
                <!-- 一些东西 -->
            </aside>
        <div>
    </body>
</html>
```