# sar

```
vmstat
sar -W -f
sar -B
```

```
export LC_ALL=C
sar -A -f /var/log/sysstat/sa04 > /tmp/$(hostname)_04012017.txt 
sar -A -f /var/log/sysstat/sa01 > /net/teamxisb/BLO/99.TEMP/sar_$(hostname)_$(date +'%Y%m%d_%H%M')_01.txt

for file in /var/log/sa/sar*; do sar -A -f "$file"  >> /tmp/sar.data3.txt; done
```
