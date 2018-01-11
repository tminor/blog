---
layout: post
title: How to pass some web security tests.
date: 2017-07-02 12:12:12
disqus: y
---

## "Previously on how to do web security..."

A few posts ago, we learned some stuff about HTTP security headers and TLS certificates; in today's post, we'll finally get around to configuring Apache on CentOS to shore up our HTTP response headers. When I started writing this post, I intended to cover the configuration of all previously detailed headers; instead, I'm going to limit this post to an intro and two headers: HSTS and CSP.

---

## Apache and headers

Before we dive into the configuration process—which is pretty simple—we should understand on a basic level how `httpd` handles configuration. More specifically, we'll look at virtual host configuration and how headers are controlled by Apache. Let's begin with virtual hosts.

### Virtual hosts

Virtual hosting refers to a method for hosting multiple sites on a single machine running a web server. Here's an illustration: a server receives a connection for an address and port; if a match exists for the request, the server responds. In the case that a virtual host exists, the server must determine whether it should match based on an IP address (IP-based virtuals host); if so, the server fulfills the request with the page at that address. In the case that multiple virtual hosts exist for a given address and port, the server must match the virtual host based on the name indicated either at the beginning of a TLS handshake using Server Name Indication ([SNI](https://en.wikipedia.org/wiki/Server_Name_Indication)) or with `httpd` where the first listed virtual host configuration block matches the request.

