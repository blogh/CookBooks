# Sizing autovacuum_work_mem

Reference : https://rhaas.blogspot.com/2019/01/how-much-maintenanceworkmem-do-i-need.html

If `autovacuum_work_mem` is not set, `maintenance_work_mem` is used.
The memory is allocated whether you use it or not.
The memory requiered is calculated like this :
* TID size = 6 bits
* Memory needed for a table = tuples * 6
* Memory needed by autovac = (tuples * scale factor + threshold) * 6

# Test setup :

```
CREATE TABLE avac(i int, t text);
ALTER TABLE avac ADD PRIMARY KEY (i);
INSERT INTO avac SELECT x FROM generate_series(1,15000000) AS F(x);
```

autovac will start at 3000050 modified tuples (default setup of autavacuum
parameters).

# Memory allocation

Script :
```
#!/bin/bash

PGDATA="/home/benoit/var/lib/postgres/pgsql-13rc1"
PGPID=$(head -1 $PGDATA/postmaster.pid)

for p in $(pgrep -P $PGPID -f 'autovacuum worker'); do
	echo "$p, $(grep VmData /proc/$p/status)"
done
```

Do an update of the table **avac** while doing a watch on another session :
```
sql> UPDATE avac SET t = 'UPDATE 1' WHERE i < 3100000;

bash> watch "~/path_to_the_script_above.sh"
```

(/proc/PID/status).VmData is a little above `maintenance_work_mem` /
`autovacuum_work_mem` :

```
VmData:    67424 kB
```

# Number of index scan / memory sizing

1 idx scan is used if we go just above the autovacuum triggering point :

```
[local]:5436 postgres@postgres=# UPDATE avac SET t = 'UPDATE 1' WHERE i < 3100000;
UPDATE 3099999

2020-09-22 10:35:50.352 CEST [522281] LOG:  automatic vacuum of table "postgres.public.avac": index scans: 1
	pages: 0 removed, 83129 remain, 0 skipped due to pins, 0 skipped frozen
	tuples: 3099999 removed, 15000000 remain, 0 are dead but not yet removable, oldest xmin: 3800
	buffer usage: 48987 hits, 75389 misses, 52673 dirtied
	avg read rate: 18.224 MB/s, avg write rate: 12.733 MB/s
	system usage: CPU: user: 7.84 s, system: 1.64 s, elapsed: 32.31 s
	WAL usage: 99751 records, 38737 full page images, 275231478 bytes
2020-09-22 10:35:55.062 CEST [522281] LOG:  automatic analyze of table "postgres.public.avac" system usage: CPU: user: 0.57 s, system: 0.25 s, elapsed: 4.70 s
```


`maintenance_work_mem`  is set to 64. We will need  `64*1024*1024/6 = 11 184
810 lines` before we need do more than one rounds of index scan.

```
[local]:5436 postgres@postgres=# UPDATE avac SET t = 'UPDATE 1' WHERE i < 11200000;
UPDATE 11199999

2020-09-22 10:45:32.127 CEST [522784] LOG:  automatic vacuum of table "postgres.public.avac": index scans: 2
	pages: 0 removed, 130249 remain, 0 skipped due to pins, 0 skipped frozen
	tuples: 11199999 removed, 14241290 remain, 0 are dead but not yet removable, oldest xmin: 3802
	buffer usage: 139049 hits, 284200 misses, 221187 dirtied
	avg read rate: 16.603 MB/s, avg write rate: 12.922 MB/s
	system usage: CPU: user: 12.87 s, system: 2.57 s, elapsed: 133.73 s
	WAL usage: 393299 records, 207732 full page images, 1235906260 bytes
```

Here, we are just under the limit : 1 idx scan again.

```
[local]:5436 postgres@postgres=# UPDATE avac SET t = 'UPDATE 1' WHERE i < 11000000;
UPDATE 10999999

2020-09-22 10:54:19.419 CEST [522948] LOG:  automatic vacuum of table "postgres.public.avac": index scans: 1
	pages: 0 removed, 137886 remain, 0 skipped due to pins, 0 skipped frozen
	tuples: 10999999 removed, 13064130 remain, 0 are dead but not yet removable, oldest xmin: 3804
	buffer usage: 138545 hits, 233138 misses, 239889 dirtied
	avg read rate: 15.113 MB/s, avg write rate: 15.551 MB/s
	system usage: CPU: user: 10.54 s, system: 2.41 s, elapsed: 120.51 s
	WAL usage: 419635 records, 239893 full page images, 1296626990 bytes
```

# Queries

Requiered memory for AV on the current database: 

