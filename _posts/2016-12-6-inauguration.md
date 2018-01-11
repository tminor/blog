---
layout: post
title: How to set up a blog using Jekyll, part 1.
date: 2016-12-06 14:46:07
disqus: y
---

### Introduction

In this series of blog posts, I'll explain the steps that I took to create this site. First up: how to set up Jekyll, a static page generator. For more information and a better breakdown of what exactly static page generators bring to the table, see [this article](https://www.smashingmagazine.com/2015/11/static-website-generators-jekyll-middleman-roots-hugo-review/). 

---

### Build and test a basic Jekyll page

The steps from this section are lifted directly from [Jekyll's documentation](http://jekyllrb.com/docs/home/) but include some troubleshooting that I had to do in order to get everything working properly. The goal is to configure and serve a bare bones Jekyll page so that you can test it via your local computer's web browser. In this guide, I'll be using CentOS 7. Start by installing some packages with `yum` and RubyGems:

```
$ yum install epel-release ruby ruby-devel rubygems gcc git
$ gem install bundler jekyll
```

Run `jekyll new <blogdir>`. This creates a default Jekyll blog directory with the following structure:

```
.
├── _config.yml
├── _data
|   └── members.yml
├── _drafts
├── _includes
|   ├── footer.html
|   └── header.html
├── _layouts
|   ├── default.html
|   └── post.html
├── _posts
├── _sass
|   ├── _base.scss
|   └── _layout.scss
├── _site
├── .jekyll-metadata
└── index.html
```

At this point (after `cd`ing into the new Jekyll directory), the documentation instructs you to run `bundle exec jekyll serve` in order to serve up some fresh web page. Unfortunately for me, this generated an error:

```
bundler: failed to load command: jekyll (/usr/local/bin/jekyll)
LoadError: cannot load such file -- json
  /home/fong/.gem/ruby/gems/jekyll-3.2.1/lib/jekyll/filters.rb:2:in `require'
  /home/fong/.gem/ruby/gems/jekyll-3.2.1/lib/jekyll/filters.rb:2:in `<top (required)>'
  /home/fong/.gem/ruby/gems/jekyll-3.2.1/lib/jekyll.rb:82:in `require'
  /home/fong/.gem/ruby/gems/jekyll-3.2.1/lib/jekyll.rb:82:in `<module:Jekyll>'
  /home/fong/.gem/ruby/gems/jekyll-3.2.1/lib/jekyll.rb:36:in `<top (required)>'
  /home/fong/.gem/ruby/gems/jekyll-3.2.1/exe/jekyll:6:in `require'
  /home/fong/.gem/ruby/gems/jekyll-3.2.1/exe/jekyll:6:in `<top (required)>'
  /usr/local/bin/jekyll:23:in `load'
  /usr/local/bin/jekyll:23:in `<top (required)>'
```

After some googling, I found a solution that seemed to remedy the issue. Open up `~/<blogdir>/Gemfile` with your gavorite text editor and append the following line: `gem "json", "2.0.2"`. Follow that up by running two more commands:

```
$ gem uninstall ffi
$ gem install ffi --platform=ruby
```

At this point I was able to run `bundle exec jekyll serve` without issue.

---

### Pick a theme and make it your own

Jekyll enables the use of pre-created themes. You can find them in a variety of places; I found the theme that this site uses [here](https://jekyllthemes.io/).

If your theme has a repository hosted on GitHub, you can clone the repository to a local directory:

```
$ mkdir <blogdir> && cd <blogdir>
$ git clone https://github.com/username/scribble
```

Once you've cloned the repository, you can run `bundle install` and `bundle exec jekyll serve` to view your webpage via your local browser by navigating to http://127.0.0.1:4000. 

---

### Conclusion

At this point, you'd probably customize your theme a bit and start writing some content. You can author your posts by editing files within the `_posts` directory. In the next installment of this series, we'll explore how to deploy and serve this new content via Capistrano and Apache on a VPS.
