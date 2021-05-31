# Keepalived

## Référence

* Manpage : https://www.keepalived.org/manpage.html

* VIP management : 
  * https://www.redhat.com/sysadmin/ha-cluster-linux
  * https://www.redhat.com/sysadmin/keepalived-basics
  * https://www.redhat.com/sysadmin/advanced-keepalived

* LoadBalancer :
  * https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/load_balancer_administration/ch-initial-setup-vsa
  * https://www.slashroot.in/lvs-linux-virtual-server-different-methods-of-load-balancing

* Keepalived VS :
  * heartbeat : https://serverfault.com/questions/361071/what-is-the-difference-between-keepalive-and-heartbeat
  * loadbalancers : https://linuxhandbook.com/load-balancing-setup/#keepalived'(

* LVS :
  * http://www.linuxvirtualserver.org/Documents.html

NOTE: these are my notes, there is a lot of copy paste from the links above.

## Misc

* VRRP : 
  * _Virtual Router Redundancy Protocol_
  * uses the concept of a _Virtual IP_ address (VIP). One or more hosts
    (routers, servers, etc.) participate in an election to determine the host
    that will control that VIP. Only one host (the master) controls the VIP at
    a time. If the master fails, VRRP provides mechanisms for detecting that
    failure and quickly failing over to a standby host.
  * There is no fencing mechanism available. If f.e. two participating nodes
    don't see each other, both will have the master state and both will carry
    the same IP(s). 
 * keepalived implements version 2 (https://tools.ietf.org/html/rfc3768) & 3
   (https://tools.ietf.org/html/rfc5798) of the protocol.

* Linux IP Virtual Servers => load balancing

* email notification on state change

* sync groups to keeps VIPs together

### VRRP

* VRRP servers are configured with a **priority value**, which can be thought
  of like a weight. The server with the highest priority will be the owner of a
  VRRP address. 
* The specification indicates that the master's priority should be 255, with
  any backup servers having a value lower than 255. In practice, a priority of
  255 isn't strictly necessary as the protocol will select the server with the
  highest priority, even if it isn't 255.
* Once a master is established, all other servers listen for periodic messages
  sent by the master to indicate that it is still alive. 
* When a master first comes online and takes over an IP address, it broadcasts
  a gratuitous ARP. This message informs other servers on the network of the
  MAC address associated with the VIP so that they can address their traffic
  correctly at Layer 2.
* VRRP is neither TCP nor UDP. VRRP uses **IP protocol number 112** for its
  operation.
* **Virtual Router ID (VRID)** is a unique identifier for a VRRP instance and
  its IP addresses (there can be more than one) on a network.
* Auth Type and Authentication String contain a simple text password to
  authenticate members of the VRRP group with each other. It was removed in
  2004 from RFC V2.
* **Advertisement Interval** indicates how often advertisements will be sent out by
  the master.
* IP Address contains one or more IP addresses for which the master is
  responsible. It is possible to have VRRP manage multiple IPs.

### Load Balancing

The *LVS (Linux Virtual Server) forwarding* (lv_kind // lvs_method) can be :

* `NAT` (Network Address Translation): (default) 

Linux Virtual Server via NAT is the simplest to configure. This is because
there is no modification required on the real servers. The real servers can be
any operating system that supports TCP IP stack. LVS via NAT is implemented
using the IP masquerading technique in Linux. 

1. The request from the user first arrives at the virtual IP assigned to the
   front end Load Balancer. 
2. The Load balancer then does an investigation on the packet and modifies it
   with a destination address of the real server from the pool ..
3. .. and forwards it to the real server. 

The end user is never aware of the Real Servers sitting in behind. The user
always thinks that actual response is created and delivered by the Virtual IP
address of the Load balancer.

The main advantage of LVS via NAT is that the Real Server's can run any
operating system and only one single IP address is in use. The Disadvantage of
LVS via nat is that the Load balancer does the rewritting of destination
address twice to fullfil a single request.  Due to this rewritting, the Load
balencer can run out of resources if the number of requests are high. The
situation gets even worse, if the number of backend real servers are more in
number.

                           +-----> Real Server 1
                           |
Client <--------> LVS <===>+
                           |
                           +-----> Real Server 2

* `TUN` (ip TUnneling):

LVS via IP Tunneling is a much better scalable solution compared to LVS via
NAT. This is because of two primary reasons.

* The Load Balencer does not do the multiple rewriting of the IP packets.
* The Actual response is never sent via the Load Balancer. 

IP Tunneling is very much similar to a VPN(well without encryption). The Real
Servers can have any IP address of any different network. But it should also
have the Virtual IP address of the Load Balancer configured on a virtual
interface. This means all the servers involved in LVS via IP tunneling method,
should have the VIP assigned. This imposes another problem of ARP. The problem
is if the client, and the LVS cluster's are all in the same LAN, Real server's
should never respond back with ARP requests for Virtual IP addresses, else the
client can mistakenly reach the Real server directly instead of going through
the Load Balancer.

   +<----------------------+======> Real Server 1
   |                       |
Client ----------> LVS --->+ 
   |                       |
   +<----------------------+======> Real Server 2

* `DR` (Direct Routing):

Although we have reduced the overhead of doing multiple packet rewrites using
the second method, we still have an overhead of IP tunneling involved there.
There is yet another method with LVS, that does not have neither the overhead
of tunneling, nor the overhead of rewriting.

This method is called Direct Routing method. Its much similar to the second
method in one aspect. Response will go from Real server directly to the user.

In this method also the Virtual IP is assigned and shared by the Load Balancer
as well as the real server. As explained in the previous section, Virtual IP
addresses are assigned to an interface that does not respond to ARP
request(this is very important in this method, as the Load Balancer, and Real
servers are all sitting in the same Physical segment ( <-> same LAN segment
?).)

The schema is the same as the above.


implementation on real servers from https://programming.vip/docs/setup-of-linux-high-availability-lvs-load-balancing-cluster-keepalived-lvs-dr.html : 

```
/sbin/ifconfig lo:1 $VIP broadcast $VIP netmask 255.255.255.255 up
/sbin/route add -host $VIP dev lo:1
echo '1' > /proc/sys/net/ipv4/conf/lo/arp_ignore
echo '2' > /proc/sys/net/ipv4/conf/lo/arp_announce
echo '1' > /proc/sys/net/ipv4/conf/all/arp_ignore
echo '2' > /proc/sys/net/ipv4/conf/all/arp_announce
```


There are many *algorithm possibe for load balancing* (lv_algo // lvs_sched): 

| Algorithm Name                                              | lv_algo value |
|:------------------------------------------------------------|:-------------:|
| Round-Robin                                                 | rr            |
| Weighted Round-Robin                                        | wrr           |
| Least-Connection                                            | lc            |
| Weighted Least-Connection                                   | wlc           |
| Locality-Based Least-Connection                             | lblc          |
| Locality-Based Least-Connection Scheduling with Replication | lblcr         |
| Destination Hash                                            | dh            |
| Source Hash                                                 | sh            |
| Source Expected Delay                                       | sed           |
| Never Queue                                                 | nq            |

## Install

### From the repo

*Warning* : 1.3.5 is shipped with Centos 7. It has some bugs which prevent it
from working correctly with track_script defaut user.
(https://access.redhat.com/errata/RHBA-2018:0972)

```
yum install -y keepalived
keepalived --version
systemctl status keepalived
```

### From the sources


Download link at  : https://www.keepalived.org/download.html

```
yum install -y gcc openssl-devel wget

VERSION="2.2.1"
wget https://www.keepalived.org/software/keepalived-${VERSION}.tar.gz
tar -xf keepalived-${VERSION}.tar.gz
cd keepalived-${VERSION}

./configure
make
make install

keepalived --version
```

Add the service :

``` 
## ExecStart path modified from /usr/sbin to /usr/local/sbin because of
## compilation

cat << '_EOF_' > /usr/lib/systemd/system/keepalived.service
[Unit]
Description=LVS and VRRP High Availability Monitor
After=syslog.target network-online.target

[Service]
Type=forking
PIDFile=/var/run/keepalived.pid
KillMode=process
EnvironmentFile=-/etc/sysconfig/keepalived
ExecStart=/usr/local/sbin/keepalived $KEEPALIVED_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
_EOF_

cat << '_EOF_' > /etc/sysconfig/keepalived
# Options for keepalived. See `keepalived --help' output and keepalived(8) and
# keepalived.conf(5) man pages for a list of all options. Here are the most
# common ones :
#
# --vrrp               -P    Only run with VRRP subsystem.
# --check              -C    Only run with Health-checker subsystem.
# --dont-release-vrrp  -V    Dont remove VRRP VIPs & VROUTEs on daemon stop.
# --dont-release-ipvs  -I    Dont remove IPVS topology on daemon stop.
# --dump-conf          -d    Dump the configuration data.
# --log-detail         -D    Detailed log messages.
# --log-facility       -S    0-7 Set local syslog facility (default=LOG_DAEMON)
#

KEEPALIVED_OPTIONS="-D"
_EOF_

systemctl daemon-reload
```

## Tools

ipvsadm

# Config

The configuration file for Keepalived is located in
`/etc/keepalived/keepalived.conf`.

## Firewall config

VRRP traffic must be allowed to pass between nodes.

For `firewalld` :

```
firewall-cmd --add-rich-rule='rule protocol value="vrrp" accept' --permanent
firewall-cmd --reload
```

For `iptables` :

```
iptables -I INPUT -p vrrp -j ACCEPT
iptables-save > /etc/sysconfig/iptables
systemctl restart iptables
```

## VIP Basic conf (tested with 1.3.5)

Setup : 
* 2 serveurs
* failover of the IP based on the availability of the server.


Conf server 1 (p2):
```
vrrp_instance VI_1 {              # Name of the instance of VRRP runnning
    state MASTER                  # Initial state
    interface eth0                # Run VRRP on this interface
    virtual_router_id 51          # see before
    priority 255                  # 255 since it's the master
    advert_int 1                  # 1 second advertisement (see before) 
#    authentication {             # This is not recommanded
#        auth_type PASS
#        auth_pass 12345
#    }
    virtual_ipaddress {           # VIP
        10.20.30.50/32
    }
}
```

Conf server 2 (p1):

```
vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 254
    advert_int 1
    virtual_ipaddress {
        10.20.30.50/32
    }
}
```

Note: The doc recommends that the master should have a priority of +50 over
other nodes.

Start keepalived with (firewall configuration must authorize VRRP communication
between nodes):

```
systemctl start keepalived
```

Traces on the `MASTER` (p2) server:

```
Jan 27 15:49:46 p2 Keepalived[4238]: Starting Keepalived v1.3.5 (03/19,2017), git commit v1.3.5-6-g6fa32f2
Jan 27 15:49:46 p2 Keepalived[4238]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 15:49:46 p2 Keepalived[4239]: Starting Healthcheck child process, pid=4240
Jan 27 15:49:46 p2 Keepalived[4239]: Starting VRRP child process, pid=4241
Jan 27 15:49:46 p2 Keepalived_healthcheckers[4240]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 15:49:46 p2 Keepalived_vrrp[4241]: Registering Kernel netlink reflector
Jan 27 15:49:46 p2 Keepalived_vrrp[4241]: Registering Kernel netlink command channel
Jan 27 15:49:46 p2 Keepalived_vrrp[4241]: Registering gratuitous ARP shared channel
Jan 27 15:49:46 p2 Keepalived_vrrp[4241]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 15:49:46 p2 Keepalived_vrrp[4241]: VRRP_Instance(VI_1) removing protocol VIPs.
Jan 27 15:49:46 p2 Keepalived_vrrp[4241]: Using LinkWatch kernel netlink reflector...
Jan 27 15:49:46 p2 Keepalived_vrrp[4241]: VRRP sockpool: [ifindex(3), proto(112), unicast(0), fd(10,11)]
Jan 27 15:49:47 p2 Keepalived_vrrp[4241]: VRRP_Instance(VI_1) Transition to MASTER STATE
Jan 27 15:49:48 p2 Keepalived_vrrp[4241]: VRRP_Instance(VI_1) Entering MASTER STATE
Jan 27 15:49:48 p2 Keepalived_vrrp[4241]: VRRP_Instance(VI_1) setting protocol VIPs.
Jan 27 15:49:48 p2 Keepalived_vrrp[4241]: Sending gratuitous ARP on eth1 for 10.20.30.50
Jan 27 15:49:48 p2 Keepalived_vrrp[4241]: VRRP_Instance(VI_1) Sending/queueing gratuitous ARPs on eth1 for 10.20.30.50
Jan 27 15:49:48 p2 Keepalived_vrrp[4241]: Sending gratuitous ARP on eth1 for 10.20.30.50
```

Traces on `BACKUP` (p1) server:

```
Jan 27 15:49:51 p1 Keepalived[4451]: Starting Keepalived v1.3.5 (03/19,2017), git commit v1.3.5-6-g6fa32f2
Jan 27 15:49:51 p1 Keepalived[4451]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 15:49:51 p1 Keepalived[4452]: Starting Healthcheck child process, pid=4453
Jan 27 15:49:51 p1 Keepalived[4452]: Starting VRRP child process, pid=4454
Jan 27 15:49:51 p1 Keepalived_healthcheckers[4453]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 15:49:51 p1 Keepalived_vrrp[4454]: Registering Kernel netlink reflector
Jan 27 15:49:51 p1 Keepalived_vrrp[4454]: Registering Kernel netlink command channel
Jan 27 15:49:51 p1 Keepalived_vrrp[4454]: Registering gratuitous ARP shared channel
Jan 27 15:49:51 p1 Keepalived_vrrp[4454]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 15:49:51 p1 Keepalived_vrrp[4454]: VRRP_Instance(VI_1) removing protocol VIPs.
Jan 27 15:49:51 p1 Keepalived_vrrp[4454]: Using LinkWatch kernel netlink reflector...
Jan 27 15:49:51 p1 Keepalived_vrrp[4454]: VRRP_Instance(VI_1) Entering BACKUP STATE
Jan 27 15:49:51 p1 Keepalived_vrrp[4454]: VRRP sockpool: [ifindex(3), proto(112), unicast(0), fd(10,11)]
```

Ip check (VIP = 10.20.30.50):

```
[root@p2 ~]# ip -br ad
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             192.168.121.162/24 fe80::5054:ff:fe4b:d93b/64
eth1             UP             10.20.30.52/24 10.20.30.50/32 fe80::5054:ff:febb:8764/64
[root@p1 ~]# ip -br add
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             192.168.121.227/24 fe80::5054:ff:fe86:d97b/64
eth1             UP             10.20.30.51/24 fe80::5054:ff:fe93:4c89/64
```

Stop Keep alived on master (p2):

```
systemctl stop keepalived
```

Trace on **former** `MASTER` (p2): 

```
Jan 27 15:54:16 p2 Keepalived[4239]: Stopping
Jan 27 15:54:16 p2 Keepalived_vrrp[4241]: VRRP_Instance(VI_1) sent 0 priority
Jan 27 15:54:16 p2 Keepalived_vrrp[4241]: VRRP_Instance(VI_1) removing protocol VIPs.
Jan 27 15:54:16 p2 Keepalived_healthcheckers[4240]: Stopped
Jan 27 15:54:17 p2 Keepalived_vrrp[4241]: Stopped
Jan 27 15:54:17 p2 Keepalived[4239]: Stopped Keepalived v1.3.5 (03/19,2017), git commit v1.3.5-6-g6fa32f2
```

Trace on **new** `MASTER` (p1):

```
Jan 27 15:54:16 p1 Keepalived_vrrp[4454]: VRRP_Instance(VI_1) Transition to MASTER STATE
Jan 27 15:54:17 p1 Keepalived_vrrp[4454]: VRRP_Instance(VI_1) Entering MASTER STATE
Jan 27 15:54:17 p1 Keepalived_vrrp[4454]: VRRP_Instance(VI_1) setting protocol VIPs.
Jan 27 15:54:17 p1 Keepalived_vrrp[4454]: Sending gratuitous ARP on eth1 for 10.20.30.50
Jan 27 15:54:17 p1 Keepalived_vrrp[4454]: VRRP_Instance(VI_1) Sending/queueing gratuitous ARPs on eth1 for 10.20.30.50
```

Ip check :

```
[root@p1 ~]# ip -br ad
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             192.168.121.227/24 fe80::5054:ff:fe86:d97b/64
eth1             UP             10.20.30.51/24 10.20.30.50/32 fe80::5054:ff:fe93:4c89/64
[root@p2 ~]# ip -br ad
lo               UNKNOWN        127.0.0.1/8 ::1/128 
eth0             UP             192.168.121.162/24 fe80::5054:ff:fe4b:d93b/64 
eth1             UP             10.20.30.52/24 fe80::5054:ff:febb:8764/64 
```

Restart keepalived on **former** `MASTER` (p2):

```
systemctl start keepalived
```

**New** `MASTER` (p1) logs => VRRP instance back to `BACKUP` state because of the
priority

```
Jan 27 15:57:20 p1 Keepalived_vrrp[4454]: VRRP_Instance(VI_1) Received advert with higher priority 255, ours 254
Jan 27 15:57:20 p1 Keepalived_vrrp[4454]: VRRP_Instance(VI_1) Entering BACKUP STATE
Jan 27 15:57:20 p1 Keepalived_vrrp[4454]: VRRP_Instance(VI_1) removing protocol VIPs.
```

**Former** `MASTER` (p2) logs => VRRP instance back to `MASTER` state because of priority

```
Jan 27 15:57:19 p2 Keepalived[4263]: Starting Keepalived v1.3.5 (03/19,2017), git commit v1.3.5-6-g6fa32f2
Jan 27 15:57:19 p2 Keepalived[4263]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 15:57:19 p2 Keepalived[4264]: Starting Healthcheck child process, pid=4265
Jan 27 15:57:19 p2 Keepalived[4264]: Starting VRRP child process, pid=4266
Jan 27 15:57:19 p2 Keepalived_healthcheckers[4265]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 15:57:19 p2 Keepalived_vrrp[4266]: Registering Kernel netlink reflector
Jan 27 15:57:19 p2 Keepalived_vrrp[4266]: Registering Kernel netlink command channel
Jan 27 15:57:19 p2 Keepalived_vrrp[4266]: Registering gratuitous ARP shared channel
Jan 27 15:57:19 p2 Keepalived_vrrp[4266]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 15:57:19 p2 Keepalived_vrrp[4266]: VRRP_Instance(VI_1) removing protocol VIPs.
Jan 27 15:57:19 p2 Keepalived_vrrp[4266]: Using LinkWatch kernel netlink reflector...
Jan 27 15:57:19 p2 Keepalived_vrrp[4266]: VRRP sockpool: [ifindex(3), proto(112), unicast(0), fd(10,11)]
Jan 27 15:57:20 p2 Keepalived_vrrp[4266]: VRRP_Instance(VI_1) Transition to MASTER STATE
Jan 27 15:57:21 p2 Keepalived_vrrp[4266]: VRRP_Instance(VI_1) Entering MASTER STATE
Jan 27 15:57:21 p2 Keepalived_vrrp[4266]: VRRP_Instance(VI_1) setting protocol VIPs.
Jan 27 15:57:21 p2 Keepalived_vrrp[4266]: Sending gratuitous ARP on eth1 for 10.20.30.50
Jan 27 15:57:21 p2 Keepalived_vrrp[4266]: VRRP_Instance(VI_1) Sending/queueing gratuitous ARPs on eth1 for 10.20.30.50
```


**What happends if the role are correctly set and the priority is equal ?**

`BACKUP` server started first (p1) => starts as `MASTER` and goes back to
`BACKUP` when the other server joins + reduces priority from 255 to 254.

```
Jan 27 16:02:13 p1 Keepalived[4548]: Starting Keepalived v1.3.5 (03/19,2017), git commit v1.3.5-6-g6fa32f2
Jan 27 16:02:13 p1 Keepalived[4548]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 16:02:13 p1 Keepalived[4549]: Starting Healthcheck child process, pid=4550
Jan 27 16:02:13 p1 Keepalived[4549]: Starting VRRP child process, pid=4551
Jan 27 16:02:13 p1 Keepalived_healthcheckers[4550]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 16:02:13 p1 Keepalived_vrrp[4551]: Registering Kernel netlink reflector
Jan 27 16:02:13 p1 Keepalived_vrrp[4551]: Registering Kernel netlink command channel
Jan 27 16:02:13 p1 Keepalived_vrrp[4551]: Registering gratuitous ARP shared channel
Jan 27 16:02:13 p1 Keepalived_vrrp[4551]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 16:02:13 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) removing protocol VIPs.
Jan 27 16:02:13 p1 Keepalived_vrrp[4551]: Using LinkWatch kernel netlink reflector...
Jan 27 16:02:13 p1 Keepalived_vrrp[4551]: VRRP sockpool: [ifindex(3), proto(112), unicast(0), fd(10,11)]
Jan 27 16:02:14 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) Transition to MASTER STATE
Jan 27 16:02:15 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) Entering MASTER STATE
Jan 27 16:02:15 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) setting protocol VIPs.
Jan 27 16:02:15 p1 Keepalived_vrrp[4551]: Sending gratuitous ARP on eth1 for 10.20.30.50
Jan 27 16:02:15 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) Sending/queueing gratuitous ARPs on eth1 for 10.20.30.50
Jan 27 16:02:15 p1 Keepalived_vrrp[4551]: Sending gratuitous ARP on eth1 for 10.20.30.50
Jan 27 16:02:15 p1 Keepalived_vrrp[4551]: Sending gratuitous ARP on eth1 for 10.20.30.50
Jan 27 16:02:15 p1 Keepalived_vrrp[4551]: Sending gratuitous ARP on eth1 for 10.20.30.50
Jan 27 16:02:15 p1 Keepalived_vrrp[4551]: Sending gratuitous ARP on eth1 for 10.20.30.50
Jan 27 16:02:18 p1 Keepalived_vrrp[4551]: (VI_1): CONFIGURATION ERROR: local instance and a remote instance are both configured as address owner, please fix - reducing local priority
Jan 27 16:02:18 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) Received advert with higher priority 255, ours 254
Jan 27 16:02:18 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) Entering BACKUP STATE
Jan 27 16:02:18 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) removing protocol VIPs.
```

`MASTER` server (p2) => Nothing special (it gets the vip as expected)

```
Jan 27 16:02:18 p2 Keepalived[4299]: Starting Keepalived v1.3.5 (03/19,2017), git commit v1.3.5-6-g6fa32f2
Jan 27 16:02:18 p2 Keepalived[4299]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 16:02:18 p2 Keepalived[4300]: Starting Healthcheck child process, pid=4301
Jan 27 16:02:18 p2 Keepalived[4300]: Starting VRRP child process, pid=4302
Jan 27 16:02:18 p2 Keepalived_healthcheckers[4301]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 16:02:18 p2 Keepalived_vrrp[4302]: Registering Kernel netlink reflector
Jan 27 16:02:18 p2 Keepalived_vrrp[4302]: Registering Kernel netlink command channel
Jan 27 16:02:18 p2 Keepalived_vrrp[4302]: Registering gratuitous ARP shared channel
Jan 27 16:02:18 p2 Keepalived_vrrp[4302]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 27 16:02:18 p2 Keepalived_vrrp[4302]: VRRP_Instance(VI_1) removing protocol VIPs.
Jan 27 16:02:18 p2 Keepalived_vrrp[4302]: Using LinkWatch kernel netlink reflector...
Jan 27 16:02:18 p2 Keepalived_vrrp[4302]: VRRP sockpool: [ifindex(3), proto(112), unicast(0), fd(10,11)]
Jan 27 16:02:18 p2 Keepalived_vrrp[4302]: VRRP_Instance(VI_1) Transition to MASTER STATE
Jan 27 16:02:19 p2 Keepalived_vrrp[4302]: VRRP_Instance(VI_1) Entering MASTER STATE
Jan 27 16:02:19 p2 Keepalived_vrrp[4302]: VRRP_Instance(VI_1) setting protocol VIPs.
Jan 27 16:02:19 p2 Keepalived_vrrp[4302]: Sending gratuitous ARP on eth1 for 10.20.30.50
Jan 27 16:02:19 p2 Keepalived_vrrp[4302]: VRRP_Instance(VI_1) Sending/queueing gratuitous ARPs on eth1 for 10.20.30.50
Jan 27 16:02:19 p2 Keepalived_vrrp[4302]: Sending gratuitous ARP on eth1 for 10.20.30.50
```

**Now what happends when the `MASTER` goes down and comes back up ?**

The **new** `MASTER` remembers that it's priority was lowered to 254 and goes
back to `BACKUP` state.

```
Jan 27 16:07:06 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) Received advert with higher priority 255, ours 254
Jan 27 16:07:06 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) Entering BACKUP STATE
Jan 27 16:07:06 p1 Keepalived_vrrp[4551]: VRRP_Instance(VI_1) removing protocol VIPs.
```

**What happends if the role are both `MASTER` and the priority is equal ?**

The exact same thing ?

TODO : how do you keep the VIP where it is when the other server comes backup
up ?


**tcpdump tests**

`tcpdump` to see the advetisement packets :

```
[root@p2 ~]# tcpdump proto 112 -i eth1
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
16:16:29.201225 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 255, authtype simple, intvl 1s, length 20
16:16:30.202523 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 255, authtype simple, intvl 1s, length 20
16:16:31.203641 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 255, authtype simple, intvl 1s, length 20
16:16:32.204744 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 255, authtype simple, intvl 1s, length 20
```


`tcpdump` after stopping `MASTER` node (p2) : p1 becomes master and advertises
it's role.

```
16:17:57.307591 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 255, authtype simple, intvl 1s, length 20
16:17:58.158690 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 0, authtype simple, intvl 1s, length 20
16:17:58.166794 IP p1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 254, authtype simple, intvl 1s, length 20
16:17:59.168823 IP p1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 254, authtype simple, intvl 1s, length 20
16:18:00.170044 IP p1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 254, authtype simple, intvl 1s, length 20
```

`tcpdump` after starting p2 again : p2 becomes master and advertises it's role.

```
16:19:17.261848 IP p1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 254, authtype simple, intvl 1s, length 20
16:19:18.263262 IP p1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 254, authtype simple, intvl 1s, length 20
16:19:19.264406 IP p1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 254, authtype simple, intvl 1s, length 20
16:19:19.264838 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 255, authtype simple, intvl 1s, length 20
16:19:20.266304 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 255, authtype simple, intvl 1s, length 20
```

Note : use `nopreempt` to prevent a server with higher priority to take back
the VIP when it's available again.


## VIP Conf with a process check

Watch out for process firewalld and switchover if needed.

```
! Configuration File for keepalived

