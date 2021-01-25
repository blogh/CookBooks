Service files are in :

``
/usr/lib/systemd/system
``

On some systems systemd logs in /run/log/journal which could make us feel we re
swapping.  

``` 
sudo journalctl --vacuum-time=1d 
sudo journalctl --vacuum-size=100M 
```
