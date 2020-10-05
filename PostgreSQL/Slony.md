# General

## Why Slony

* <> versions of PostgreSQL
* <> hardware and operation systems
* replicates only a subset of the data

## Requierments

* 2.2 : PostgreSQL >= 8.3 to now
* 1.2 : PostgreSQL <= 8.2

* TimeZone recognised by PostgreSQL (UTC /  GMT)
* reliable network, slon process on the same network ????
* same database encoding on all nodes

## Concepts

* Cluster : named set of PostgreSQL database instances
* Node : A PostgreSQL database that will be participating in replication.
* Replication Set : set of tables and sequences that are replicateed between
  nodes in Slony Cluster.
* Origin : Only place where the user application is permetted to modify data.
  Also called master provider (or event node in some commands).
* Providers / Subscriber :  A node can be provider and subscriber in cascading
  replication.  The origin cannot be a subscriber.

* Slon daemon : process that manages replication for the node. It is designed
  to process replication events :
  + configuration event : via the slonik script
  + SYNC event : Updates to tables regrouped together. (group of transactions)
* Slonik : command processor for configuration uppdate.
* Slony-I Path Communication


* Slon : elephant
* Slony : elephants
* Slonik : litte elephant
* Slony-I

## Limitations

* Need PK
* No BLOBS
* No DDL
* No modification to USERs and ROLEs

Scripts can be used with "slonik execute script" to propagate DDL changes.

## Events

Configuration & Application changes are propagated thru events.

Events are inserted in the event queue (`sl_event` table on the node). The
events are sent to all the remote slon's & then to slon's `remoteWorker`.

Event id = (Node id, sequence number)

### Sync

SYNC events are used to transfert application data from one node to the next.

Modifications are recorded in the `sl_log_1` and `sl_log_2` tables. The
`local_listener` thread periodically creates a SYNC event that encompasses the
events not yet commited.

The `remoteWorker` thread of for a slon processes the SYNC and queries all the
rows from the log tables that are encompassed by the SYNC. The data is then
applied on the subscriber.

### Confirmation

When an event is processed by a remote node a line is added to `sl_confirm`.
The message is transferred back to all other nodes in the cluster.

### Event cleanup

The `slon cleanup` thread periodically runs a function that deletes all but
the most recently confirmed event for each origin/reveiver pair. (sl_event ?)

Then old SYNC events are deleted in `sl_confirm`.

Then the data from `sl_log_1` and `sl_log_2` tables.

### Slonik and Event confirmation

Slonik's "wait for event" command is used to ensure that an event has been
processed.

### Listen Paths (automatic after 1.1)

# Scripts and queries

## Get tables without PK

Get tables without PK :

```
psql -h $MASTERHOST -p $MASTERPORT -d $MASTERDBNAME -U $REPLICATIONUSER <<_EOF_
SELECT n.nspname, c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE relkind='r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE contype='p' AND conrelid=c.oid)
ORDER BY n.nspname, c.relname;
_EOF_
```

They can then be added with :

```
ALTER TABLE <schema>.<table> ADD COLUMN <id_column> SERIAL PRIMARY KEY;
```

## No bytea

```
SELECT n.nspname, c.relname, attname, attnum, typname 
FROM pg_attribute a 
     INNER JOIN pg_type t on a.atttypid = t.oid 
     INNER JOIN pg_class c ON c.oid = a.attrelid 
     INNER JOIN pg_namespace n ON  n.oid=c.relnamespace 
WHERE typname = 'bytea'
  AND n.nspname NOT LIKE ALL (ARRAY['pg_%','information_schema'])
ORDER BY 1,2,4;
```

## Create the list of set commands (for the diy method)

Get the list tables :

```
psql -h $MASTERHOST -p $MASTERPORT -d $MASTERDBNAME -U $REPLICATIONUSER <<_EOF_
SELECT format('set add table (set id=1, origin=1, id=%s, fully qualified name = ''%I.%I'');',
       row_number() OVER (ORDER BY n.nspname, c.relname),
       n.nspname,
       c.relname)
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE relkind='r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'repack')
ORDER BY n.nspname, c.relname;
_EOF_
```

Get the list of sequences :

