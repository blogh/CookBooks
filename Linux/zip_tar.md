# ZIP / UNZIP

list content
```
zip -g backup.zip liste.txt
```

```
unzip -l backup.zip
```

```
zip -r backup.zip backup
```

```
gunzip -c ${v_src_dump} | tar xvfp -
```

# tar

exclude
```
tar zcvf uybbbdt06_postgres.tar.gz --exclude=/home/postgres/backup /home/postgres
```

split tar fixed size files
```
tar -L 13631488 -cM --file=archvive.tar-{1..99} expdp.PANDORE-PROD.bpdr003.20160304-1130.CRQ-223808.tar.gz
```

agglomerate tars
```
tar -xM --file=archvive.tar-{1..99}
```
