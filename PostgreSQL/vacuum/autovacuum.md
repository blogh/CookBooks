# `scale_factor` and `threshold`

When a table or it's indexes are bloated, modifying the configuration on the
table can be done according to this : 

|  *autovacuum*        | L < 1 million | L >= 1 million | L >= 5 millions | L >= 10 millions |
|:---------------------|--------------:|---------------:|----------------:|-----------------:|
| vacuum_scale_factor  |  0.2 (défaut) |            0.1 |            0.05 |              0.0 |
| vacuum_threshold     |   50 (défaut) |    50 (défaut) |     50 (défaut) |          500 000 |
| analyze_scale_factor |  0.1 (défaut) |   0.1 (défaut) |            0.05 |              0.0 |
| analyze_threshold    |   50 (défaut) |    50 (défaut) |     50 (défaut) |          500 000 |

```
ALTER TABLE <nom_table> SET (
   autovacuum_vacuum_scale_factor = <valeur>,
   autovacuum_vacuum_threshold = <valeur>,
   autovacuum_analyze_scale_factor = <valeur>,
   autovacuum_analyze_threshold = <valeur>
);
```

# `autovacuum_work_mem`

`maintenance_work_mem` is used for _CREATE INDEX_, _VACUUM_ and _ALTER TABLE
ADD FOREIGN KEY_. By default, the value of `maintenance_work_mem` is used if
`autovacuum_work_mem` is not used.

`autovacuum_work_mem` is used to store the TID of dead lines. Since a TID is 6
bit in length. Therefore the requiered memory is :

```
(dead lines * autovacuum_vacuum_scale_factor + autovacuum_vacuum_threshold) * TID Size
```

Consider adding a little memory to have some slack.

http://rhaas.blogspot.com/2019/01/how-much-maintenanceworkmem-do-i-need.html

If the requiered memory is less than what we have set in `autovacuum_work_mem`
then only this will be used.

`autovacuum_work_mem` is capped to 1GB.

# `autovacuum_naptime`

The autovacuum launcher whole job is to make sure that each database is
periodically visited by an autovacuum worker. This period is contoled by
`autovacuum_naptime`, it's default value of is 1 minute.

Increasing it is usually a bad idea, it delays the cleanup of dead tuples. One
exception is for databases with huge number of databases. In that case, the
autovacuum launcher might not be able to launch a worker per database every
minute.

Some times, when a table has lots of modifications and it's size is small
enought for the cleanup to last less than `autovacuum_naptime`, it can be a
good idea to reduce the value of this parameter.

http://rhaas.blogspot.com/2019/02/tuning-autovacuumnaptime.html

# Collect stats from the autovacuum on a table with `awk`

```
export TABLE="schema.table"
export LOGFILE="postgresql-9.3-main.log"

awk -r '
 BEGIN {
   print "datetime;pages removed;pages remain;tuples removed;tuple remain;tuple dead"
 }
 /LOG:  automatic vacuum of table "$TABLE/{
   d=$1 " " $2;
   getline; pr=$2; pn=$4;
   getline; tr=$2;tn=$4; td=$6;
   getline; getline;
   print d ";" pr ";" pn ";" tr ";" tn ";" td
}' $LOGFILE
```

# Wraparound and 'autovacuum_freeze_max_age'

Tables with lines older than 'autovacuum_freeze_max_age' need to be vacuumed to
prevent a freeze of the transaction when the 1 million transaction stock is
reached.

List table (relkind 'r') or materialized view ('m') with a relfrozenxid older
than `autovacuum_freeze_max_age`.

```
SELECT c.oid::regclass as table_name, 
       pg_size_pretty(pg_table_size(c.oid)),
       greatest(age(c.relfrozenxid),
       age(t.relfrozenxid)) as age
FROM pg_class c
LEFT JOIN pg_class t ON c.reltoastrelid = t.oid
WHERE c.relkind IN ('r', 'm') 
  AND greatest(age(c.relfrozenxid),age(t.relfrozenxid)) > current_setting('autovacuum_freeze_max_age')::integer
ORDER BY pg_table_size(c.oid);
```