```
psql -h $MASTERHOST -p $MASTERPORT -d $MASTERDBNAME -U $REPLICATIONUSER <<_EOF_
SELECT format('set add sequence (set id=1, origin=1, id=%s, fully qualified name = ''%I.%I'');',
       row_number() OVER (ORDER BY n.nspname, c.relname),
       n.nspname,
       c.relname)
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE relkind='S'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'repack')
ORDER BY n.nspname, c.relname;
_EOF_
```

## Slonik Script to create a Slony-I Cluster (for the diy method)

Script create.sh

```
#!/bin/sh

slonik <<_EOF_
#--
# define the namespace the replication system uses in our example it is
# slony_example
#--
cluster name = $CLUSTERNAME;

#--
# admin conninfo's are used by slonik to connect to the nodes one for each
# node on each side of the cluster, the syntax is that of PQconnectdb in
# the C-API
# --
node 1 admin conninfo = 'host=$MASTERHOST port=$MASTERPORT dbname=$MASTERDBNAME user=$REPLICATIONUSER';
node 2 admin conninfo = 'host=$SLAVEHOST port=$SLAVEPORT dbname=$SLAVEDBNAME user=$REPLICATIONUSER';

#--
# init the first node.  This creates the schema
# _$CLUSTERNAME containing all replication system specific database
# objects.

#--
init cluster ( id=1, comment = 'Master Node');

#--
# Slony-I organizes tables into sets.  The smallest unit a node can
# subscribe is a set.  The following commands create one set containing
# all 4 pgbench tables.  The master or origin of the set is node 1.
#--
create set (id=1, origin=1, comment='All tables');
/** ADD ALL SET COMMANDS HERE **/

#--
# Create the second node (the slave) tell the 2 nodes how to connect to
# each other and how they should listen for events.
#--

store node (id=2, comment = 'Slave node', event node=1);
store path (server = 1, client = 2, conninfo='host=$MASTERHOST port=$MASTERPORT dbname=$MASTERDBNAME user=$REPLICATIONUSER');
store path (server = 2, client = 1, conninfo='host=$SLAVEHOST port=$SLAVEPORT dbname=$SLAVEDBNAME user=$REPLICATIONUSER');
_EOF_
```

## Slonik script to subscribe Nodes (for the diy method)

script subscribe.sh

```
#!/bin/sh
slonik <<_EOF_
#----
# This defines which namespace the replication system uses
# ----
cluster name = $CLUSTERNAME;

# ----
# Admin conninfo's are used by the slonik program to connect
# to the node databases.  So these are the PQconnectdb arguments
# that connect from the administrators workstation (where
# slonik is executed).
# ----
node 1 admin conninfo = 'dbname=$MASTERDBNAME host=$MASTERHOST port=$MASTERPORT user=$REPLICATIONUSER';
node 2 admin conninfo = 'dbname=$SLAVEDBNAME host=$SLAVEHOST port=$SLAVEPORT user=$REPLICATIONUSER';

# ----
# Node 2 subscribes set 1
# ----
subscribe set ( id = 1, provider = 1, receiver = 2, forward = no);
_EOF_
```

## List tables & indexes to compare number of lines

List tables with estimated number of lines and size of table :

```
SELECT n.nspname, c.relname, reltuples, pg_table_size(c.oid), pg_size_pretty(pg_table_size(c.oid))
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE relkind='r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'repack')
ORDER BY n.nspname, c.relname;
```

List indexes with estimated number of lines and size of table :

```
SELECT n.nspname, c.relname, reltuples, pg_table_size(c.oid), pg_size_pretty(pg_table_size(c.oid))
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE relkind='i'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'repack')
ORDER BY n.nspname, c.relname;
```

Liste tables with real number of lines and real size :

```
SET client_min_messages TO 'LOG';
DO LANGUAGE PLPGSQL $$
DECLARE
  rec record;
  req text;
  nb  integer;
BEGIN
  RAISE LOG '==> Schema | Table | relTuple | Count | Size | Size_pretty';
  FOR rec IN SELECT n.nspname, c.relname, reltuples, pg_table_size(c.oid) AS size, pg_size_pretty(pg_table_size(c.oid)) AS size_pretty
            FROM pg_class c
            JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE relkind='r'
              AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'repack')
            ORDER BY n.nspname, c.relname
  LOOP
    req := 'SELECT count(*) FROM '||quote_ident(rec.nspname)||'.'||quote_ident(rec.relname);
    EXECUTE req INTO nb;
    RAISE LOG '==> % | % | % | % | % | %', rec.nspname, rec.relname, rec.reltuples, nb, rec.size, rec.size_pretty;
  END LOOP;
END
$$;
```

