---
layout: post
title: "Logistic Regression in R and Python"
date: 2014-10-28 16:25:06 -0700
comments: true
---

python中的scikit-learn库提供了一系列机器学习的算法，其中包括Logistic Regression。不过默认的，该库提供的是加入L2惩罚项的Logistic回归。但是程序设置上，python与R语言中有点出入，使得默认设置下同样数据出现的结果相差很大。

## R语言
在R语言中执行带惩罚项的Logistic回归，需要加载glmnet包。包中Logistic回归的优化目标是：

$$L(\theta)_R = -\frac{\text{log likelihood}}{\text{nobs}} + \lambda * \text{penalty}$$

其中$\text{nobs}$代表样本量。惩罚项如果是L2惩罚，则是$\frac{1}{2} \parallel \theta \parallel_2^2$，其中不包含截距项。如果是L1惩罚，就是$|\theta|_1$.

glmnet的设置：

- family=‘binomial’ 代表Logistic回归;
- alpha 表示elasticnet的混合参数：

$$\frac{1-\alpha}{2} \parallel \theta \parallel_2^2 + \alpha |\theta|_1$$

所以$\alpha=1$表示lasso的L1惩罚，$\alpha=0$表示岭回归的L2惩罚;
lambda 就是优化目标中的参数λ
默认的，glmnet会添加截距项，并对自变量进行标准化。


## python
python的scikit-learn中，Logistic回归是参考的[这篇文献](http://www.csie.ntu.edu.tw/~cjlin/papers/maxent_dual.pdf)。文献中二阶惩罚优化的目标函数是：

$$L(\theta) = -C*\text{log likelihood} + \frac{1}{2}\parallel \theta \parallel_2^2$$

与R语言的区别在于，这里的惩罚项里包含截距项。另外参数设置上，这里的$C$相当于$\lambda$，都是作为一个权衡似然函数和惩罚项的参数。

若想要与R语言的优化目标一致，则需要满足：

- 不含截距项
- $n\lambda = \frac{1}{C}$

其中，$n$表示样本量，$\lambda$是R语言glmnet函数中的*lambda*参数，$C$是python中的参数。

## Code

选择iris数据的前100行，作一个二分类的Logistic回归。设置python中$C=1$，R语言中应该有$n\lambda=1$，所以*lambda*应该是$\frac{1}{n}=0.01$。

### 无截距项

python：无截距项

{% highlight python %}
from sklearn import linear_model
from sklearn import datasets
iris = datasets.load_iris()
index = iris.target != 2
logit = linear_model.LogisticRegression(C=1.0,  tol=1e-8, fit_intercept= False)
logit.fit(iris.data[index, ], iris.target[index])
print [logit.coef_, logit.intercept_]
{% endhighlight %}

```
[array([[-0.44234418, -1.48544863,  2.23987714,  1.01147778]]), 0.0]
```

R语言：无截距，不标准化

{% highlight R %}
library(glmnet)
index = 1:100
iris.x = as.matrix(iris[index, 1:4])
iris.y = as.factor(as.character(iris[index, 5]))
# 不标准化自变量，不添加截距项
logit = glmnet(iris.x, iris.y, family="binomial", alpha=0, lambda=1/100, standardize=F, thresh =1e-8, intercept = F)
coef(logit)
{% endhighlight %}

```
5 x 1 sparse Matrix of class "dgCMatrix"
                     s0
(Intercept)   .        
Sepal.Length -0.4385104
Sepal.Width  -1.4868544
Petal.Length  2.2384771
Petal.Width   1.0031797
```


结果基本一致。

### 添加截距项？
最后，若想添加截距项后两个程序结果一致，可以修改python中的`intercept_scaling`参数，其参数解释为：

> when self.fit_intercept is True, instance vector x becomes [x, self.intercept_scaling], i.e. a “synthetic” feature with constant value equals to intercept_scaling is appended to the instance vector. The intercept becomes intercept_scaling * synthetic feature weight Note! the synthetic feature weight is subject to l1/l2 regularization as all other features. To lessen the effect of regularization on synthetic feature weight (and therefore on the intercept) intercept_scaling has to be increased.

具体的计算原理不清楚，但依据解释，只要增大`intercept_scaling`就可以减少惩罚项对截距的影响。

先来看看python中添加截距项的默认结果：

{% highlight python %}
logit = linear_model.LogisticRegression(C=1.0,  tol=1e-8, fit_intercept= True)
logit.fit(iris.data[index, ], iris.target[index])
print [logit.coef_, logit.intercept_]
{% endhighlight %}

```
[array([[-0.4070443 , -1.46126494,  2.23984278,  1.00849909]]), array([-0.26042082])]
```

增大intercept_scaling=100000的结果：

{% highlight python %}
logit = linear_model.LogisticRegression(C=1.0,  tol=1e-8, fit_intercept= True, intercept_scaling=1e5)
logit.fit(iris.data[index, ], iris.target[index])
print [logit.coef_, logit.intercept_]
{% endhighlight %}

```
[array([[-0.44234418, -1.48544863,  2.23987714,  1.01147778]]), 0.0]
```

R语言中添加截距项的结果：

{% highlight R %}
logit = glmnet(iris.x, iris.y, family="binomial", alpha=0, lambda=1/100, 
               standardize=F, thresh = 1e-8, intercept = T)
coef(logit)
{% endhighlight %}

```
5 x 1 sparse Matrix of class "dgCMatrix"
                     s0
(Intercept)  -6.6114025
Sepal.Length  0.4403477
Sepal.Width  -0.9070024
Petal.Length  2.3084749
Petal.Width   0.9623247
```

增大`intercept_scaling=100000`后与R语言的结果基本一致了。