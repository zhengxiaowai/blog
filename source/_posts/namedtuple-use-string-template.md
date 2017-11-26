---
title: namedtuple —— 使用字符串动态生成类
date: 2016-12-08 16:32:00
categories: 
- 源码分析
tags:
---

Python 中的 `namedtuple` 是一个对 `tuple` 的加强机制，返回一个具有命名字段的 `tuple` 子类。

<!--more-->

## 参数检查

```python
def namedtuple(typename, filed_name, verbose=False, rename=False):
    pass
```

namedtuple 的参数由四个构成：

- typename 是该元组的名字
- field_name 是该元组成员的名字
- verbose 是否输出构造的源码
- rename 是否在 field_name 非法时候进行重命名


```python
if isinstance(field_names, basestring):
    field_names = field_names.replace(',', ' ').split()
field_names = map(str, field_names)
typename = str(typename)
```

调用 namedtuple 的第一步是处理 `field_name` 参数，该参数可以是 basestring 也就是说可以是 str 或者 unicode，再把 `field_name` 转化成列表。在使用 basestring 类型时，可以用 `,` 或者 ` ` 隔开。


```python
if rename:
    seen = set()
    for index, name in enumerate(field_names):
        if (not all(c.isalnum() or c=='_' for c in name)
            or _iskeyword(name)
            or not name
            or name[0].isdigit()
            or name.startswith('_')
            or name in seen):
            field_names[index] = '_%d' % index
        seen.add(name)
```

如果把 `rename` 为 `True` 将会重命名非法的的成员名字为「下划线 + 位置」,如果不使用 `rename` ，当非法成员存在时候会抛出异常。

```python
for name in [typename] + field_names:
    # 全部为 str 类型
	if type(name) != str:
		raise TypeError('Type names and field names must be strings')

    # 不能只由数字和下划线
	if not all(c.isalnum() or c=='_' for c in name):
		raise ValueError('Type names and field names can only contain '
						 'alphanumeric characters and underscores: %r' % name)
    # 不能是关键字
	if _iskeyword(name):
		raise ValueError('Type names and field names cannot be a '
						 'keyword: %r' % name)
    # 不能以数字开头
	if name[0].isdigit():
		raise ValueError('Type names and field names cannot start with '
						 'a number: %r' % name)
seen = set()
for name in field_names:
    # 在 rename 为 False 时候 name 不能以下划线开始
	if name.startswith('_') and not rename:
		raise ValueError('Field names cannot start with an underscore: '
						 '%r' % name)
    # 不能存在重复成员
	if name in seen:
		raise ValueError('Encountered duplicate field name: %r' % name)
	seen.add(name)
```

以上是对 `typename` 和 `field_name` 的类型检查，可以看出在使用时候应该避免以下情况：

- 非 str
- 只用下划线和数字
- 关键字
- 数字开头
- 下划线开头
- 重复成员

## 填充「类模板」

namedtuple 是继承自 `tuple` 的子类，具有他的一切特性，每个子类的代码都是在调用时候生成的，使用的是 Python 的字符串模板。

使用 `typename` 和 `field_name` 填充字符串模板，生成代码

```python
class_definition = _class_template.format(
    typename = typename,
    field_names = tuple(field_names),
    num_fields = len(field_names),
    arg_list = repr(tuple(field_names)).replace("'", "")[1:-1],
    repr_fmt = ', '.join(_repr_template.format(name=name)
                         for name in field_names),
    field_defs = '\n'.join(_field_template.format(index=index, name=name)
                           for index, name in enumerate(field_names))
)
```

定义一个 `Point` 参数有 `x, y, z`，打开 `verbose`，查看输出构建类。

```python
>>> Point = namedtuple('Point', 'x y z', verbose=True)
class Point(tuple):
    'Point(x, y, z)'

    __slots__ = ()

    # 定义的成员
    _fields = ('x', 'y', 'z')

    # 实例化 namedstuple 的 Point
    def __new__(_cls, x, y, z):
        'Create new instance of Point(x, y, z)'
        return _tuple.__new__(_cls, (x, y, z))

    # 生成一个 Point 的实例
    @classmethod
    def _make(cls, iterable, new=tuple.__new__, len=len):
        'Make a new Point object from a sequence or iterable'
        result = new(cls, iterable)
        if len(result) != 3:
            raise TypeError('Expected 3 arguments, got %d' % len(result))
        return result

    # 显示信息
    def __repr__(self):
        'Return a nicely formatted representation string'
        return 'Point(x=%r, y=%r, z=%r)' % self

    # 把 field 转化成字典
    def _asdict(self):
        'Return a new OrderedDict which maps field names to their values'
        return OrderedDict(zip(self._fields, self))

    # 替换成员的值，返回一个新的实例
    def _replace(_self, **kwds):
        'Return a new Point object replacing specified fields with new values'
        result = _self._make(map(kwds.pop, ('x', 'y', 'z'), _self))
        if kwds:
            raise ValueError('Got unexpected field names: %r' % kwds.keys())
        return result

    # 把整个 namedtuple 实例序列化
    def __getnewargs__(self):
        'Return self as a plain tuple.  Used by copy and pickle.'
        return tuple(self)

    # 构造类的各个成员成描述符
    __dict__ = _property(_asdict)

    # 清除 OrderedDict 对数据进行 picker 化时候返回的状态
    def __getstate__(self):
        'Exclude the OrderedDict from pickling'
        pass

    # 定义 field 的属性为类属性，itemgetter 定义取值操作
    x = _property(_itemgetter(0), doc='Alias for field number 0')

    y = _property(_itemgetter(1), doc='Alias for field number 1')

    z = _property(_itemgetter(2), doc='Alias for field number 2')
```

至此，构建 Point 的代码已经填充完成，但是还需要使用解释器执行该代码片段，才能真正 load 进内存中


```python
# 执行 exec 时候临时的 namespace
namespace = dict(_itemgetter=_itemgetter, __name__='namedtuple_%s' % typename,
                 OrderedDict=OrderedDict, _property=property, _tuple=tuple)
try:
    exec class_definition in namespace
except SyntaxError as e:
    raise SyntaxError(e.message + ':\n' + class_definition)

# 返回生成的类
result = namespace[typename]

try:
    # 把当前调用帧中的全局变量 __name__ 添加到生成类的 __module__ 中
    result.__module__ = _sys._getframe(1).f_globals.get('__name__', '__main__')
except (AttributeError, ValueError):
    pass

return result
```

class_definition 在使用 exec 执行的时候放在临时生成的 namespace 中，需要从 namespace 获取变量。

最后就可以使用 namedtuple 生成的类，每个成员都是类级别的描述符，实例化后和普通类一样使用，由于元组的不可修改的，所以 namedtuple 的属性也是不可以修改。