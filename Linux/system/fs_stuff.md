# FS mount options

## noatime / nodiratime

Check with `stat <filename>`:

```
[benoit@benoit-dalibo ~]$ stat .bashrc
  File: .bashrc
  Size: 631       	Blocks: 8          IO Block: 4096   regular file
Device: fd03h/64771d	Inode: 1584481     Links: 1
Access: (0644/-rw-r--r--)  Uid: ( 1000/  benoit)   Gid: ( 1000/  benoit)
Context: unconfined_u:object_r:user_home_t:s0
Access: 2022-06-01 11:07:30.484122709 +0200
Modify: 2022-04-28 09:45:12.806798673 +0200
Change: 2022-04-28 09:45:12.813798743 +0200
 Birth: 2022-04-28 09:45:12.806798673 +0200
```

* mtime: modification of the date
* ctime: rename of the file
* atime: access time
* birth: creation

`noatime` dont record when the file as beenlast accessed.

## dir_index

Change the way files are search in directories. Unusally enabled by default.

```bash
$ sudo tune2fs -l /dev/sda2 | grep features
```
```ŧext
Filesystem features:      has_journal ext_attr resize_inode dir_index filetype 
                          needs_recovery extent 64bit flex_bg sparse_super large_file
			  huge_file dir_nlink extra_isize metadata_csum
```

## mount option: data=writeback

For ext3 & ext4, "data=ordered" is the default, which writes to the main file
system before committing to the journal.

The 'data=writeback' mode does not preserve data ordering when writing to the
disk, so commits to the journal may happen before the data is written to the
file system. This method is faster because only the meta data is journaled, but
is not good at protecting data integrity in the face of a system failure.

If there is a crash between the time when metadata is commited to the journal
and when data is written to disk, the post-recovery metadata can point to
incomplete, partially written or incorrect data on disk; which can lead to
corrupt data files. Additionally, data which was supposed to be overwritten in
the filesystem could be exposed to users - resulting in a security risk.

**ext4 doc**

data=journal		All data are committed into the journal prior to being
			written into the main file system.  Enabling
			this mode will disable delayed allocation and
			O_DIRECT support.

data=ordered	(*)	All data are forced directly out to the main file
			system prior to its metadata being committed to the
			journal.

data=writeback		Data ordering is not preserved, data may be written
			into the main file system after its metadata has been
			committed to the journal.

...

There are 3 different data modes:

* writeback mode
In data=writeback mode, ext4 does not journal data at all.  This mode provides
a similar level of journaling as that of XFS, JFS, and ReiserFS in its default
mode - metadata journaling.  A crash+recovery can cause incorrect data to
appear in files which were written shortly before the crash.  This mode will
typically provide the best ext4 performance.

* ordered mode
In data=ordered mode, ext4 only officially journals metadata, but it logically
groups metadata information related to data changes with the data blocks into a
single unit called a transaction.  When it's time to write the new metadata
out to disk, the associated data blocks are written first.  In general,
this mode performs slightly slower than writeback but significantly faster than journal mode.

* journal mode
data=journal mode provides full data and metadata journaling.  All new data is
written to the journal first, and then to its final location.
In the event of a crash, the journal can be replayed, bringing both data and
metadata into a consistent state.  This mode is the slowest except when data
needs to be read from and written to disk at the same time where it
outperforms all others modes.  Enabling this mode will disable delayed
allocation and O_DIRECT support.

https://www.kernel.org/doc/Documentation/filesystems/ext3.txt
https://www.kernel.org/doc/Documentation/filesystems/ext4.txt

## mount option nobarrier

**ext 4 doc**

barrier=<0|1(*)>	This enables/disables the use of write barriers in
barrier(*)		the jbd code.  barrier=0 disables, barrier=1 enables.
nobarrier		This also requires an IO stack which can support
			barriers, and if jbd gets an error on a barrier
			write, it will disable again with a warning.
			Write barriers enforce proper on-disk ordering
			of journal commits, making volatile disk write caches
			safe to use, at some performance penalty.  If
			your disks are battery-backed in one way or another,
			disabling barriers may safely improve performance.
			The mount options "barrier" and "nobarrier" can
			also be used to enable or disable barriers, for
			consistency with other ext4 mount options.

https://www.kernel.org/doc/Documentation/filesystems/ext3.txt
https://www.kernel.org/doc/Documentation/filesystems/ext4.txt
