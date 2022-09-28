# borgbackup

## Setup a repo and backup

```
borg -e repokey $REPOPATH
```
Nb: with the repokey mode the key is stored in the repo. (see message)

```
borg create --progress --stats $REPOPATH::Init $TARGET
```
Nb: data will be compressed with lz4

## List backups

```
borg list benoit
```
