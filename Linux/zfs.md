# ZFS


List zfs volumes
```
zpool list
```

list zfs mounts
```
zfs list
```

create zfs volume
```
zfs create -o mountpoint=/home/oracrs zdata1/oracrs 
```

set the size of a zfs volume
```
zfs set volsize=7G  zdata1/oracrs 
```

get reservation for a volume
```
zfs get all zdata1/oracle  |grep reservation
```
