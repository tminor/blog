---
layout: post
title: Configuring a name server.
date: 2017-01-02 02:36:17
disqus: y
---

### Introduction

Now that we have a method to easily spin up VMs, we'll configure a name server for our environment. The name server will use BIND DNS for name resolution and will also use ISC's DHCP daemon for dynamic IP configuration. We'll configure the two to work together to provide dynamic DNS (DDNS).

---

### Install and configure BIND DNS

In order to install the VM, adjust the script referenced in the [last post](https://blog.tminor.io/2016/12/27/iconrad-project-2/) and run it. If all goes well, the installation should take care of itself. Set up a non-root administrative user. 

```
# useradd -G wheel <user>
# passwd <user>
```

Once the user is created, run `visudo` in order to allow users in the `wheel` group `sudo` permissions. With the file open, search using `/` for the term `wheel`. Uncomment the line as seen below:

```
## Allows people in group wheel to run all commands
 %wheel ALL=(ALL)       ALL
```

Save the file using `:wq` and logout. Login the newly created user. Install BIND:

```
$ yum install bind bind-utils
```

BIND's primary config file is `/etc/named.conf`. Open this file and find the `options` block. Above this, create an ACL block using the following syntax:

```
<snip>

acl "trusted" {
        192.168.1.0/24; // Allows 192.168.1 subnet 
        127.0.0.1; // Allow from localhost
};

</snip>
```

This example ACL allows all traffic from the private network address `192.168.1.0`. If your name server were publically reachable, it may be advisable to use such an ACL to avoid attacks that could render the system unusable. Any host specified in the ACL will be able to perform recursive lookups against the name server. Next, edit the `options` block to reflect the following:

```
options {
        listen-on port 53 { 127.0.0.1; 192.168.1.3; };
        listen-on-v6 port 53 { ::1; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        allow-query     { trusted; };   # Allows queries from "trusted" hosts

        recursion yes;

        dnssec-enable yes;
        dnssec-validation yes;

        /* Path to ISC DLV key */
        bindkeys-file "/etc/named.iscdlv.key";

        managed-keys-directory "/var/named/dynamic";
};
```

This block specifies options such as those related to `dnssec` which is used to securely configure the server for DDNS. The values above are default. Recursion is set to `yes`; if this is the desired value, make sure that the ACL block is configured properly to allow only specific clients to use the system recursively. Ensure also that the server is listening on port 53 and that the host's IP address is listed after the loopback address (it could be listed before, so the order doesn't matter).

At the end of the file, add `include /etc/named/named.conf.local`. This file is used to indicate all local zone information for reverse and forward zones:

```
<snip>

zone ‘‘area.example.com’’ {
        type master;
        file ‘‘/etc/named/zones/db.area.example.com’’;
};

zone ‘‘1.168.192.in-addr.arpa’’ {
        type master;
        file ‘‘/etc/named/zones/db.192.168.1’’;
};

</snip>
```

These files will be used to specify hostnames and the IP addresses that they should be resolved to. Create a zone file for the forward zone in `/etc/named/zones`. The general form should be as follows:

```
$ORIGIN example.com.
$TTL 604800     ; 1 week
example.com.      IN SOA  ns1.example.com. admin.example.com. (
                                82         ; serial
                                604800     ; refresh (1 week)
                                86400      ; retry (1 day)
                                2419200    ; expire (4 weeks)
                                604800     ; minimum (1 week)
                                )

                        NS      ns1.example.com.

ns1                     A       192.168.1.3

$TTL 21600      ; 6 hours

ntp1                    A       192.168.1.22
```

The file contains, generally, resource records (RRs) and directives. Anything preceded by a `$` is a directive. In this file, the `$ORIGIN` directive is a variable that contains the domain for the hosts listed below it. For example, the `A` record for ns1 would be completed by appending the `$ORIGIN` value, resulting in `ns1.example.com.`. The `$TTL` value dictates the time to live for a resource record. This determines the amount of time that referring recursive servers cache a record before requesting an update. The first resource record in a zone file is the Start of Authority, or SOA RR. This defines many different values, such as the contact for the domain and other general information. The reverse zone file contains the same information but uses `PTR` records for reverse IP to name mappings. See the following for an example:

```
;
; Reverse zone file for 1.168.192.IN-ADDR.ARPA.
;
$ORIGIN 1.168.192.IN-ADDR.ARPA.
$TTL 604800     ;1W default TTL for zone
@       IN      SOA     ns1.example.com. admin.example.com. (
                        3               ; Serial
                        604800          ; Refresh
                        86400           ; Retry
                        2419200         ; Expire
                        604800 )        ; Negative Cache TTL

; name servers - NS records
        IN      NS      ns1.example.com.

; PTR Records
200     IN      PTR     host.example.com.     ; 192.168.1.200
```