vrrp_track_process track_firewalld {
    process firewalld
    weight 10
}

vrrp_instance VI_1 {
    state MASTER
    interface eth1
    virtual_router_id 51
    priority 244
    advert_int 1
    virtual_ipaddress {
        10.20.30.50/32
    }
    track_process {
        track_firewalld
    }
}
```

This needs the kernel to support proc events.

```
WARNING - the kernel does not support proc events - track_process will not work
```

An alternative to this is to use a `vrrp_script` with the command 'pgrep
firewalld'. The difference is that `track_process` does an exact match
(equivalent to `pgrep "^firewalld$"`).

## VIP Conf with a interface check

It is also possible to use `track_interface` to influence the priority.

## VIP Conf with a track file check

```
! Configuration File for keepalived


track_file trigger_file {                 # vrrp_track_file is deprecated
    file "/var/run/trigger_file.trigger"
}

vrrp_instance VI_1 {
    state MASTER
    interface eth1
    virtual_router_id 51
    priority 244
    advert_int 1
    virtual_ipaddress {
        10.20.30.50/32
    }
    track_file {
        trigger_file weight 1		 # Name of track_file and weight
    }
}
```

The weight is multiplied by the number in the `track_file` to calculate the
priority. If the weight is 0. The value inside the track file must be 0 for the
instance to become `MASTER`. Otherwise the state of the instance becomes
`FAULT`.

Logs :

```
Jan 28 16:29:05 p1 Keepalived[22670]: Starting Keepalived v2.2.1 (01/17,2021)
Jan 28 16:29:05 p1 Keepalived[22670]: Running on Linux 3.10.0-957.12.2.el7.x86_64 #1 SMP Tue May 14 21:24:32 UTC 2019 (built for Linux 3.10.0)
Jan 28 16:29:05 p1 Keepalived[22670]: Command line: '/usr/local/sbin/keepalived' '-D'
Jan 28 16:29:05 p1 Keepalived[22670]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 28 16:29:05 p1 Keepalived[22670]: Configuration file /etc/keepalived/keepalived.conf
Jan 28 16:29:05 p1 systemd: PID file /var/run/keepalived.pid not readable (yet?) after start.
Jan 28 16:29:05 p1 Keepalived[22671]: NOTICE: setting config option max_auto_priority should result in better keepalived performance
Jan 28 16:29:05 p1 Keepalived[22671]: Starting VRRP child process, pid=22672
Jan 28 16:29:05 p1 Keepalived_vrrp[22672]: Registering Kernel netlink reflector
Jan 28 16:29:05 p1 Keepalived_vrrp[22672]: Registering Kernel netlink command channel
Jan 28 16:29:05 p1 Keepalived_vrrp[22672]: Assigned address 10.20.30.51 for interface eth1
Jan 28 16:29:05 p1 Keepalived_vrrp[22672]: Assigned address fe80::5054:ff:fe93:4c89 for interface eth1
Jan 28 16:29:05 p1 Keepalived_vrrp[22672]: Registering gratuitous ARP shared channel
Jan 28 16:29:05 p1 Keepalived_vrrp[22672]: (VI_1) removing VIPs.
Jan 28 16:29:05 p1 Keepalived_vrrp[22672]: (VI_1) Entering BACKUP STATE (init)
Jan 28 16:29:05 p1 Keepalived_vrrp[22672]: VRRP sockpool: [ifindex(  3), family(IPv4), proto(112), fd(13,14)]
Jan 28 16:29:07 p1 Keepalived_vrrp[22672]: (VI_1) Backup received priority 0 advertisement
Jan 28 16:29:07 p1 Keepalived_vrrp[22672]: (VI_1) Receive advertisement timeout
Jan 28 16:29:07 p1 Keepalived_vrrp[22672]: (VI_1) Entering MASTER STATE
Jan 28 16:29:07 p1 Keepalived_vrrp[22672]: (VI_1) setting VIPs.
Jan 28 16:29:07 p1 Keepalived_vrrp[22672]: (VI_1) Sending/queueing gratuitous ARPs on eth1 for 10.20.30.50
Jan 28 16:29:07 p1 Keepalived_vrrp[22672]: Sending gratuitous ARP on eth1 for 10.20.30.50
```

```
Jan 28 16:29:08 p2 Keepalived[5255]: Starting Keepalived v2.2.1 (01/17,2021)
Jan 28 16:29:08 p2 Keepalived[5255]: Running on Linux 3.10.0-957.12.2.el7.x86_64 #1 SMP Tue May 14 21:24:32 UTC 2019 (built for Linux 3.10.0)
Jan 28 16:29:08 p2 Keepalived[5255]: Command line: '/usr/local/sbin/keepalived' '-D'
Jan 28 16:29:08 p2 Keepalived[5255]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 28 16:29:08 p2 Keepalived[5255]: Configuration file /etc/keepalived/keepalived.conf
Jan 28 16:29:08 p2 systemd: PID file /var/run/keepalived.pid not readable (yet?) after start.
Jan 28 16:29:08 p2 Keepalived[5256]: NOTICE: setting config option max_auto_priority should result in better keepalived performance
Jan 28 16:29:08 p2 Keepalived[5256]: Starting VRRP child process, pid=5257
Jan 28 16:29:08 p2 Keepalived_vrrp[5257]: Registering Kernel netlink reflector
Jan 28 16:29:08 p2 Keepalived_vrrp[5257]: Registering Kernel netlink command channel
Jan 28 16:29:08 p2 Keepalived_vrrp[5257]: Assigned address 10.20.30.52 for interface eth1
Jan 28 16:29:08 p2 Keepalived_vrrp[5257]: Assigned address fe80::5054:ff:febb:8764 for interface eth1
Jan 28 16:29:08 p2 Keepalived_vrrp[5257]: Registering gratuitous ARP shared channel
Jan 28 16:29:08 p2 Keepalived_vrrp[5257]: (VI_1) removing VIPs.
Jan 28 16:29:08 p2 Keepalived_vrrp[5257]: (VI_1) Entering BACKUP STATE (init)
Jan 28 16:29:08 p2 Keepalived_vrrp[5257]: VRRP sockpool: [ifindex(  3), family(IPv4), proto(112), fd(13,14)]
```

`tcpdump` show a priority of 244 on p1:

```
[root@p1 keepalived]# tcpdump proto 112 -i eth1
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
17:00:15.922318 IP p1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 244, authtype none, intvl 1s, length 20
```

Increase the priority on p1 by echoing 2 in the file : 244 + 2 * 1 = 246

```
[root@p1 keepalived]# echo "2" > /var/run/trigger_file.trigger
[root@p1 keepalived]# tcpdump proto 112 -i eth1
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
17:20:52.150457 IP p1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 246, authtype none, intvl 1s, length 20
```

Increase the priority on p2 by echoing 4 in the file : 244 + 4 * 1 = 248

```
[root@p2 keepalived]# echo "4" > /var/run/trigger_file.trigger
[root@p1 keepalived]# tcpdump proto 112 -i eth1
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
17:21:34.193529 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 248, authtype none, intvl 1s, length 20
```

Edit `/etc/keepalived/keepalived.conf` and set the weight to 2, reload the
conf : 244 + 4 * 2 = 252

```
[root@p1 keepalived]# tcpdump proto 112 -i eth1
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
17:23:37.481601 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 252, authtype none, intvl 1s, length 20
```

Set the weight to 0 in `/etc/keepalived/keepalived.conf`, `tcpdump` shows no
advetisement packet. It's expected if the weight is 0 and there is a value
different than 0 in the file the state becomes `FAULT`.

```
Jan 28 17:27:51 p1 Keepalived_vrrp[25734]: (VI_1): entering FAULT state (tracked file trigger_file has status -254)
Jan 28 17:27:51 p1 Keepalived_vrrp[25734]: (VI_1) entering FAULT state

