---
layout: post
title: "性能提升: reids与内存缓存"
date: 2018-12-11 15:21:06 -0700
comments: true
---

redis是基于内存的数据库，单次查询的速度很快。但要查询的数据分布在不同的key里，且查询字段较多时，速度依然会被拖慢。简单来说，性能分为`网络耗时` 和 `查询耗时`。

当数据量比较小，更新不频繁，而且查询逻辑复杂时，可以把数据读到内存中，定时从redis更新。这种方法把网络耗时降到0，查询耗时又不会比redis差。

如果数据量比较大，读进内存这一步就很耗时，只能在redis中查询。可以使用pipiline或者lua脚本来减少网络耗时，尽量在一次网络交互就拿到所有查询结果。

## 内存缓存

将redis中的数据，读到内存中。使用时，直接对自带的内存做计算，并且可以转换成更方便的数据结构进行查询。适用的场景是**数据量小，更新不频繁**。

关键的问题，在于更新内存中的缓存。什么时候更新，如何更新？

### 带有效期的字典: expiredict

[expiringdict](https://pypi.org/project/expiringdict/) 实现了一个带有效期(和长度限制)的字典，可以设置key在多久之后过期。简单的测试:
```
import time
from expiringdict import ExpiringDict
cache = ExpiringDict(max_age_seconds=3, max_len=10)
cache['test'] = 123
time.sleep(3)
'test' in cache # False
```

接下来一个简单的函数，就能保证(1)总能拿到有效的数据 (2)过期后自动获取数据，并返回更新后的数据。
```
def get_cache_data(key):
  global cache
  if key in cache:
    cacahe[key] = 'run function to get data from redis'
  return cacahe[key]
```

值得注意的是，`run function to get data from redis`这一步也可以做适当的优化。
如果在redis存贮的数据，是hash或者set等复杂的数据结构，应该把数据序列化成字符，存贮成字符串对象，读取后再反序列化。因为redis对hash结构`HGETALL`的操作，比`GET`操作要耗时的多(`GET`操作是最快的)。做个简单的测试就可以体会到了:

```
import time
import json

cli = get_redis_cli()

def read_hash():
  t1 = time.time()
  res = cli.hgetall('hash_data')
  print('read_hash time cost: {0:.2f}ms'.format(1000 * (time.time() - t1)))
  return res

def read_kv():
  t1 = time.time()
  res = json.loads(cli.hget('kv_data'))
  print('read_kv time cost: {0:.2f}ms'.format(1000 * (time.time() - t1)))
  return res

if __name__ == '__main__':
  data = {i: i + 1 for i in rang(10000)}
  cli.hmset('hash_data', data)
  cli.set('kv_data', json.dumps(data))
  read_kv(); read_hash()
```
当`data`比较小时可能差异不明显，测试中长度达到1w，区别就很显著了。


### 基于共享内存的更新方法
不论怎样，更新内存时`run function to get data from redis`这一步总会有多余的耗时。有没有可能把这部分也优化掉？

随手查到[mmap](https://docs.python.org/3/library/mmap.html)，这家伙把内存数据映射到一个文件，其他进程可以对文件进行读写操作，进而共享控制同一块内存。[gensim](https://radimrehurek.com/gensim/intro.html)就是用mmap来做并行训练的。

可行的操作是，线下定时更新文件对应的内存数据，线上的N个进程从文件读取更新的数据。这就把内存更新的耗时完全移到线下了，而且多进程共享还能节省内存。唯一的缺点就是，需要再线下维护一个定时任务。

## 降低网络开销

数据量比较大或者更新频繁时，只能从redis做查询，得到结果。能够优化的，仅仅是减少服务器与redis的通信次数，降低频繁的数据传输的耗时。

两种方案，一是redis内置的pipeline，一次发送多个查询，执行完毕后返回多个查询的结果；二是使用lua脚本，将脚本发送到redis服务器执行。相比pipeline，lua脚本的灵活性更高一些。如果多个查询之间有逻辑依赖(比如如果'test'在某个set里，就直接返回结果，否则再继续查询'test'是否在另一个set里)，就是最适合使用lua 的场景了。

### pipeline

pipeline使用起来很简单，编写指令，最后execute会把所有指令的结果一起返回。适合**多个查询相互独立**的场景。
```
cli = get_strict_redis()
pipe = cli.pipeline()
pipe.sismember('set1', '我在这里吗')
pipe.sismember('set2', '你在哪里啊')
res = pipe.execute()
# [False, False]      # 你们都不在这里
```

### lua脚本
[lua](http://www.lua.org/start.html)是门编程语言，灵活性自然是有保障的。redis提供了对lua环境的支持，可以把lua代码发给redis执行。整体也不算太难，看看语法比葫芦画瓢就行了。

实现一个稍微复杂一点的例子，如果 `'我在这里吗' in 'set1'`为True，就继续看 `'你在哪里啊' in 'set2'`是否为True；否则第二个查询就不需要做了，直接返回1。

```
script = '''local ret = {}
    local exist = redis.call('sismember', 'set1', KEYS[1])
    table.insert(ret, exist)
    if exist1 == 1 then
      table.insert(ret, redis.call('sismember', 'set2', KEYS[2]))
    else
      table.insert(ret, 1)
    end
    return ret
'''
res = rcli.eval(script, 2, '我在这里吗', '你在哪里啊')
# [0, 1]
```
