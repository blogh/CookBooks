# firewalld

## Zones

A network zone defines the level of trust for network connections. This is a
one to many relation, which means that a connection can only be part of one
zone, but a zone can be used for many network connections.

The zone defines the firewall features that are enabled in this zone:
* Predefined services
* Ports and protocols
* ICMP blocks
* Masquerading
* Forward ports
* Rich language rules

Default zones are :
* drop
* block
* public
* external (for masquerading)
* dmz
* work
* home
* internal
* trusted

It's possible to add (`--new-zone`) / remove (`--delete-zone`). \
It's also possible to change the zone of an interface (`--zone` + 
`--add-interface`)

Examples of commands :

```
[root@ka1 ~]# firewall-cmd --get-zones
block dmz drop external home internal public trusted work

[root@ka1 ~]# firewall-cmd --get-zone-of-interface eth2
public

[root@ka1 ~]# firewall-cmd --get-active-zones
internal
  interfaces: eth1
  sources: 10.20.30.0/24
public
  interfaces: eth0 eth2

[root@ka1 ~]# firewall-cmd --info-zone internal
internal (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth1
  sources: 10.20.30.0/24
  services: ssh mdns samba-client dhcpv6-client dhcp http postgresql
  ports: 5433/tcp 5432/tcp
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```

It's possible to add port, service, protocol, icmp blocks, port forwarding,
masquerading or rich rules PER zone. Each type as list, query, add, remove
options.

```
firewall-cmd --zone internal --add-masquerade
firewall-cmd --zone internal --add-service postgresql
firewall-cmd --zone internal --add-port 5432
```

The changes or queries can be made on the permanent configuration with the
`--permanent` option.

## Links 

* https://firewalld.org/documentation/