Jan 28 17:27:50 p2 Keepalived_vrrp[8390]: (VI_1): entering FAULT state (tracked file trigger_file has status -254)
Jan 28 17:27:50 p2 Keepalived_vrrp[8390]: (VI_1) entering FAULT state
```

Set the weight to 0 in the track file on both servers, p2 starts advertising again:

```
[root@p1 keepalived]# tcpdump proto 112 -i eth1
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
17:31:59.415764 IP p2 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 244, authtype none, intvl 1s, length 20
```

The states have changed : 

```
Jan 28 17:36:33 p1 Keepalived_vrrp[25734]: (VI_1): tracked file trigger_file leaving FAULT state
Jan 28 17:36:33 p1 Keepalived_vrrp[25734]: (VI_1) Entering BACKUP STATE

Jan 28 17:31:56 p2 Keepalived_vrrp[8390]: (VI_1): tracked file trigger_file leaving FAULT state
Jan 28 17:31:56 p2 Keepalived_vrrp[8390]: (VI_1) Entering BACKUP STATE
Jan 28 17:31:59 p2 Keepalived_vrrp[8390]: (VI_1) Receive advertisement timeout
Jan 28 17:31:59 p2 Keepalived_vrrp[8390]: (VI_1) Entering MASTER STATE
```

## VIP Conf with a script check

This is an example with _Patroni_, there are other ways to do it (probably
better) with _HAProxy_. In that case _HAProxy_ can be used with _keepalived_ to
manage a VIP in front of the _HAProxy_.

The check script checks the status of the software you want to look for. It
returns 0 if everything is fine and something else if there is a problem. If
the script returns a non 0 return code more than `fail` (see below) times the
VRRP instance changes it's state to `FAULT`.

`chmod 700` on the check/track script.

Conf on the both servers:

```
global_defs {
    enable_script_security
    script_user root          # helps with the 1.3.5 bug
}

