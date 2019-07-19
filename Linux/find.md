# find

looks for one file or an other
```
find ~postgres \( -name "recovery.*" -o -name "postgresql.*conf*" \)
```

hardlinks toward the same files
```
find . -samefile /home/postgres/ybbb04/instance/base/1/2996
```

file with the most hardlinks ( %n = number of hardlinks )
```
find  $PGDATA -type f -printf '%n %p\n' | awk '$1 > 1{$1="";print}'
```

links
```
find $PGDATA -type l -exec ls -al {} \;
```

broken links (-L: follow links; -type l: symlink)
```
find -L $PGDATA -type l
```

find all files modified on the 7th of June, 2007:
```
find . -type f -newermt 2007-06-07 ! -newermt 2007-06-08
```

To find all files accessed on the 29th of september, 2008:
```
find . -type f -newerat 2008-09-29 ! -newerat 2008-09-30
```

Find files which had their permission changed on the same day:
```
find . -type f -newerct 2008-09-29 ! -newerct 2008-09-30
find . -type f -newermt "2016-02-23" ! -newermt "2016-02-24" -exec ls -al {} \;
```

Find and tar
```
find . -name "postgresql-2015-09-21*" -exec tar -rvf /bkp01/log_postgresql-2015-09-21.tar {} \;
tar zcvf test.tar.gz $(find -name "*.txt" |sort )
```
		

