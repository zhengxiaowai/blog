---
title: Django 带数据迁移 Model
date: 2016-06-01 16:49:48
categories: 
- 总结
tags:
---

Django 的 Model 迁移默认是先删除改表然后在另一个地方创建表，这时候会删除老的表的数据，但是有时候需要带着数据迁移。

<!--more-->

参考: [Stack Overflow](http://stackoverflow.com/questions/25648393/how-to-move-a-model-between-two-django-apps-django-1-7/26472482#26472482)

具体操作：
- 删除Model，添加Model到新的app中，然后执行 makemigrations。
- 会在老的app的migrations的文件下和新的app的migrations文件下多出两个新的migtations文件。


## 先修改 Delete 的 Model 文件

先修改删除Model的文件：（TheModel 是 Model 名字）（newapp_themodel是数据库表名字）

```python
class Migration(migrations.Migration):
    dependencies = []
    database_operations = [
        migrations.AlterModelTable('TheModel', 'newapp_themodel')
    ]
    state_operations = [
        migrations.DeleteModel('TheModel')
    ]
    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=database_operations,
            state_operations=state_operations)
    ]
```

Django的Model操作分为两个部分，一个是状态操作（state_operations）和数据库操作（database_operations），使用SeparateDetabaseAndState 分离这两部操作，默认是不分离的。

由于需要保护数据，所有在状态上我们要删除这个Model，但是并不在数据库中删除该表，只是重命名该表。


## 修改迁移后的 Model 文件
然后在修改创建Model的文件：

```python
class Migration(migrations.Migration):
    dependencies = [
        ('old_app', 'above_migration')
    ]
    state_operations = [
        migrations.CreateModel(
            name='TheModel',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
            ],
            options={
                'db_table': 'newapp_themodel',
            },
            bases=(models.Model,),
        )
    ]
    operations = [
        migrations.SeparateDatabaseAndState(state_operations=state_operations)
    ]
```
这一步只需要把操作编程状态操作就可以了，并不实际操作数据库，这样就完成了migrations文件的修改。

最后 migrate 搞定收工。