After configuring the forward and reverse zone files, check for syntax errors:

```
$ named-checkconf
$ named-checkzone example.com /etc/named/zones/db.area.example.com
$ named-checkzone 1.168.192.in-addr.arpa /etc/named/zones/db.192.168.1
```

Ensure that `named` is configured to start during the boot process:

```
$ sudo chkconfig named on
```

---

### Install and configure DHCP

Install ISC's DHCP daemon:

```
$ sudo yum install dhcp
```

The main configuration file for `dhcpd` is `/etc/dhcpd/dhcpd.conf`. Open it and adjust the configuration to reflect the following:

```
# DHCP Config for homelab, IP addresses 192.168.1.2-254

authoritative;

# Use recommended update scheme
ddns-updates on;
ddns-update-style interim;
allow client-updates;
update-static-leases on;

ddns-domainname "example.com.";
ddns-rev-domainname "in-addr.arpa.";

# Specify the location of the TSIG key file
include "/etc/named/DDNS_UPDATE";

# add a zone block for each forward and reverse zone
zone example.com. {
        primary 127.0.0.1;
        key "DDNS_UPDATE";
}

zone 1.168.192.in-addr.arpa. {
        primary 127.0.0.1;
        key "DDNS_UPDATE";
}

# Declare the subnet and its options
subnet 192.168.1.0 netmask 255.255.255.0 {
        option routers                  192.168.1.1;
        option subnet-mask              255.255.255.0;

        option domain-name              "example.com";
        option domain-name-servers       192.168.1.3; # ns1.example.com

        option time-offset              -18000;         # Eastern Standard Time

        range 192.168.1.2 192.168.1.254;

#       Be sure to specify any statically addressed hosts
        host ns1 {
                ddns-hostname "ns1";
                hardware ethernet 52:54:00:5E:3F:AF;
                fixed-address 192.168.100.3;
        }
}
```

I personally had a difficult time getting DDNS working because I chose to statically address my name server. If this is the case for you, make sure you specify any such hosts. 

In order to secure DDNS, `named` and `dhcpd` can use a TSIG key for authenticated updates to the DNS zone files. Generate a file containing the TSIG key:

```
$ dnssec-keygen -a HMAC-SHA1 -b 128 -r /dev/urandom -n <ddns.key.file>
```

This command will create two files, `Kdhcpi_updater.*.key` and `Kdhcp_updater.*.private`. Copy the key from the `*.private` file and copy it into the TSIG key file. The file can be named arbitrarily, however the syntax should conform to the following:

```
key <key-name> {
        algorithm HMAC-MD5.SIG-ALG.REG.INT;
        secret <key>;
};
```

Create two copies and move them into the configuration directories for `named` and `dhcpd`. Change the files to be read-only for users and groups `named` and `dhcpd`:

```
$ chown named:named /path/to/key
$ chmod 400 /path/to/key
```

Alter `/etc/named/named.conf.local` to reflect the following:

```
include "/etc/named/ddns.key";

zone "example.com" {
        type master;
        file "/etc/named/zones/db.example.com"; # zone file path
        allow-update { key "ddns.key"; };
};

zone "1.168.192.in-addr.arpa" {
        type master;
        file "/etc/named/zones/db.192.168.1";  # 192.168.1.0/24 subnet
        allow-update { key "ddns.key"; };
};
```

At this point, all necessary configuration has been completed to accommodate dynamic DNS updates; to test, make sure the test host's primary network interface configuration file (usually `/etc/sysconfig/network-scripts/ifcfg-eth0`) contains the directive to enable DHCP:

```
BOOTPROTO="dhcp"
```

Also, make sure to comment out any lines that specify static IP address configuration. Reboot the machine to test whether the machine attains an IP address from the DHCP server. If not, enable logging for `named` and `dhcpd`. 

---

### Logging

To enable `named` logging, insert a log clause in any of `named`'s configuration files. I'd probably advise doing this in the main config file. The should conform to the following syntax:

```
logging{
  channel simple_log {
    file "/var/log/named/bind.log" versions 3 size 5m;
    severity warning;
    print-time yes;
    print-severity yes;
    print-category yes;
  };
  category default{
    simple_log;
  };
};
```

For more information on the options within the clause, see [here](http://www.zytrax.com/books/dns/ch7/logging.html).

`dhcpd`'s default logging is found via `syslog`. If you don't like this, add a line such as the following to `/etc/syslog.conf`:

```
local0.debug    /var/log/dhcpd
```

In extreme cases, packet capturing tools such as `tcpdump` may be necessary.

---

### Conclusion

After following the above guide, VMs should be able to boot and automatically attain an IP address, register their host names via DDNS, and perform recursive DNS requests against the name server. Next up is OpenLDAP and Kerberos.