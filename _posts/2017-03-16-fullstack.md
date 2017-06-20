---
layout: post
title: "Tornado & SPA(Single Page Application)"
date: 2017-03-12 11:21:06 -0700
comments: true
---

前端领域SPA(Single Page Application)如火如荼，一个SPA也包含了路由的概念和简单的数据处理过程。简单来说就是一个单文件比如`index.html`，包含了所有的网站内容。它自身的路由使得你可以看到浏览器中url的变化，但实际并没有发生网络请求。因为第一次打开网站时就加载了所有组件。这样在网站内部来回穿梭就如丝般顺滑，是极佳的体验。遇到这样的网站切勿点击刷新。

回到开发上来，前后端分离使得开发相对独立，后端致力于提供API返回数据，后端致力于数据的展现。而在部署时，目前流行的方式似乎是前后端各开一个独立的服务进程，但对一个全栈来说调试起来未免有点复杂。前端再如何进化，最后的产品始终是HMTL，CSS和Javascript的结合，完全可以作为静态文件在浏览器中渲染。所以在后端中加一个路由用来渲染前端生成的文件就可以了。

## 问题
问题在于，SPA有自己独立的路由，后端也有数据接口的路由，二者很容易搞混。
比如下边的路由设置:

```python
router = [
     (r"/api/(.*)", APIHandler)
     (r"/(.*)", StaticFileHandler)  # StaticFileHandler 是一个渲染静态文件的类
]
```
其中`/api`是后端的数据接口，其他是SPA的前端页面。

访问`/api/...`时会调用后端的数据接口`APIHandler`，其他情况下调用`StaticFileHandler`渲染静态文件。而SPA有自己的路由，比如`/class/course1`。然而当访问这个路由时，会首先被后端拦截并匹配到相应的`StaticFileHandler`，去寻找`class`文件夹中的`course1`文件。这个目录当然是不存在的，于是返回404错误。

理想状态应该是所有非`/api`开头的路由，都转发到SPA相应的页面中去。注意这里就千万不要在SPA中也设置`api`路由了，否则永远也转不过去。

## Django方案

这篇博客[URL Routing for a Decoupled App, with Angular 2 and Django](https://www.metaltoad.com/blog/url-routing-decoupled-app-angular-2-and-django)介绍了如何将Django的后端与Angular2的前端无缝结合。

## tornado方案

在tornado中，有`StaticFileHandler`模块可以渲染静态文件。基于这个模块定义一个子类，将所有非js和css文件的路由都重定向到主页面。

```python
class Ag2Handler(StaticFileHandler):
    @gen.coroutine
    def get(self, path, *args, **kwargs):
        if path.strip('/').split('.')[-1] not in ['js', 'css']:
            path = 'index.html'
        yield super(Ag2Handler, self).get(path, *args, **kwargs)

router = [
    (r"/api/(.*)", APIHandler),
    (r"/(.*)", Ag2Handler, {'default_filename': 'index.html', 'path': 'XXXXXX'})
]
```

访问`/class/resume`页面时，在后端被最后一个路由`r"/(.*)"`匹配到。使用`Ag2Handler`渲染，强行重定向到主页`index.html`，完工。


