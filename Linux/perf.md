# perf

install : 

```
dnf install perf
```

Run :

```
sudo perf top \
  --no-children \
  --call-graph=fp \
  --dsos=/usr/pgsql-12/bin/postgres \
  --show-nr-samples
```
