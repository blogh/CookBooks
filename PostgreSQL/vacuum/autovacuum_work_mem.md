**Valid for PostgreSQL 14**

# Sizing autovacuum_work_mem

Reference : https://rhaas.blogspot.com/2019/01/how-much-maintenanceworkmem-do-i-need.html

The calculus for the alocation of memory is done here :
* src/backend/access/heap/vacuumlazy.c
* src/backend/commands/vacuumlazy.c.

```
2134         if (vacrelstats->useindex)
   1         {
   2                 maxtuples = (vac_work_mem * 1024L) / sizeof(ItemPointerData);
   3                 maxtuples = Min(maxtuples, INT_MAX);
   4                 maxtuples = Min(maxtuples, MaxAllocSize / sizeof(ItemPointerData));
   5
   6                 /* curious coding here to ensure the multiplication can't overflow */
   7                 if ((BlockNumber) (maxtuples / LAZY_ALLOC_TUPLES) > relblocks)
   8                         maxtuples = relblocks * LAZY_ALLOC_TUPLES;
   9
  10                 /* stay sane if small maintenance_work_mem */
  11                 maxtuples = Max(maxtuples, MaxHeapTuplesPerPage);
  12         }
  13         else
  14         {
  15                 maxtuples = MaxHeapTuplesPerPage;
  16         }
```

LAZY_ALLOC_TUPLES (MaxHeapTuplesPerPage) is computed here
`src/include/access/htup_details.h, it's value is 291.

```
574 #define MaxHeapTuplesPerPage    \
  1         ((int) ((BLCKSZ - SizeOfPageHeaderData) / \
  2                         (MAXALIGN(SizeofHeapTupleHeader) + sizeof(ItemIdData))))

