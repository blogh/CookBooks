# GREP

Display file with matches (-l) (-L does the opposite):

```
$ grep -rl "port" ~/git/me/
/home/benoit/git/me/CookBooks/.git/hooks/post-update.sample
/home/benoit/git/me/CookBooks/.git/hooks/pre-commit.sample
/home/benoit/git/me/CookBooks/.git/hooks/pre-rebase.sample
/home/benoit/git/me/CookBooks/.git/hooks/fsmonitor-watchman.sample
/home/benoit/git/me/CookBooks/LICENSE
/home/benoit/git/me/CookBooks/Linux/tcpdump.md
/home/benoit/git/me/CookBooks/Linux/netstat.md
/home/benoit/git/me/CookBooks/Linux/misc.md
```

Print only matching string (-o) dont display filename (-h) which is useless here:

```
$ echo "postgres  39886  39877  0 Mar16 ?        00:01:02 postgres: 10/main: archiver process   last was 0000000300000F73000000A0" | grep -oh "[0-9A-F]\{24\}"
0000000300000F73000000A0
```


Grep for a date & hour, display only the matching string:

```
grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}' postgresql-9.2-cms.log | head -n 1
```
