# Loop devices

## What ?

## Loop Devices

Regular Files that are mounted as File System

Linux allows users to create a special block device by which they can map a
normal file to a virtual block device.

* It can be used to install an operating system over a file system without
  going through repartitioning the drive.
* A convenient way to configure system images (after mounting them).
* Provides permanent segregation of data.
* It can be used for sandboxed applications that contain all the necessary
  dependencies.

## Device Mapper

The Device Mapper is a kernel driver that provides a framework for volume
management. It provides a generic way of creating mapped devices, which may be
used as logical volumes. It does not specifically know about volume groups or
metadata formats. 

(stolen from <https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/logical_volume_manager_administration/device_mapper>)


The Linux kernel has a notion of device mapping: a block device, such as a hard
disk partition, can be mapped into another device, usually in /dev/mapper/,
with additional processing over the data that flows through it30. A typical
example is encryption device mapping: all writes to the mapped device are
encrypted, and all reads are deciphered, transparently.

(stolen from <https://guix.gnu.org/manual/en/html_node/Mapped-Devices.html>)

## How ?

## Create a loop device to mount a file

Create a file and make a filesystem in it:

```bash
mkdir ~/tmp
dd if=/dev/zero of=~/tmp/delayed-block bs=1G count=1
sudo mkfs.ext4 ~/tmp/delayed-block
```

Create a loopdevice:

```bash
# sudo losetup --find              # find first unused device
#              --show              # display loop device name
#              ~/tmp/delayed-block  # the file
sudo losetup --find --show ~/tmp/delayed-block 
```

```bash
losetup -al
```
```console
NAME       SIZELIMIT OFFSET AUTOCLEAR RO BACK-FILE                      DIO LOG-SEC
/dev/loop0         0      0         0  0 /home/benoit/tmp/delayed-block   0     512
```

Mount the loop device:

```bash
mkdir -p ~/tmp/folder
sudo mount -o sync /dev/loop0 ~/tmp/delayed-folder
```

It worked:

```bash
df -h ~/tmp/folder/
```
```console
Filesystem      Size  Used Avail Use% Mounted on
/dev/loop0      974M   24K  907M   1% /home/benoit/tmp/delayed-folder
```

Umount:

```bash
umount /home/benoit/tmp/delayed-folder
```

## Improving the device ... with a delay

Device-Mapper's "delay" target delays reads and/or writes and maps them to
different devices.

```bash
echo "0 `sudo blockdev --getsz /dev/loop0` delay /dev/loop0 0 <milliseconds>" |\
        sudo dmsetup create delayed-device
```

Format and mount the delayed device:

```bash
mkdir -p ~/tmp/delayed-folder
sudo mount -o sync /dev/mapper/delayed-device ~/tmp/delayed-folder
```

The new device:

```bash
df -h /dev/mapper/delayed-device
```
```console
Filesystem                  Size  Used Avail Use% Mounted on
/dev/mapper/delayed-device  974M   24K  907M   1% /home/benoit/tmp/delayed-folder
```

Infos on the mappers:

```bash
sudo dmsetup ls
```
```console
delayed-device	(253:4)
fedora_localhost--live-home	(253:3)
fedora_localhost--live-root	(253:1)
fedora_localhost--live-swap	(253:2)
luks-d5f7766a-7628-44fa-8136-f4cdd8bfa3d4	(253:0)
```
```bash
sudo dmsetup table
```
```console
delayed-device: 0 2097152 delay 7:0 0 100
fedora_localhost--live-home: 0 810565632 linear 253:0 16074752
fedora_localhost--live-root: 0 146767872 linear 253:0 826640384
fedora_localhost--live-swap: 0 16072704 linear 253:0 2048
luks-d5f7766a-7628-44fa-8136-f4cdd8bfa3d4: 0 973412352 crypt aes-xts-plain64 :64:logon:cryptsetup:d5f7766a-7628-44fa-8136-f4cdd8bfa3d4-d0 0 8:3 32768 1 allow_discards
```

Info on our mapper:

```bash
sudo dmsetup info delayed-device
```
```console
Name:              delayed-device
State:             ACTIVE
Read Ahead:        256
Tables present:    LIVE
Open count:        0
Event number:      0
Major, minor:      253, 4
Number of targets: 1
```

## Cleanup:

Umount the file:

```bash
sudo umount ~/tmp/delayed-folder
```

Remove the mapper if needed:

```bash
sudo dmsetup remove /dev/mapper/delayed-device
```

Note: `dmsetup remove` has `--force` option replaces the table with one that
fails all io. Unmounting is cleaner.


The loop device:

```bash
sudo losetup --detach /dev/loop0
```

Note: don't rm `/dev/loop0`. If you did, you can recreate it with `sudo mknod -m
0660 /dev/loop0 b 7 0`.

The file and mound point:

```bash
rm ~/tmp/delayed-block
rm -Rf ~/tmp/delayed-folder
```

## Ressource

* <https://itsfoss.com/loop-device-linux/>
* <https://dev.to/an773/slow-io-simulation-in-linux-336e>
