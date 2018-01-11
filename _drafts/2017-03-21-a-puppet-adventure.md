---
layout: post
title: The beginning of a Puppet adventure.
date: 2017-03-21 09:17:21
disqus: y
---

### Learning Puppet

During this whole learning endeavor, my tendency has been to run headlong at whatever objective happens to stand next. For most things (such as Spacewalk) this works out well enough. With OpenLDAP, I learned that it wasn't necessarily the optimum strategy; doing so resulted in a lot of fustration born of copious amounts of trial and error, a lot of which could have been avoided with some reading and patience. Despite the frustration, I did come away with what I felt to be a more thorough understanding (though I do not intend to insenuate that I deeply understand its inner workings and every nuance---I certainly do not). Maybe it's self evident, but as complexity compounds, so does requisite research and general study---two things that I am not particularly adept at.

Puppet is yet another objective that is at odds with success via cursory research. So instead of yielding to weakness, I will instead attempt to distill my learning experience through some posts. Here we goooooo!

---

### Fundamentals of Puppet

*much of what's found below is taken directly from Puppet's [documentation](https://docs.puppet.com/puppet/4.9/index.html) and reworded*

**What is puppet and what does it do?**

Puppet is a configuration management tool written in Ruby. It uses its own declarative language to *declare* resources, classes, state, etc. that should be endemic to nodes on an as defined basis.

**Architecture and behavior**

Puppet uses one or more Puppet masters that manage nodes running Puppet agents. On a periodic basis, an agent sends a list of facts about itself to the master and requests a catalog. Facts reference a number of attributes unique to a system such as a node's IP address, whether a file is present, what services are running, and so on. The requested catalog is a list of attributes that describe a desired state peculiar to that node; if the agent finds that a resource is not in a desired state, it makes the necessary changes. After applying changes, the agent sends a report to the master.

**About Puppet's DSL**

As alluded to above, Puppet's functionality is predicated on its declarative nature. Puppet's DSL declares resources, and according to the documentation, "every other part of the language exists to add flexibility and convenience to the way resources are declared." Resources are grouped together in classes, where classes define configuration necessary to the functionality of a service or application. Smaller classes may be combined such that they provide a combination of configuration, services, etc. necessary for e.g. a database server. Further, Puppet may also classify nodes. Node definitions dictate what classes should apply to a node. Alternatively, Puppet can utilize data provided from an [External Node Classifier](https://docs.puppet.com/guides/external_nodes.html) or Hiera.

**Resources**

> Resources are the fundamental unit for modeling system configurations. Each resource describes some aspect of a system, like a specific service or package.

Puppet enforces resources via catalogs; a catalog defines a desired state and ensures it through the application of declared resources.

Puppet resources have a type, title, and attribute-value pairs that conform to the following syntax:

{% highlight puppet %}
type {'title':
  attribute => value,
}
{% endhighlight %}

Resource types dictate what aspects of configuration that resource can manage. Puppet has many built-in resource types such as files, services, and packages. New resource types can be defined in either Puppet or Ruby. 

The title is an identifying string that must be unique per resource type; duplicate titles will cause a compilation failure. An example might be a resource of the type file, in which case the title could be any arbitrary string value such as `'spam'`. Generally this is a bad idea and would annoy others and cause confusion; instead, a file would be better served in being identified by its path, such as `/etc/sssd/sssd.conf`.

Attributes describe the desired state of a resource; resources generally have attributes that are required, optional, and in many cases have attributes that contain default values if no value is specifically assigned.

**Ordering**

Puppet uses attributes called metaparameters that can be used with any resource type. Metaparameters do not directly define system state but instead define how resources should interact with each other. A common example would be a service and its configuration file:

{% highlight puppet %}
package {'krb5-server':
  ensure => present,
  before => File['/etc/krb5.conf'],
{% endhighlight %}

The above code defines that the package for Kerberos 5 should be installed *before* ensuring the presence of its config file. Likewise, `require` can be used to establish the same dependency but with the opposite ordering:

{% highlight puppet %}
file {'/etc/krb5.conf':
  ensure  => file,
  source  => 'puppet:///modules/kerberos/krb5.conf',
  require => Package['krb5-server'],
{% endhighlight %}

The above is missing certain attributes that should otherwise be specified, but the point is nonetheless suitably illustrated.

**Classes**

> Classes are named blocks of Puppet code that are stored in modules for later use and are not applied until they are invoked by name.

The syntax prescribes the following conventions:

{% highlight puppet  %}
class <name> (
  <data type> $<variable name> = '<default value>'
){
  resource { 'title':
    attribute => value,
    attribute => $<variable name>,
  }
}
{% endhighlight %}

Class definitions contain the `class` keyword, a class name, and a comma-separated list of parameters. Past that are curly brackets (opening and closing) between which is arbitrary Puppet code.

**Manifests and modules**

Files containing Puppet code are called manifests and are prepended with the `.pp` file extension. Class definitions are contained in manifests which are in turn contained within modules to which the code belongs. The file structure for a module generally appears as follows:

```
/etc/puppetlabs/code/environments/production/modules/ntp/
├── CHANGELOG.md
├── checksums.json
├── CONTRIBUTING.md
├── data
│   ├── . . .
├── examples
│   └── init.pp
├── Gemfile
├── hiera.yaml
├── LICENSE
├── manifests
│   ├── config.pp
│   ├── init.pp
│   ├── install.pp
│   └── service.pp
├── metadata.json
├── NOTICE
├── Rakefile
├── README.markdown
├── spec
│   ├── acceptance
│   │   ├── . . .
── templates
│   ├── keys.epp
│   ├── ntp.conf.epp
│   └── step-tickers.epp
└── types
    ├── key_id.pp
    └── poll_interval.pp
```

**END**

I think that covers the fundamentals reasonably well. For a much better, more in depth explanation, see [the official documentation](https://docs.puppet.com/puppet/4.9/index.html).


