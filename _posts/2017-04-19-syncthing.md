---
layout: post
title: Syncthing, configuring a self-hosted syncing service.
date: 2017-04-20 15:57:14
disqus: y
---

### An interlude

I'm breaking from the series of web security posts in a diversion that I hope will end in an acceptable solution to a problem I've been experiencing. The problem is not unique and many solutions exist for it: I have a bunch of directories that I'd like to sync between multiple machines. I've been using `rsync`, and while I'm sure it's possible to wrangle it into doing what I'd like, I'm interested in a more elegant solution. Enter [Syncthing](https://syncthing.net/).

### How is Syncthing unique?

The de facto standard solution for the problem stated above is Dropbox. Dropbox is great and Just Works™, but I'd like a self-hosted solution. Not only that, but I don't need any of the bells and whistles that Dropbox offers and it's another excuse to fiddle around with technoligically interesting things.

---

### Installing Syncthing

Syncthing has [different flavors for different operating systems](https://docs.syncthing.net/users/contrib.html#contributions) and in this case I'm running CentOS 7. You can find the unofficial Syncthing RPM and accompanying directions [here](https://github.com/mlazarov/syncthing-centos).

I had to install `rpmdevtools` before following the instructions above, though you may have to install all of the additional packages suggested in the documentation:

```
$ sudo yum install rpmdevtools
```

Now we can install the RPM and proceed:

```
$ yum install https://github.com/mlazarov/syncthing-centos/releases/download/v0.14.7/syncthing-0.14.7-0.el7.centos.x86_64.rpm
```

Once the RPM is installed, we can set up the necessary directory structure, clone the repo, and build the package:

```
$ git clone https://github.com/mlazarov/syncthing-centos.git rpmbuild/
$ mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
$ echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
$ cd ~/rpmbuild/SOURCES/
$ spectool -g ../SPECS/syncthing.spec
$ cd ~/rpmbuild/SPECS/
$ rpmbuild -bb syncthing.spec
```


---

### Configuring Syncthing

[The Getting Started](https://docs.syncthing.net/intro/getting-started.html) guide walks through the configuration process by advising us to configure Syncthing at `https://localhost:8384`; since I'm configuring Syncthing on a remote server, I found that [the configuration section of the documentation](https://docs.syncthing.net/users/config.html) helped me get to the point where I could reach the admin console over the Internet.

First, start the service to generate the `.config` directory for Syncthing:

```
$ sudo systemctl start syncthing@<username>
```

We can now find Syncthing's config file at `$HOME/.config/syncthing`; let's open it and make some alterations so that we can get to the admin console. Find the `<gui>` element and change the value for the `<address>` child element to reflect the value for the IP address at which we'll be reaching the admin console:

```
<gui enabled="true" tls="true">
    <address>192.168.0.255:8384</address>
    <apikey>l7jSbCqPD95JYZ0g8vi4ZLAMg3ulnN1b</apikey>
    <theme>default</theme>
</gui>
```

Once this is done, restart the service and connect to the address that we entered above. You should receive a warning about the interface being open to the internet; click on the **settings** button and set up a username/password and check the box to enable HTTPS. Restart the service and reload the page.

### Adding additional devices

Next we'll need to configure Syncthing on other devices that expect to participate in synchronizing directories and files. I'm running Syncthing on OS X, so that's the only platform I'll cover (unless I decide to start using it on Windows, in which case I'll update this at that point).

I found that [this GitHub project](https://github.com/xor-gate/syncthing-macosx/releases/tag/v0.14.8-2) seems to be the best maintained of the Community Contributions. Not only that but it provides a DMG for installation which you can find at the hyperlink included in the last sentence. Use the DMG to install Syncthing; a window should prompt you to move the Syncthing icon into the `~/Applications` directory, which you should do. Go ahead and double-click the application; Syncthing should open its web interface at `http://127.0.0.:8384`. When I set everything up, Syncthing was configured to auto-update, which it did. After restarting, the web interface was not reachable. I didn't want to wrestle with it, so I turned off auto-update in settings, moved the application to the trash, reinstalled it and everything worked.

To add other devices, you can click "Show ID" under the Actions drop down menu, copy the ID, click "+Add Remote Device" in the other machine's web console, and paste the ID. Once this is done, you should see a prompt on the other web console to add another remote device which configures everything once you accept it. The last thing that I did—configuration-wise—was designate the headless server as an "Introducer;" this means that any additional devices added via the web interface on the headless server will be auto-configured on any additional devices. Pretty cool.

Now you can configure synced directories to your heart's content.
