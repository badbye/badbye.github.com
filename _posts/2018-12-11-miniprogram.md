---
layout: post
title: "小程序开发经验"
date: 2018-12-11 15:21:06 -0700
comments: true
---

记录一些开发小程序的经验。

## 自定义组件

### tabBar
底栏`tabBar`是可以自定义的。但如果自定义的话，最好**把几个tab对应的页面做成一个单页面**。否则切换tab时，由于页面的跳转，底栏tab会有明显的闪烁。

### 顶部状态栏

顶部状态栏也是可以自定义的，设置`"navigationStyle": "custom"`即可。但是要注意适配，尤其是像iPhone X，小米8等有刘海的机型。
官方自带的状态栏，高度是会随着机型变化的。

另外，左上角的`返回键`是无法控制的。小程序内部会维护一个栈(LIFO, Last In First Out)来存贮访问过的页面。
当发生页面跳转时，把上一个页面的路由放入栈中，点击返回键时从栈推出最后访问的页面路由。栈的最大长度时6，也就是页面最多跳转6次。当栈为空时，返回键消失。

官方明令警告，**不要尝试修改页面栈，会导致路由以及页面状态错误**。一开始把整个小程序做成了单页面，后来悲剧地发现没有返回键了。也没办法自定义，无奈只好重来。

所以自定义状态栏，最多也就能控制下它的高度，字体的大小等等，没有太大的必要。

### toast

官方自带的toast组件太不好用了，只有个对号的icon，连个X的icon都舍不得给。而且宽度无法改变，字体长度也有限制。好在自定义toast组件过程中，也没遇到什么问题。

只有一个，在使用`wx.setClipboardData`复制文本时，复制成功后会自动调用官方自带的toast组件显示`内容已复制`。这时再唤醒自定义的组件，就两重toast，有些尴尬。解决方法也很简单，手动隐藏掉即可:

```
wx.setClipboardData({
  data: 'xxxxxx',
  success: () => {
    wx.hideToast()  # 手动隐藏官方的toast
    self.myOwnToast('已复制到剪贴板')
  }
})
```


## cover-view 与 cover-image

cover-view 和 cover-image 是可以覆盖在小程序原生组件之上的文本视图和图片视图。
原生组件指的是像`video`,`map`和`canvas`等组件。使用时有以下几点需要注意:

- cover-view标签内部，只能嵌套`cover-view`,`cover-image`,`button`，其他标签无效。

- 不支持`background-image`, `overflow`等样式

其实所有值得注意的点，官方也都列出来了：[cover-view.html](https://developers.weixin.qq.com/miniprogram/dev/component/cover-view.html#cover-image)。
坑爹的是，这些不支持的效果，**在开发者工具预览时都是有效的，只有在真机上测试才会失效**。


## Canvas画布

小程序定义了一个新的尺度`rpx`，所有手机在小程序内部的宽度都是750rpx。写样式的时占满所有宽度就可以`width:750rpx`。然而当使用canvas绘图时，
canvas并不支持`rpx`，仍然只能用`px`。若要画图占满整个宽度，只能用以下的方式:

```
<canvas class='canvas' canvas-id="canvasElement" style="width:{{wx.getSystemInfoSync().windowWidth}}px"></canvas>
```

使用小程序接口动态获取屏幕宽度。

## wepy的坑

- 当修改数据时，记得运行`this.$apply()`更新页面

- 没有完整的生命周期，只有一个`onLoad`事件
