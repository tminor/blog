---
layout: post
title: Web security and you.
date: 2017-03-26 09:30:45
disqus: y
---

### Why should I care?

About a month and a half ago a coworker pointed out that when tested against [these standards](https://securityheaders.io/?q=blog.tminor.io&followRedirects=on), my web site receives a failing grade. Even more, when tested against [this battery of standards](https://www.ssllabs.com/ssltest/analyze.html?d=blog.tminor.io), my site barely passed, receiving a C.

In reality, I could get away with trivializing these issues and ignore them altogether. This site is just a pet project that serves no mission critical importance; it's not used to serve sensitive information; it doesn't host any web applications (at least ones that I've written); I could have shrugged it off and ignored it. But no! Defeatism begets mediocrity and no one wants to be average!

---

### Security headers and you

The tests linked above examine different aspects of web security as they pertain to actual web pages. I'll start with [https://securityheaders.io](https://securityheaders.io), through which this site received a big fat "F." What sort of implications underly a lack of HTTP security headers?

**HTTP basics**

Let's assume some measure of ignorance and establish a basic foundational knowledge (mostly for my own sake). From [RFC 7230](https://tools.ietf.org/html/rfc7230):

> The Hypertext Transfer Protocol (HTTP) is a stateless application-level protocol for distributed, collaborative, hypertext information systems.[<sup>1</sup>](https://tools.ietf.org/html/rfc7230)

More pragmatically, HTTP is a request/response protocol that functions to deliver messages over a session-layer connection between a client and server. A client may be any of a variety of applications that submits an HTTP request to a system that runs an application that responds to said HTTP requests. A typical HTTP message takes the form of a retrieval request (GET). A request message begins with a request line, specifying a [method token](https://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html), a [Uniform Resource Identifier](https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.2) (URI), and the protocol version, followed by header fields (which we care about for this post) and two CRLFs (Carriage Return Line Feed), indicating the expectation that the message body containing a payload is to follow (if necessary).

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

> Each header field consists of a case-insensitive field name followed by a colon (":"), optional leading whitespace, the field value, and optional trailing whitespace.

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

Alice is connected to the Internet via a local wireless network at a coffee shop. The AP is password protected using [WPA2-PSK](https://en.wikipedia.org/wiki/IEEE_802.11i-2004); Bob is also using the coffee shop's AP to access the Internet. Unfortunately for Alice, Bob is interested in malicious packet sniffing. WPA2-PSK encrypts over-the-air traffic using individualized pairwise keys derived (via [four-way handshake](https://en.wikipedia.org/wiki/IEEE_802.11i-2004#The_four-way_handshake)) by concatenating a slew of variable that include (but are not limited to) the PSK, the AP's MAC address, and so on; unfortunately (again—Alice is very unlucky), Bob is versed in the ways of the four-way handshake and knows that—if he captures it—he can ultimately snoop Alice's traffic. Bob forcefully deauths Alice and captures the four-way handshake between Alice and the AP. Bob can now decrypt Alice's traffic. In this case, if Alice is interacting with a website over HTTP, Bob can see any transaction between Alice and that website. Thankfully, fewer and fewer websites deliver sensitive information via HTTP (and Firefox even warns users [when they do](https://blog.mozilla.org/security/2017/01/20/communicating-the-dangers-of-non-secure-http/)).

*Active attck*

As a variation on the above, let's consider that Bob is a little more aggressive and has managed to man-in-the-middle Alice. Bob intercepts Alice's traffic by virtue of [ARP cache poisoning](https://en.wikipedia.org/wiki/ARP_spoofing) and attempts to use [SSLStrip](https://www.youtube.com/watch?v=MFol6IMbZ7Y) to force Alice's browser to continue its session with alicesbank.com using HTTP and proxy the connection so that he can get whatever information he needs to steal all of Alice's money.

*HSTS to the rescue*

HSTS was really born as a solution to the latter issue and proves its usefulness in such instances. Let's assume that Alice uses a modern browser that utilizes Google's [HSTS preload list](https://hstspreload.org/). Even if Alice had never connected to her bank's website—given that alicesbank.com has been added to the preload list—, Alice's browser will not allow her to connect in the case described above. Very nifty indeed.

In the case of a passive attacker, the utility of HSTS is slightly diminished. HSTS cannot control whether or not a website uses HTTPS/HSTS. In such an instance the onus is upon the user to be aware of unencrypted connections. Thankfully, browsers have taken to very prominent warnings to notify users in such instances.

Here's a real life example using `curl -s -D- https://paypal.com/`:

```
HTTP/1.0 301 Moved Permanently
Location: https://www.paypal.com/
Strict-Transport-Security: max-age=63072000
Connection: Keep-Alive
Content-Length: 0
```

*Shortcomings*

HSTS can be bypassed with a bit of effort. See [this blog post](https://finnwea.com/blog/bypassing-http-strict-transport-security-hsts) for more information.

**Content-Security-Policy**

> (CSP is) a mechanism by which web developers can control the resources which a particular page can fetch or execute... [<sup>3</sup>](https://www.w3.org/TR/CSP/)

Cross-site scripting (XSS) has been a notable threat vector since [at least 2007](http://eval.symantec.com/mktginfo/enterprise/white_papers/b-whitepaper_exec_summary_internet_security_threat_report_xiii_04-2008.en-us.pdf#page2). XSS exploits a browser's inability to destinguish malicious code that otherwise originates from a benign, trusted web site. As an example, this site currently includes code from `blog-tminor-io.disqus.com/embed.js`. Unfortunately, this web server would happily deliver code even if it originated from `malicious.blog-tminor-io.disqus.com/owned.js`. CSP mitigates this threat by using source whitelisting to inform a browser what 