```
WITH reference AS (                                                             
    SELECT n.nspname, c.relname, c.reltuples,                                       
           COALESCE(SUBSTRING(array_to_string(c.reloptions, E' ') || ' ' FROM 'autovacuum_vacuum_scale_factor=#"[0-9]*#" %' FOR '#'), current_setting('autovacuum_vacuum_scale_factor')) AS autovacuum_vacuum_scale_factor,
           COALESCE(SUBSTRING(array_to_string(c.reloptions, E' ') || ' ' FROM '%autovacuum_vacuum_threshold=#"[0-9]*#" %'   FOR '#'), current_setting('autovacuum_vacuum_threshold')) AS autovacuum_vacuum_threshold
    FROM pg_class c                                                             
         INNER JOIN pg_namespace n ON c.relnamespace = n.oid                    
    WHERE n.nspname NOT LIKE ALL(ARRAY['pg_%', 'information_schema'])                
      AND c.relkind = 'r'                                                         
)                                                                                   
SELECT nspname, relname, reltuples,                                                 
       (reltuples * autovacuum_vacuum_scale_factor::numeric + autovacuum_vacuum_threshold::int)::bigint  AS avac_start_at,
       pg_size_pretty((reltuples * autovacuum_vacuum_scale_factor::numeric + autovacuum_vacuum_threshold::int)::bigint * 6) AS pretty_avac_req_memory,
       (reltuples * autovacuum_vacuum_scale_factor::numeric + autovacuum_vacuum_threshold::int)::bigint * 6 AS avac_req_memory,
       pg_size_pretty((reltuples * 6)::bigint) AS pretty_vac_fulltable_req_memory,
       (reltuples * 6)::bigint AS vac_fulltable_req_memory 
FROM reference
ORDER BY avac_req_memory DESC;

 nspname |   relname    |   reltuples   | avac_start_at | pretty_avac_req_memory | avac_req_memory | pretty_vac_fulltable_req_memory | vac_fulltable_req_memory
---------+--------------+---------------+---------------+------------------------+-----------------+---------------------------------+--------------------------
 public  | avac         | 1.4987546e+07 |       2997559 | 17 MB                  |        17985354 | 86 MB                           |                 89925276
 public  | t_2col_large |         1e+06 |        200050 | 1172 kB                |         1200300 | 5859 kB                         |                  6000000
 public  | avac2        |             0 |        100000 | 586 kB                 |          600000 | 0 bytes                         |                        0
 public  | dedup        |             1 |            50 | 300 bytes              |             300 | 6 bytes                         |                        6
(4 rows)
```

Query to get the max `autovacuum_work_mem` :

```
WITH reference AS (                                                             
    SELECT n.nspname, c.relname, c.reltuples,                                       
           COALESCE(SUBSTRING(array_to_string(c.reloptions, E' ') || ' ' FROM 'autovacuum_vacuum_scale_factor=#"[0-9]*#" %' FOR '#'), current_setting('autovacuum_vacuum_scale_factor')) AS autovacuum_vacuum_scale_factor,
           COALESCE(SUBSTRING(array_to_string(c.reloptions, E' ') || ' ' FROM '%autovacuum_vacuum_threshold=#"[0-9]*#" %'   FOR '#'), current_setting('autovacuum_vacuum_threshold')) AS autovacuum_vacuum_threshold
    FROM pg_class c                                                             
         INNER JOIN pg_namespace n ON c.relnamespace = n.oid                    
    WHERE n.nspname NOT LIKE ALL(ARRAY['pg_%', 'information_schema'])                
      AND c.relkind = 'r'                                                         
), detail AS (
    SELECT nspname, relname, reltuples,                                                 
           pg_size_pretty((reltuples * autovacuum_vacuum_scale_factor::numeric + autovacuum_vacuum_threshold::int)::bigint * 6) AS pretty_avac_req_memory,
           (reltuples * autovacuum_vacuum_scale_factor::numeric + autovacuum_vacuum_threshold::int)::bigint * 6 AS avac_req_memory,
           pg_size_pretty((reltuples * 6)::bigint) AS pretty_vac_fulltable_req_memory,
           (reltuples * 6)::bigint AS vac_fulltable_req_memory 
    FROM reference
)
SELECT pg_size_pretty(max(avac_req_memory)) AS autovacuum_work_mem, 
       pg_size_pretty((max(avac_req_memory)::numeric*1.1)::bigint)  AS autovacuum_work_mem_plus_10pct
  FROM detail;


 autovacuum_work_mem | autovacuum_work_mem_plus_10pct 
---------------------+--------------------------------
 17 MB               | 19 MB
(1 row)
```
