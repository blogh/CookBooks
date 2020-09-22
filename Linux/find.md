# find

## Find stuff

Looks for one file or an other

```
find ~postgres \( -name "recovery.*" -o -name "postgresql.*conf*" \)
```

Hardlinks toward the same files

```
find . -samefile $PGDATA/base/1/2996
```

File with the most hardlinks ( %n = number of hardlinks )
```
find  $PGDATA -type f -printf '%n %p\n' | awk '$1 > 1{$1="";print}'
```

Links

```
find $PGDATA -type l -exec ls -al {} \;
```

Broken links (-L: follow links; -type l: symlink)

```
find -L $PGDATA -type l
```

Find all files modified on the 7th of June, 2007:

```
find . -type f -newermt 2007-06-07 ! -newermt 2007-06-08
```

Find all files accessed on the 29th of september, 2008:

```
find . -type f -newerat 2008-09-29 ! -newerat 2008-09-30
```

Find files which had their permission changed on the same day:

```
find . -type f -newerct 2008-09-29 ! -newerct 2008-09-30
find . -type f -newermt "2016-02-23" ! -newermt "2016-02-24" -exec ls -al {} \;
```

Find older than x day or minutes

```
find /wals -regex "^.*/[0-9A-F]*$" -mtime 1 -print
find /wals -regex "^.*/[0-9A-F]*$" -mmin +60 -print
```



find with regex :

```
find /wals -regex "^.*/[0-9A-F]*$" -mtime 1 -print
find /wals -regextype sed -regex "^.*/[0-9A-F]\{24\}$" -print
```

## Find and do something

Find and tar :

```
find . -name "postgresql-2015-09-21*" -exec tar -rvf /bkp01/log_postgresql-2015-09-21.tar {} \;
tar zcvf test.tar.gz $(find -name "*.txt" |sort )
```
		
Find with regexp and print only the name :
`
for t in $(find . -regex "^.*/[0-9]*" -type f -printf "%f\n"); do oid2name -f$t | grep $t | grep -v toast; done
`
