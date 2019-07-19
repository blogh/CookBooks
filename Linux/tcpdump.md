# tcpdump

```
tcpdump -i eth0 -s0 -nl -w- dst port postgres | strings -n8
```
