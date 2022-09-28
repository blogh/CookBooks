```
SELECT pid, datname, user, current_timestamp - xact_start AS xs, current_timestamp - query_start AS qs, current_timestamp - state_change AS sc, state, wait_event, query
FROM pg_stat_activity
WHERE backend_type in ('client backend', 'parallel worker')
  AND state = 'active'
  AND pid <> pg_backend_pid()
--  AND current_timestamp - query_start > INTERVAL '1 hour'
;
```
