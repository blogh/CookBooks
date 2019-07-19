# Restart

Restart uprocs run
```
uxrst ctl upr=$upr mu=$mug nupr=$nupr
```
# Purge

Purge uproc run by by status
```
uxpur ctl upr=$upr mu=$mug status=a,o
```

# List	

List with all columns
```
uxlst ctl ses=$sesl upr=$uprl mu=$mugr status=a,o,e full
```

List history
```
uxlst ctl upr=IUOGA010FT nupr=2094719 hst 
```

list in launch wait
```
uxlst fla upr=HUOE39* full 
```
	
Count aborted uprocs (first 5 lines are cosmetic)
```
uxlst ctl status=a |tail -n+5 | wc -l
```
	
# Run 

Launch new session
```
uxadd fla ses=OSOPH001AT upr=OUOPH001AD mu=rora pdate=25/09/2014 user=ora_dmlr
```
	
# delete

delete session
```
uxdlt ses ses=osooi001*
uxdlt ses ses=isooi001*
```

# show

show session
```
uxshw ses exp ses=OSOUS002*
```

show link between stanza
```
uxshw ses exp ses=TSPYC001HT lnk
```

show uproc
```
uxshw upr exp upr=OUOUS002*
```

show task
```
uxshw tsk ses=OSOUS002* upr=* mu=rORA
```

show rule
```
uxshw rul rul=LUNJEU
```

# Update

Update an uproc
```
uxupd tsk exp ses=TSPYT001HD upr=TUPYT001EP mu=rpo nomodel TECHINF DISABLE
```
