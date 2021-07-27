## Install

```
sudo apt install pgcluu
sudo yum install pgcluu
```

or

```
tar xzf pgcluu-3.x.tar.gz
cd pgcluu-3.x/
perl Makefile.PL
make && sudo make install
```

## usage

## Start collecting


```
mkdir /tmp/stat_db1/
pgcluu_collectd -D -i 60 /tmp/stat_db1/
LOG: Detach from terminal with pid: 11323
```

or 

```
pgcluu_collectd -D -i 60 /tmp/stat_db1/ -h 10.10.1.1 -U postgres -d mydb
```

With the service

```
systemctl daemon-reload
systemctl enable pgcluu_collectd.service
systemctl enable pgcluu.service
systemctl enable pgcluu.timer
systemctl start pgcluu_collectd.service
systemctl start pgcluu.timer
```

## stop collecting

```
pgcluu_collectd -k
```

## Create the report

```
pgcluu -o /var/www/pgcluu/reports/ /var/lib/pgcluu/data/
```
