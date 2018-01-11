---
layout: post
title: Configuring Kerberos and Syncrepl GSSAPI auth.
date: 2017-03-03 12:43:12
disqus: y
---

### Why Kerberos?

For quite some time, I have not been able to configure my OpenLDAP hosts to replicate over TLS successfully. It has been a frustrating experience for a variety of reasons (not the least of which is my naivety); first, debugging OpenLDAP has been a learning experience in and of itself. Once I figured out how to enable logging, deciphering the true meaning for `olcLogLevel` directive values was beyond my level of understanding. (It's maybe more accurate to say that interpretting the logs given certain directive values is beyond me.) Instead of making an informed decision, I utilized trial and error to elicit any sort of meaningful logging information. At best, I managed to evoke a generic `TLS handshake failure` message. After quite a lot of banging my head against a wall, I felt that I was on the verge of concussion.

I consigned myself to failure and decided to approach the issue with a different strategy. The problem: replication taking place in cleartext. After some research, I learned that OpenLDAP is generally used in tandem with Kerberos; using Kerberos, OpenLDAP hosts can authenticate via GSSAPI. GSSAPI is a generic interface by which a service can perform all of the functions necessary to enforce confidentiality and authenticity. Kerberos supports a variety of encryption methods, however the default appears to be `aes256-cts-hmac-sha1-96` (see [here](http://crypto.stackexchange.com/questions/11626/what-does-aes256-cts-hmac-sha1-96-mean-in-relation-to-kerberos)). Consensus seems to indicate that this is perfectly suitable (for a discussion on alternatives, see [here](https://blog.cryptographyengineering.com/2012/10/09/so-you-want-to-use-alternative-cipher/)[it's worth noting that MIT Kerberos doesn't support any of the listed alternatives]).

During the time that it took to configure Kerberos and OpenLDAP, I discovered more ways to effectively debug OpenLDAP and subsequently tracked down the cause of the TLS failure between the two LDAP hosts. After stopping `slapd`, I started it in debug mode by running `slapd -d 512` (I don't think the debug mode mattered in this case, but it seemed to unearth a log message that indicated a specific certificate issue). The first error message to catch my eye was as follows:

```
TLS error -8054:You are attempting to import a cert with the same issuer/serial as an existing cert, but that is not the same cert.
```

Needless to say I felt quite stupid. I quickly deleted one of the server certificates and regenerated it with a different serial number... and it worked. At that point, I had functional TLS encryption for replication between the two hosts. Anyhow, let's move on to the configuration of Kerberos.

---

### Install and configure Kerberos

Some documentation found across the internet recommends configuring the master KDC (Key Distribution Center) on the same host as OpenLDAP; I did not do this. I set up a separate host for the KDC, so we'll start with a blank CentOS 6 VM. Assuming basic configuration is done, install the Kerberos server package:

```
$ sudo yum install krb5-server-ldap
```

This package includes a schema file that can be used to create an LDIF file that we'll use to configure OpenLDAP to include Kerberos objects and attributes. Using `scp`, `ftp`, etc., send the schema file to the LDAP hosts. The schema file path is `/usr/share/doc/krb5-server-ldap-1.10.3/kerberos.schema`. On the LDAP host, create a new directory; the following steps will generate a lot of files and subdirectories, so it helps to keep everything contained within a staging directory. First, create a dummy `.conf` file and insert the following include statement:

```
include /path/to/staging/dir/kerberos.schema
```

Next, run `slaptest` against the dummy `.conf` file:

```
$ slaptest -f kerberos.schema -F /path/to/target/dir
```

Open the newly created LDIF file:

```
$ vi /path/to/target/dir/cn\=config/cn\=schema/*.ldif
```

Delete the following attributes:

```
structuralObjectClass: olcSchemaConfig
entryUUID: 
creatorsName: cn=config
createTimestamp: 
entryCSN: 
modifiersName: cn=config
modifyTimestamp: 
```

And change these attributes:

```
dn: cn={0}kerberos
cn: {0}kerberos
```

to reflect the following:

```
dn: cn=kerberos,cn=schema,cn=config
cn: kerberos
```

Load the new schema LDIF:

```
$ sudo ldapadd -H ldapi:/// -Y EXTERNAL -f krbschema.ldif
```

Verify that the schema has been added:

```
sudo ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=schema,cn=config" dn
```

Next, we'll begin to configure OpenLDAP as the Kerberos backend. Create the following LDIF file:

```
dn: ou=users,dc=example,dc=com
ou: Users
objectClass: top
objectClass: organizationalUnit
description: Central location for UNIX users

dn: ou=groups,dc=example,dc=com
ou: Groups
objectClass: top
objectClass: organizationalUnit
description: Central location for UNIX groups

dn: ou=services,dc=example,dc=com
ou: Services
objectClass: top
objectClass: organizationalUnit
description: Group for service accounts.

dn: ou=kerberos,ou=services,dc=example,dc=com
ou: kerberos
objectClass: top
objectClass: organizationalUnit
description: Kerberos OU to store Kerberos principals.

dn: cn=krbadmin,ou=groups,dc=example,dc=com
objectClass: top
objectClass: posixGroup
cn: krbadmin
gidNumber: 800
description: Kerberos administrator's group.

dn: cn=krbadmin,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: posixAccount
objectClass: top
cn: krbadmin
givenName: Kerberos Administrator
mail: kerberos.admin@example.com
sn: krbadmin
uid: krbadmin
uidNumber: 800
gidNumber: 800
homeDirectory: /home/krbadmin
loginShell: /bin/false
displayname: Kerberos Administrator
```

Load the LDIF file and then change the password for the `krbadmin` user:

```
ldappasswd -xWSD "cn=admin,dc=example,dc=com" "cn=krbadmin,ou=users,dc=example,dc=com"
```

We'll now continue configuration on the KDC. Edit `/etc/krb5.conf`:

```
[logging]
 default = SYSLOG:INFO:LOCAL1
 kdc = SYSLOG:NOTICE:LOCAL1
 admin_server = SYSLOG:WARNING:LOCAL1

[libdefaults]
 default_realm = EXAMPLE.COM
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true

[realms]
 example.COM = {
  kdc = kdc1.example.com
  admin_server = kdc1.example.com
  default_domain = example.com
  database_module = openldap_ldapconf
 }

[domain_realm]
 .example.com = EXAMPLE.COM
 example.com = EXAMPLE.COM

[appdefaults]
 pam = {
  debug = false
  ticket_lifetime = 36000
  renew_lifetime = 36000
  forwardable = true
  krb4_convert = false
 }

[dbmodules]
 openldap_ldapconf = {
  db_library = kldap
  ldap_kerberos_container_dn = ou=kerberos,ou=services,dc=example,dc=com
  ldap_kdc_dn = cn=krbadmin,ou=users,dc=example,dc=com
   # this object needs to have read rights on
   # the realm container, principal container and realm sub-trees
  ldap_kadmind_dn = cn=krbadmin,ou=users,dc=example,dc=com
   # this object needs to have read and write rights on
   # the realm container, principal container and realm sub-trees
  ldap_service_password_file = /etc/krb5.d/stash.keyfile
  ldap_servers = ldap://ldap1.example.com ldap://ldap2.example.com
  ldap_conns_per_server = 5
 }
```

Next, edit the ACL file for the `kadmind` daemon (`/var/kerberos/krb5kdc/kadm5.acl`):

```
*/admin@EXAMPLE.COM *
```

Edit `/var/kerberos/krb5kdc/kdc.conf`:

```
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 EXAMPLE.COM = {
  #master_key_type = aes256-cts
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
  supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
 }
```

---

### Create the KDC database

Create a directory and a `stash.keyfile` so that the KDC can authenticate itself to `kadmin` and other database utilities:

```
$ sudo mkdir /etc/krb5.d/ && sudo touch /etc/krb5.d/stash.keyfile
```

The next command will create objects and attributes in our LDAP directory for Kerberos:

```
$ sudo kdb5_ldap_util -D "cn=admin,dc=example,dc=com" create -subtrees "ou=kerberos,ou=services,dc=example,dc=com" -r EXAMPLE.COM -s -H ldap://ldap1.example.com
```

Extract the `krbadmin` password so that Kerberos can authenticate via the directory:

```
$ sudo kdb5_ldap_util -D "cn=admin,dc=example,dc=com" stashsrvpw -f /etc/krb5.d/stash.keyfile cn=krbadmin,ou=users,dc=example,dc=com
```

Enable `kadmin` and `krb5kdc` on startup:

```
$ sudo chkconfig krb5kdc on && sudo chkconfig kadmin on
```

Finally, start the two services:

```
$ sudo service krb5kdc start && sudo service kadmin start
```

---

### Creating Kerberos principals

Run `kadmin.local` to start the command-line interface for `kadmin`. Begin by creating principals for yourself as both a regular user and admin:

```
kadmin.local:  addprinc user@EXAMPLE.COM
kadmin.local:  addprinc user/admin@EXAMPLE.COM
```

After creating our administrative principal, we can authenticate to the KDC remotely and add principals on each host. On each of the LDAP hosts, install the `krb5-workstation` package and run the following commands to create host principals:

```
$ sudo kadmin -p user/admin@EXAMPLE.COM
kadmin:  addprinc -randkey host/ldap1.example.com@EXAMPLE.COM
WARNING: no policy specified for host/ldap1.example.com@EXAMPLE.COM; defaulting to no policy
Principal "host/ldap1.example.com@EXAMPLE.COM" created.

kadmin:  ktadd host/ldap1.example.com@EXAMPLE.COM
Entry for principal host/ldap1.example.com@EXAMPLE.COM with kvno 4, encryption type aes256-cts-hmac-sha1-96 added to keytab FILE:/etc/krb5.keytab.
Entry for principal host/ldap1.example.com@EXAMPLE.COM with kvno 4, encryption type aes128-cts-hmac-sha1-96 added to keytab FILE:/etc/krb5.keytab.
Entry for principal host/ldap1.example.com@EXAMPLE.COM with kvno 4, encryption type des3-cbc-sha1 added to keytab FILE:/etc/krb5.keytab.
Entry for principal host/ldap1.example.com@EXAMPLE.COM with kvno 4, encryption type arcfour-hmac added to keytab FILE:/etc/krb5.keytab.
Entry for principal host/ldap1.example.com@EXAMPLE.COM with kvno 4, encryption type des-hmac-sha1 added to keytab FILE:/etc/krb5.keytab.
Entry for principal host/ldap1.example.com@EXAMPLE.COM with kvno 4, encryption type des-cbc-md5 added to keytab FILE:/etc/krb5.keytab.
```

Ensure correct ownership of the `krb5.keytab` file:

```
$ sudo chown root:ldap /etc/krb5.keytab
$ sudo chmod 640 /etc/krb5.keytab
```

Add the following to `/etc/sysconfig/ldap`:

```
KRB5_KTNAME=/etc/krb5.keytab
```

Repeat these steps for the second LDAP host as well.

---

### Configure OpenLDAP for SASL

Create and load the following LDIF file:

```
# Configure SASL for our OpenLDAP server.

dn: cn=config
changetype: modify
delete: olcSaslSecProps
-
add: olcSaslSecProps
olcSaslSecProps: noanonymous,noplain
-
add: olcSaslHost
olcSaslHost: kdc1.example.com
-
add: olcSaslRealm
olcSaslRealm: EXAMPLE.COM
```

The authentication process is predicated on the presence of a valid Kerberos ticket; we'll want to automate this so we don't have to think about it. I'm sure there are several ways to do this, but I've chosen to use an Upstart job. Create a file in the `/etc/init` directory (I chose `k5start.conf`) with the following contents:

```
start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]
respawn
normal exit 0 1 TERM HUP
exec /usr/bin/k5start -U -f /etc/krb5.keytab -b -K 10 -l 24h -k /tmp/krb5cc_55 -o ldap
```

This job will start `k5start` as a background process, ensuring that a valid ticket exists at all times. With everything in place, it's time to configure `syncrepl` for GSSAPI. Create an LDIF file with the following contents:

```
dn: olcDatabase={2}bdb,cn=config
changetype: modify
replace: olcSyncRepl
olcSyncRepl:
  rid=001
  provider=ldap://ldap1.example.com
  starttls=critical
  tls_reqcert=allow
  bindmethod=sasl
  saslmech=gssapi
  searchbase="dc=example,dc=com"
  type=refreshAndPersist
  retry="5 5 300 5"
  timeout=1
  interval=00:00:00:10
olcSyncRepl:
  rid=002
  provider=ldap://ldap2.example.com
  starttls=critical
  tls_reqcert=allow
  bindmethod=sasl
  saslmech=gssapi
  searchbase="dc=example,dc=com"
  type=refreshAndPersist
  retry="5 5 300 5"
  timeout=1
  interval=00:00:00:10
```

---

### Configure clients

Finally, we'll configure any client that should authenticate via LDAP and Kerberos; it's pretty much as simple as ensuring that the client is synced via `ntpd`, ensuring that the client has a valid Kerberos ticket, and ensuring that all services are installed and configured properly. First prepare the client by installing all of the client tools for Kerberos and LDAP, as well as SSSD:

```
$ sudo yum install sssd openldap-clients krb5-workstation
```

The client's `/etc/krb5.conf` file should appear as follows:

```
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 default_realm = example.com
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true

[realms]
 example.com = {
  kdc = kdc1.example.com
  admin_server = kdc1.example.com
 }

[domain_realm]
 .example.com = EXAMPLE.COM
 example.com = EXAMPLE.COM
```

Next, configure SSSD via `/etc/sssd/sssd.conf`

```
[domain/default]

cache_credentials = True
krb5_realm = example.com
krb5_server = kdc1.example.com
auth_provider = krb5
chpass_provider = krb5

id_provider = ldap
ldap_search_base = dc=example,dc=com
ldap_uri = ldap://ldap1.example.com
ldap_id_use_start_tls = True
ldap_tls_cacertdir = /etc/openldap/cacerts
ldap_tls_cacert = /etc/openldap/cacerts/cacert.pem

[sssd]

services = nss, pam
domains = default

[nss]

homedir_substring = /home
```

Make sure that SSSD is started and enabled on start up:

```
$ sudo chkconfig sssd on && sudo service sssd start
```

Test the client with the following command:

```
$ getent passwd <user>
```

If you get a result, everything should be working properly.

---

### What's next?

I think I've indicated this enough already, but OpenLDAP has posed the most significant challenge so far. Of all the things that contributed to the challenge, I can say that learning how to debug OpenLDAP was at the top. As well, setting up TLS only served to compound any issues as I had never dealt with managing certificates. (In the future, I'll try to establish a more formal process for PKI using a centralized certificate authority—I think this would've prevented the issue in the first place since `certutil` would've likely complained about duplicate serial numbers and certificate subjects.) Anyhow, the next steps I plan to take deviate from the IConrad list; after learning a bit (and after being pointed towards [this](https://www.reddit.com/r/linuxadmin/comments/4n70ku/advice_for_starting_a_job_in_this_field/d42plhv/)), it's become apparent that the logical order of the list is... a bit illogical. I'm going to migrate my Spacewalk server from the hypervisor to a VM and move from there into Puppetizing everything. I also have one vestigial regret from the decisions I made during the setup process of my homelab: I really wish that I had used LVM or ZFS. Maybe I'll make that the next step after getting Puppet off the ground...