vrrp_script keepalived_check_patroni {
    script "/usr/local/bin/keepalived_check_patroni.sh p1"
    interval 1		# interval between checks
    timeout 5		# how long to wait for the script return
    rise 1              # How many time the script must return ok, for the
                        # host to be considered healthy (avoid flapping)
    fall 1              # How many time the script must return Ko; for the
                        # host to be considered unhealthy (avoid flapping)
}

vrrp_instance VI_1 {
    state MASTER
    interface eth1
    virtual_router_id 51
    priority 244
    advert_int 1
    virtual_ipaddress {
        10.20.30.50/32
    }
    track_script {
        keepalived_check_patroni
    }
}
```

The `vrrp_script` (wget will return `22` if it's not the primary, zero
otherwise. 

```
#!/bin/bash

/usr/bin/curl \
   -X GET -I --fail \
#   --cacert ca.pem
#   --cert p1.pem \
#   --key p1-key.pem \
   https://127.0.0.1:8008/primary &>/dev/null
```

Alternative : `/usr/bin/curl --fail $IP:8008/leader` will return 0 (HTTP 200)
if the node is the leader or 22 (HTTP 503) otherwise. $IP is the address
specified in the `connect_address` of patroni.


**Test** : Patroni stopped, start keepalived's

```
Jan 28 11:27:22 p1 Keepalived[10382]: Starting Keepalived v2.2.1 (01/17,2021)
Jan 28 11:27:22 p1 Keepalived[10382]: Running on Linux 3.10.0-957.12.2.el7.x86_64 #1 SMP Tue May 14 21:24:32 UTC 2019 (built for Linux 3.10.0)
Jan 28 11:27:22 p1 Keepalived[10382]: Command line: '/usr/local/sbin/keepalived' '-D'
Jan 28 11:27:22 p1 Keepalived[10382]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 28 11:27:22 p1 Keepalived[10382]: Configuration file /etc/keepalived/keepalived.conf
Jan 28 11:27:22 p1 systemd: PID file /var/run/keepalived.pid not readable (yet?) after start.
Jan 28 11:27:22 p1 Keepalived[10383]: NOTICE: setting config option max_auto_priority should result in better keepalived performance
Jan 28 11:27:22 p1 Keepalived[10383]: Starting VRRP child process, pid=10384
Jan 28 11:27:22 p1 Keepalived_vrrp[10384]: Registering Kernel netlink reflector
Jan 28 11:27:22 p1 Keepalived_vrrp[10384]: Registering Kernel netlink command channel
Jan 28 11:27:22 p1 Keepalived_vrrp[10384]: Assigned address 10.20.30.51 for interface eth1
Jan 28 11:27:22 p1 Keepalived_vrrp[10384]: Assigned address fe80::5054:ff:fe93:4c89 for interface eth1
Jan 28 11:27:22 p1 Keepalived_vrrp[10384]: Registering gratuitous ARP shared channel
Jan 28 11:27:22 p1 Keepalived_vrrp[10384]: (VI_1) removing VIPs.
Jan 28 11:27:22 p1 Keepalived_vrrp[10384]: VRRP sockpool: [ifindex(  3), family(IPv4), proto(112), fd(12,13)]
Jan 28 11:27:23 p1 Keepalived_vrrp[10384]: Script `keepalived_check_patroni` now returning 1
Jan 28 11:27:23 p1 Keepalived_vrrp[10384]: VRRP_Script(keepalived_check_patroni) failed (exited with status 1)
```

```
Jan 28 11:31:37 p2 Keepalived[27557]: Starting Keepalived v2.2.1 (01/17,2021)
Jan 28 11:31:37 p2 Keepalived[27557]: Running on Linux 3.10.0-957.12.2.el7.x86_64 #1 SMP Tue May 14 21:24:32 UTC 2019 (built for Linux 3.10.0)
Jan 28 11:31:37 p2 Keepalived[27557]: Command line: '/usr/local/sbin/keepalived' '-D'
Jan 28 11:31:37 p2 Keepalived[27557]: Opening file '/etc/keepalived/keepalived.conf'.
Jan 28 11:31:37 p2 Keepalived[27557]: Configuration file /etc/keepalived/keepalived.conf
Jan 28 11:31:37 p2 systemd: PID file /var/run/keepalived.pid not readable (yet?) after start.
Jan 28 11:31:37 p2 Keepalived[27558]: NOTICE: setting config option max_auto_priority should result in better keepalived performance
Jan 28 11:31:37 p2 Keepalived[27558]: Starting VRRP child process, pid=27559
Jan 28 11:31:37 p2 Keepalived_vrrp[27559]: Registering Kernel netlink reflector
Jan 28 11:31:37 p2 Keepalived_vrrp[27559]: Registering Kernel netlink command channel
Jan 28 11:31:37 p2 Keepalived_vrrp[27559]: Assigned address 10.20.30.52 for interface eth1
Jan 28 11:31:37 p2 Keepalived_vrrp[27559]: Assigned address fe80::5054:ff:febb:8764 for interface eth1
Jan 28 11:31:37 p2 Keepalived_vrrp[27559]: Registering gratuitous ARP shared channel
Jan 28 11:31:37 p2 Keepalived_vrrp[27559]: (VI_1) removing VIPs.
Jan 28 11:31:37 p2 Keepalived_vrrp[27559]: VRRP sockpool: [ifindex(  3), family(IPv4), proto(112), fd(12,13)]
Jan 28 11:31:37 p2 Keepalived_vrrp[27559]: Script `keepalived_check_patroni` now returning 1
Jan 28 11:31:37 p2 Keepalived_vrrp[27559]: VRRP_Script(keepalived_check_patroni) failed (exited with status 1)
```

No VIPS :

```
[root@p1 keepalived]# ip -br ad
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             192.168.121.227/24 fe80::5054:ff:fe86:d97b/64
eth1             UP             10.20.30.51/24 fe80::5054:ff:fe93:4c89/64
[root@p2 ~]# ip -br ad
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             192.168.121.162/24 fe80::5054:ff:fe4b:d93b/64
eth1             UP             10.20.30.52/24 fe80::5054:ff:febb:8764/64
```

Start patroni on the previous standby server :

```
systemctl start patroni@demo
[root@p1 keepalived]# patronictl -c /etc/patroni/demo.yaml list
+ Cluster: patroni-demo (6917907806887637850) --+-----------+
| Member | Host        | Role    | State   | TL | Lag in MB |
+--------+-------------+---------+---------+----+-----------+
| p1     | 10.20.30.51 | Replica | running |  7 |        16 |
+--------+-------------+---------+---------+----+-----------+
```

The instances goes back to it's standby state and nothing changes VIP wise.

Start the other patroni server:

```
root@p1 keepalived]# patronictl -c /etc/patroni/demo.yaml list
+ Cluster: patroni-demo (6917907806887637850) --+-----------+
| Member | Host        | Role    | State   | TL | Lag in MB |
+--------+-------------+---------+---------+----+-----------+
| p1     | 10.20.30.51 | Replica | running |  8 |         0 |
| p2     | 10.20.30.52 | Leader  | running |  8 |           |
+--------+-------------+---------+---------+----+-----------+
```

Keepalived's script finds the Leader on p2 and starts the VIP :

```
Jan 28 11:38:43 p2 Keepalived_vrrp[27559]: Script `keepalived_check_patroni` now returning 0
Jan 28 11:38:43 p2 Keepalived_vrrp[27559]: VRRP_Script(keepalived_check_patroni) succeeded
Jan 28 11:38:43 p2 Keepalived_vrrp[27559]: (VI_1) Entering BACKUP STATE
Jan 28 11:38:46 p2 Keepalived_vrrp[27559]: (VI_1) Receive advertisement timeout
Jan 28 11:38:46 p2 Keepalived_vrrp[27559]: (VI_1) Entering MASTER STATE
Jan 28 11:38:46 p2 Keepalived_vrrp[27559]: (VI_1) setting VIPs.
Jan 28 11:38:46 p2 Keepalived_vrrp[27559]: (VI_1) Sending/queueing gratuitous ARPs on eth1 for 10.20.30.50
Jan 28 11:38:46 p2 Keepalived_vrrp[27559]: Sending gratuitous ARP on eth1 for 10.20.30.50
```

Stop patroni on the Leader Node :

```
systemctl stop patroni@demo
[root@p1 keepalived]# patronictl -c /etc/patroni/demo.yaml list
+ Cluster: patroni-demo (6917907806887637850) -+-----------+
| Member | Host        | Role   | State   | TL | Lag in MB |
+--------+-------------+--------+---------+----+-----------+
| p1     | 10.20.30.51 | Leader | running |  9 |           |
+--------+-------------+--------+---------+----+-----------+
```

The cluster failsover, keepalived's sees that the leader is no longer on p2 and
switches to the `FAULT` state :

```
Jan 28 11:40:30 p2 Keepalived_vrrp[27559]: Script `keepalived_check_patroni` now returning 1
Jan 28 11:40:30 p2 Keepalived_vrrp[27559]: VRRP_Script(keepalived_check_patroni) failed (exited with status 1)
Jan 28 11:40:30 p2 Keepalived_vrrp[27559]: (VI_1) Entering FAULT STATE
Jan 28 11:40:30 p2 Keepalived_vrrp[27559]: (VI_1) sent 0 priority
Jan 28 11:40:30 p2 Keepalived_vrrp[27559]: (VI_1) removing VIPs
```

The new leader (p1) server's status becomes `BACKUP` then `MASTER` :

```
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: Script `keepalived_check_patroni` now returning 0
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: VRRP_Script(keepalived_check_patroni) succeeded
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: (VI_1) Entering BACKUP STATE
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: (VI_1) Backup received priority 0 advertisement
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: (VI_1) Backup received priority 0 advertisement
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: (VI_1) Receive advertisement timeout
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: (VI_1) Entering MASTER STATE
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: (VI_1) setting VIPs.
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: (VI_1) Sending/queueing gratuitous ARPs on eth1 for 10.20.30.50
Jan 28 11:40:30 p1 Keepalived_vrrp[10384]: Sending gratuitous ARP on eth1 for 10.20.30.50
```

Start patroni on p2, no changes in the logs of keepalived :

```
[root@p1 keepalived]# patronictl -c /etc/patroni/demo.yaml list
+ Cluster: patroni-demo (6917907806887637850) --+-----------+
| Member | Host        | Role    | State   | TL | Lag in MB |
+--------+-------------+---------+---------+----+-----------+
| p1     | 10.20.30.51 | Leader  | running |  9 |           |
| p2     | 10.20.30.52 | Replica | running |  8 |         0 |
+--------+-------------+---------+---------+----+-----------+
```

Switchover to the other node :

```
[root@p1 keepalived]# patronictl -c /etc/patroni/demo.yaml switchover
Master [p1]:
Candidate ['p2'] []:
When should the switchover take place (e.g. 2021-01-28T12:44 )  [now]:
Current cluster topology
+ Cluster: patroni-demo (6917907806887637850) --+-----------+
| Member | Host        | Role    | State   | TL | Lag in MB |
+--------+-------------+---------+---------+----+-----------+
| p1     | 10.20.30.51 | Leader  | running |  9 |           |
| p2     | 10.20.30.52 | Replica | running |  9 |         0 |
+--------+-------------+---------+---------+----+-----------+
Are you sure you want to switchover cluster patroni-demo, demoting current master p1? [y/N]: y
2021-01-28 11:44:39.45440 Successfully switched over to "p2"
+ Cluster: patroni-demo (6917907806887637850) --+-----------+
| Member | Host        | Role    | State   | TL | Lag in MB |
+--------+-------------+---------+---------+----+-----------+
| p1     | 10.20.30.51 | Replica | stopped |    |   unknown |
| p2     | 10.20.30.52 | Leader  | running |  9 |           |
+--------+-------------+---------+---------+----+-----------+

