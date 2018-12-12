---
layout: post
title: "散列函数与分流算法"
date: 2018-12-12 16:38:06 -0700
comments: true
---

## 散列函数
散列函数（hash function）对一种对任意输入，都返回一个固定长度输出的函数。常被用来检测信息的完整性，常用的函数有MD5,SHA1等。下载软件时，有的网站会提供一个md5值，下载完成后可以计算软件的md5值，对比是否与网站上的一致。如果不一致，可能是没下完整，也可以是被黑客"改造后"的软件，尽量不要安装。

散列函数应该有以下特点:

- 同样的输入，保证会有同样的输出。

- 很难找到其他的输入，使得它的输出与指定的输出相等。保证如果输入的信息被篡改，那输出的散列值变化的概率几乎为1。

第二个特点被称做“弱抗碰撞性”。**碰撞**就是说两条不同的信息，散列值相等。理论上碰撞当然是不可避免的，比如MD5函数固定地返回32位字母和数字的组合。
这个组合有(26 + 10)^32种，但输入的信息是无穷多个可能。所以散列函数无法保证不碰撞，只能尽量让输出保持随机性，降低碰撞的概率。

## 分流算法

分流算法是公司做AB测试系统时，将不同的用户分配到不同实验时使用的算法。分流算法需要做到的效果是：

- 随机性，保证每个实验的用户群体结构类似

- 指定时间内，同一个用户被分配到的实验id不会变

这两个特点刚好是散列函数的特长。只要把时间因素加入散列函数，就可以保证在指定时间内，输出的不变性，同时随机性也完全有保证。

## 实战
```
import time
import random
from hashlib import md5
SALT = 'add some random salt in hash function'
EXPID_CONF = {'A': 30, 'B': 20, 'C': 50}

def split_stream(uid, expid_conf=None, unchange_time=7 * 24 * 3600):
    """
    @param uid: 用户id
    @param expid_conf: 实验ID和流量配置，默认使用 EXPID_CONF 的配置
    @param unchange_time: 多长时间内保持分流结果不变，默认7天
    """
    expid_conf = expid_conf or EXPID_CONF
    for val in expid_conf.values():
        assert val >= 0
    # 计算随机的hash值
    time_factor = int(time.time() / unchange_time)
    msg = '{uid}+{salt}+{t}'.format(uid=uid, salt=SALT, t=time_factor)
    hash_bytes = md5(msg.encode()).digest()

    # hash值转为数字, 对总流量取模, 保证  0 <= rand_int <= stream_sum
    stream_sum = sum(expid_conf.values())
    rand_int = int.from_bytes(hash_bytes, byteorder='big') % stream_sum

    # 计算分流结果，判断rand_int的取值落在哪个实验区间即可
    stream_seq = sorted(expid_conf.items(), key=operator.itemgetter(1))
    for expid, stream_count in stream_seq:
        if rand_int < stream_count:
            return expid
        rand_int -= stream_count


if __name__ == '__main__':
    # 随便测试
    from collections import Counter
    res = []
    for i in range(0, 10000):
        uid = random.randint(0, 100000)
        res.append(split_stream(uid))
    print(Counter(res))
```
