---
layout: post
title: Web security and you.
date: 2017-04-08 10:51:13
disqus: y
---

### Why should I care?

About a month and a half ago a coworker pointed out that when tested against [these standards](https://securityheaders.io/?q=blog.tminor.io&followRedirects=on), my web site receives a failing grade. Even more, when tested against [this battery of standards](https://www.ssllabs.com/ssltest/analyze.html?d=blog.tminor.io), my site barely passed, receiving a C.

In reality, I could get away with trivializing these issues and ignore them altogether. This site is just a pet project that serves no mission critical purpose; it's not used to serve sensitive information; it doesn't host any web applications (at least ones that I've written); I could have shrugged it off and ignored it. But no! Defeatism begets mediocrity and no one wants to be average!

---

### Security headers and you

The tests linked above examine different aspects of web security as they pertain to actual web pages. I'll start with [https://securityheaders.io](https://securityheaders.io), through which this site received a big fat "F." What sort of implications underly a lack of HTTP security headers?

**HTTP basics**

Let's assume some measure of ignorance and establish a basic foundational knowledge (mostly for my own sake). From [RFC 7230](https://tools.ietf.org/html/rfc7230):

> The Hypertext Transfer Protocol (HTTP) is a stateless application-level protocol for distributed, collaborative, hypertext information systems.

More pragmatically, HTTP is a request/response protocol that functions to deliver messages over a session-layer connection between a client and server. A client may be any of a variety of applications that submits an HTTP request to a system that runs an application that responds to said HTTP requests. A request message begins with a request line, specifying a [method token](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html), a [Uniform Resource Identifier](https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.2) (URI), and the protocol version, followed by header fields (which we care about for this post) and two CRLFs (Carriage Return Line Feed), indicating the expectation that the message body containing a payload is to follow (if necessary).

**What purpose do HTTP headers serve?**

We'll start with an example. Running `curl -I` against this site returns the following response header fields:

```
HTTP/1.1 200 OK
Date: Sun, 26 Mar 2017 15:56:39 GMT
Server: Apache/2.4.6 (CentOS) OpenSSL/1.0.1e-fips
Last-Modified: Tue, 21 Mar 2017 15:36:46 GMT
ETag: "12a0-54b3f6958bf80"
Accept-Ranges: bytes
Content-Length: 4768
Content-Type: text/html; charset=UTF-8
```

Again, from RFC 7230:

> Each header field consists of a case-insensitive field name followed by a colon (":"), optional leading whitespace, the field value, and optional trailing whitespace.[<sup>1</sup>](https://tools.ietf.org/html/rfc7230)

Many of the fields above are defined in RFC 7230 and others, but 7230 also specifies that header fields are fully extensible. As such, HTTP has a variety of header fields that are standard and non-standard. Borrowing from Wikipedia, HTTP headers serve to define operating parameters of an HTTP transaction.

Moving on, we will concern ourselves with header fields that prescribe methods of operation that ensure security. Taking a look at the report generated above, the header fields that are missing from an HTTP transaction with my site are as follows:

1. Strict-Transport-Security
2. Content-Security-Policy
3. Public-Key-Pins
4. X-Frame-Options
5. X-XSS-Protection
6. X-Content-Type-Options
7. Referrer-Policy

Let's move on to examining and defining the function of each.

---

### HTTP security headers

Within the past few years, the web has seen a surge in malicious activity. These attacks capitalize on a wide variety of threat vectors including social engineering, software vulnerabilities, and so on. Though HTTP headers can't solve human gullibility, they can help to prevent other types of attacks.

**Strict-Transport-Security**

> (HSTS) defines a mechanism enabling web sites to declare themselves accessible only via secure connections and/or for users to be able to direct their user agent(s) to interact with given sites only over secure connections.[<sup>2</sup>](https://tools.ietf.org/html/rfc6797)

First, let's consider what sort of threat such a specification would aim to mitigate.

*Passive attack*

Alice is connected to the Internet via a local wireless network at a coffee shop. The AP is password protected using [WPA2-PSK](https://en.wikipedia.org/wiki/IEEE_802.11i-2004); Bob is also using the coffee shop's AP to access the Internet. Unfortunately for Alice, Bob is interested in malicious packet sniffing. WPA2-PSK encrypts over-the-air traffic using individualized pairwise keys derived (via [four-way handshake](https://en.wikipedia.org/wiki/IEEE_802.11i-2004#The_four-way_handshake)) by concatenating a slew of variables that include (but are not limited to) the PSK, the AP's MAC address, and so on; unfortunately (again—Alice is very unlucky), Bob is versed in the ways of the four-way handshake and knows that—if he captures it—he can ultimately snoop Alice's traffic. Bob forcefully de-auths Alice and captures the four-way handshake between Alice and the AP. Bob can now decrypt Alice's traffic. In this case, if Alice is interacting with a website over HTTP, Bob can see any transaction between Alice and that website. Thankfully, fewer and fewer websites deliver sensitive information via HTTP (and Firefox even warns users [when they do](https://blog.mozilla.org/security/2017/01/20/communicating-the-dangers-of-non-secure-http/)).

*Active attack*

As a variation on the above, let's consider that Bob is a little more aggressive and has managed to man-in-the-middle Alice. Bob intercepts Alice's traffic by virtue of [ARP cache poisoning](https://en.wikipedia.org/wiki/ARP_spoofing) and attempts to use [SSLStrip](https://www.youtube.com/watch?v=MFol6IMbZ7Y) to force Alice's browser to continue its session with alicesbank.com using HTTP and proxy the connection so that he can get whatever information he needs to steal all of Alice's money.

*HSTS to the rescue*

HSTS was really born as a solution to the latter issue and proves its usefulness in such instances. Let's assume that Alice uses a modern browser that utilizes Google's [HSTS preload list](https://hstspreload.org/). Even if Alice had never connected to her bank's website—given that alicesbank.com has been added to the preload list—, Alice's browser will not allow her to connect in the case described above. Very nifty indeed.

In the case of a passive attacker, the utility of HSTS is slightly diminished. HSTS cannot control whether or not a website uses HTTPS/HSTS. In such an instance the onus is upon the user to be aware of unencrypted connections. Thankfully, browsers have taken to very prominent warnings to notify users in such instances.

*Shortcomings*

HSTS can be bypassed with a bit of effort. See [this blog post](https://finnwea.com/blog/bypassing-http-strict-transport-security-hsts) for more information.

**Content-Security-Policy**

> [CSP is] a mechanism by which web developers can control the resources which a particular page can fetch or execute...[<sup>3</sup>](https://www.w3.org/TR/CSP/)

Content-Security-Policy is designed to mitigate the risk of content injection vulnerabilities such as cross-site scripting (XSS). XSS exploits the basic principle underpinning [same-origin policy](https://en.wikipedia.org/wiki/Same-origin_policy), which (as an oversimplification) asserts that code from one page is permitted to access data from another if they have the same origin (where origin is defined as a URI's scheme, port, and host). An attacker can exploit any number of software vulnerabilities to inject malicious client-side scripts into an otherwise benign web page.

As an example, a miscreant could inject an HTML script source attribute to load malicious code. It's very common to see web pages loading code from CDNs such as Google:

{% highlight html %}
<script src="https://ajax.googleapis.com/ajax/libs/angularjs/1.5.7/angular.min.js"></script>
{% endhighlight %}

At first I was confused by this; I wasn't sure exactly how this conformed to any sort of same-origin policy. In order to understand the principal of same-origin, it's important to distinguish that same-origin only applies in terms of the browser (i.e. only the browser cares about same-origin). A same-origin policy generally only enforces rules to prevent, for example, an iframe (a web page within a web page, more or less) from reading or modifying contents from the parent frame. This means that if a web page loads a script from an external source *before* sending it to a browser, there's no issue; the browser sees all of the code and content coming from the same place.

Hopefully this explanation makes clear how content on the server side can be exploited. Let's consider an example where a server doesn't enforce CSP.

Let's say that Bob runs a WordPress blog. Bob has auto-updating disabled and is behind on patching and missed one of the latest [WordPress vulnerabilities](https://blog.sucuri.net/2017/02/content-injection-vulnerability-wordpress-rest-api.html). Alice, being a savvy ne'er-do-well, has happened upon Bob's blog and begins to poke at it until discovering that the site is ripe for owning. Alice injects copious amounts of porn and spam, leaving Bob's blog a steaming cesspool.

For the sake of illustration, let's say that Bob is a consultant in the info sec space. If potential clients were to happen upon Bob's site, that would be a little embarassing, needless to say.

This probably doesn't bare explaining, but this hypothetical situation could have been prevented with CSP white listing. There's even a [plugin](https://wordpress.org/plugins/wp-content-security-policy/) so that anyone can do it!

**Public-Key-Pins**

> [HTTP Public Key Pinning] allows web host operators to instruct user agents to remember ("pin") the hosts' cryptographic identities over a period of time.[<sup>4</sup>](https://tools.ietf.org/html/rfc7469)

Let's start with an example of an HTTP response that contains an HPKP field.

```
$ curl -I https://github.com

HTTP/1.1 200 OK
Server: GitHub.com
Date: Fri, 07 Apr 2017 19:42:32 GMT
Content-Type: text/html; charset=utf-8
Status: 200 OK
<snip>
Public-Key-Pins: 
  max-age=5184000; 
  pin-sha256="WoiWRyIOVNa9ihaBciRSC7XHjliYS9VwUGOIud4PB18="; 
  pin-sha256="RRM1dGqnDFsCJXBTHky16vi1obOlCgFFn/yOhI/y+ho="; 
  pin-sha256="k2v657xBsOVe1PQRwOsHsw3bsGT2VzIqz5K+59sNQws="; 
  pin-sha256="K87oWBWM9UZfyddvDfoxL+8lpNyoUB2ptGtn0fv6G2Q="; 
  pin-sha256="IQBnNBEiFuhj+8x6X8XLgh01V9Ic5/V3IRQLNFFc7v4="; 
  pin-sha256="iie1VXtL7HzAMF+/PVPR9xzT80kQxdZeJ+zduCB3uj0="; 
  pin-sha256="LvRiGEjRqfzurezaWuj8Wie2gyHMrW5Q06LspMnox7A="; 
  includeSubDomains
</snip>
```

As we can see, the HPKP header field contains a `max-age` directive; this particular directive specifies the length of time which a pin is trusted by a User Agent (UA). Following this directive, we see several pin directives specifying different hash values (which are all derived via SHA-256 as this is the only hash function currently supported under RFC 7469).

Okay, great. But what does all of this mean and what risk does HPKP hope to mitigate?

Consider the breach of [DigiNotar](https://en.wikipedia.org/wiki/DigiNotar#Issuance_of_fraudulent_certificates). DigiNotar was compromised in 2011 and a wildcard certificate was issued for `*.google.com` (amongst many others). The attacker was then able to man-in-the-middle Gmail users in Iran using the fraudulent cert. At the time, Google Chrome reported an error due to a missing or incorrect HPKP pin.

An HPKP pin is generally a hash of the Subject Public Key Info portion of an X.509 certificate. So in the case above, users were being provided with a valid cert for `*.google.com`, but the hash of the SPKI did not match the one found (or not) in the HPKP header field. Chrome reported this to the user while other browsers did not.

**X-Frame-Options**

> The use of "X-Frame-Options" allows a web page from host B to declare that its content (for example, a button, links, text, etc.) must not be displayed in a frame (&ltframe&gt or &ltiframe&gt) of another page.[<sup>5</sup>](https://tools.ietf.org/html/rfc7034#section-1)

Clickjacking—in simple terms—is a technique used to trick a user into clicking something other than what was intended by the user. An example might be the following:

An attacker lures an unsuspecting victim into viewing their web page via an enticing ad. Once on the page, the attacker includes a multitude of interesting hyperlinks that the user clicks on. Unbeknownst to the victim, the attacker has used an invisible iframe placed directly over the interesting hyperlink. What the victim doesn't know is that they've unwittingly clicked a Facebook "like" button. Gasp!

This could be prevented if Facebook used X-Frame-Options in its response headers, which it does:

```
HTTP/1.1 200 OK
<snip>
public-key-pins-report-only: max-age=500; pin-sha256="WoiWRyIOVNa9ihaBciRSC7XHjliYS9VwUGOIud4PB18="; pin-sha256="r/mIkG3eEpVdm+u/ko/cwxzOMo1bk4TyHIlByibiA5E="; pin-sha256="q4PO2G2cbkZhZ82+JgmRUyGMoAeozA+BSXVXQWB8XWQ="; report-uri="http://reports.fb.com/hpkp/"
<snip>
X-Frame-Options: DENY
</snip>
```

(I left the `public-key-pins-report-only` to illustrate that Facebook uses a different version of the HPKP header; in this case, all violations are reported but not acted upon [i.e. the browser allows connections upon violation].)

In the case given above, the attacker's site is unable to load the Facebook "like" button in an invisible iframe.

**X-XSS-Protection**

I don't really feel like going into this one too much because:

> The HTTP X-XSS-Protection response header is a feature of Internet Explorer, Chrome and Safari that stops pages from loading when they detect reflected cross-site scripting (XSS) attacks. Although these protections are largely unnecessary in modern browsers when sites implement a strong Content-Security-Policy that disables the use of inline JavaScript ('unsafe-inline'), they can still provide protections for users of older web browsers that don't yet support CSP.

Here's an example in an HTTP response from GitHub:

```
HTTP/1.1 200 OK
Server: GitHub.com
Date: Sat, 08 Apr 2017 12:18:34 GMT
Content-Type: text/html; charset=utf-8
Status: 200 OK
<snip>
X-XSS-Protection: 1; mode=block
</snip>
```

IE 8 was the first to implement this feature, followed by Safari and Chrome using XSS Auditor. I'm not sure how IE works, but you can find the source code for XSS Auditor [on Github](https://github.com/WebKit/webkit/blob/master/Source/WebCore/html/parser/XSSAuditor.cpp). Simply put, the browser uses heuristics to detect common patterns of XSS attacks and blocks them.

**X-Content-Type-Options**

> The X-Content-Type-Options response HTTP header is a marker used by the server to indicate that the MIME types advertised in the Content-Type headers should not be changed and be followed.

Since I was completely ignorant of this prior to starting this section, I'm going to go into some detail.

Multipurpose Internet Mail Extensions (MIME) was initially designed as an extension to SMTP in order to provide facilities to represent body content in character sets other than US-ASCII (which did not provide for transmission of extended character sets; 7-bit characters as opposed to 8-bit). RFC 1341 includes [specifications for RFC 822 header fields](https://tools.ietf.org/html/rfc1341#page-2) (and body part headers... very confusing), one of which is the Content-Type field, which is intended to describe data contained within the body such that a UA can suitably choose a mechanism by which to present the data.

Though MIME was originally intended as an extension upon SMTP, it is also used by other Internet protocols for similar purposes. As an example, a server may say "this is data, and its MIME type is `image/jpg`." In Java, it would appear as:

{% highlight java %}
// Response is of type javax.servlet.ServletReponse
response.setContentType("image/jpg");
{% endhighlight %}

The browser then knows how to handle the data. In the example, the browser can render the data internally, whereas if the data were presented as MIME type `application/pdf`, it would know to render the data with whatever the browser knows as the PDF handler.

Alright, so what does X-Content-Type-Options do?

When this header field is absent, some browsers will practice "content sniffing," which involves the browser guessing MIME types by examining a byte stream (which generally employs a mixture of heuristics, file signatures, etc.). This imposes a security risk; a browser may improperly interpret data types provided by an attacker, allowing the possibility for a XSS attack (see [this old paper](http://www.adambarth.com/papers/2009/barth-caballero-song.pdf)). All of this can be avoided by including the X-Content-Type-Options header field:

```
$ curl -I https://www.facebook.com

HTTP/1.1 200 OK
<snip>
X-Content-Type-Options: nosniff
<snip>
Content-Type: text/html
</snip>
```

**Referrer-Policy**

Referrer-Policy allows a site to send reference information for instances where a user clicks a hyperlink away from the site to another. When a user clicks a link, the browser sends a request that includes the referrer information. Referrer logging can then be used for analytics to identify traffic patterns for promotional and statistical purposes.

(Interesting trivia: the Referrer-Policy referrer field is represented as `referer`, a misspelling that originated in the initial proposition to incorporate the header in the HTTP specification.)

The logging of this information raises some privacy concerns. Scott Helme (the author of securityheaders.io) [indicates](https://scotthelme.co.uk/a-new-security-header-referrer-policy/) that a site can't receive an A+ without a "good policy." I'm kind of unclear on what constitutes a "good" policy; I'll examine that in my next post where I hope to implement these headers.

###END

Alright, this has gone on long enough. In the next post, I'll try to stick to an illustration of how to implement the headers above via Apache configs. Oh yeah, I'll also explain the results of the tests from [Qualys](https://www.ssllabs.com/ssltest/analyze.html?d=blog.tminor.io).