... after a while ...

[root@p1 keepalived]# patronictl -c /etc/patroni/demo.yaml list
+ Cluster: patroni-demo (6917907806887637850) --+-----------+
| Member | Host        | Role    | State   | TL | Lag in MB |
+--------+-------------+---------+---------+----+-----------+
| p1     | 10.20.30.51 | Replica | running | 10 |         0 |
| p2     | 10.20.30.52 | Leader  | running | 10 |           |
+--------+-------------+---------+---------+----+-----------+
```

On p1, keepalived's instance's state becomes `FAULT` again :

```
Jan 28 11:44:39 p1 Keepalived_vrrp[10384]: Script `keepalived_check_patroni` now returning 1
Jan 28 11:44:39 p1 Keepalived_vrrp[10384]: VRRP_Script(keepalived_check_patroni) failed (exited with status 1)
Jan 28 11:44:39 p1 Keepalived_vrrp[10384]: (VI_1) Entering FAULT STATE
Jan 28 11:44:39 p1 Keepalived_vrrp[10384]: (VI_1) sent 0 priority
Jan 28 11:44:39 p1 Keepalived_vrrp[10384]: (VI_1) removing VIPs.
```

On p2, keepalived's instance's state moves from `FAULT` to `BACKUP` to `MASTER`
: 

```
Jan 28 11:44:39 p2 Keepalived_vrrp[27559]: Script `keepalived_check_patroni` now returning 0
Jan 28 11:44:39 p2 Keepalived_vrrp[27559]: VRRP_Script(keepalived_check_patroni) succeeded
Jan 28 11:44:39 p2 Keepalived_vrrp[27559]: (VI_1) Entering BACKUP STATE
Jan 28 11:44:42 p2 Keepalived_vrrp[27559]: (VI_1) Receive advertisement timeout
Jan 28 11:44:42 p2 Keepalived_vrrp[27559]: (VI_1) Entering MASTER STATE
Jan 28 11:44:42 p2 Keepalived_vrrp[27559]: (VI_1) setting VIPs.
Jan 28 11:44:42 p2 Keepalived_vrrp[27559]: (VI_1) Sending/queueing gratuitous ARPs on eth1 for 10.20.30.50
Jan 28 11:44:43 p2 Keepalived_vrrp[27559]: Sending gratuitous ARP on eth1 for 10.20.30.50
```

## VIP Notify scripts

The notify script is called when there is a change in state. It takes 4
parameters :

* $1 : the value `GROUP` or `INSTANCE` ;
* $2 : `Name` of the group of instance (in our case `VI_1`) ;
* $3 : `State` (values `MASTER` / `BACKUP` / `FAULT`) ;
* $4 : `Priority`.

Different scripts can be called for each actions too (`notify_*`).

The notify script will be called after the `notify_*` scripts.

`chmod 700` on the notify script.

```
vrrp_script keepalived_check_patroni {
    script "/usr/local/bin/keepalived_check_patroni.sh"
    interval 1		# interval between checks
    timeout 5		# how long to wait for the script return
    rise 1              # How many time the script must return ok, for the
                        # host to be considered healthy (avoid flapping)
    fall 1              # How many time the script must return Ko; for the
                        # host to be considered unhealthy (avoid flapping)
    weight 1            # adjust priority by this weight, default 0
}

