---
layout: post
title: SICP - "Learning how to code."
date: 2017-07-15 09:38:19
disqus: y
---

## Yet another diversion

I'm afraid that my posting habits reveal something about myself that I am slightly ashamed of: that I have an inability to focus on one project for an extended period of time. I think that's okay—at least in the context of self-guided learning and experimentation (at least I'm learning something new, right?). Being a neophyte, I feel the urge to learn many things, and the number of things seems to be intrinsically expanding.

Among the great number of things I should learn, I'd guess that "learning to code" is probably one of the most important. Several times I've started a course on `$LANGUAGE` and learned how to print `Hello, world!` and solve various math problems. Just as many times, I've fallen off the wagon, distracted by yet another diversion, every time thinking, "if only I understood the basic concepts of computer science."

And finally, I've found a book that does just that: [*Structure and Interpretation of Computer Programs*](http://sarabander.github.io/sicp/). It seems inevitable that every time SICP is discussed, it's derided for its outdated use of Scheme (I don't really care if it is or not; I'd like to learn LISP so that I may one day master Emacs). I think Brian Harvey does a great job [defending SICP](https://people.eecs.berkeley.edu/~bh/sicp.html):

> The idea that computer science should be about ideas, not entirely about programming practice, has since widened to include non-technical ideas about the context and social implications of computing.

So it's not important that I'm learning specifically *x* or *y*—where *x* or *y* are something like Apache, etc.—, but that I understand the non-technical ideas, the context, and the social implications of being able to provide or implement *x* or *y*.

---

In this post, I'm going to focus on an exercise in the first chapter that I've found difficult to parse and understand. SICP is very precise in its concepts and parlance; my goal is to describe the solution to the problem in a way that's conformant to those strictures.

(It's probably worth mentioning the reason that I've taken a detour with this post: I did a really stupid thing and `yum update`d my KVM host and broke a bunch of stuff. It's caused me to [rashly] consider blowing everything away, but what I'll probably do is devise some sort of remediation strategy that involves a migration and implementing a backup/snapshot system that would have made my life a lot simpler; oh well, it will be a valuable learning experience, I'm sure!)

---

## What's the problem?

Reading SICP is tedious. It's easy to begin a section, ingest the words, and proceed to the next section having not the slightest notion of what just happened. Ingesting the text is a simple task; digesting it requires resolve and intent. In this post, we'll attempt to work through Exercise 1.5 from SICP.

So here's the problem:

> **Exercise 1.5:** Ben Bitdiddle has invented a test to determine whether the interpreter he is faced with is using applicative-order evaluation or normal-order evaluation. He defines the following two procedures:

{% highlight scheme %}
(define (p) (p))

(define (test x y) 
  (if (= x 0) 
      0 
      y))
{% endhighlight %}

> Then he evaluates the expression

{% highlight scheme %}
(test 0 (p))
{% endhighlight %}

> What behavior will Ben observe with an interpreter that uses applicative-order evaluation? What behavior will he observe with an interpreter that uses normal-order evaluation? Explain your answer. (Assume that the evaluation rule for the special form if is the same whether the interpreter is using normal or applicative order: The predicate expression is evaluated first, and the result determines whether to evaluate the consequent or the alternative expression.)

### Normal-order evaluation

Normal-order evaluation is described most succinctly in section 1.1.5:

> [Normal-order evaluation] would not evaluate the operands until their values were needed.

Given our example, we evaluate the combination `(test 0 (p))` without first evaluating and reducing the operands:

{% highlight scheme %}
(test 0 (p))

;; Values for operands are needed, apply operator to the first operand, substituting the argument 0 for x.
(if (= 0 0)
    0
   (p))

;; Don't evaluate (p) as its value is not needed.
0
{% endhighlight %}

The operand `(p)` was never evaluated since the application of the operator `if` yielded the reduction of the original test combination.

### Applicative-order evaluation

Applicative-order evaluation is also most succinctly described in section 1.1.5:

> [Applicative-order evaluation would] evaluate the body of the procedure with each formal parameter replaced by the corresponding argument.

Section 1.1.3 also states:

> 1. Evaluate the subexpressions of the combination. 
> 2. Apply the procedure that is the value of the leftmost subexpression (the operator) to the arguments that are the values of the other subexpressions (the operands).

The authors then proceed to point out that:

> the evaluation rule is recursive in nature...

The authors also demonstrate this evaluation method in terms of a tree where each terminating node is evaluated up, "in a percolating" fashion.

Using this as an illustrative example, we can see that we cannot evaluate the operator until we have the values for both operands. Evaluating `x` is easy: it's ` 0`. Evaluating `(p)` evaluates to itself infinitely. Using applicative-order evaluation, the interpreter hangs.

---

In writing this post, I realized how difficult it is to describe—in fastidious detail—how processes are evaluated. I tried very hard to use the correct terminology wherever possible. To quote one of the authors: 

> "If you have the name of [a] spirit, you have power over it."
