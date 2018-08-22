---
layout: post
title: "Django 缓存机制"
date: 2018-08-22 15:23:06 -0700
comments: true
---

大部分的内容都在文档里说的很清楚了：[Django’s cache framework](https://docs.djangoproject.com/en/2.1/topics/cache/)。

需要的注意的是，要在`settings.py`文件中添加中间件。
```
MIDDLEWARE = [
    'django.middleware.cache.UpdateCacheMiddleware',           # 更新缓存
    'django.middleware.security.SecurityMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'django.middleware.cache.FetchFromCacheMiddleware',        # 获取缓存
]
```

另一个让我烦恼一个多小时的问题是，设置`TIMEOUT`参数无效。查找Django的源文件(`./core/cache/backends/memcached.py`)，打印出设置缓存时的信息。发现不论参数设置多少，缓存的有效期都变成了600s。

后来终于在django的`conf/global_settings.py`这个文件里找到`CACHE_MIDDLEWARE_SECONDS = 600`这个参数。看名字是中间件的缓存时间，懒得深究了。在`settings.py`文件中把这个参数值也修改一下，再次测试，终于得到预期的效果。这个问题竟然在放狗都没搜到，值得一记。

