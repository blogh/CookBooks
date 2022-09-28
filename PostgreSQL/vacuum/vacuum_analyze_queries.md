**Valid for PostgreSQL 14**

# queries to vacuum table picked by the lastvacuum service of [check_pgactivity](https://github.com/OPMDG/check_pgactivity)

List table without vacuum for more than a month :

```
SELECT schemaname, relname,  pg_size_pretty(pg_relation_size(schemaname || '.' || relname)), n_live_tup, n_dead_tup, last_vacuum, last_autovacuum, vacuum_count, autovacuum_count
FROM pg_stat_user_tables 
WHERE (current_timestamp - last_vacuum > interval '1 month' AND current_timestamp - last_autovacuum > interval '1 month')
   OR (last_vacuum IS NULL AND last_autovacuum IS NULL)
ORDER BY pg_relation_size(schemaname || '.' || relname) DESC;
```

Create the `VACUUM ANALYZE` command execute with \gexec (if available) :

```
SELECT 'VACUUM ANALYZE ' || schemaname || '.' || relname || ';'
FROM pg_stat_user_tables
WHERE (current_timestamp - last_vacuum > interval '1 month' AND current_timestamp - last_autovacuum > interval '1 month')
   OR (last_vacuum IS NULL AND last_autovacuum IS NULL);

-- with a limit to pace the maintenance
SELECT 'VACUUM ANALYZE ' || schemaname || '.' || relname || ';'
FROM pg_stat_user_tables
WHERE (current_timestamp - last_vacuum > interval '1 month' AND current_timestamp - last_autovacuum > interval '1 month')
   OR (last_vacuum IS NULL AND last_autovacuum IS NULL)
LIMIT 50;
```

# queries to vacuum table picked by the lastanalyze service of [check_pgactivity](https://github.com/OPMDG/check_pgactivity)



List table without analyze for more than a month :

```
-- Post 9.4 with `n_mod_since_analyze`
SELECT schemaname, relname, pg_size_pretty(pg_relation_size(schemaname || '.' || relname)), n_live_tup, n_mod_since_analyze, last_analyze, last_autoanalyze, analyze_count, autoanalyze_count
FROM pg_stat_user_tables 
WHERE (current_timestamp - last_analyze > interval '1 month' AND current_timestamp - last_autoanalyze > interval '1 month')
   OR (last_analyze IS NULL AND last_autoanalyze IS NULL)
ORDER BY pg_relation_size(schemaname || '.' || relname) DESC;

-- Pre 9.4 without `n_mod_since_analyze`
SELECT schemaname, relname, pg_size_pretty(pg_relation_size(schemaname || '.' || relname)), last_analyze, last_autoanalyze, analyze_count, autoanalyze_count
FROM pg_stat_user_tables 
WHERE (current_timestamp - last_analyze > interval '1 month' AND current_timestamp - last_autoanalyze > interval '1 month')
   OR (last_analyze IS NULL AND last_autoanalyze IS NULL)
ORDER BY pg_relation_size(schemaname || '.' || relname) DESC;
```

Create the `ANALYZE` command execute with \gexec (if available) :

```
SELECT 'ANALYZE ' || schemaname || '.' || relname || ';'
FROM pg_stat_user_tables
WHERE (current_timestamp - last_analyze > interval '1 month' AND current_timestamp - last_autoanalyze > interval '1 month')
   OR (last_analyze IS NULL AND last_autoanalyze IS NULL);

-- with a limit to pace the maintenance
SELECT 'ANALYZE ' || schemaname || '.' || relname || ';'
FROM pg_stat_user_tables
WHERE (current_timestamp - last_analyze > interval '1 month' AND current_timestamp - last_autoanalyze > interval '1 month')
   OR (last_analyze IS NULL AND last_autoanalyze IS NULL)
LIMIT 50;
```

