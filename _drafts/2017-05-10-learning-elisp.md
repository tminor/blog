---
layout: post
title: Learning elisp.
date: 2017-05-09 12:55:35
disqus: y
---

### Learning elisp



### First, learn to walk!

At first I tried writing a complicated function to accomplish a particular task 

## Hello, world.

As with every language, we must begin with printing "Hello, world!"

And like other languages, there are many ways to achieve this goal. Here's one:

{% highlight elisp %}
(princ "Hello, world!")
{% endhighlight %}

If we evaluate the above using `C-x C-e` in our buffer, we'll see the following in our minibuffer:

```
Hello world!"Hello world!"
```

In case you're confused (as I was), it's worth noting that `princ` does two things: it outputs the printed representation of our object (Hello world!) to an output stream and returns the object. `princ` and `print` are dissimilar in that `princ` outputs to an output stream in a human friendly way (without quotes) where `print` ensures that the object fed to an output stream is 
