# Logical replication: Initial synchronization

What can we see ? where ?

## Publication

The initial copy can be see in the pg_stat_progress_copy (>= pg14).
It's a PIPE type, so we don't have the inforamtion `bytes_total`.

```
SELECT p.*,
       c.reltuples,
       pg_relation_size(c.oid),
       CASE WHEN c.reltuples = 0 THEN 0 ELSE (100 * p.tuples_processed / c.reltuples)::int END AS pct_tuple,
       CASE WHEN pg_relation_size(c.oid) = 0 THEN 0 ELSE (100 * p.bytes_processed / pg_relation_size(c.oid))::int END AS pct_bytes
  FROM pg_stat_progress_copy p 
       INNER JOIN pg_class c ON p.relid = c.oid;

  pid   | datid | datname | relid | command | type | bytes_processed | bytes_total | tuples_processed | tuples_excluded | reltuples | pg_relation_size | pct_tuple | pct_bytes 
--------+-------+---------+-------+---------+------+-----------------+-------------+------------------+-----------------+-----------+------------------+-----------+-----------
 990017 | 24691 | bench   | 50667 | COPY TO | PIPE |        64832103 |           0 |           675413 |               0 |     3e+06 |        409714688 |        23 |        15
(1 row)
```

We can see the walsenders dedicated for the apply & the sync activity.

```
SELECT pid,
       application_name,
       wait_event,
       query
  FROM pg_stat_activity 
 WHERE backend_type='walsender';

  pid   |            application_name             |     wait_event      |                                            query                                            
--------+-----------------------------------------+---------------------+---------------------------------------------------------------------------------------------
 990013 | sub_t                                   | WalSenderWaitForWAL | START_REPLICATION SLOT "sub_t" LOGICAL 0/0 (proto_version '2', publication_names '"pub_t"')
 990017 | pg_16574_sync_16391_7054555878165241703 | ¤                   | COPY public.pgbench_accounts TO STDOUT
(2 rows)
```

A temporary replication slot is created for the synchronisation.
The initialisation is therefore limited by `max_replication_slots.`.

```
 SELECT slot_name,
        active,
	active_pid,
	restart_lsn,
	confirmed_flush_lsn 
  FROM pg_replication_slots ;

                slot_name                | active | active_pid | restart_lsn | confirmed_flush_lsn 
-----------------------------------------+--------+------------+-------------+---------------------
 sub_t                                   | t      |     990013 | D/E513F428  | D/E513F460
 pg_16574_sync_16391_7054555878165241703 | f      |          ¤ | D/E513F3B8  | D/E513F3F0
(2 rows)
```

## Subscription

The initialisation process for the subscription is visible ni `pg_subscription_rel`.

The details are in: `src/backend/replication/logical/tablesync.c`.
>        There are several reasons for doing the synchronization this way:
>         - It allows us to parallelize the initial data synchronization
>               which lowers the time needed for it to happen.
>         - The initial synchronization does not have to hold the xid and LSN
>               for the time it takes to copy data of all tables, causing less
>               bloat and lower disk consumption compared to doing the
>               synchronization in a single process for the whole database.
>         - It allows us to synchronize any tables added after the initial
>               synchronization has finished.
>
>        The stream position synchronization works in multiple steps:
>         - Apply worker requests a tablesync worker to start, setting the new
>               table state to INIT.
>         - Tablesync worker starts; changes table state from INIT to DATASYNC while
>               copying.
>         - Tablesync worker does initial table copy; there is a FINISHEDCOPY (sync
>               worker specific) state to indicate when the copy phase has completed, so
>               if the worker crashes with this (non-memory) state then the copy will not
>               be re-attempted.
>         - Tablesync worker then sets table state to SYNCWAIT; waits for state change.
>         - Apply worker periodically checks for tables in SYNCWAIT state.  When
>               any appear, it sets the table state to CATCHUP and starts loop-waiting
>               until either the table state is set to SYNCDONE or the sync worker
>               exits.
>         - After the sync worker has seen the state change to CATCHUP, it will
>               read the stream and apply changes (acting like an apply worker) until
>               it catches up to the specified stream position.  Then it sets the
>               state to SYNCDONE.  There might be zero changes applied between
>               CATCHUP and SYNCDONE, because the sync worker might be ahead of the
>               apply worker.
>         - Once the state is set to SYNCDONE, the apply will continue tracking
>               the table until it reaches the SYNCDONE stream position, at which
>               point it sets state to READY and stops tracking.  Again, there might
>               be zero changes in between.


Postgres tries to spawn a worker per table limited by: 

* max_sync_workers_per_subscription
* max_logical_replication_workers
* max_worker_processes. 

```
SELECT s.subname,
       d.datname,
       c.relname,
       CASE sr.srsubstate
          WHEN 'i' THEN 'INITIALIZED'
	  WHEN 'd' THEN 'COPY IN PROGRESS'
	  WHEN 'f' THEN 'DONE COPYING'
	  WHEN 's' THEN 'SYNCHRONIZED'
	  WHEN 'r' THEN 'READY'
       END AS state,
       sr.srsublsn
  FROM pg_subscription_rel sr
       INNER JOIN pg_subscription s ON s.oid = sr.srsubid 
       INNER JOIN pg_class c ON sr.srrelid = c.oid 
       INNER JOIN pg_database d ON s.subdbid = d.oid;

 subname | datname |     relname      |      state       |  srsublsn  
---------+---------+------------------+------------------+------------
 sub_t   | bench   | pgbench_branches | READY            | D/E513F460
 sub_t   | bench   | pgbench_tellers  | READY            | D/E513F428
 sub_t   | bench   | pgbench_history  | READY            | D/E513F3F0
 sub_t   | bench   | pgbench_accounts | COPY IN PROGRESS | ¤
(4 rows)
```

In `pg_replication_origin_status`, we can see a temporary origin created during the COPY phase.

```
SELECT * FROM pg_replication_origin_status;

 local_id | external_id | remote_lsn | local_lsn  
----------+-------------+------------+------------
        1 | pg_16574    | 0/0        | 5/6AE72F90
        3 | ¤           | D/E513F3F0 | 0/0

(2 rows)
```
