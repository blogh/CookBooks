# sort

Reverse sort on column 2 with field separator `|` :

```
cut -d'|' -f1,7 lag_info_conp01_5433.log | sort -t'|' -k2 -r | head -n1
2017-11-15 18:33:01.594303+01|888
```

Reversed Numeric sort on first column

```
sort -k 1 -nr filename
```