vrrp_instance VI_1 {
    state MASTER
    interface eth1
    virtual_router_id 51
    priority 244
    advert_int 1
    virtual_ipaddress {
        10.20.30.50/32
    }
    track_script {
        keepalived_check_patroni
    }
    #notify_master <STRING>|<QUOTED-STRING> [username [groupname]]
    #notify_backup <STRING>|<QUOTED-STRING> [username [groupname]]
    #notify_fault <STRING>|<QUOTED-STRING> [username [groupname]]
    #notify_stop <STRING>|<QUOTED-STRING> [username [groupname]]   # executed when stopping VRRP
    notify MY_SCRIPT_HERE root root
}
```

## NAT Load Balancer

VRRRP Syc Group is an extension to VRRP protocol. The main goal is to define a
bundle of VRRP instance to get synchronized together  so  that transition of
one instance will be reflected to others group members.


Config firewalld :
http://www.yolinux.com/TUTORIALS/LinuxTutorialIptablesNetworkGateway.html NOT
WORKING :
* ipvsadm -Lnc shown a connection in SYN_RECV from what I understand an Ack is
  never received.
* same with or without firwall
* The packet goes to the real server but nothing is sent back (firewalld and
  selinux disabled)

```
[root@ka1 ~]# ip -br ad
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             192.168.121.219/24 fe80::5054:ff:fe00:4151/64
eth1             UP             10.20.30.12/24 10.20.30.20/24 fe80::5054:ff:fe1d:9485/64
eth2             UP             10.20.31.10/24 10.20.31.20/24 fe80::5054:ff:feab:1a50/64

