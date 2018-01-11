---
layout: post
title: Web security and you, part two.
date: 2017-04-14 2:40:13
disqus: y
---

### The saga continues

Before getting into configuring Apache to accomodate secure response headers (which I'll save for the next post to avoid another lengthy post), I need to cover the Qualys SSL Report generated [here](https://www.ssllabs.com/ssltest/analyze.html?d=blog.tminor.io). I neglected to mention in my last post that if you're reading this in the not-so-distant future, all of these tests will probably (hopefully) return favorable results. In any case, I hope to outline how my site failed, why, and what implications underly its failure.

---

### What's the point?

I understand that certificates are a necessary cog in the machine of secure web browsing. I've watched [this Computerphile video](https://www.youtube.com/watch?v=GSIDS_lvRv4) several times and it helped me to understand the whole process a bit more, but my depth of knowledge has remained, nonetheless, quite shallow.

To better understand public key certificates, it's important to identify the problem that they are intended to solve. In simple terms, public key certificates are intended to establish a digital entity's identity and maintain data integrity using cryptography.

One of the more easily understood examples of cryptography is a typical cereal box style decoder ring. These rings generally (always?) use affine encipherment which [simply](https://en.wikipedia.org/wiki/Affine_cipher) means that alpha characters are encoded as their numerical equivalent (a → 1, b → 2, etc.). If two parties hope to share a secret using such a method, the parties must agree upon a predetermined shared secret. This is an example of symmetric key cryptography (a single key serves to encrypt *and* decrypt).

With public key cryptography, two parties needn't share a secret to establish a secure means of communication. Public key cryptography is a cryptographic system that utilizes a key pair, one public and one private. Let's use Alice and Bob to illustrate how this works. Alice wants to send a private message to Bob but lives many miles away and can't meet Bob to exchange a shared secret. Thankfully, Bob already has a system set up and sends Alice his brand new public key. Alice uses Bob's key to encrypt a message and sends it off to him. Unfortunately, Eve intercepts the message, hoping to learn all of Alice and Bob's salacious secrets. Thankfully for Alice and Bob, Eve doesn't have the private key and therefore can't decrypt the message. Fantastic!

Okay, so now we have a basic understanding of public key cryptography. Let's make explicit another implication presented in public key cryptography: given that Bob keeps his private key *private*, it can be used to prove his identity and the authenticity of his digital communications (and can be used to prove cryptographic [non-repudiation](http://world.std.com/~cme/non-repudiation.htm)). 

**X.509... or Public Key Infrastructure**

So Bob has a public and private key and can establish his identitiy using a certificate containing his public key; how can we prove that Chuck—as a malicious actor—hasn't created a certificate in Bob's name? Well, in the hypothetical illustration above, we can't. This is where public key infratructure (PKI) comes in. PGP (as an example of a sort of *ad libitum* method of ensuring authenticity and data integrity) relies on a variation of PKI, but it utilizes a decentralized model to establish trust (like we saw with Alice and Bob earlier). This is not a bad thing, but it's not the method by which trust is established on the web (generally speaking). The Internet uses a centralized method to accomplish this. [RFC 5280](https://tools.ietf.org/html/rfc5280#page-8) defines this in great detail; essentially, an entity requests a certificate using a cryptographic digital signature and a certificate is granted to that entity by a trusted authority using its signature. Here's a rough illustration of how the process might look from request to usage:

1. An entity requests a certificate using a Certificate Signing Request (CSR).
2. A Certificate Authority (CA) (such as Google, ISRG, etc.) receives the request and issues a certificate, given that the requester has sufficiently proven their identity.
3. When a user agent (UA) receives the certificate, it checks against its trust store whether the certificate issuer is a valid one.
4. If the UA finds that a certificate is self-signed or issued by a CA not contained within the trust store, the UA warns the user.

**Transport Layer Security**

Certificates are utilized on the Internet as a means of establishing secure communication via Transport Layer Security (TLS). TLS was preceded by Secure Sockets Layer (SSL) and is often colloquially (and confusingly) referred to as such. TLS brings together all of the concepts explored above: it is a protocol by which two applications can establish secure, private communication and ensure data integrity using symmetric cryptography. The easiest way to understand this is to walk through a typical TLS handshake between a client and server:

```
CLIENT: ClientHello - message containing TLS/SSL options (cipher suite, TLS version, etc.)
SERVER: ServerHello - server responds with chosen TLS/SSL options
SERVER: Certificate - server's certificate chain sent to client
SERVER: ServerHelloDone - server indicates completion of its part of negotiation
CLIENT: ClientKeyExchange - client sends encrypted session key using server's public key
CLIENT: ChangeCipherSpec - client intializes negotiated options for all future messages
CLIENT: Finished - client asks server to verify negotiated options
SERVER: ChangeCipherSpec - same as above, but enacted by the server
SERVER: Finished - verification requested by server

Encrypted application data can now be sent
```

As we can see, the server's certificate is used to both prove its identity and establish a secure channel of communication between itself and a client. To reiterate: a client makes a request to connect to a server; the server responds with its certificate containing its public key; the client uses the server's public key to encrypt a private session key that's generated client-side and that will be used to establish symmetric encryption; the client and server agree that the information they've exchanged is correct and begin encrypted communication.

---

### What does Qualys's SSL report tell us?

The report linked at the top of the post does several things: first, we're presented with basic information such as the validity dates, the common name, the issuer, etc. of each certificate. Here are some highlights with some basic explanation:

> Key: 	RSA 2048 bits (e 65537)

This attribute specifies the method used to obtain the public key; in this case, the key used was generated with [RSA](https://tools.ietf.org/html/rfc3447) and is 2048 bits in length. An alternative to RSA is elliptic curve cryptography; I was curious to see the prominence of key types and found that both Facebook and Google seem to have used this method for key generation. Take a look at [this StackExchange answer](https://crypto.stackexchange.com/a/1194) for more interesting discussion regarding RSA and EC.

> Extended Validation: 	No

Extended validation (EV) certificates involve a lengthier, more involved process for verifying the identity of an entity. To a user in front of a browser, this appears as a green bar, padlock, and the entity's legal name appearing next to the URL at the top of browser. Also, they are [very expensive](https://www.digicert.com/ev-price-comparison.htm).

> Certificate Transparency: 	No

Certificate Transparency is an experimental protocol for the logging of TLS certificate activity, allowing transparent auditing. I find it odd that this test failed, as Let's Encrypt advertises that they [log all certificates upon issuance](https://letsencrypt.org/certificates/). As an interesting side note, CT led to the [recent kerfuffle involving Google Chrome and Symantec](https://groups.google.com/a/chromium.org/d/msg/blink-dev/eUAKwjihhBs/rpxMXjZHCQAJ).

> OCSP Must Staple: 	No

OCSP stands for Online Certificate Status Protocol and is defined in RFC 6960 as "a protocol useful in determining the current status of a digital certificate without requiring Certificate Revocation Lists (CRLs)." If a private key is compromised, an attacker can intercept and impersonate the party to which the key originally belonged. The original entity can generate a new certificate, however the attacker can persist in impersonation. Originally when clients received a certificate from a host, they'd check against previously retrieved CRLs; CRLs were generally handled poorly in the past [by browsers](https://news.netcraft.com/archives/2013/05/13/how-certificate-revocation-doesnt-work-in-practice.html). OCSP is an alternative that involves an additional check where a client requests a certificate's revocation status from the issuing CA. For more highly trafficked sites, this could cause an increased burden on infrastructure. OCSP stapling shifts the burden to the server to which a certificate belongs; the server contacts the issuing CA at regular intervals requesting revocation status and returns it to the client. OCSP Stapling has been plagued by [its implementation](https://www.grc.com/revocation/ocsp-must-staple.htm) resulting in inconsistent deployment and adoption in browsers. OCSP Must Staple aims to solve the problem by adding a certificate extension that indicates that a respons MUST be stapled, otherwise the browser is to return a failure. This prevents attackers from skirting the return of a non-mandatory OCSP response. 

> DNS CAA: 	No

Certificate Authority Authorization records are a type of DNS record that specify CAs authorized to issue certificates for a given domain. Before a certificate is issued, the CA performs a lookup to verify whether or not it is authorized. [As pointed out here](https://scotthelme.co.uk/certificate-authority-authorization/), it's not a perfect solution but adds yet another line of defense.

**Configuration**

The remainder of the report covers protocol and cipher suite support as well as vulnerability information. Among the list are two cipher suites both listed under TLS 1.0. This section also points out that my site may not be compatible with browsers that don't support SNI. Server Name Indication is an extension to TLS that involves the client indicating the host name intended for connection; this enables a single server to present several certificates via one IP address without using a single certificate (it is possible to list multiple domain names in a certificate's `subjectAltName` field, but the certificate must be reissued every time the list changes, rendering this strategy impractical).

**Protocol details (END)**

This section outlines quite a lot of information (a good bit of which I covered in the last post). One of the biggest detractors to my site's grade in this report is the fact that it's vulnerable to the POODLE attack (i.e. the site supports SSL 3.0). I would really like to write about POODLE, but I'm afraid it's [quite a bit over my head](https://security.stackexchange.com/a/70724). Maybe some day (far in the future) I'll be able to understand it. For now, I'll call it quits. In the next post I'll finally get around to actually fixing all of this!