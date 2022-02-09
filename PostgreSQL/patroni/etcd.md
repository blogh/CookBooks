# etcd

## Install 

```
yum update -y
yum install -y etcd
```

## Firewall

```
systemctl enable firewalld
```

```
firewall-cmd --quiet --permanent --new-service=etcd
firewall-cmd --quiet --permanent --service=etcd --set-short=Etcd
firewall-cmd --quiet --permanent --service=etcd --set-description="Etcd server"
firewall-cmd --quiet --permanent --service=etcd --add-port=2379-2380/tcp
firewall-cmd --quiet --permanent --add-service=etcd
firewall-cmd --quiet --reload
```

Note :
* 2380: server communication
* 2379: client communication

## Cleanup an old etcd configuration

```
systemctl stop etcd
rm -Rf /var/lib/etcd/patroni-clusters.etcd
```

Note: `/var/lib/etcd/patroni-clusters.etcd` is what we use it this demo.

## Configuration NOSSL

In the `/etc/etcd/etcd.conf` file :

```
LOCAL_IP=<ip_du_server (IP)>
NODE_NAME=<nom_du_server (HOST)>
ETCD_INITIAL_CLUSTER=<HOST1=http://IP1:2380,HOST2=http://IP2:2380,HOST3=http://IP3:2380>

cat <<_EOF_ >/etc/etcd/etcd.conf
#[Member]
ETCD_DATA_DIR="/var/lib/etcd/patroni-clusters.etcd"
ETCD_LISTEN_PEER_URLS="http://${LOCAL_IP}:2380"
ETCD_LISTEN_CLIENT_URLS="http://${LOCAL_IP}:2379,http://127.0.0.1:2379,http://[::1]:2379"
ETCD_NAME="$NODE_NAME"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${LOCAL_IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://${LOCAL_IP}:2379"
ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER}"
ETCD_INITIAL_CLUSTER_TOKEN="patroni-clusters"
ETCD_INITIAL_CLUSTER_STATE="new"
_EOF_
```

## Configuration SSL

In the `/etc/etcd/etcd.conf` file :

```
LOCAL_IP=<ip_du_server (IP)>
NODE_NAME=<nom_du_server (HOST)>
ETCD_INITIAL_CLUSTER_SSL=<HOST1=http://IP1:2380,HOST2=http://IP2:2380,HOST3=http://IP3:2380>

cat <<_EOF_ >/etc/etcd/etcd.conf
#[SSL]
ETCD_CLIENT_CERT_AUTH=true
ETCD_CERT_FILE=/var/lib/etcd/ssl/${NODE_NAME}-cert.pem
ETCD_KEY_FILE=/var/lib/etcd/ssl/${NODE_NAME}-key.pem
ETCD_TRUSTED_CA_FILE=/var/lib/etcd/ssl/CA-cert.pem

ETCD_PEER_CLIENT_CERT_AUTH=true
ETCD_PEER_CERT_FILE=/var/lib/etcd/ssl/${NODE_NAME}-cert.pem
ETCD_PEER_KEY_FILE=/var/lib/etcd/ssl/${NODE_NAME}-key.pem
ETCD_PEER_TRUSTED_CA_FILE=/var/lib/etcd/ssl/CA-cert.pem

#[Member]
ETCD_DATA_DIR="/var/lib/etcd/patroni-clusters.etcd"
ETCD_LISTEN_PEER_URLS="https://${LOCAL_IP}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${LOCAL_IP}:2379,https://127.0.0.1:2379,https://[::1]:2379"
ETCD_NAME="$NODE_NAME"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${LOCAL_IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://${LOCAL_IP}:2379"
ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER_SSL}"
ETCD_INITIAL_CLUSTER_TOKEN="patroni-clusters"
ETCD_INITIAL_CLUSTER_STATE="new"
_EOF_
```

Later on set :

```
export ETCDCTL_CA_FILE=/var/lib/etcd/ssl/CA-cert.pem
export ETCDCTL_KEY_FILE=/var/lib/etcd/ssl/srv1-key.pem
export ETCDCTL_CERT_FILE=/var/lib/etcd/ssl/srv1-cert.pem
export ETCDCTL_ENDPOINTS=https://$IP1:2379,https://$IP2:2379,https://$IP3:2379,
```

## Start

```
systemctl --now enable etcd
```

## Checks

```
# etcd api v2
etcdctl member list
```

## Activate authentication

```
#etcd api v2
etcdctl user add root
etcdctl -u root auth enable
etcdctl -u root role remove guest
```





