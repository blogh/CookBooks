
Options can be found in /proc/config.gz if the kernel was compiled with 
CONFIG_IKCONFIG_PROC=y

```
[me@srv ~]$ /tmp$ zgrep AUTOGROUP /proc/config.gz
# CONFIG_SCHED_AUTOGROUP is not set
```
