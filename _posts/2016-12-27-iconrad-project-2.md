---
layout: post
title: Installing Spacewalk and KVM VMs.
date: 2016-12-27 7:32:37
disqus: y
---

### Introduction

This post will cover the steps necessary to setup and configure Spacewalk in order to use it in conjunction with `libvirt` for hands-off installations. I'll also attempt to explain how to import errata in an automated fashion (by shamelessly using someone else's script).

---

### Install Spacewalk

Set up the local Spacewalk repo:

```
$ rpm -Uvh http://yum.spacewalkproject.org/2.6/RHEL/7/x86_64/spacewalk-repo-2.6-0.el7.noarch.rpm
```

Ensure additional dependencies for `jpackage` are present:

```
$ su
$ cat > /etc/yum.repos.d/jpackage-generic.repo << EOF
   [jpackage-generic]
   name=JPackage generic
   #baseurl=http://mirrors.dotsrc.org/pub/jpackage/5.0/generic/free/
   mirrorlist=http://www.jpackage.org/mirrorlist.php?dist=generic&type=free&release=5.0
   enabled=1
   gpgcheck=1
   gpgkey=http://www.jpackage.org/jpackage.asc
   EOF
```

Spacewalk requires a Java Virtual Machine with version 1.6.0 or greater. Install the following RPM that contains a version of `openjdk` that works with Spacewalk:

```
$ rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-<version>
```

Spacewalk is also dependent upon a backend database; we'll install PostgreSQL:

```
$ yum install spacewalk-postgresql spacewalk-setup-postgresql
```

Follow any prompts during the installation process. If the setup asks for an FQDN, be sure to use the one that is intended for future use. 

Configure `iptables` to allow traffic for Spacewalk:

```
$ iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
$ iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
```

Next, install the scipt for automatic errata importation. This won't be immediately useful; once machines are registered with Spacewalk, Spacewalk will inventory all installed packages and draw in all applicable CVEs for those packages so that patching for vulnerabilities can be done in a timely manner. Set up the `~/spacewalk` directory and download the script:

```
$ mkdir ~/spacewalk
$ wget https://cefs.steve-meier.de/errata-import.tar
$ tar -xf errata-import.tar
$ chmod 700 errata-import.pl
```

Test the script to make sure that it works properly. Next, open a file for a cron job script that will be used to download and publish the errata on a weekly basis:

{% highlight bash %}
#! /bin/bash

export SPACEWALK_USER=$USER
export SPACEWALK_PASS=$PASSWORD

cd /home/tminor/spacewalk
rm errata.latest.xml
wget https://cefs.steve-meier.de/errata.latest.xml
./errata-import.pl --server example.com --errata errata.latest.xml --publish

export SPACEWALK_USER=nothing
export SPACEWALK_PASS=nothing
{% endhighlight %}

The above script does not take a secure approach to storing credentials. You may want to read [the answers in this Stack Exchange thread](http://unix.stackexchange.com/questions/212329/hiding-password-in-shell-scripts) for a better understanding and breakdown of security risks and best practices. Make sure that the script is read-only and owned by root:

```
$ chmod 700 errata-cron.sh
```

Open `root`'s crontab:

```
$ sudo crontab -e
```

Add the following line to the file and save it:

```
0 0 * * 1 /tminor/home/spacewalk/errata-cron.sh
```

---

### Setting up Spacewalk with a kickstartable distribution

Before Spacewalk can accomodate kickstarting VMs, it needs to be made aware of any distributions that will be used for VM deployments. The first image that I used was a minimal CentOS 6 installation; choose any source from [here](http://isoredirect.centos.org/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1611.iso) and download an ISO and then mount it.

```
$ wget <link>
$ sudo mkdir /var/distro-trees/CentOS-6.8min
$ sudo mount -oloop /var/iso-images/CentOS-6.8-x86_64-minimal.iso /var/distro-trees/CentOS-6.8min/
```

It's also useful to include an entry in `/etc/fstab` so that this mount persists across reboots. Open it with an editor and add:

```
# <device>                                            <dir>                                   <type>  <options>                       <dump>  <fsck>
/var/iso-images/CentOS-6.8-x86_64-minimal.iso         /var/distro-trees/CentOS-6.8min/        iso9660 user,auto,loop                  0       0
```

At this point Spacewalk requires attention via its web interface. Navigate to it via the host's FQDN or IP address. Once there find, the "Channels" tab, click "Manage Software Channels" and click **"+ Create Channel"**; see the screenshot below:

![Spacewalk Step 1]({{ site.url }}/images/spacewalk/step1.png)

Populate the new channel with packages using `rhnpush`:

```
rhnpush --server <servername> -u <user> -p <password> --channel centos-6 /var/distro-trees/CenOS-6.8min/Packages/*.rpm
```

Next, find the control panel below and click **"+ Create Distribution"**:

![Spacewalk Step 2]({{ site.url }}/images/spacewalk/step2.png)

Complete the required fields as seen below:

![Spacewalk Step 2.5]({{ site.url }}/images/spacewalk/step3.png)

Click **"+ Create Kickstart Distribution"** to generate the kickstart ditribution. Next, create the kickstart profile. Navigate to the menu below:

![Spacewalk Step 3]({{ site.url }}/images/spacewalk/step5.png)

Fill out the fields as seen below. Disregard any options not pictured in the screenshot:

![Spacewalk Step 3.5]({{ site.url }}/images/spacewalk/step4.png)

The resources specified are largely irrelevant; CPU, memory, and disk space will all be specified through a shell cript that utilizes `virsh` to provision necessary resources. With the kickstart profile created, VMs can now be created as necessary. 

Next, create a simple `virsh` script:

{% highlight bash %}
#! /bin/bash

virt-install \
        --connect qemu:///system \
        --name=<name> \
        --ram=1024 \
        --vcpus=1 \
        --location /var/distro-trees/CentOS-6.8min/ \
        --disk path=/home/tminor/homelab/<name>.img \
        --network=network:labnet \
        --extra-args="ks=http://example.com/cblr/svc/op/ks/profile/CentOS-6-Minimal:1:HomeLabInc serial console=tty0 console=ttyS0,115200 ip=dhcp" \
        --nographics
{% endhighlight %}

The script will very likely require quite a bit of tinkering before it will work properly. I found it difficult to figure out the kickstart URL, but it should be something similar to the one seen above. The above script also utilizes DHCP, so if necessary, assign a static IP until it's possible to assign IP addresses dynamically via DHCP. The network portion should be the KVM virtual network created earlier.

Once the script is run, you should be left with a fresh installation. The root password should have been set up during the process of creating the kickstart distribution, so I'd recommend setting up a non-root administrative user first.

---

### Conclusion

After all is said and done, the directions above should have resulted in an installation of Spacewalk that provides a kickstart profile capable of spinning up a very basic CentOS 6 VM. In the next post, I'll demonstrate how to turn our first VM into a name server with BIND DNS and DHCP.