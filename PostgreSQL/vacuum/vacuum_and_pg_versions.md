# Autovacuum evolution per version

## PostgreSQL 14

[Release notes](https://www.postgresql.org/docs/release/14.0/)

Parameters:
* `vacuum_cost_page_miss`'s default value becomes 2 (was 10).
* `vacuum_cleanup_index_scale_factor` is removed (unused since 13.3).
* `vacuum_failsafe_age`
   - Specifies the maximum age (in transactions) that a table's
     `pg_class.relfrozenxid` field can attain before `VACUUM` takes
     extraordinary measures to avoid system-wide transaction ID wraparound
     failure. This is `VACUUM`'s strategy of last resort. The failsafe
     typically triggers when an autovacuum to prevent transaction ID wraparound
     has already been running for some time, though it's possible for the
     failsafe to trigger during any `VACUUM`.
   - disable cost base delay
   - disable non-essential tasks such as index cleanup.
* `maintenance_io_concurrency` also impacts analyze since it now does page
  prefetches.
* `vacuum_multixact_failsafe_age`: same as `vacuum_failsafe_age` but fo multi
  XID

Commands:
* `VACUUM (INDEX CLEANUP AUTO|ON|OFF`
   - `AUTO`: can skip index mainteance if there is not enought dead line (ie
     it's too expensive to do the maintenance). (default)
   - `ON`: force cleanup (old behavior)
   - `OFF`: disable index cleanup for cases where we have to `VACUUM` quickly
     e.g. to prevente Wraparound.
   - not used byt VACUUM FULL, if the XID Wraparound failsafe mecanism is
     triggered index cleanup will be skipped.
   - improves on a v12 feature.
   - `vacuumdb --force-index-cleanup`
   - `vacuumdb --no-index-cleanup`
* `VACUUM (PROCESS_TOAST ON|OFF)`
   - `ON`: process the TOAST table (required for `VACUUM FULL`) (default)
   - `OFF`: ignores the TOAST table
   - `vacuumdb --no-process-toast`
* `COPY FREEZE`
   - Freeze the line while copying
   - Requires that the table was created or truncated in the transaction and
     that the transaction doesn't hold cursor or older snapshots
   - Doesn't work on partitionned table
   - Since the data is inserted in a forzen state the lines a visible
     immediately which violates MVCC.

Others:
* improve performances
* More information in autovacuum/autoanalyze logs
   - index info for autovacuum
   - buffer usage and io timings info (if `track_io_timing` is enabled)

     ```
     2022-02-09 10:52:38.420 CET [306047]() LOG:  automatic vacuum of table "postgres.public.t": index scans: 1
         pages: 0 removed, 5406 remain, 0 skipped due to pins, 0 skipped frozen
         tuples: 500000 removed, 500000 remain, 0 are dead but not yet removable, oldest xmin: 4816636
         index scan needed: 5406 pages from table (100.00% of total) had 500000 dead item identifiers removed
         index "t_pkey": pages: 2745 in total, 0 newly deleted, 0 currently deleted, 0 reusable
         index "idx_t": pages: 789 in total, 0 newly deleted, 0 currently deleted, 0 reusable
         I/O timings: read: 0.090 ms, write: 0.000 ms
         avg read rate: 0.071 MB/s, avg write rate: 0.088 MB/s
         buffer usage: 19825 hits, 4 misses, 5 dirtied
         WAL usage: 19741 records, 5 full page images, 5106700 bytes
         system usage: CPU: user: 0.22 s, system: 0.00 s, elapsed: 0.44 s
     2022-02-09 10:52:38.577 CET [306047]() LOG:  automatic analyze of table "postgres.public.t"
         I/O timings: read: 30.624 ms, write: 0.000 ms
         avg read rate: 0.952 MB/s, avg write rate: 0.250 MB/s
         buffer usage: 5587 hits, 19 misses, 5 dirtied
         system usage: CPU: user: 0.05 s, system: 0.00 s, elapsed: 0.15 s
     ```

## PostgreSQL 13

[Release notes](https://www.postgresql.org/docs/release/13.0/)

Parameters:
* allow `INSERT` to trigger autovacuum, previously it could only trigger
  autoanalyze.
  - enables index only scans since the visibility bits will now be set.
  - allows insert only table to be vacuumed from time to time which spreads the
    freezing activity.
  - two new options:
    - `autovacuum_vacuum_insert_threshold`
    - `autovacuum_vacuum_insert_scale_factor`

Commands:
* `VACUUM (PARALLEL int)`.
  - allows to use N background worker to process indexes in parallel:
  - the amount of workers counts towards `max_parallel_maintenance_workers`
  - an index can participate in parallel vacuuming only if it's bigger than
    `min_parallel_index_scan_size`.
  - 0 disables the feature.
  - unavailable for `VACUUM FULL`.
  - `vacuumdb -P/--parallel=interger` (different from `-j/--jobs`)

Others:
* autovacuum tracks WAL usage.
* new wait event `VacuumDelay` to report on cost-based vacuum delay.
* new view `pg_stat_progress_analyze`

## PostgreSQL 12

[Release notes](https://www.postgresql.org/docs/release/12.0/)

Parameters:
* `autovacuum_vacuum_cost_delay` decreased to 2ms (from 20ms).
* `vacuum_cost_delay ` cas accept sub-millisecond timings.

Commands:
* `VACUUM (TRUNCATE ON|OFF)`
  - default `ON`
  - prevent `VACUUM` from truncating trailing empty space.
  - decrease the locking requirements (no need for an `ACCESS EXCLUSIVE` lock
    on the table).
  - prevents returning space to the operation system.
  - unavailable for `VACUUM FULL`
  - storage parameters: `vacuum_truncate` and `toast.vacuum_truncate`
* `VACUUM (INDEX CLEANUP ON|OFF`
   - `ON`: force cleanup (default)
   - `OFF`: disable index cleanup for cases where we have to `VACUUM` quickly
     e.g. to prevente Wraparound.
   - storage parameter `vacuum_index_cleanup`.
* `VACUUM|ANALYZE (SKIP_LOCKED ON|OFF)`
   - `ON`: dont wait for any conflicting locks to be released when beginning
     work on a relation
   - `OFF`: wait, the default
   - `VACUUM` may still block when opening the relation's indexes.
   - `VACUUM ANALYZE` may still block when acquiring sample rows from
     partitions, table inheritance children, and some types of foreign tables
   - skips all the partitions of a partition table if conflicting lock is found
     on the partitionned table.
   - `vacuumdb --skip-locked`
* `vacuumdb`
   - `--skip-locked`
   - `--disable-page-skipping`: Disable skipping pages based on the contents of
     the visibility map.
   - `--min-xid-age` and `--min-mxid-age`: select tables for vacuum based on
     their wraparound horizon.

Others:
* vacuum improvements on GiST indexes
* allows for the modification of autovacuum storage option on system tables if
  `allow_system_table_mods` is ON).
* new view `pg_stat_progress_cluster` to follow the progress of the `CLUSTER`
  and ` VACUUM FULL` commands.

## PostgreSQL 11

[Release notes](https://www.postgresql.org/docs/release/11.0/)

Parameters:
* `log_autovacuum_min_duration` logs skipped tables that are concurrently being
  dropped.

Commands:
* parenthesis option syntax for `ANALYZE`

Others:
* the computation of `pg_class.reltuples` by `VACUUM` is consistent with its
  computation by `ANALYZE`.
* `VACUUM` updates the FSM.
* limit unnecessary index scans in `VACUUM`.

## PostgreSQL 10

[Release notes](https://www.postgresql.org/docs/release/10.0/)

* `VACUUM VERBOSE` reports the number of skipped frozen pages and oldest xmin
  - also present in `log_autovacuum_min_duration`'s output.
* some performance improvement.
* decreased locking on GIN indexes.

## PostgreSQL 9.6

[Release notes](https://www.postgresql.org/docs/release/9.6/)

Commands:
* `VACUUM (DISABLE_PAGE_SKIPPING ON|OFF)`
  - force processing of all the pages, might be usefull on case of visibility
    map corruption.
  - normally, `VACUUM` skips the pages that are all frozen or all visible
    (except for agressive vacuum) or to avoid waiting for other session to
    finish using them (see 9.2).

Others:
* new view `pg_stat_progress_vacuum`.
* Improved stats on columns with lots of NULL's
* Avoid taking an EXCLUSIVE LOCK when no page truncation is possible.
* Avoid re-vacuuming pages containing only frozen tuples.

## PostgreSQL 9.5

[Release notes](https://www.postgresql.org/docs/release/9.5/)

Parameters:
* new storage parameter `log_autovacuum_min_duration`

Commands:
* `vacuumdb --jobs`

Others:
* `ANALYZE` computes basic stats for column without equality operator (null
  frac, avg col width)
* autovacuum workers listen to sighup signal & configuration change.
* `VACUUM` now logs the number of pages skipped due to pins.


## PostgreSQL 9.4

[Release notes](https://www.postgresql.org/docs/release/9.4/)

Commands:
* `VACUUM FULL` & `CLUSTER` attempts to `FREEZE` tuples.
* new parameter `autovacuum_work_mem`
* `vacuumdb --analyze-in-stages` to analyze in stages of increasing
  granularity
  - updates only optimizer statistics like `--analyze-only`
  - This allows minimal statistics to be created quickly and iterate on all
    databases for each stage before going to the next one.
  - `src/bin/scripts/vacuumdb.c`
     - stage 1: Generating minimal optimizer statistics (1 target)

       `SET default_statistics_target=1; SET vacuum_cost_delay=0;`

     - stage 2:  Generating medium optimizer statistics (10 targets)

       `SET default_statistics_target=10; RESET vacuum_cost_delay;`

     - stage 3: Generating default (full) optimizer statistics

       `RESET default_statistics_target;`

Others:
* `VACUUM` properly report dead but not-yet-removable rows to the statistics
  collector whereas befor it reported theme as live rows.
* the new column `pg_stat_all_tables.n_mod_since_analyze` displays the amount
  of modifications (`INSERT`, `UPDATE`, `DELETE`) done on a table since last
  analyze. The info was used by auto analyze and was previously hidden.

## PostgreSQL 9.3

[Release notes](https://www.postgresql.org/docs/release/9.3/)

Commands:
* `vacuumdb --table`

Others:
* Vacuum rechecks visibility after it has removed expired tuples to increase
  the chances of marking a page all visible.

## PostgreSQL 9.2

[Release notes](https://www.postgresql.org/docs/release/9.2/)

* The I/O activity of autovacuum is made more verbose when
  `log_autovacuum_min_duration` is triggered.
* `VACUUM` can skip pages that cannot be locked to avoid being stuck.

## PostgreSQL 9.1

[Release notes](https://www.postgresql.org/docs/release/9.1/)

Parameters:
* `log_autovacuum_min_duration`'s maximum value the maximum possible value for
  an int (it was previously 35 minutes)

Commands:
* `VACUUM FULL VERBOSE` & `CLUSTER VERBOSE`

Others:
* `VACUUM` and `ANALYZE` operations are now tracked in the `pg_stat_*_tables`
  views (count and last run for both their manual and automatic forms)
* autovacuum no longer wait when it cannot acquire a table lock

## PostgreSQL 9.0

[Release notes](https://www.postgresql.org/docs/release/9.0/)

Commands:
* new `VACUUM FULL` implementation: it now rewrites the entire table and
  indexes, rather than moving individual rows to compact space. It is
  substantially faster in most cases, and no longer results in index bloat.
* `VACUUM` has a new syntax with parenthesis.
* `vacuumdb --analyze-only`

Others:
* `ANALYZE` now supports inheritance-tree statistics. This is particularly
  useful for partitioned tables. However, autovacuum does not yet automatically
  re-analyze parent tables when child tables change. Interestingly enough this
  was still true before PostgreSQL 14.

## Before

Seriously .. update man