Each virtual host is defined using a `<VirtualHost>` directive that is contained within `httpd`'s main config file or in separate config files; the separate config files and their locations depend upon the distribution from whence `httpd`'s package came. For details on this, see [Apache's documentation](https://wiki.apache.org/httpd/DistrosDefaultLayout) on the matter. (For some reason I adopted the Debian way–this was mostly out of ignorance, but I like it well enough.)

### A little about .htaccess

One way to configure a web site is to alter the corresponding `<VirtualHost>` directive within its config file; another way to accomplish this is to use a file called `.htaccess`. `.htaccess` is located in a web site's document root (or any other directory). When Apache loads the directory housing the content being retrieved, it knows to read `.htaccess`. One thing to to note:

> You should avoid using .htaccess files completely if you have access to httpd main server config file. Using .htaccess files slows down your Apache http server. Any directive that you can include in a .htaccess file is better set in a Directory block, as it will have the same effect with better performance.

That's directly from Apache's documentation. I don't think this matters much, especially if you are hosting your site on modern computers. With larger web sites, this may matter a little more.

### mod_headers

Apache provides a relatively limited set of functionality by default; however, it also provides extensibility through the use of modules. Common modules include examples such as `mod_ssl`, `mod_proxy`, and `mod_perl`.

`mod_headers` can be used to control HTTP headers. The syntax for header directives is as follows:

```
Header [condition] add|append|echo|edit|edit*|merge|set|setifempty|unset|note header [[expr=]value [replacement] [early|env=[!]varname|expr=expression]]
```

Header directives need only conform to the above syntax and can be specified in a site's virtual host config file or `.htaccess`; this means that the sky (or your imagination) is the limit when it comes to setting header fields and their values. Check out an HTTP response from Zappos:

```
$ curl -I zappos.com

. . .
Connection: keep-alive
Location: http://www.zappos.com/
X-Core-Value: 3. Create Fun and A Little Weirdness
X-Recruiting: If you're reading this, maybe you should be working at Zappos instead.  Check out jobs.zappos.com
. . .
```

Back to business. To set an HSTS response header, we need to recall the directives specified in RFC 6797, found [here](https://tools.ietf.org/html/rfc6797#section-6.1). They are `max-age` and `includeSubDomains`. In addition, many sites use the `preload` directive; I couldn't find `preload` documented in the RFC or in any official capacity elsewhere, so my guess is that it's a *de facto* standard as implemented by all modern browsers. See [my previous blog post](https://blog.tminor.io/2017/04/08/web-security-1/) to read more about HSTS and preload lists.

### Configure HSTS

Given the syntax above, let's build a proper directive specifying `strict-transport-security`. We know that the directive will begin with `Header`, so that seems like a reasonable start. Next, we must (optionally) choose a *condition*. Conditions can be used to granularly control how a server handles response headers; as an example, the server may remove a header given a specified HTTP status code. In our case, we want to assign the value *always* to this parameter. Absent this value, our server will only respond with the `strict-transport-security` header on a successful response. Our next argument will be a value from the list above; Apache's documentation contains the following line:

> For set, append, merge and add a value is specified as the next argument.

Well, we certainly want to specify some values so we have our choices narrowed down. `append` and `merge` can be excluded, and upon reading the description of `add` we see that `set` is probably the value we're looking for. So we shall set some values for the directives we specified in the last section: `max-age`, `includeSubdomains`, and `preload` (really we only need to assign an integer value for `max-age` as the others are essentially boolean).

HSTS can utilize multiple directives; I was unable to find any explicit coverage of how to handle this in Apache's documentation. My guess is that Apache assumes that an administrator should know that `httpd` responds with headers exactly how they're written in a config file and that an administrator should also be familiar with proper header syntax; after all, most (all?) RFCs on the subject of HTTP probably contain the following Augmented Backus-Naur Form syntax (ABNF) table:

```
Strict-Transport-Security = "Strict-Transport-Security" ":"
                            [ directive ]  *( ";" [ directive ] )

     directive            = directive-name [ "=" directive-value ]
     directive-name       = token
     directive-value      = token | quoted-string
```

This syntax is covered in great detail in [RFC 2616](https://tools.ietf.org/html/rfc2616#section-2). As we see above, each directive (or token in RFC parlance [though I think token is a broader term]) is separated by a semicolon. Also note that the HSTS directives are bookended by double-quotes. (After reading parts of RFCs 6797 and 2616, I think that Apache does some magic on the vhost header directive to make it conformant to specifications. Anyway, on to the final product.)

Let's put the above information together to form a coherent HSTS header directive for our vhost configuration:

```
Header set Strict-Transport-Security "max-age=31415926; includeSubDomains"
```

I personally decided to exclude `preload` as I don't think it's really necessary in my case (and I don't want to break anything if I mess something up). Most documentation available on the Internet indicates that some caution should be taken with the `preload` directive. Scott Helme [gives good reasons](https://scotthelme.co.uk/hsts-cheat-sheet/#preload) for why you may not want to go this route. To have your site included in the preload list, you can add it [here](https://hstspreload.org/).

### Content-security-policy

Now that we know how to create vhost header directives, we can jump right into picking the proper values for `content-security-policy`. Let's take a look at CSP's use in the wild by running `curl -I https://mobile.twitter.com`:

```
. . .
content-security-policy: 
	default-src 'self'; 
	connect-src 'self'; 
	font-src 'self' data:; 
	frame-src https://twitter.com https://*.twitter.com https://*.twimg.com twitter: https://www.google.com https://5415703.fls.doubleclick.net; 
	img-src https://twitter.com https://*.twitter.com https://*.twimg.com https://maps.google.com https://www.google-analytics.com https://stats.g.doubleclick.net https://www.google.com https://ad.doubleclick.net data:; 
	media-src https://*.twitter.com https://*.twimg.com https://*.cdn.vine.co; 
	object-src 'self'; 
	script-src 'unsafe-inline' 'unsafe-eval' https://*.twitter.com https://*.twimg.com https://www.google.com https://www.google-analytics.com https://stats.g.doubleclick.net; 
	style-src 'unsafe-inline' https://*.twitter.com https://*.twimg.com; 
	report-uri https://twitter.com/i/csp_report?a=O5SWEZTPOJQWY3A%3D&ro=false;
. . .
```

A quick glance shows a pretty standard whitelisting style; the example uses many of the most common source control directives such as `object-src` and `script-src`. According to most instructions and common practice, this is how most CSP directive lists would look.

While doing some research for this post I ran across a [paper](https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/45542.pdf) that covers CSP in thorough detail; I highly recommend it. In the paper, the authors examine usage of CSP across the Internet and conclude that—in the vast majority of cases—CSP is largely ineffective in mitigating XSS; note, however, that the reasons given by the authors for ineffectiveness generally stem from slight misconfigurations and improperly used directives. As a point of reference, the authors consider wildcard usage in whitelists to be inherently insecure as it allows for inclusion of content from arbitrary hosts.

When building a proper CSP whitelist, it is often necessary to conduct a thorough audit of web pages and content that CSP is designed to control. It shouldn't be surprising that in many cases CSP whitelists are left incomplete or generally cause unforeseen issues. A suggested method for rolling out CSP is by using `Content-Security-Policy-Report-Only` and specifying whitelists but only reporting infractions and not blocking content. When Twitter began using CSP in 2011, their engineering team [discovered](https://blog.twitter.com/2011/improving-browser-security-with-csp) quite a bit about their infrastructure using this method (you can find another example of rolling out CSP in [this series of posts on DropBox's tech blog](https://blogs.dropbox.com/tech/tag/content-security-policy/)). Even in Twitter's case, however, the CSP we saw above fails at least one of the checks presented in section 3.3.5 of the aforementioned paper. You can check for yourself by using [this handy tool](https://csp-evaluator.withgoogle.com/).

Thankfully, the authors present an alternative method for utilizing CSP:

> Instead of relying on whitelists, application maintainers should apply a nonce-based protection approach.

A nonce-based policy uses [nonces](https://en.wikipedia.org/wiki/Cryptographic_nonce) (surprising!) to validate loaded or inline scripts. An example policy would appear as follows:

```
Content-Security-Policy:
	script-src ’nonce-random123’
	default-src ’none’
```

The HTML script tag that accompanies the above policy would assert the specified nonce:

{% highlight html %}
<script nonce="random123"
	src="https://example.org/script.js?callback=foo">
</script>
{% endhighlight %}

The proposed method presents a challenge in that code would need to be refactored, but not extensively. The authors also suggest that nonce-based policies don't account for pages that use code that is dynamically generated. The authors go on to propose an addition to CSP in the form of an additional `script-src` expression that they call `'strict-dynamic'` that accomodates such instances. `'strict-dynamic'` is included in CSP3, which is [currently in draft form](https://www.w3.org/TR/CSP/#strict-dynamic-usage) and is—according to the authors—implemented in current versions of Chrome and Opera. (I noticed that `'script-dynamic'` is included on the [Mozilla Developer Network](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/script-src#strict-dynamic), but I couldn't find a definitive answer to whether it's supported in the latest versions of Firefox.)

For more extensive information about CSP best practice according to Google, see [this page](https://csp.withgoogle.com/docs/index.html).

#### Creating a Nonce-based Policy

We need to know a few more details before we implement a nonce-based policy. Nonces are dynamically generated, meaning that a new nonce is created every time a page is requested and is inserted into every script element. This can be done a million different ways; here I'll demonstrate how this could possibly be done with PHP and Apache.

Let's assume that Apache knows about our site and that it can at least display a basic HTML document; outside of that, Apache doesn't know how we want it to handle files with a `.php` extension. Let's change that by opening up `httpd`'s main config file, `/etc/httpd/conf/httpd.conf`, and append the following:

```
<FilesMatch "\.ph(p[2-6]?|tml)$">
    SetHandler application/x-httpd-php
</FilesMatch>
```

Restart `httpd`.

With that done, let's create a basic `.php` file in the site's document root (`/var/www/example.com/public_html/test.php`):

{% highlight html %}
<!DOCTYPE HTML>
<html>

<body>
  <script>
    document.write(6 * 7);
  </script>
</body>

</html>
{% endhighlight %}

If we navigate to our test page, we should see '42' printed in the top left corner of the browser window. Great!

Now let's add some PHP at the top of the file to generate a nonce:

{% highlight php %}
<?php
  $nonce = exec('openssl rand -base64 32');
  header("Content-Security-Policy: script-src 'nonce-".$nonce."'");
?>
{% endhighlight %}

I'm sure a nonce could be natively generated in PHP; instead of figuring out how to do that, I gave in to laziness and used PHP's `exec()` function to call `openssl` to generate a random value for the variable `$nonce`. After generating the value, we then use PHP's `header()` function to send our nonce in a properly formatted CSP header string.

Let's add this to our simple `test.php` file:

{% highlight html %}
<?php
  $nonce = exec('openssl rand -base64 32');
  header("Content-Security-Policy: script-src 'nonce-".$nonce."'");
?>

<!DOCTYPE HTML>
<html>

<body>
  <script nonce="<?php echo $nonce; ?>">
    document.write(6 * 7);
  </script>
</body>

</html>
{% endhighlight %}

You can see that we also have a new attribute in our `<script>` tag where Apache can resolve the variable `$nonce` and insert its value into the tag. Let's give it a test by navigating to our new page and viewing the source. (With Firefox on macOS you can do this by using the `⌘-u` keyboard shortcut.) We should see something similar to the following:

{% highlight html %}
<!DOCTYPE HTML>
<html>

<body>
  <script nonce="rbtNmFdxqMwtWSof7ZtlOvn5aItSVOon/j3ERky412I=">
    document.write(6 * 7);
  </script>
</body>

</html>
{% endhighlight %}

We can verify also that we get a nonce value in the headers by running `curl -I` against our site:

```
HTTP/1.1 200 OK
Date: Mon, 03 Jul 2017 05:01:53 GMT
Server: Apache/2.2.15 (CentOS)
X-Powered-By: PHP/5.3.3
Content-Security-Policy: script-src 'nonce-u3gydq0ren/rpw2QExXDY/EGnOlNRDVY95aQ1fWHrUQ='
```

We can also test that this works by changing the nonce attribute to some arbitrary value (that's not the actual nonce). If we do so, we see that nothing is displayed on the page when we navigate to it. Fantastic! In the next post, I might continue with this but will more likely do a little work with Puppet.

# Fin