[root@ka1 ~]# firewall-cmd --get-zones
block dmz drop external home internal public trusted work

[root@ka1 ~]# grep ZONE /etc/sysconfig/network-scripts/ifcfg-eth?
/etc/sysconfig/network-scripts/ifcfg-eth0:ZONE=
/etc/sysconfig/network-scripts/ifcfg-eth1:ZONE=internal
/etc/sysconfig/network-scripts/ifcfg-eth2:ZONE=public

[root@ka1 ~]# systemctl restart network
[root@ka1 ~]# systemctl restart firewalld


# Set up IP FORWARDing and Masquerading
firewall-cmd --permanent --zone=public --add-masquerade
firewall-cmd --permanent --zone=internal --add-source=10.20.30.0/24
# or use a "direct" iptables configuration:
# firewall-cmd --permanent --direct --passthrough ipv4 -t nat -I POSTROUTING -o eth0 -j MASQUERADE -s 192.168.10.0/24
# Add services offered by the gateway. eg if the gateway is acting as a DHCP server and web server:
firewall-cmd --permanent --zone=internal --add-service=postgres
firewall-cmd --reload


???
[root@ka1 ~]# firewall-cmd --permaent --zone=public --add-port=5433/tcp
success
[root@ka1 ~]# firewall-cmd --permanent --zone=internal --add-port=5433/tcp
success

