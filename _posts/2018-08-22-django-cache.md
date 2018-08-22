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



## R的服务器
托福于Rstudio的[httpuv](https://github.com/rstudio/httpuv)包，R语言也终于可以做后端了。httpuv的底层是两个C语言库libuv和http-parser，所以在吞吐量上并不逊色Python的web框架。

httpuv完成了基础的HTTP和WebSocket请求的处理接口，基于它二次开发的框架有fiery和plumber。当然shiny也算，不过shiny的前后端集成度太高，并不适合做为单纯的后端使用。


一个fiery的例子：[R的高性能 http 服务 fiery](http://www.bjt.name/2017/05/fiery-http-server?nsukey=B42S4QLuETAvMepKKwFx6RFdg%2FnxiskRubncWUbBYAYRffKBeuDRfx94G8y%2F2OpcEoJxKlWJh6xhKqneD%2ByU67pc7flFWatVicjxPtlPGZ4ilxvtXGiJWc%2F1j7xaAiB%2Bzlphx7dcJmuuqwIabKfMpRgtlJ%2F7RsA2vS73OtlFdG0rX%2FQzn%2Fi%2FC3jf4Hxj7LDt)

fiery和plumber的简单对比：[Benchmark of R's http framework](https://gist.github.com/badbye/cb89b796b6c5835f6538989c380f6e72)

## Nginx

[Nginx](https://www.nginx.com/resources/wiki/)是一个开源的HTTP Server，同时支持转发，代理，权限认证和负责均衡等功能。在Nginx的帮助下，可以轻易的在一台服务器上配置多个网站和应用程序。

在使用R语言的框架搭建好一个简易APP之后，可以使用nginx来为他配置上你的域名。以下是一个简单的配置文件，假定有两个APPs在监听9123和9124端口，下边的配置可以将访问serverr.com的请求均匀的转发到9123和9124端口。

```
upstream rserver {
    server 127.0.0.1:9123;
    server 127.0.0.1:9124;
}

server {
    server_name serverr.com;  # config host name
    location / {
        proxy_pass http://rserver;
    }
}
```

把以上配置写入rserver.conf文件中，并放在nginx的配置文件里，重启nginx使之生效。此处以及后文假定系统为Ubuntu。
```bash
sudo cp rserver.conf /etc/nginx/conf.d
sudo nginx -s reload
```

如果serverr.com是你自己的域名，你需要到域名提供商那里设置DNS将该域名指向你的主机IP。为了简单起见，可以修改本地的hosts文件，将serverr.com域名指向自己：

```bash
sudo vi /etc/hosts
# 添加这样一行信息:  127.0.0.1 serverr.com
```

设置完成后，就可以通过`curl http://serverr.com/predict?val=190`访问了。可以使用[siege](https://github.com/JoeDog/siege)工具来测试效果：

```bash
siege -c 255 -r 10 'http://serverr.com/predict?val=190'
siege -c 255 -r 10 'http://localhost:9123/predict?val=190'
siege -c 255 -r 10 'http://localhost:9124/predict?val=190'
```

这里使用nginx的测试结果稍微好一点点，但效果并不十分明显。因为数据的处理太过简单，主要在于IO的耗时。相比于直接访问端口，访问域名会需要额外的一点时间来解析并转发。使用nginx的负载均衡的另一个优点在于，当其中一个程序宕机时，nginx会自动把请求转发到另一个健康的程序上去，保证服务不间断。

最后介绍一些安全措施：

1. 参考[Shiny 工程化实践之HTTPS加密](https://segmentfault.com/a/1190000007903606)中的nginx设置，为你的网站配置https。

2. 参考[RESTRICTING ACCESS WITH HTTP BASIC AUTHENTICATION](https://www.nginx.com/resources/admin-guide/restricting-access-auth-basic/)为APP设置密码

3. 通过iptables规则，设置特定IP才能访问。

以下规则使得只有192.168.1.1到192.168.1.255的IP地址可以访问本机的9123和9124端口，杜绝其他外来流量。
```bash
sudo iptables -I INPUT -p TCP --dport 9123 -j DROP
sudo iptables -I INPUT -p TCP --dport 9124 -j DROP
sudo iptables -I INPUT -m iprange --src-range 192.168.1.1-192.168.1.255 -p TCP --dport 9123 -j ACCEPT
sudo iptables -I INPUT -m iprange --src-range 192.168.1.1-192.168.1.255 -p TCP --dport 9124 -j ACCEPT
```