## Check the status of slony's triggers 

With this query : (see [pg_trigger's doc](https://www.postgresql.org/docs/current/catalog-pg-trigger.html))
* Enables triggers are set to `O` 
* Disabled triggers are set to `D` 

```
SELECT n.nspname, c.relname,
       (SELECT tgenabled FROM pg_trigger WHERE c.oid = tgrelid AND tgname LIKE '%_denyaccess') AS denyaccess,
       (SELECT tgenabled FROM pg_trigger WHERE c.oid = tgrelid AND tgname LIKE '%_truncatedeny') AS truncatedeny,
       (SELECT tgenabled FROM pg_trigger WHERE c.oid = tgrelid AND tgname LIKE '%_logtrigger') AS logtrigger,
       (SELECT tgenabled FROM pg_trigger WHERE c.oid = tgrelid AND tgname LIKE '%_truncatetrigger') AS truncatetrigger
  FROM pg_class c
       INNER JOIN pg_namespace n ON c.relnamespace = n.oid
 WHERE n.nspname NOT LIKE ALL (ARRAY['pg_%','information_schema'])
 ORDER BY 1,2;
```

Triggers should be set to Disabled on the "standby" side (= read only)


# Install Tests

## Préreq Centos

### Server 1

Install PostgreSQL binaries

```
yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum install -y postgresql95-server slony1-95.x86_64

/usr/pgsql-9.5/bin/postgresql95-setup initdb
export PGDATA=/var/lib/pgsql/9.5/data
cp $PGDATA/postgresql.conf $PGDATA/postgresql.conf.old

cat <<_EOF_ >>$PGDATA/postgresql.conf
listen_addresses='*'
_EOF_

systemctl enable postgresql-9.5
systemctl start postgresql-9.5
```

Config PostgreSQL user (`.bashrc` / `.bash_profile`):

```
cat <<_EOF_ >>~postgres/.bash_profile
export PATH=$PATH:$HOME/.local/bin:$HOME/bin:/usr/pgsql-9.5/bin
export PGDATA=/var/lib/pgsql/9.5/data/

export CLUSTERNAME="slon_pg95_pg12"

export MASTERHOST=10.20.60.50
export MASTERPORT=5432
export MASTERDBNAME=pgbench

export SLAVEHOST=10.20.60.51
export SLAVEPORT=5432
export SLAVEDBNAME=pgbench

export REPLICATIONUSER=slony
export PGBENCHUSER=pgbench
_EOF_
. ~postgres/.bash_profile
```

Config PostgreSQL :

```
cp $PGDATA/pg_hba.conf $PGDATA/pg_hba.conf.old
cat <<_EOF_ >$PGDATA/pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD

local   all             all                                     peer
host    all             all             0.0.0.0/0               md5
host    all             all             127.0.0.1/32            ident
host    all             all             ::1/128                 ident
_EOF_
psql -c "SELECT pg_reload_conf();"
```

Cleanup :

```
dropdb   -p $MASTERPORT $MASTERDBNAME
dropuser -p $MASTERPORT $PGBENCHUSER
dropuser -p $MASTERPORT $REPLICATIONUSER
```

Setup (**change password as needed**):

```
psql -p $MASTERPORT -c "CREATE ROLE $PGBENCHUSER WITH PASSWORD '$PGBENCHUSER' LOGIN;"
psql -p $MASTERPORT -c "CREATE ROLE $REPLICATIONUSER WITH PASSWORD '$REPLICATIONUSER' LOGIN SUPERUSER;"
psql -p $MASTERPORT -c "CREATE DATABASE $MASTERDBNAME OWNER $PGBENCHUSER;"

cat <<_EOF_ > ~/.pgpass
*:*:*:pgbench:pgbench
*:*:*:slony:slony
_EOF_
chmod 600 ~/.pgpass

pgbench -h $MASTERHOST -p $MASTERPORT -U $PGBENCHUSER -i -s 1 $MASTERDBNAME
```

Add PKs to `pgbench_history` :

```
psql -h $MASTERHOST -p $MASTERPORT -U $PGBENCHUSER -d $MASTERDBNAME <<_EOF_
BEGIN;

ALTER TABLE pgbench_history
  ADD COLUMN id SERIAL;

UPDATE pgbench_history
  SET id = nextval('pgbench_history_id_seq');

ALTER TABLE pgbench_history
  ADD PRIMARY KEY(id);

COMMIT;
_EOF_
```

or with a one liner :

```
ALTER TABLE public.pgbench_history ADD COLUMN id SERIAL PRIMARY KEY;
```

### Server 2

Install binaries :

```
yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum install -y postgresql12-server slony1-12.x86_64


/usr/pgsql-12/bin/postgresql-12-setup initdb
export PGDATA=/var/lib/pgsql/12/data
cat <<_EOF_ >>$PGDATA/postgresql.conf
listen_addresses='*'
_EOF_

systemctl enable postgresql-12
systemctl start postgresql-12
```

Config PostgreSQL user :

```
cat <<_EOF_ >>~postgres/.bash_profile
export PATH=$PATH:$HOME/.local/bin:$HOME/bin:/usr/pgsql-12/bin
export PGDATA=/var/lib/pgsql/12/data/

export CLUSTERNAME="slon_pg95_pg12"

export MASTERHOST=10.20.60.50
export MASTERPORT=5432
export MASTERDBNAME=pgbench

export SLAVEHOST=10.20.60.51
export SLAVEPORT=5432
export SLAVEDBNAME=pgbench

export REPLICATIONUSER=slony
export PGBENCHUSER=pgbench
_EOF_
```

Cleanup :

```
dropdb -p $SLAVEPORT $SLAVEDBNAME
dropuser -p $SLAVEPORT $PGBENCHUSER
dropuser -p $SLAVEPORT $REPLICATIONUSER
```

Create a user :

```
psql -p $SLAVEPORT -c "CREATE ROLE $PGBENCHUSER WITH PASSWORD '$PGBENCHUSER' LOGIN;"
psql -p $SLAVEPORT -c "CREATE ROLE $REPLICATIONUSER WITH PASSWORD '$REPLICATIONUSER' LOGIN SUPERUSER;"
psql -p $SLAVEPORT -c "CREATE DATABASE $MASTERDBNAME OWNER $PGBENCHUSER;"

cat <<_EOF_ > ~/.pgpass
*:*:*:pgbench:pgbench
*:*:*:slony:slony
_EOF_
chmod 600 ~/.pgpass
```

Copy the globals :

```
pg_dumpall -h $MASTERHOST -p $MASTERPORT -U $REPLICATIONUSER --globals-only |
   psql -p $SLAVEPORT
```

Copy the structure of the database :

```
pg_dump -h $MASTERHOST -p $MASTERPORT -d $MASTERDBNAME -U $REPLICATIONUSER --exclude-schema="_$CLUSTERNAME" -s |
   psql -p $SLAVEPORT
```

## Compile on Debian

Install perl package :

```
apt-get install libpg-perl libdbd-pg-perl autoconf
```

I also did compile postgresql so I had (need  to cehck what was necessary):

```
sudo apt-get install build-essential libreadline-dev \
     zlib1g-dev flex bison libxml2-dev libxslt-dev \
     libssl-dev libxml2-utils xsltproc wget git
```

Compile with perl tools :

```
git clone git://git.postgresql.org/git/slony1-engine.git
cd slony1-engine/
git checkout REL_2_2_8
autoconf
./configure --with-pgconfigdir=/usr/lib/postgresql/9.1/bin --with-perltools
make
sudo make install
```

## Slonik scripts (diy)

### Server 1

Create the create.sh script and launch it after adding the set commands
generated with the SQL queries.

```
bash ./create.sh 2>&1 | tee create.log
```

Edit `/usr/lib/systemd/system/slony1-22-95.service` and fix `SLONCLUSTERNAME` and
SLONCONNINFO.

Then :

```
systemctl daemon-reload
systemctl start slony1-22-95
systemctl status slony1-22-95
```

Create the `subscribe.sh` script and launch it.

```
bash ./subscribe.sh 2>&1 | tee create.log
```

Test with pgbench :

```
pgbench -h $MASTERHOST -p $MASTERPORT -U pgbench -c 5 -T 300 pgbench
```

NOTE : I had problems with `SLONCONNINFO` in the service file. The quotes should
be after the first = sign.

```
Environnement="SLONCONNINFO=host= port= dbname= user="
```

### Server 2

Once the `subscribe.sh` script is launched on server 1.

Edit `/usr/lib/systemd/system/slony1-22-12.service` and fix `SLONCLUSTERNAME` and
`SLONCONNINFO`.

Then :

```
systemctl daemon-reload
systemctl start slony1-22-12
systemctl status slony1-22-12
```

## Perl scripts

### Server 1

Build the configuration :

```
slonik_build_env \
   -node $MASTERHOST:$MASTERDBNAME:$REPLICATIONUSER::$MASTERPORT \
   -node $SLAVEHOST:$SLAVEDBNAME:$REPLICATIONUSER::$SLAVEPORT \
   -schema public > /etc/slony1-95/slony_tools_bench.conf
```

There was a bug here for pg > 11
(https://github.com/ssinger/slony1-engine/issues/19) (FIXED)

Add some Configuration to the file (Note : dollars are escaped except for those
that need to be replaced by their value):

```
cat >> /etc/slony1-95/slony_tools_bench.conf << _EOF_

\$CLUSTER_NAME = '$CLUSTERNAME';
\$PIDFILE_DIR = '/var/run/slony1-95';
\$LOGDIR = '/var/log/slony1-95';
\$MASTERNODE = 1;
\$DEBUGLEVEL = 2;
@PKEYEDTABLES = () unless @PKEYEDTABLES;
@SEQUENCES = () unless @SEQUENCES;

\$SLONY_SETS = {
        "set_all" => {
                "set_id"      => 1,
                "table_id"    => 1,
                "sequence_id" => 1,
                "pkeyedtables" => \@PKEYEDTABLES,
                "sequences" => \@SEQUENCES
        }
};
_EOF_
```

Create the cluster :

```
slonik_init_cluster --config /etc/slony1-95/slony_tools_bench.conf | slonik
```

Configure the slon daemon for a **service**:

```
mkdir -p /etc/slony1-95/$CLUSTERNAME
cat >> /etc/slony1-95/$CLUSTERNAME/slon.conf << _EOF_
cluster_name='$CLUSTERNAME'
conn_info='host=/var/run/postgresql port=$MASTERPORT user=postgres dbname=$MASTERDBNAME'
_EOF_
```

Note : you might have to modify the init.d script

* the `/etc/init.d` script can be taken from `slony1-engine/tools/start_slon.sh`
* `SLON_BIN_PATH`, `SLON_CONF` and `SLON_LOG` have to be updated in the service
script
* it might be necessary to add : `pid_file='<path to pid>'`
* You migth have to create the links in `/etc/rc3.d`.

Configure the slon daemon for **systemctl**

```
systemctl daemon-reload
systemctl start slony1-22-95
systemctl status slony1-22-95
```

Note : You might have to modify : `/usr/lib/systemd/system/slony1-22-95.service`

* The `SLONCONNINFO` was broken for me I had to move the quotes : 

  ```
  Environment="SLONCONNINFO=host=localhost port=5432 user=slony dbname=pgbench"`   
  ```

* The `SLONCLUSTERNAME` might have to be changed for slony to find the schema in
  the database :

  ```
  Environment=SLONCLUSTERNAME=migration_pg91_pg12
  ```

Create a set and add tables to it :

```
slonik_create_set --config /etc/slony1-95/slony_tools_bench.conf set_all | slonik
```

Subscribe node 2 to the set :

```
slonik_subscribe_set --config /etc/slony1-95/slony_tools_bench.conf set_all node2 | slonik
```

Copy the file `/etc/slony1-95/slony_tools_bench.conf` on the other node
`/etc/slony1-12/slony_tools_bench.conf`.

Checks :

```
psql -h $MASTERHOST -p $MASTERPORT -d $MASTERDBNAME -U $REPLICATIONUSER << _EOF_
SET search_path TO _slon_pg95_pg12;
SELECT * FROM sl_node;
SELECT * FROM sl_set;
SELECT * FROM sl_subscribe;
SELECT * FROM sl_components;
\x
SELECT * FROM sl_status;
_EOF_
```

If you use systemd, traces will be in `/var/log/syslog` or `/var/log/messages`.

### Server 2

Configure the slone daemon on the second node (more details above) :

* for a **service**:

  ```
  mkdir -p /etc/slony1-12/$CLUSTERNAME
  cat >> /etc/slony1-12/$CLUSTERNAME/slon.conf <<_EOF_
  cluster_name='$CLUSTERNAME'
  conn_info='host=/var/run/postgresql port=$MASTERPORT user=postgres dbname=$MASTERDBNAME'
  _EOF_
  ```

* for **systemctl** : You might have to modify : `/usr/lib/systemd/system/slony1-22-12.service`

  ```
  systemctl daemon-reload
  systemctl start slony1-22-12
  systemctl status slony1-22-12
  ```

# Admin

## Add table to replication set

1) Create the table on all nodes
2) Create a new set, add the table to it, make the subscribers subscribe to it
3) Merge the new set to the old one

Use the commands :

* `slonik_create_set`
* `slonik_merge_sets`

Slonik script (pay attention to set id and table ids when adding tables to a
set) :

```
slonik <<_EOF_
cluster name = $CLUSTERNAME;

 node 1 admin conninfo = 'host=$MASTERHOST port=$MASTERPORT dbname=$MASTERDBNAME user=$REPLICATIONUSER';
 node 2 admin conninfo = 'host=$SLAVEHOST port=$SLAVEPORT dbname=$SLAVEDBNAME user=$REPLICATIONUSER';

  create set (id=2, origin=1, comment='a second replication set');
  set add table (set id=2, origin=1, id=5, fully qualified name = 'public.matable', comment='some new table');

  subscribe set(id=2, provider=1,receiver=2);
  merge set(id=1, add id=2,origin=1);
_EOF_
```

Queries to get the maximum id for tables and sets :

```
psql -p $MASTERPORT -At -c "SELECT max(tab_id) FROM _slon_pg95_pg12.sl_table ;"  $MASTERDBNAME
psql -p $MASTERPORT -At -c "SELECT max(set_id) FROM _slon_pg95_pg12.sl_set ;"  $MASTERDBNAME
```

## Add columns to a table

* Write the script without BEGIN/COMMIT/ROLLBACK
* stop the application
* use EXECUTE SCRIPT to pass the script on all nodes

```
slonik <<_EOF_
cluster name = $CLUSTERNAME;

 node 1 admin conninfo = 'host=$MASTERHOST port=$MASTERPORT dbname=$MASTERDBNAME user=$REPLICATIONUSER';
 node 2 admin conninfo = 'host=$SLAVEHOST port=$SLAVEPORT dbname=$SLAVEDBNAME user=$REPLICATIONUSER';

  execute script (
    filename = 'changes.ddl',
    event node = 1
  );
_EOF_
```

## Add a node

* Create a table and add the schema
* Add the node
* Create the path between the node and the origin (back and forth)
* Subscribe the node to the relevant sets

The perl tools to use are :

```
slonik_add_node --config <config> <new node> <event node>
slonik_subscribe_set --config <config> <set name> <node>
```

To add the node the slonik script has to store the node and add the paths :

```
# ADD NODE
cluster name = slon_pg95_pg12;
 node 1 admin conninfo='host=10.20.60.50 dbname=pgbench user=slony port=5432';
 node 2 admin conninfo='host=10.20.60.51 dbname=pgbench user=slony port=5432';
  try {
     store node (id = 1, event node = 2, comment = 'Node 1 - pgbench@10.20.60.50');
  } on error {
      echo 'Failed to add node  to cluster';
      exit 1;
  }

# STORE PATHS
  store path (server = 1, client = 2, conninfo = 'host=10.20.60.50 dbname=pgbench user=slony port=5432');
  store path (server = 2, client = 1, conninfo = 'host=10.20.60.51 dbname=pgbench user=slony port=5432');
  echo 'added node 1 to cluster';
  echo 'Please start a slon replication daemon for node 1';
```

After that, it is necessary to subscribe to the set on the new node.

BUG ?
* slonik_failover node1 => node2
* slonik_drop_node node1
* slonik_add_node node1
* slonik_subscribe_set seta_all node1 (the slonik script's provider was still 1)

## Add a cascaded node

* Create a table and add the schema
* Add the node
* Create the path between the new node and it's provider
* Subscribe the node to the relevant sets with the new provider (different from
  origin)
* wait for event

## Remove a replication node

Two ways depending on what you want :

* drop node : removes the slony schema and tell the other nodes that the node
  is gone
* uninstall node : removes the slony schema from the node

Commands :

* `slonik_drop_node`
* `slonik_uninstall_nodes`

Perl tools to drop a node :

```
slonik_drop_node --config <path_to_config> <node> <origin>
```

Slonik script to drop the node 2:

```
slonik <<_EOF_
cluster name = $CLUSTERNAME;
 node 1 admin conninfo = 'host=$MASTERHOST port=$MASTERPORT dbname=$MASTERDBNAME user=$REPLICATIONUSER';
 node 2 admin conninfo = 'host=$SLAVEHOST port=$SLAVEPORT dbname=$SLAVEDBNAME user=$REPLICATIONUSER';

  drop node (id = 2, event node = 1);
_EOF_
```

Perl tools to uninstall all node (cannot target one):

```
slonik_uninstall_nodes --config <path_to_config>
```

Slonik script to uninstall the node 1 :

```
slonik <<_EOF_
cluster name = $CLUSTERNAME;
 node 1 admin conninfo = 'host=$MASTERHOST port=$MASTERPORT dbname=$MASTERDBNAME user=$REPLICATIONUSER';
 node 2 admin conninfo = 'host=$SLAVEHOST port=$SLAVEPORT dbname=$SLAVEDBNAME user=$REPLICATIONUSER';

  uninstall node (id = 1);
_EOF_
```

## Change a subscription source

* use resubscribe

## Switchover

* Choose a valid replica : it has to be connected to the origin
* Stop the application to avoid deadlocks
* Perform the following slony actions
  * Lock the set
  * Sync it
  * Wait for event
  * Move the set

Command:

```
slonik_move_set --config <path_to_config> <set> <origin> <backup>
```

Slonik script to move set 1 from node 1 to node 2:

```
slonik <<_EOF_
cluster name = $CLUSTERNAME;

 node 1 admin conninfo = 'host=$MASTERHOST port=$MASTERPORT dbname=$MASTERDBNAME user=$REPLICATIONUSER';
 node 2 admin conninfo = 'host=$SLAVEHOST port=$SLAVEPORT dbname=$SLAVEDBNAME user=$REPLICATIONUSER';

  echo 'Locking down set 1 on node 1';
  lock set (id = 1, origin = 1);
  sync (id = 1);
  wait for event (origin = 1, confirmed = 2, wait on = 2);
  echo 'Locked down - moving it';
  move set (id = 1, old origin = 1, new origin = 2);
  echo 'Replication set 1 moved from node 1 to 2.  Remember to';
  echo 'update your configuration file, if necessary, to note the new location';
  echo 'for the set.';
_EOF_
```

It is better to modify the configuration is you dont plan to switch back
quickly. You can either edit the file or regenerate part of the configuration
with `slonik_build_env`.

There was a bug here for pg > 11
(https://github.com/ssinger/slony1-engine/issues/19) (FIXED)

Check post migration :

```
psql -h $MASTERHOST -p $MASTERPORT -d $MASTERDBNAME -U $REPLICATIONUSER << _EOF_
SET search_path TO _slon_pg95_pg12;
SELECT * FROM sl_node;
SELECT * FROM sl_set;
SELECT * FROM sl_subscribe;
SELECT * FROM sl_components;
\x
SELECT * FROM sl_status;
_EOF_
```

## Failover

* Stop the applications
* Use the failover command and feed it all the failed nodes and who will
  replace them.
* Re-connect the application to the new master node
* Drop the old nodes

Use perl tools to perform the operation :

```
slonik_failover --config <config> <dead node> <target>
slonik_drop_node --config <path_to_config> <node> <origin>
```

The slonik script for the failover is the following

```
cluster name = slon_pg95_pg12;
 node 1 admin conninfo='host=10.20.60.50 dbname=pgbench user=slony port=5432';
 node 2 admin conninfo='host=10.20.60.51 dbname=pgbench user=slony port=5432';
  try {
      failover (id = 1, backup node = 2);
  } on error {
      echo 'Failure to fail node 1 over to 2';
      exit 1;
  }
  echo 'Replication sets originating on 1 failed over to 2';
```

The slonik script for the failover is the following

```
cluster name = slon_pg95_pg12;
 node 1 admin conninfo='host=10.20.60.50 dbname=pgbench user=slony port=5432';
 node 2 admin conninfo='host=10.20.60.51 dbname=pgbench user=slony port=5432';
  drop node (id = 1, event node = 2);
  echo 'dropped node 1 cluster'
```

