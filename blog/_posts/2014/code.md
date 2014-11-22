---
title: "code"
layout: post
robots: none
---

Fenced code blocks can now be syntax highlighted using the power of Pygments.


    ~~~php
    print "Hello World"
    ~~~
 

The same goes for inline code:

    You could also do something like this: `var foo = 'bar'`{:.language-javascript}. Amazing!

~~~php
print "Hello World"
~~~

```R
print("hello world!")
```
    
## Setting the default language
If you don't want to set the language for inline code blocks like that every time, 
you can define a global default language for the entire site in your `_config.yml`
