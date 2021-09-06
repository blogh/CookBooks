# Journald & swap
## Configuration
From man journald.conf

```
Storage

Controls where to store journal data. One of "volatile", "persistent", "auto"
and "none". 

If "volatile", journal log data will be stored only in memory, i.e.  below the
/run/log/journal hierarchy (which is created if needed). 

If "persistent", data will be stored preferably on disk, i.e. below the
/var/log/journal hierarchy (which is created if needed), with a fallback to
/run/log/journal (which is created if needed), during early boot and if the
disk is not writable.  

"auto" is similar to "persistent" but the directory /var/log/journal is not
created if needed, so that its existence controls where log data goes.

"none" turns off all storage, all log data received will be dropped. Forwarding
to other targets, such as the console, the kernel log buffer, or a syslog
socket will still work however. Defaults to "auto".
```

Example :

```
$ grep Storage /etc/systemd/journald.conf
#Storage=auto

$ ls -al /var/log/journal
ls: cannot access /var/log/journal: No such file or directory

$ journalctl --disk-usage
Archived and active journals take up 1.1G on disk.

$ du -sh /run/log/journal
1.2G    /run/log/journal
```

Note: also check:
* /etc/systemd/journald.conf
* /etc/systemd/journald.conf.d/*.conf
* /run/systemd/journald.conf.d/*.conf
* /usr/lib/systemd/journald.conf.d/*.conf


The journal can be moved to a persistent storage by using `persistent` or
`auto` with a `/var/log/journal` directory.

It's also possible to test the hypothesis by purging journal files and checking
how the swap evolves.

```
sudo journalctl --vacuum-time=1d
sudo journalctl --vacuum-size=100M
```

The maximum size of the journal is 10% of the file system with a maximum of
4GB.

Several parameters can be use to control the size for :

* persistant storage :
  * SystemMaxUse : Specifies the maximum disk space that can be used by the
    journal in persistent storage.
  * SystemKeepFree : Specifies the amount of space that the journal should
    leave free when adding journal entries to persistent storage.
  * SystemMaxFileSize : Controls how large individual journal files can grow to
    in persistent storage before being rotated.
* volatile storage :
  * RuntimeMaxUse : Specifies the maximum disk space that can be used in
    volatile storage (within the /run filesystem).
  * RuntimeKeepFree : Specifies the amount of space to be set aside for other
    uses when writing data to volatile storage (within the /run filesystem).
  * RuntimeMaxFileSize : Specifies the amount of space that an individual
    journal file can take up in volatile storage (within the /run filesystem)
    before being rotated.

MaxRetentionSec can be used to limit the retention in terms of time.

## Reloading configuration

Use restart or stop/start on some versions.
See [bug](https://github.com/systemd/systemd/issues/2236)

Adding removing /var/log/journal is detected on the fly.