echo 1 > /proc/sys/net/ipv4/ip_forward    # Enables packet forwarding by kernel
```


```
vrrp_sync_group VIPLB {
#   Group the external and internal VRRP instances so they fail over together
    group {
        VIPLB_external
        VIPLB_internal
    }
}

vrrp_instance VIPLB_external {
    state BACKUP
    interface eth1
    virtual_router_id 91
    priority 100
    virtual_ipaddress {
        10.20.30.49/24
#        10.20.30.49/32
    }
}

vrrp_instance VIPLB_internal {
    state BACKUP
    interface eth0
    virtual_router_id 92
    priority 100
    virtual_ipaddress {
        192.168.121.66/24
#        10.20.30.50/32
    }
}

virtual_server 10.20.30.49 5433 {
    delay_loop 10                   # delay for checker polling
    protocol TCP
    lvs_sched rr                    # Was lb_algo
    lvs_method NAT                  # Was lb_kind
    persistence_timeout 7200        # Time before idle connexion timeout

#    real_server 10.20.30.51 5432 {
    real_server 192.168.121.227 5432 {
        weight 1
        TCP_CHECK {
          connect_timeout 5
          connect_port 5432
        }
    }

#    real_server 10.20.30.52 5432 {
    real_server 192.168.121.162 5432 {
        weight 1
        TCP_CHECK {
          connect_timeout 5
          connect_port 5432
        }
    }
}
```


## Putting it all together : PG / Patroni / KeepAlived

The mission:
* 1 RW VIP on Patroni's Leader Node.
* 1 RO VIP on any node with load balancing.


