---
title: 「译」Django 的 migtarion 冲突处理
date: 2016-06-20 16:51:24
categories: 
- 翻译
tags:
---

Migrantion 是 Django 最有用的的特性之一，但是对于我来说改变 Model 这是一个很可怕的任务。尽管能够阅读文档，我仍然很害怕 migration 的冲突或者丢失数据，或者需要手动处理 migration 文件，或者这样那样的事情。事实上，一旦理解它们，migration 是很酷的、很有用的。关于以上的问题你将不会有任何疑问。
<!--more-->

**翻译自 Oana Ratiu 的《[Django Migrations and How to Manage Conflicts](https://www.algotech.solutions/blog/python/django-migrations-and-how-to-manage-conflicts/)》**

我一直不能找到一些有价值的文章和文档，也许在某个地方，所有的方法都可以解决冲突。然而从来没有人在 Google 上仔细的搜索。在这些问题上我会尝试收集一些不同角度。主要的是，我会尝试去解释你可以在项目中找到的那些 migrations，如何解决 migration 的冲突，和一些数据迁移的。我会假定你是有 Django、Python 和 GIT 的使用经验。

[在 Django 的文档中对 migrations 的简单定义](https://docs.djangoproject.com/en/1.9/topics/migrations/#module-django.db.migrations)：

> Migrantion 是 Django 根据你的想法，改变 Model （添加字段、删除 Model 等）到数据库中的方法。它们大多数是自动的，但是你需要知道什么时候执行 migrations，执行它们时候，你可能会遇到的问题。

无论你选择是的 PostgreSQL, MySQL 还是 SQLite，你都可以使用一套命令去管理数据库。我将会较多的谈论关于 **makemigrations** 命令，它会基于你对 Model 的改动，然后创建新的 migrations。还有就是 **migrate** 命令，它会使 migrations 生效，完成后使它们失效和列出它们状态。

## 我的 migrations 在哪里？

在你的工程中，你可以找到 migrations 文件（.py 的文件）在 migrations 的文件夹里。确保文件夹中有 **\_\_init\_\_.py** 这个文件，如果没有这个文件，那么还是没有效果。

在你的 settings 文件中每个已安装的 app，你都可以找到对应得 migration 文件。例如，你可以在**…/lib/python2.7/site-packages/django/contrib/auth/migrations** 找到 User 的 migration。

你可以在你的数据库中找到 **django_migrations** 表，它列出了已经生效的 migrations。这是为了在切换分支的时候产生不同的 migrations，让你忘记执行到了哪里。

```
my_data=# select * from django_migrations;
 id |      app      |          name           |            applied            
----+---------------+-------------------------+-------------------------------
 .. |     ...       |          ...            |             ...             
 10 | myapp         | 0001_initial            | 2016-03-17 07:22:30.329448+00
 11 | myapp         | 0002_auto_20160316_0909 | 2016-03-17 07:22:30.956985+00
 12 | myapp         | 0003_auto_20160318_1345 | 2016-03-18 13:45:23.895839+00
 .. |     ...       |          ...            |             ...             
(16 rows)
 
my_data=#
```

## 首先，为什么要保存 migrations 在项目中？

也许你会说：为什么不在 Python / Django 的项目中 GIT-ignore 所有的 migrations，让每个开发者创建自己的 migration 文件？这样做可以避免掉一些不必要的操作。很好，这就是写这篇文章的一个理由。 

在继续之前，我希望你把在每次改变 model 改变后生成的 migrations 提交并推送到你仓库。这样所有的开发者都会拥有一份相同的 migrations。我必须强调这一点。

为什么这是如此重要的？想象一下，如果没有 migrations 在你的项目中，团队里的每个成员都要在本地生成自己的 migrations 文件。然而，我的项目最终总会在产品环境下，部署的时候会创建初始化的 migration 同时还会 migrate 数据库。在之后的时间，如果 model 改变我还会重新部署一次，这样又会在产品服务器上生成新的 migration。 但是如果现在发生一些事情，难道我还要有第二台产品服务器？再次部署，创建新的 migration 文件然后 migrate 我的数据库。这样一来，第一台产品服务器就有两份 migration 文件，然而第二台产品服务器只有一份 migration 文件，这一个巨大矛盾。我不能截断任何数据库的改变和执行数据库回滚。从根本上来说，如果你想回滚数据库，那就只能在每个服务器上。

所以，请保证 migrations 在你的项目中。你也许会遭遇冲突，但是如果你想要你的数据库版本，活着想要回滚数据库，在你的生活中，做一个开发者比监测 migrations 容易的多。

## Migration 冲突

假设我们有一个 Django 的项目，一份初始化 migration，同时也使用 GIT。我们使用 GIT，所以我们使用分支。我们使用分支，所以在 并分支的时候可能有 migrations 的冲突。当然，在团队中应该知道每个人在做什么，避免修改相同的 models。团队合作是重要的，但是一个人不可能总是避免 migrations 的冲突。因此千万别吓坏了，然后删除数据库，我就是这样干了很多次。它们是可以被很简单的修复，为了做到这一点，我将会解释一些简单的例子，但是它们是很有用的方法。你可以在你需求上选择一个最好的。

我们需要一份数据库的初始化 migration（Django 将会比较任何一个 model 去初始化 migration，而不是当前的数据库状态），我们不需要手动的修改数据库。 

假设，我们有一个 UserProfile 的 model 同时还有两个分支：

- 分支1，一个开发者添加一个 "address" 的字段到 UserProfile Model 中，这样就有了 "migration 0003\_userprofile\_address.py"
- 分支2，我想添加一个 "age" 字段到 UserProfile Model 中，这样就有了 "0003\_userprofile\_age.py"

我的分支是分支2，我想合并分支1到分支2，在执行 GIT merge 后，在分支2中不但有我的 migrations 还有从分支1中来的 "0003\_userprofile\_address.py"。那么问题来了，这两个 migration 文件都试图修改相同的 model，而且都是以 "0003_" 命名的。 

这里有三种可用的解决方法。前面两种是我推荐的，但是劝告你最好避免是使用第三种方法。

### 方法1：使用 -merge

无论何时，在你使用这个方法之前，这都是非常容易的，因为 Django 会自动合并。因此，如果你是有经验丰富的开发者，你事先会知道这种方法是会失败的。考虑到这个选项只对非常简单的 model 的变化非常有用。

那么，为了让 Django 合并你的 migrations，你应该遵循以下步骤：

- 尝试执行 **python manage.py migrate** (在这个时候，Django 将会查看这些冲突，然后告诉你执行 **python manage.py makemigrations –merge**
- 执行 **python manage.py makemigrations –merge**，migrations 将会自动被合并；你将会创建一个新的 migration 叫 **0004_merge.py** 被放在migrations 文件夹中。
- 执行 **python manage.py migrate**

```python
$ python manage.py migrate
CommandError: Conflicting migrations detected (0003_userprofile_age, 0003_userprofile_address in myapp).
To fix them run 'python manage.py makemigrations --merge'
$ python manage.py makemigrations --merge
Merging berguiapp
  Branch 0003_userprofile_age
    - Add field age to userprofile
  Branch 0003_userprofile_address
    - Add field address to userprofile
 
Merging will only work if the operations printed above do not conflict
with each other (working on different fields or models)
Do you want to merge these migration branches? [y/N] y
 
Created new merge migration .../migrations/0004_merge.py
$ python manage.py migrate
Operations to perform:
  Synchronize unmigrated apps: ...
  Apply all migrations: ... myapp, ...
Synchronizing apps without migrations:
  Creating tables...
  Installing custom SQL...
  Installing indexes...
Running migrations:
  Applying myapp.0003_userprofile_age... OK
  Applying myapp.0003_userprofile_address... OK
  Applying myapp.0004_merge... OK
$
```

请记住这条信息 "Merging will only work if the operations printed above do not conflict with each other (working on different fields or models)"。如果有复杂的修改，那么Django的可能不会正确合并 migrations，你将需要使用另一种方法。

### 方法2：回滚然后再次合并

若果是第一次失败，你应该选择这个方法，或者你不认同有这么多的 migration 文件在你应用程序中。（尽管 Django 允许多个 migration 文件在你的项目中）。

- 使用 `python manage.py migrate myapp my_most_recent_common_migration` 在你的分支中回滚最近正常的 migration。
- 你也可以这么做：
    - 暂时移除你的 migration，执行 `python manage.py migrate`，再次添加你的 migration 然后执行 `python manage.py migrate`。如果你的 migrations 涉及到不同的 models，同时又要有不同的 migration 生成，你应该使用这个 case。
    - 移除这两部分 migrations 同时执行 `python manage.py makemigrations` 和 `python manage.py migrate` 获得一个从 **0003\_userprofile\_age.py** 和 **0003\_userprofile\_address.py** 融合后的 migration。如果你想当前的改变只生成一个 migration， 同时只涉及到相同的 model，你应该使用这个 case。需要注意的是，如果这个 migration 在别的分支中也删除了，确保没有人拥有它和任何人都知道这个已经被删除。如果你删除了，同时有有人使用了，这会导致一些恶心的 BUG。应该遵循一个基本的原装：不要删除后者修改其他人使用的 migration。
    - 把 migration "0003\_" 改成 "0004\_"(这不是强制的，但是得可以这么做)，修改依赖属性指向 "0003_" migration 同时执行 `python manage.py migrate`。这个方案可以替代第一种方案，但是你不得不手动修改 migration 的依赖属性指向最新的一个。你更喜欢回滚然后重新创建 migration 或者你喜欢手动修改 migration ，这都带有浓重的个人色彩。就我个人而言我喜欢第一个。

执行下面这个 snippet 之前，我移除两个 migrations （考虑到这两个分支都是我创建并且没有别人使用，因此我也使用第二种方法解释以上的东西）

```
$ python manage.py migrate myapp 0002_auto_20160316_0909
Operations to perform:
  Target specific migration: 0002_auto_20160316_0909, from myapp
Running migrations:
  Unapplying myapp.0003_userprofile_age... OK
$ python manage.py makemigrations
Migrations for 'myapp':
  0003_auto_20160318_1345.py:
    - Add field address to userprofile
    - Add field age to userprofile
$ python manage.py migrate
Operations to perform:
  Synchronize unmigrated apps: ...
  Apply all migrations: ... myapp, ...
Synchronizing apps without migrations:
  Creating tables...
  Installing custom SQL...
  Installing indexes...
Running migrations:
  Applying myapp.0003_auto_20160318_1345... OK
$ 
```

如果有来自分支1的 migration 在相同的地方做和修改，你应该要小心地决定哪些是需要保留的，然后重新 migration。

### 方法3: 手动修改 migrations

这种情况是极少发生的，但是如果你真的到了无法选择的地步，阅读 Django 中 writing Django migrations 的文档（[英文](https://docs.djangoproject.com/en/1.9/howto/static-files/deployment/) [中文](http://python.usyiyi.cn/django_182/howto/writing-migrations.html)），可以让你快速熟悉 migration 的主要部分。

## 数据迁移

在一个项目中其中一个迁移必定是数据迁移。假如有那么一个需求，把一个 ManyToMany  的关系改变成 OneToMany 的关系或者要报一个表分成两个表，这样必然有生成一个 migration。但是数据发生了什么？我们仍然需要数据在当前的数据库中。这就体现了数据迁移带来的好处，你要写一个自定义的 migration，这些脚本会把在执行 ```python manage.py migrate``` 之后的表结构和你的数据关联起来。你数据将会在新的表中。

需要明确你的数据迁移需要依赖什么。这个依赖会涉及到最后生成的 migration （名字，或者更精确的），同时需要被开发者指定。但是如果我们在产品服务器中有不同的 migration 设定，需要在每台服务器上小心地做出相应地依赖设定。虽然这是无趣的，但是可以避免复杂的迁移机制。

在 fixture 和数据迁移中还是有一些不同。Fixtures 是导入一些默认的数据到数据库中，然而数据迁移是在数据库上改变一些数据。fixture 是一个放在 fixture 文件夹中的一个 JSON 文件，使用命令：```python manage.py laoddata myapp/fixtures/my_fixture.json``` 导入。这种方法是把默认的一类对象放入数据库中。另一种方法是，在 migrations 的文件夹中的数据迁移是一个 migration 文件。你不能使用数据迁移添加新的条目到你的数据库中，你只能在数据库众包修改他们。

## 结束

migrations 是一种很有用的数据库更新机制。当你使用 Django 和数据库工作时候，你必须考虑使用 migrations。

即使你不是一个后端程序员，或者你使用不同的框架，没有使用类似的机制，尝试去理解他们背后的逻辑。他们也许就不是你第一看见的那么复杂，所有的问题都可以被很好的解决。