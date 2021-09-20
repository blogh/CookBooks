# PGBOUNCER

[website](http://www.pgbouncer.org/config.html)

## pgbouncer.ini

3 sections:

* `[pgbouncer]`
* `[databases]`
* `[users]`

### [pgbouncer]

Connections:

* `listen_address`, `listen_port`
* `unix_socket_dir`, `unix_socket_mode`, `unix_socket_group`

Files:

* `logfile`
* `pidfile`
* `auth_file`
* `auth_hba_file` if `auth_type` is `hba`

Authentication:

* `auth_type` (`md5`, `scram-sha-256`, `cert`...)
* `auth_query`

  ```
  CREATE OR REPLACE FUNCTION pgbouncer.user_lookup(in i_username text, out uname text, out phash text)
  RETURNS record AS $$
  BEGIN
      SELECT usename, passwd FROM pg_catalog.pg_shadow
      WHERE usename = i_username INTO uname, phash;
      RETURN;
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;
  REVOKE ALL ON FUNCTION pgbouncer.user_lookup(text) FROM public, pgbouncer;
  GRANT EXECUTE ON FUNCTION pgbouncer.user_lookup(text) TO pgbouncer;
  ```

* `auth_user`
* `auth_file`: The auth file can be generated with the following query

  ```
  SELECT $$"$$ || replace( usename, $$"$$, $$""$$) || $$" "$$ || replace( passwd, $$"$$, $$""$$ ) || $$"$$ 
  from pg_shadow 
  where passwd is not null 
  order by 1;
  ```	

Pools and connections:

* `pool_mode` (`session`, `transaction`, `statement`)
* `max_client_conn` (100)
* `default_pool_size` (20): max size of the pool size, additionnal connection will
  wait.
* `min_pool_size` (0): number of connection to open at the first connection.
* `reserve_pool_size` (0): if a connection wait for more than
  `reserve_pool_timeout` (5) allocate a connection from this pool.
* `max_db_connections` (0): maximum number of connection per database.
* `max_user_connections` (0): maximum number of connection per user.

Console access control:

* `admin_users`
* `stats_users`: users that have access to all `SHOW` command except `SHOW FDS`

TLS:

* client:
  * `client_tls_sslmode` (`disable`, `allow`, `prefer`, `require`,
    `verify-ca`/`verify-full`)
  * `client_tls_key_file`
  * `client_tls_cert_file`
  * `client_tls_ca_file`

* server:
  * `server_tls_sslmode` (`disable`, `allow`, `prefer`, `require`,
    `verify-ca`/`verify-full`)
  * `server_tls_key_file`
  * `server_tls_cert_file`
  * `server_tls_ca_file`

Dangerous timeout:

* `query_timeout`
* `query_wait_timeout`: maximum time queries can be allowed to wait for
  execution.
* `client_idle_timeout`
* `idle_transaction_timeout`


Others:

* `server_reset_query` (`DISCARD ALL`, `DEALLOCATE ALL`) see
  [doc](https://www.postgresql.org/docs/13/sql-discard.html)
* `server_reset_query_always`: to use `server_reset_query` after each
  transaction which is not the default. The default is the session.
* `server_check_query`: query to test the connection `SELECT 1;`
* `server_lifetime` (3600): unused connection older than this are closed.
* `server_idle_timeout` (600): connection idle for longer than this are closed.

### [database]

Connection string:

```
data1 = host=localhost port=5433 dbname=data1 user=yoyo .. [param=value]
data2 = host=localhost port=5433 dbname=data2 .. [param=value]
```

Others :

* `auth_user`
* `pool_size` (20)
* `min_pool_size` (0)
* `reserve_pool` (0)
* `connect_query`
* `pool_mode` (`session`, `transaction`, `statement`)
* `max_db_connections` (0)
* `client_encoding`
* `datestyle`
* `timezone`

### [users]

* `pool_mode` (`session`, `transaction`, `statement`)
* `max_user_connections` (0)

