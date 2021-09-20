# prepared statements & connection pooling

## What are prepared statements ?

```
=# PREPARE gettuple AS SELECT reltuples FROM pg_class WHERE relname = $1;
PREPARE
=# EXECUTE gettuple('pg_class');
 reltuples
-----------
       391
(1 row)
=# DEALLOCATE gettuple ;
DEALLOCATE
```

## Why use prepared statements

* prevent SQL injection ;
* improve performance on the database side by taking advantage of the plan
  cache.

## How does PostgreSQL manage this

## What's the problem with connection pooling & prepared statements

In general :

* parameters can be set for a session for example : `statement_timeout`, if we
  do nothing it could impact the next person who uses the connection. 
  That's why we have to do a `DISCARD ALL` to clean everthing up.

* prepared statements are recorded at the session level in the database. If we
  don't clean things up, we will reveive error because the prepared statements
  we want to create might already exists. That's why `DISCARD ALL` includes
  `DEALLOCATE ALL` ([doc](https://www.postgresql.org/docs/13/sql-discard.html))

  Example with psycopg2 and pgbouncer: 
  ```
  psycopg2.errors.DuplicatePreparedStatement: prepared statement "myplan" already exists
  ```

prepared statements cannot be used with most external poolers when in
transaction pooling mode:

* [pgbouncer](http://www.pgbouncer.org/features.html): No
* [pgagroal](https://agroal.github.io/pgagroal/pipelines.html): No
* [odyssey](https://github.com/yandex/odyssey/issues/16): No
* [pgpool](https://www.pgpool.net/docs/pgpool-II-3.0.15/doc/pgpool-en.html): No

Where as poolers included in the application can do something about it :
* [Npgsql](https://www.roji.org/prepared-statements-in-npgsql-3-2): Yes
* jdbc: No

It's because, since the prepared statements are created at session level, if we
do transaction pooling at the transaction level, we could have two kinds of
errors :

* the prepared statement already exists when we create it :

  ```
  psycopg2.errors.DuplicatePreparedStatement: prepared statement "myplan" already exists
  ```

* the prepared statements doesn't exist when we try to execute a prepared
  statement we preapred in a previous transaction :

  ```
  psycopg2.errors.InvalidSqlStatementName: prepared statement "myplan" does not exist
  ```

Note: it's possible to `DISCARD ALL` at the end of the transaction, with the
impact that everything we set in the session up to there is gone. So we need to
re-set all the session stuff and reprepare.

## Work arounds

### Npgsql's presistent prepared statements and autoprepare

The user always prepare his queries (that what we never run across the case of
"prepared statement doesnt exists" case.  Npgsql tracks all prepared statement
for each connection in an array and send's the prepared statement to PostgreSQL
only if it's needed.

Statements can be tagger as persistent. They have a lifetime, when they are too
long they are `DEALLOCATED`.

When the transaction is closed, they do the cleanup with the equivalent of
`DISCARD ALL - DEALLOCATE ALL`.

Often used queries can also be autoprepared based on the frequency they are
used. (if you cannot/don't use `prepare()` on your queries)

* [Prepared stateement doc](https://www.npgsql.org/doc/prepare.html)
* [Persistent prepare statement](https://github.com/npgsql/npgsql/issues/483)
* [Prepared statements and Npgsql](https://github.com/npgsql/npgsql/issues/434)

### Jdbc

When a query is prepared, if `prepareThreshold` is set, server side prepared
statement will be used only after the query is used that many times. There is a
per connection cache. It's size is determined by
`preparedStatementCacheQueries` or `preparedStatementCacheSizeMiB`.

There is no garanty that the prepared statement will be present if you use 
use `transaction mode`. It's something that has to be done by a layer above
jdbc.

* [Using prepared statements](https://dotnettutorials.net/lesson/prepared-statement-in-jdbc/)
* [jdbc connection pooing & prepared statements](https://stackoverflow.com/questions/6094529/prepared-statements-along-with-connection-pooling)

### preprepare

[preprepare](https://github.com/dimitri/preprepare) is a PostgreSQL extension
that tracks all statements that needs to be prepared in a relation with two
columns (name & statement).

The configuration is minimal :

```
custom_variable_classes = 'preprepare'        # only for 9.1 and earlier
preprepare.at_init  = on                      # auto prepare at connect init
preprepare.relation = 'preprepare.statements' # the aforementionned relation
```

To prepare the statement run `SELECT prepare_all();`. If you use  pg > 8.4 and
`preprepare.at_init` is set to `on`. It's done automatically.

A `discard()` function is also present. It does: `DISCARD ALL - DEALLOCATE
ALL`.

The extension is old, and there is not much activity on it (but there might be
no reason for more activity).

