# Journald & swap

From man journald.conf

```
Storage

Controls where to store journal data. One of "volatile", "persistent", "auto"
and "none". If "volatile", journal log data will be stored only in memory, i.e.
below the /run/log/journal hierarchy (which is created if needed). If
"persistent", data will be stored preferably on disk, i.e. below the
/var/log/journal hierarchy (which is created if needed), with a fallback to
/run/log/journal (which is created if needed), during early boot and if the
disk is not writable.  "auto" is similar to "persistent" but the directory
/var/log/journal is not created if needed, so that its existence controls where
log data goes.  "none" turns off all storage, all log data received will be
dropped. Forwarding to other targets, such as the console, the kernel log
buffer, or a syslog socket will still work however. Defaults to "auto".
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

The journal can be moved to a persistent storage.

It's also possible to test the hypothesis by purging journal files and checking
how the swap evolves.

```
sudo journalctl --vacuum-time=1d
sudo journalctl --vacuum-size=100M
```