** sizeof(ItemPointerData) =  6.
```

The maximum amount of memory allocated for the vacuum is :

* if `autovacuum_work_mem` is not set `maintenance_work_mem`
* if the amount of memory requiered to allocated as much TID's as there are
  lines in the table (`(relblocks * LAZY_ALLOC_TUPLES *
  sizeof(ItemPointerData)`) is lower than the memory specified for the vacuum
  the we allocate just that

The memory requiered by the autovacuum is computer like so (TID size = 6
octets):

* Memory needed for a table = tuples * 6
* Memory needed by autovac = (tuples * scale factor + threshold) * 6

The memory used by autovacuum is capped to 1GB.


# Test setup :

```
psql << _EOF_
CREATE TABLE avac(i int, t text);
INSERT INTO avac SELECT x FROM generate_series(1,15000000) AS F(x);
ALTER TABLE avac ADD PRIMARY KEY (i);
_EOF_
```

autovac will start at 3000050 modified tuples (default setup of autavacuum
parameters).

```
sql> SELECT relname, relpages, reltuples FROM pg_class WHERE relname = 'avac';
-[ RECORD 1 ]------
relname   | avac
relpages  | 66372
reltuples | 1.5e+07
```

# memory allocation // Valgrind

Set `maintenance_work_mem = 1GB` and start PostgreSQL with valgrind

```
$ valgrind --tool=massif \
           --trace-children=yes \
	   /usr/pgsql-12/bin/postgres "-D" "/home/benoit/var/lib/postgres/pgsql-12"
```

Update the table so that the autovacuum will be triggered (chec with watch):

```
sql> UPDATE avac SET t = 'UPDATE 1' WHERE i < 3100000;
sql> SELECT relname, n_dead_tup, last_autovacuum FROM pg_stat_user_tables WHERE relname = 'avac' \watch
```

When the autovacuum is done, stop PostgreSQL

Get the info about the last autovacuum

```
$ grep -A5 "automatic vacuum" ./log/postgresql-Tue.log
2020-11-17 15:28:38.840 CET [49968] LOG:  automatic vacuum of table "postgres.public.avac": index scans: 1
	pages: 0 removed, 83129 remain, 1 skipped due to pins, 0 skipped frozen
	tuples: 3099999 removed, 15000003 remain, 0 are dead but not yet removable, oldest xmin: 57639109
	buffer usage: 101327 hits, 136880 misses, 114833 dirtied
	avg read rate: 11.395 MB/s, avg write rate: 9.559 MB/s
	system usage: CPU: user: 34.37 s, system: 2.14 s, elapsed: 93.85 s
```

Show the stats for process 49968 :


```
$ ms_print massif.out.49968 | more
--------------------------------------------------------------------------------
Command:            /usr/pgsql-12/bin/postgres -D /home/benoit/var/lib/postgres/pgsql-12
Massif arguments:   (none)
ms_print arguments: massif.out.49968
--------------------------------------------------------------------------------


    MB
139.7^                                                              @@@@@:
     |#:::::::@::::::::@::::::::@:::::::::::::::::::::::::::::::::::@    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
     |#:::::::@::::::::@::: ::::@::::::::  :                        @    :
   0 +----------------------------------------------------------------------->Gi
     0                                                                   21.14

Number of snapshots: 84
 Detailed snapshots: [4 (peak), 14, 24, 34, 44, 52, 62, 72, 82]
```

Get the snapshot no 4 (peak) :

```
--------------------------------------------------------------------------------
  n        time(i)         total(B)   useful-heap(B) extra-heap(B)    stacks(B)
--------------------------------------------------------------------------------
  4     58,996,960      146,509,704      146,500,133         9,571            0
99.99% (146,500,133B) (heap allocation functions) malloc/new/new[], --alloc-fns, etc.
->99.18% (145,308,544B) 0x8D610B: ??? (in /usr/pgsql-12/bin/postgres)
| ->99.08% (145,158,968B) 0x8DB30D: palloc (in /usr/pgsql-12/bin/postgres)
| | ->99.07% (145,143,296B) 0x51BD40: heap_vacuum_rel (in /usr/pgsql-12/bin/postgres)
| | | ->99.07% (145,143,296B) 0x6410F1: ??? (in /usr/pgsql-12/bin/postgres)
| | |   ->99.07% (145,143,296B) 0x642389: vacuum (in /usr/pgsql-12/bin/postgres)
| | |     ->99.07% (145,143,296B) 0x720D88: ??? (in /usr/pgsql-12/bin/postgres)
| | |       ->99.07% (145,143,296B) 0x721F00: ??? (in /usr/pgsql-12/bin/postgres)
| | |         ->99.07% (145,143,296B) 0x722024: StartAutoVacWorker (in /usr/pgsql-12/bin/postgres)
| | |           ->99.07% (145,143,296B) 0x730A3A: ??? (in /usr/pgsql-12/bin/postgres)
| | |             ->99.07% (145,143,296B) 0x487BB1F: ??? (in /usr/lib64/libpthread-2.30.so)
| | |               ->99.07% (145,143,296B) 0x55E2F49: select (in /usr/lib64/libc-2.30.so)
| | |                 ->99.07% (145,143,296B) 0x730E5B: ??? (in /usr/pgsql-12/bin/postgres)
| | |                   ->99.07% (145,143,296B) 0x732980: PostmasterMain (in /usr/pgsql-12/bin/postgres)
| | |                     ->99.07% (145,143,296B) 0x4CE8D0: main (in /usr/pgsql-12/bin/postgres)
| | |
| | ->00.01% (15,672B) in 1+ places, all below ms_print's threshold (01.00%)
| |
| ->00.10% (149,576B) in 1+ places, all below ms_print's threshold (01.00%)
|
->00.81% (1,191,589B) in 1+ places, all below ms_print's threshold (01.00%)
```

The theorical maximum memory is :

```
66372 pages * 291 * 6 = 115 885 512 octets = 110.52 Mo (we re close :p)
```

This value is lower than `maintenance_work_mem`, it should be the amount used.
Valgrind shows an observed memory of 145 143 296 octets = 139.71 Mo.

Set `maintenance_work_mem = 64MB`, re trigger an autovacuum, get the vacuum stats
from the logs.

```
$ grep -A5 "automatic vacuum" ./log/postgresql-Tue.log
2020-11-17 16:16:34.661 CET [52134] LOG:  automatic vacuum of table "postgres.public.avac": index scans: 1
	pages: 0 removed, 83129 remain, 1 skipped due to pins, 0 skipped frozen
	tuples: 3099999 removed, 15000001 remain, 0 are dead but not yet removable, oldest xmin: 57639126
	buffer usage: 101283 hits, 136924 misses, 114635 dirtied
	avg read rate: 11.398 MB/s, avg write rate: 9.543 MB/s
	system usage: CPU: user: 34.50 s, system: 2.24 s, elapsed: 93.85 s
```

Get the stats for process 52134 :

```
$ ms_print massif.out.52134 | more
--------------------------------------------------------------------------------
Command:            /usr/pgsql-12/bin/postgres -D /home/benoit/var/lib/postgres/pgsql-12
Massif arguments:   (none)
ms_print arguments: massif.out.52134
--------------------------------------------------------------------------------


    MB
65.31^                                       :::::::::::::::::::::::::::::
     |#:::::::@::::::::@:::::::@:::::::::::@@:                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    :
     |#:::::::@::::::::@:::::::@:::::::::  @ :                      :    ::::@
   0 +----------------------------------------------------------------------->Gi
     0                                                                   21.13

Number of snapshots: 88
 Detailed snapshots: [4 (peak), 14, 24, 34, 44, 54, 64, 74, 84]
```

Get snapshot no 4 (peak):

```
--------------------------------------------------------------------------------
  n        time(i)         total(B)   useful-heap(B) extra-heap(B)    stacks(B)
--------------------------------------------------------------------------------
  4     58,983,922       68,476,808       68,465,757        11,051            0
99.98% (68,465,757B) (heap allocation functions) malloc/new/new[], --alloc-fns, etc.
->98.24% (67,274,168B) 0x8D610B: ??? (in /usr/pgsql-12/bin/postgres)
| ->98.03% (67,124,592B) 0x8DB30D: palloc (in /usr/pgsql-12/bin/postgres)
| | ->98.00% (67,108,920B) 0x51BD40: heap_vacuum_rel (in /usr/pgsql-12/bin/postgres)
| | | ->98.00% (67,108,920B) 0x6410F1: ??? (in /usr/pgsql-12/bin/postgres)
| | |   ->98.00% (67,108,920B) 0x642389: vacuum (in /usr/pgsql-12/bin/postgres)
| | |     ->98.00% (67,108,920B) 0x720D88: ??? (in /usr/pgsql-12/bin/postgres)
| | |       ->98.00% (67,108,920B) 0x721F00: ??? (in /usr/pgsql-12/bin/postgres)
| | |         ->98.00% (67,108,920B) 0x722024: StartAutoVacWorker (in /usr/pgsql-12/bin/postgres)
| | |           ->98.00% (67,108,920B) 0x730A3A: ??? (in /usr/pgsql-12/bin/postgres)
| | |             ->98.00% (67,108,920B) 0x487BB1F: ??? (in /usr/lib64/libpthread-2.30.so)
| | |               ->98.00% (67,108,920B) 0x55E2F49: select (in /usr/lib64/libc-2.30.so)
| | |                 ->98.00% (67,108,920B) 0x730E5B: ??? (in /usr/pgsql-12/bin/postgres)
| | |                   ->98.00% (67,108,920B) 0x732980: PostmasterMain (in /usr/pgsql-12/bin/postgres)
| | |                     ->98.00% (67,108,920B) 0x4CE8D0: main (in /usr/pgsql-12/bin/postgres)
| | |
| | ->00.02% (15,672B) in 1+ places, all below ms_print's threshold (01.00%)
| |
| ->00.22% (149,576B) in 1+ places, all below ms_print's threshold (01.00%)
|
->01.74% (1,191,589B) in 67 places, all below massif's threshold (1.00%)
```

Theorical max memory :

```
66372 pages * 291 * 6 = 115 885 512 octets = 110.517 Mo.
```

This is more than `maintenance_work_mem` (64 Mo), we should use `maintenance_work_mem`.
Valgrind shows an observed memory of 67 108 920 octets = 64 Mo.

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

