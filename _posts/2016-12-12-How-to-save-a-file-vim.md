---
layout: post
title: Saving a read-only file in vi.
date: 2016-12-12 12:39:12
disqus: y
---

### Oops

Let's say that you've just finished a long edit of a read-only config file as a regular user. You forgot to open the file with elevated privileges. What do you do? Thankfully, `vi` allows users to run UNIX commands without having to exit the program:

```
:w !sudo tee %
```

Here's a quick breakdown of the above command:

1. `:` tells `vi` that you'd like to issue a command.
2. `w` tells `vi` to write the current file.
3. `!` tells `vi` to expect a shell command to follow.
4. `tee` is a shell command to copy from standard input and write to standard output.
5. `%` tells `vi` to use the current file name.

As an aside, you may also be interested to note that you can open a shell prompt from within `vi` by running `:sh`. `vi` will use whatever is returned by `echo $SHELL`.
