---
layout: post
title: How to set up a blog using Jekyll, part 3.
date: 2016-12-13 12:13:34
disqus: y
---

### Introduction

Welcome to the final round of this series on how to set up a Jekyll blog! In this post, I'll go over how to set up Apache to provide URL redirection and how to set up a certificate with Let's Encrypt.

---

### Install and configure Apache

Before we get into the rigmarole of installing Apache, we'll take a look at why we're choosing Apache over any other alternative. The answer—in my case at least—is because it's pretty much the *de facto* standard of HTTP servers. There's ample documentation, it's proven to be reliable/secure, and I've used it in the past and find its configuration to be pretty straightforward. If you're interested in learning more about HTTP servers, take a look at [this](https://opensource.com/business/16/8/top-5-open-source-web-servers) post. You can also see current HTTP server usage statistics [here](https://w3techs.com/technologies/overview/web_server/all).

Moving on, we'll first want to install Apache and enable it on startup:

```
$ sudo yum install httpd
$ sudo systemctl enable httpd
```

Next, we'll create a directory for our site's document root; essentially, Apache looks in a document root directory for content requested via HTTP. For our purposes, we'll create just one directory. Apache supports virtual hosts in order to facilitate hosting multiple web sites on one physical host. Create a directory for each virtual host and change the permissions and ownership:

```
$ sudo mkdir -p /var/www/example.com
$ sudo chown -R $USER:$USER /var/www/example.com
$ sudo chmod -R 755 /var/www
```

The `$USER` variable above should be replaced by the user that we use to administer the web server. By running these commands, we've done the following:

1. Established our Apache document root for example.com.
2. Changed ownership to our administrative (non-root) user.
3. Assigned read permissions to `/var/www/` so that pages can be served properly.

The next steps in the process are peculiar to CentOS; they are but one example in illustrating some of the differences between the various flavors of Linux. With a default installation of Apache on any version of the RHEL-based distributions, virtual host configuration would be done via `/etc/httpd/conf/httpd.conf`, but in this case we'll implement a directory structure used in Debian-based distributions. Create the necessary directories:

```
$ sudo mkdir /etc/httpd/sites-available
$ sudo mkdir /etc/httpd/sites-enabled
```

Open `/etc/httpd/conf/httpd.conf` with your favorite text editor and add the following line to the bottom of the file:

```
IncludeOptional sites-enabled/*.conf
```

A quick explanation of what's going on here: this directory structure facilitates a more flexible method for managing multiple virtual hosts. For each site, we would create a file in `/etc/sites-available` and then symbolically link to a file in `/etc/sites-enabled`; if we need to take a site offline for any reason, we need only to destroy the symbolic link.

We'll now create our virtual host file. Open up a new file, `/etc/httpd/sites-available/example.com.conf/` and add the following:

```
<VirtualHost *:80>
    ServerName www.example.com
    ServerAlias example.com
    DocumentRoot /var/www/example.com/public_html
    ErrorLog /var/www/example.com/error.log
    CustomLog /var/www/example.com/requests.log combined
</VirtualHost>
```

Restart Apache:

```
$ sudo apachectl restart
```

This is the bare minimum to get Apache up and running to serve a web site. One quick note: even though our virtual host file specifies port 80 (the default for HTTP), HTTPS will still work. I'm not really sure why this is. If anyone happens to read this and could shed some light, I'd be interested to know why. I suspect it has something to do with the `mod_rewrite` rules defined below, but I'm not 100% sure.

---

### Configure a 301 redirect with Apache

What's a 301 redirect? Essentially, a 301 redirect takes traffic for a target URL and sends it to a different, specified URL. In our case, we'll use it to redirect traffic from `example.com` to `www.example.com`. This strategy can be used for a variety of reasons other than simple redirects; if a company wants to protect its intellectual property, it might purchase domain names that include misspellings. An example is `gogle.com`. Try it out. You'll get redirected to `google.com`. For a more detailed explanation, see [here](https://en.wikipedia.org/wiki/HTTP_301).

Before this can work properly we'll need to have DNS A records for the two URLs involved in this process. Using BIND DNS as an example, the records would look like the following within the zone file for example.com:

```
$ORIGIN example.com.
...
www		IN		A		192.168.0.1
@		IN		A		192.168.0.1
...
```

We'll also have to ensure that we've enabled Apache's `mod_rewrite` module. This module is enabled by default on CentOS 7, but in case it's not enabled, add the following line to `/etc/httpd/conf.modules.d/00-base.conf`:

```
LoadModule rewrite_module modules/mod_rewrite.so
```

Open up `/etc/httpd/conf/httpd.conf` again, find the following block, and change the `AllowOverride` directive to reflect the following:

```
<Directory "/var/www/html">
    AllowOverride All
    # Allow open access:
    Require all granted
</Directory>
```

Restart Apache:

```
$ sudo systemctl restart httpd
```

With `AllowOverride` enabled, Apache reads `.htaccess` files in the document root, as defined in `/etc/httpd/conf/httpd.conf` (`/var/www/` by default). To configure 301 redirects per virtual host, we'll need to make sure that our `.htaccess` files exist in each site's document root. The `.htaccess` file contains rules that are defined through the use of regular expressions and rule conditions. If you're interested in learning more about `mod_rewrite`, see [here](http://httpd.apache.org/docs/current/mod/mod_rewrite.html) and [here](http://httpd.apache.org/docs/current/mod/mod_rewrite.html). 

Generally, we'd expect to create and edit our `.htaccess` files in place on our web server. Since we're using Capistrano, we'll avoid this. When Capistrano runs its deployment tasks, it executes the following:

{% highlight ruby %}
namespace :symlink do
  desc "Symlink release to current"
  task :release do
    on release_roles :all do
      tmp_current_path = release_path.parent.join(current_path.basename)
      execute :ln, "-s", release_path, tmp_current_path
      execute :mv, tmp_current_path, current_path.parent
    end
  end
{% endhighlight %}

As you can see, Capistrano takes all of our old content and executes `mv` to store it in a releases directory. To avoid the removal of our `.htaccess` file every time we run `cap deploy`, we simply need to edit and save the file within our local Jekyll blog directory. The file should resemble the following in order to redirect from non-www to a www URL:

```
RewriteEngine On
RewriteBase /
RewriteCond %{HTTP_HOST} !^www\. [NC]
RewriteRule ^(.*)$ https://www.%{HTTP_HOST}/$1 [R=301,L]
```

Since we'll be setting up SSL certificates for our website, we want to make sure that the above file reflects as much—`https://` instead of `http://`. 

---

### Install a Let's Encrypt certificate

In this section, we'll install an SSL certificate issued by Let's Encrypt. Let's Encrypt uses a certificate management agent to verify the identity of a web host; Let's Encrypt documentation recommends Certbot, so we'll install it:

```
$ sudo yum install python-certbot-apache
```

Before we generate the certificate, we need to install Apache's `mod_ssl` module:

```
$ sudo yum install mod_ssl
```

To generate the certificate, run the command below and follow the interactive prompts:

```
$ sudo certbot --apache -d example.com
```

You can find the certificate files in `/etc/letsencrypt/live`. We'll restart Apache for these changes to take effect:

```
$ sudo systemctl restart httpd
```

We should now be able to reach our site with an `https://` prefix.

---

### Conclusion

We now have a blogging platform that utilizes automated deployment, Apache URL redirection, and TLS encryption via Let's Encrypt. 
