---
layout: post
title: How to set up a blog using Jekyll, part 2.
date: 2016-12-09 09:46:46
disqus: y
---

### Introduction

This post will build upon the previous one by detailing what it takes to automate the deployment of a Jekyll site via Capistrano. First, we'll take a look at the benefits and outline why we might be interested in implementing Jekyll in this fashion. Hypothetically, we could edit our posts directly on the web server hosting our blog. This would surely be the simplest way to publish our content, but it would probably be preferable to have a testing environment so that we have a place to do a dry run before posting something riddled with typographical errors and whatnot. With Capistrano, our workflow would look something like this:

1. Create a post on your local machine.
2. Use Jekyll to serve your site over the loopback address.
3. Test the site with your browser.
4. Assuming everything went well, deploy new content to a web server.

I've got this working and I find that it's extremely convenient and works pretty well. Whenever I have a post ready to go, it's as simple as running `cap deploy` from the Jekyll blog directory and voilà, everything is ready for viewing on the internet!

---

### Install Capistrano

As with every project, I began the process by using google to find a suitable guide. The first that I found was [this one](https://www.digitalocean.com/community/tutorials/how-to-get-started-with-jekyll-on-an-ubuntu-vps) on DigitalOcean. The first issue that I ran into was that Capistrano has released version 3 since DigitalOcean's guide was posted. Knowing nothing about Capistrano, this only meant that Capistrano didn't work the way I expected. If you're interested in deeper reading on the differences between the two, check out [this](http://building.wanelo.com/2014/03/31/capistrano-you-have-changed.html) post. While it feels like a cop out, I opted to install version 2 instead of learning something new (probably something I shouldn't admit). Without further ado, let's get into the installation process.

The first thing to do is install Capistrano via RubyGems. We'll use the `-v` option to specify a particlar version—namely, not version 3. After installation completes, we'll `cd` into our Jekyll blog directory and run the `capify` command. Here are the commands, in order:

```
$ gem install capistrano -v 2.15.5
$ cd <blogdir>
$ capify .
```

The last command (`capify`) creates all the necessary files and directories for a Capistrano deployment, one of which is a Capistrano `config/` directory. Inside we'll find a file, `deploy.rb`. This file needs to be customized per requirements. See mine below; I've added comments outlining changes that I made and why (I stole mine from [here](https://dsgn.io/thoughts/post/jekyll-deployment-with-digitalocean/)):

{% highlight ruby %}
set :application, "Blog"
set :repository, '_site'
set :scm, :none
set :deploy_via, :copy
set :copy_compression, :gzip
set :use_sudo, false

# When running cap deploy from a machine running OS X, it is necessary
# to specify to Capistrano that we want to use GNU tar; otherwise,
# cap deploy will throw errors
set :copy_local_tar, "/usr/local/bin/gtar" if `uname` =~ /Darwin/

# the name of the user that should be used for deployments on your VPS
set :user, "tminor"

# the path to deploy to on your VPS
set :deploy_to, "/var/www/example.com/current"

# the ip address of your VPS
role :web, "192.168.1.0"

before 'deploy:update', 'deploy:update_jekyll'

namespace :deploy do
  [:start, :stop, :restart, :finalize_update].each do |t|
    desc "#{t} task is a no-op with jekyll"
    task t, :roles => :app do ; end
  end

  desc 'Run jekyll to update site before uploading'
  task :update_jekyll do
    # clear existing _site
    # build site using jekyll
    # remove Capistrano stuff from build
    # also added bundle exec to avoid build errors
    %x(rm -rf _site/* && bundle exec jekyll build && rm _site/Capfile && rm -rf _site/config)
  end
end
{% endhighlight %}

Assuming everything is set up properly in our `deploy.rb` we can run `cap deploy:setup` to prepare the VPS with the necessary Capistrano directories. Having done that, we can now run `cap deploy` to deploy our blog. 

---

### NTP issue

In the previous section, we assumed everything was good to go. In my case, this wasn't so. When running `cap deploy`, the output indicated that there may be a time sync issue. The error messages were similar to the ones below:

```
** [out :: 123.45.67.890] tar: 20110603143429/.autotest: time stamp 2011-06-03 14:34:33 is 368.72042712 s in the future
** [out :: 123.45.67.890] tar: 20110603143429/.bundle: time stamp 2011-06-03 14:34:33 is 368.719540808 s in the future
** [out :: 123.45.67.890] tar: 20110603143429/.hgignore: time stamp 2011-06-03 14:34:33 is 368.719465444 s in the future
** [out :: 123.45.67.890] tar: 20110603143429/app: time stamp 2011-06-03 14:34:34 is 369.719382175 s in the future
```

The fix was fairly straightforward. I pointed OS X towards `time.google.com` and did the same for my CentOS VPS. I'll skip instructions for OS X as it's fairly straightforward. In order to fix this issue on CentOS (and pretty much any other flavor of Linux), start by installing `ntpd` via `yum install ntp`. Once installed, edit `/etc/ntp.conf` to reflect the following:

```

<snip>

# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
server time.google.com iburst
#server 0.centos.pool.ntp.org iburst
#server 1.centos.pool.ntp.org iburst
#server 2.centos.pool.ntp.org iburst
#server 3.centos.pool.ntp.org iburst

</snip>

```

Feel free to pick the NTP provider of your choice; I chose Google's NTP service because they've been doing some pretty cool stuff to keep ahead of leap second issues (it's also easy to remember but no more/no less reliable or better than any other choice). For more reading on this, see [here](https://developers.google.com/time/smear). For more background reading on UNIX time, see [here](https://en.wikipedia.org/wiki/Unix_time) and [here](https://www.youtube.com/watch?v=Uqjg8Kk1HXo) for a video overview of leap seconds and the potential for issues stemming from them.

---

### Conclusion

There's not much of a conclusion to be made here, but it might need to be said that what we've done so far is not enough to get our blog on the internet for all of our adoring fans to see. In the next part of this series, we'll set up Apache and a slew of other things in order to get our site up and running in a respectable manner. 
