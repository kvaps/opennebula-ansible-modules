# OpenNebula Ansible Modules

## Description

Ansible modules for OpenNebula

## Roadmap

The following list represent's all of OpenNebula's resources reachable through their API. The checked items are the ones that are fully functional and tested:

* [ ] [oneacct](http://docs.opennebula.org/doc/stable/cli/oneacct.1.html)
* [X] [oneacl](http://docs.opennebula.org/doc/stable/cli/oneacl.1.html)
* [X] [onecluster](http://docs.opennebula.org/doc/stable/cli/onecluster.1.html)
* [X] [onedatastore](http://docs.opennebula.org/doc/stable/cli/onedatastore.1.html)
* [X] [onegroup](http://docs.opennebula.org/doc/stable/cli/onegroup.1.html)
* [X] [onehook](http://docs.opennebula.org/doc/stable/cli/onehook.1.html)
* [X] [onehost](http://docs.opennebula.org/doc/stable/cli/onehost.1.html)
* [X] [oneimage](http://docs.opennebula.org/doc/stable/cli/oneimage.1.html)
* [X] [onetemplate](http://docs.opennebula.org/doc/stable/cli/onetemplate.1.html)
* [ ] [oneuser](http://docs.opennebula.org/doc/stable/cli/oneuser.1.html)
* [ ] [onevdc](http://docs.opennebula.org/doc/stable/cli/onevdc.1.html)
* [ ] [onevm](http://docs.opennebula.org/doc/stable/cli/onevm.1.html)
* [X] [onevnet](http://docs.opennebula.org/doc/stable/cli/onevnet.1.html)
* [ ] [onezone](http://docs.opennebula.org/doc/stable/cli/onezone.1.html)
* [ ] [onesecgroup](http://docs.opennebula.org/doc/stable/cli/onesecgroup.1.html)
* [ ] [onevcenter](http://docs.opennebula.org/doc/stable/cli/onevcenter.1.html)
* [ ] [onevrouter](http://docs.opennebula.org/doc/stable/cli/onevrouter.1.html)
* [ ] [oneshowback](http://docs.opennebula.org/doc/stable/cli/oneshowback.1.html)
* [X] [onemarket](http://docs.opennebula.org/doc/stable/cli/onemarket.1.html)
* [ ] [onemarketapp](http://docs.opennebula.org/doc/stable/cli/onemarketapp.1.html)


## Compatibility

This add-on is compatible with OpenNebula 5.6+ (older version can work but not have properly tested)

## Requipments

There is no actially any requipments.

## Installation

Clone this repository into your modules library:

```
git clone https://github.com/kvaps/opennebula-ansible-modules library/opennebula
```

Update path in your ansible.cfg file:

```ini
[defaults]
library = library
```

## Example Usage

```yaml
tasks:

- onecluster:
    name: "cluster1"
    template: "RESERVED_CPU=0 RESERVED_CPU=0"

- onedatastore:
    name: "images"
    chmod: "600"
    user: "oneadmin"
    group: "oneadmin"
    clusters: "default cluster1"
    template: |
      ALLOW_ORPHANS="NO"
      CLONE_TARGET="SYSTEM"
      DRIVER="raw"
      DS_MAD="fs"
      DS_MIGRATE="YES"
      LN_TARGET="SYSTEM"
      RESTRICTED_DIRS="/"
      SAFE_DIRS="/var/tmp"
      TM_MAD="fs_lvm"
      TYPE="IMAGE_DS"
      BRIDGE_LIST="{{ lookup("pipe","echo node{1..50}") }}"

- onehost:
    name: "{{ item }}"
    template: "RESERVED_CPU=100 RESERVED_MEM=2922448"
    im_mad: "kvm"
    vmm_mad: "kvm"
    cluster: "cluster1"
  loop: "{{ lookup("pipe","echo node{1..50}") }}"

- oneimage:
    name: "Debian 10"
    chmod: "644"
    user: "oneadmin"
    group: "oneadmin"
    path: "https://marketplace.opennebula.wedos.cloud/images/debian-10.qcow2"
    type: "OS"
    datastore: "files"
    template: "DEV_PREFIX=vd FORMAT=raw LABELS=OS"

- onetemplate:
    name: "Debian 10"
    template: "{{ lookup('template', 'templates/cloud.j2') }}"
    chmod: "600"
    user: "oneadmin"
    group: "oneadmin"
  vars:
    name: "Debian 10"
    image: "Debian 10"
    logo: "images/logos/debian.png"

- onevnet:
    name: dev-ip
    template: |
      BRIDGE="vmbr0v4000"
      DNS="10.28.0.1"
      PHYDEV="bond0"
      SECURITY_GROUPS="0"
      VLAN_ID="4000"
      VN_MAD="802.1Q"
    clusters: "default cluster1"
    chmod: "604"
    user: "oneadmin"
    group: "oneadmin"
  
- onevnetar:
    ar_uniq_key: "IP"
    template: "{{ ar_template }}"
  loop_control:
    loop_var: ar_template
  loop:
      - |
          AR=[
            GATEWAY="172.16.0.1",
            IP="172.16.0.5",
            SIZE="250",
            TYPE="IP4" ]
      - |
          AR=[
            GATEWAY="172.17.0.1",
            IP="172.17.0.5",
            SIZE="250",
            TYPE="IP4" ]

```

## Development

To contribute bug patches or new features, you can use the github Pull Request model. It is assumed that code and documentation are contributed under the Apache License 2.0. 

More info:
* [How to Contribute](http://opennebula.org/addons/contribute/)
* Support: [OpenNebula user forum](https://forum.opennebula.org/c/support)
* Development: [OpenNebula developers forum](https://forum.opennebula.org/c/development)
* Issues Tracking: Github issues

## Author

* Author: [kvaps](http://github.com/kvaps)


