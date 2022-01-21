# patroni

## Install

```
yum install --nogpgcheck -y -e 0 "https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm"

PGVER=11
PACKAGES=(
    gcc epel-release
    "postgresql${PGVER}" "postgresql${PGVER}-contrib" "postgresql${PGVER}-server"
)

yum install --nogpgcheck -y -e 0 "${PACKAGES[@]}"

# These packages need the EPEL repo
yum install --nogpgcheck -y -e 0 python3-pip python3-devel python3-psycopg2

# Install Patroni
pip3 --quiet install patroni[etcd]
```

## Create the service

```
cat <<'EOF' > /etc/systemd/system/patroni@.service
[Unit]
Description=Patroni cluster %i
After=syslog.target network.target etcd.service
# uncomment if etcd is on the same server
#Wants=etcd.service
ConditionPathExists=/etc/patroni/%i.yaml

[Service]
Type=simple

User=postgres
Group=postgres

ExecStart=/usr/local/bin/patroni /etc/patroni/%i.yaml
ExecReload=/bin/kill -s HUP $MAINPID

KillMode=process
TimeoutSec=30
Restart=no

# make sure any pgpass created in /tmp is private
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl --quiet daemon-reload
```

## Configure the watchdog

```
cat <<'EOF' > /etc/udev/rules.d/99-watchdog.rules
SUBSYSTEM=="misc", KERNEL=="watchdog", ACTION=="add", RUN+="/bin/setfacl -m u:postgres:rw- /dev/watchdog"
EOF
rmmod i6300esb
modprobe i6300esb
```

## Firewall

```
systemctl --quiet --now enable firewalld
firewall-cmd --quiet --permanent --new-service=patroni
firewall-cmd --quiet --permanent --service=patroni --set-short=Patroni
firewall-cmd --quiet --permanent --service=patroni --set-description="Patroni server"
firewall-cmd --quiet --permanent --service=patroni --add-port=8008/tcp
firewall-cmd --quiet --permanent --add-service=patroni
firewall-cmd --quiet --permanent --add-service=postgresql
firewall-cmd --quiet --reload
```

## Patroni config NO SSL

```
mkdir -p /etc/patroni

NODE_NAME=srv1
LOCAL_IP=10.20.199.3
ETCD_HOSTS=10.20.199.3:2379,10.20.199.4:2379,10.20.199.5:2379

cat<<EOF > /etc/patroni/demo.yaml
scope: patroni-demo
name: ${NODE_NAME}

# rest API of Patroni
restapi:
  listen: ${LOCAL_IP}:8008
  connect_address: ${LOCAL_IP}:8008

# Etcd cluster
etcd:
  hosts: ${ETCD_HOSTS}

bootstrap:
  dcs:
    ttl: 30                           # check interval
    loop_wait: 10                     # sleep time between each loop exec
    retry_timeout: 10                 # timeout for various actions (postgresql or dcs)
    #maximum_lag_on_failover: 16777216 # maximum lag in bytes to be part of the election process
    master_start_timeout: 300         #
    #synchronous_mode: on/off
    postgresql:
      use_pg_rewind: false
      use_slot: true
      parameters:
        archive_mode: "on"
        archive_command: /bin/true

  initdb:
    - encoding: UTF8
    - data-checksums

  pg_hba:
    - host replication replicator 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5

postgresql:
  listen: "*:5432"                        # listen_addresses parameter of pgsql
  connect_address: ${LOCAL_IP}:5432 # what address to advertise to outside through the api
  data_dir: /var/lib/pgsql/${PGVER}/data
  bin_dir: /usr/pgsql-${PGVER}/bin
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator # created during bootstrap
      password: repass
    superuser:
      username: postgres  # set durint initdb
      password: pgpass
  # parameters:    # pg parameters
  #  param: value

watchdog:
  mode: required
  device: /dev/watchdog
  safety_margin: 5
EOF

chown -R postgres: /etc/patroni/
```

Note: use `PATRONICTL_CONFIG_FILE` to avoid typing  `-c <conf_file>` in all
patronictl commands.

## Patroni config SSL

```
mkdir -p /etc/patroni

NODE_NAME=srv1
LOCAL_IP=10.20.199.3
ETCD_HOSTS=10.20.199.3:2379,10.20.199.4:2379,10.20.199.5:2379

cat<<EOF > /etc/patroni/demo.yaml
scope: patroni-demo
name: ${NODE_NAME}

# rest API of Patroni
restapi:
  listen: ${LOCAL_IP}:8008
  connect_address: ${LOCAL_IP}:8008
  username: test
  password: test
  cacert: /etc/patroni/CA-cert.pem
  cert: /etc/patroni/srv1-cert.pem
  key: /etc/patroni/srv1-key.pem

# Etcd cluster
etcd:
  hosts: ${ETCD_HOSTS}
  protocol: https
  cacert: /etc/patroni/CA-cert.pem
  cert: /etc/patroni/${NODE_NAME}-cert.pem
  key: /etc/patroni/${NODE_NAME}-key.pem

bootstrap:
  dcs:
    ttl: 30                           # check interval
    loop_wait: 10                     # sleep time between each loop exec
    retry_timeout: 10                 # timeout for various actions (postgresql or dcs)
    #maximum_lag_on_failover: 16777216 # maximum lag in bytes to be part of the election process
    master_start_timeout: 300         #
    #synchronous_mode: on/off
    postgresql:
      use_pg_rewind: false
      use_slot: true
      parameters:
        archive_mode: "on"
        archive_command: /bin/true

  initdb:
    - encoding: UTF8
    - data-checksums

  pg_hba:
    - host replication replicator 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5

postgresql:
  listen: "*:5432"                        # listen_addresses parameter of pgsql
  connect_address: ${LOCAL_IP}:5432 # what address to advertise to outside through the api
  data_dir: /var/lib/pgsql/${PGVER}/data
  bin_dir: /usr/pgsql-${PGVER}/bin
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator # created during bootstrap
      password: repass
    superuser:
      username: postgres  # set durint initdb
      password: pgpass
  # parameters:    # pg parameters
  #  param: value

watchdog:
  mode: required
  device: /dev/watchdog
  safety_margin: 5
EOF

chown -R postgres: /etc/patroni/
```

Note: use `PATRONICTL_CONFIG_FILE` to avoid typing  `-c <conf_file>` in all
patronictl commands.

Note: PATRONI_CTL_CACERT, PATRONI_CTL_CERTFILE, PATRONI_CTL_KEYFILE

## Start

```
systemctl start patroni@demo
```

## Api test

with ssl:

```
curl  --cert srv1-cert.pem --cacert CA-cert.pem --key srv1-key.pem \
      -s https://10.20.199.4:8008/patroni | python3 -m json.tool
```

without ssl:

```
curl -s 10.20.199.4:8008/patroni | python3 -m json.tool
```

