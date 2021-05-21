# tcpdump

## Things to know 

* The target interface is specified with `-i`, it could be `any` 
* To have numeric host name and ports ad `-nn`
* The list of filters must be between quotes (for ease of use) and can be eg 
  * src, src port, src net
  * dst, dst port, dst net
  * tcp
  * proto 112

## Exemples

```
tcpdump -i eth0 -s0 -nl -w- dst port postgres | strings -n8
```

```
timeout 600 tcpdump -n -i eth0 -w capture.pcap -s 0 -C 200 'tcp and host 192.168.100.99 and port 5432 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'
```


## Links

* https://danielmiessler.com/study/tcpdump/
* https://artofnetworkengineering.com/2021/01/04/tcpdump-filters-an-intro/
