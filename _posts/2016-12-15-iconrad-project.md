---
layout: post
title: Installing KVM and Open vSwitch.
date: 2016-12-21 11:43:16
disqus: y
---

### iConrad's Sysadmin Project

Over the last several months, I've been chipping away at a monumental project. You can find it [here](https://www.reddit.com/r/linuxadmin/comments/2s924h/how_did_you_get_your_start/cnnw1ma/). I've made it through step four, but I'll start my write-ups with step one, trying my best to reconstruct the lessons learned and the actions taken at the time I actually did them. 

In this post, I'll go over step 1: "Set up a KVM hypervisor." This innocuous looking set of instructions turns out to be very involved, so let's get started. 

---

### Install KVM

First up, install all of the packages necessary for KVM:

```
$ yum install kvm qemu-kvm python-virtinst libvirt libvirt-python \
    libguestfs-tools virt-install
```

Enable `libvirtd` and start it:

```
$ systemctl enable libvirtd && systemctl start libvirtd
```

`libvirtd` enables the starting and stopping of VMs as well as interaction with `libvirt`'s API.

---

### Virtual networking with Open vSwitch

KVM relies on the kernel for packet forwarding; check to see if it's enabled:

```
$ sudo cat /proc/sys/net/ipv4/ip_forward
```

If it's not (returns 0), enable it:

```
$ sysctl -w net.ipv4.ip_forward=1
```

At this point, KVM needs some sort of virtual network device capable of bridging our virtual and physical interfaces. Standard KVM installations advise the use of a Linux bridge device; while there's certainly nothing wrong with using this method, there are alternatives such as Open vSwitch. OVS is the virtual networking device of choice for OpenStack. It's generally touted as conducive to a highly dynamic environment. It also supports features such as GRE tunneling, whereas a Linux bridge does not ([although this appears to be maybe untrue](http://blog.asiantuntijakaveri.fi/2012/01/layer-2-over-layer-3-using-linux-built.html)).

Install all of the necessary packages (several of these are probably already installed):

```
$ yum install make gcc openssl-devel autoconf automake \
        rpm-build redhat-rpm-config python-devel openssl-devel \
        kernel-devel kernel-debug-devel libtool wget
```

Create the RPM for Open vSwitch:

```
$ mkdir -p ~/rpmbuild/SOURCES
$ wget http://openvswitch.org/releases/openvswitch-<version>.tar.gz
$ cp openvswitch-<version>.tar.gz ~/rpmbuild/SOURCES/
$ tar xfz openvswitch-<version>.tar.gz
$ sed ’s/openvswitch-kmod, //g’ \
        openvswitch-<version>/rhel/openvswitch.spec \
        > openvswitch-<version>/rhel/openvswitch_no_kmod.spec
```

Build and install the RPM:

```
$ rpmbuild -bb --nocheck \
        ~/openvswitch-<version>/rhel/openvswitch_no_kmod.spec
$ ls -l ~/rpmbuild/RPMS/x86_64/
$ yum localinstall \
        ~/rpmbuild/RPMS/x86_64/openvswitch-<version>.x86_64.rpm
```

Start and enable OVS:

```
$ systemctl start openvswitch && systemctl enable openvswitch
```

### Open vSwitch Configuration

Usually, OVS is configured via its CLI config tool, `ovs-vsctl`. In this section, I won't use it. Instead, the network service should take care of device creation. This is done via interface configuration files found in `/etc/sysconfig/network-scripts/ifcfg-<device>`. First, define the bridging device, in this case `ifcfg-ovsbr`:

```
DEVICE=ovsbr
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSBridge
BOOTPROTO=static
IPADDR=192.168.1.200
NETMASK=255.255.255.0
HOTPLUG=no
GATEWAY=192.168.1.1
```

Next, the physical interface (Ethernet) needs to be connected to the new virtual bridge. **Be aware:** if you mess something up in this step and you are connected via SSH, you could get disconnected. With services like DigitalOcean, this shouldn't be a problem as console access is provided via the web interface. Open the file that corresponds to the physical interface; in many cases, this is `ifcfg-eth0`:

```
DEVICETYPE=ovs
TYPE=OVSPort
OVS_BRIDGE=ovsbr
# TYPE=Ethernet
# BOOTPROTO=none
DEFROUTE=yes
PEERDNS=yes
PEERROUTES=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_PEERDNS=yes
IPV6_PEERROUTES=yes
IPV6_FAILURE_FATAL=no
NAME=em1
UUID=8a9afa2f-9bd5-40b1-9193-3f1af48d67be
DEVICE=em1
ONBOOT=yes
NM_CONTROLLED=no
```

It may be beneficial to comment out any lines that are improperly configured; in the case of something getting borked, you only need to uncomment to revert back to the previous configuration. In order to accomodate VLANs, OVS uses internal ports that function as "fake bridges." Create a new interface configuration file for the VLAN device:

```
DEVICE=vlan100
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSIntPort
BOOTPROTO=static
IPADDR=192.168.100.1
NETMASK=255.255.255.0
OVS_BRIDGE=vlan100
```

The parameters are pretty straightforward. Restart the network service to automatically create all devices:

```
$ systemctl network.service restart
```

When the network service restarts, it will read the above configuration files and create all of the necessary OVS devices. Check the status of OVS:

```
$ ovs-vsctl show
```

The output should be similar to the following:

```
083dc7a9-43ca-4a95-b601-3c088ae7945a
    Bridge ovsbr
        Port ovsbr
            Interface ovsbr
                type: internal
        Port "vnet1"
            tag: 100
            Interface "vnet1"
        Port "vlan100"
            tag: 100
            Interface "vlan100"
                type: internal
```

Whenever a VM is added to `ovsbr`, a new port should be added similar to `vnet1` above.

---

### Set up KVM's virtual network

With the help of `libvirt`, configuration for VMs (domains in `libvirt` parlance) and virtual networks can be managed through XML files. Create an XML file for the virtual network:

```
<network>
  <name>$NAME</name>
  <forward mode='bridge'/>
  <bridge name='vlan100'/>
</network>
```

You can store this file wherever you like. I keep all XML files and domain images in a specific directory. KVM needs to be made aware of this network definition. Use `virsh` to define a new network:

```
$ virsh net-define network.xml
```

KVM should now be ready for the installation of VMs.

---

### Conclusion

After following the above steps, you should have the following:

1. A KVM hypervisor managed with `libvirt`.
2. An open vSwitch virtual bridge with a VLAN interface

Before installing the first VM, I'll walk through the steps to setup a Spacewalk server. Spacewalk enables systems management through a nice graphical web interface and also provides premade Kickstart scripts that will be used to automate the install process. 
