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
uxlst ctl upr=$upr nupr=2094719 hst 
```

list in launch wait
```
uxlst fla upr=$upr full 
```
	
Count aborted uprocs (first 5 lines are cosmetic)
```
uxlst ctl status=a |tail -n+5 | wc -l
```
	
# Run 

Launch new session
```
uxadd fla ses=$ses upr=$upr mu=rora pdate=25/09/2014 user=ora_dmlr
```
	
# delete

delete session
```
uxdlt ses ses=$ses
uxdlt ses ses=$ses
```

# show

show session
```
uxshw ses exp ses=$ses
```

show link between stanza
```
uxshw ses exp ses=$ses lnk
```

show uproc
```
uxshw upr exp upr=$upr
```

show task
```
uxshw tsk ses=$ses upr=* mu=$muname
```

show rule
```
uxshw rul rul=LUNJEU
```

# Update

Update an uproc
```
uxupd tsk exp ses=$ses upr=$upr mu=$muname nomodel TECHINF DISABLE
```
