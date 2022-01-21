#!/bin/sh

export LANG=C

test -z "$1" || export PGDATA=$1
test -d "$PGDATA" || \
{
    echo "La variable PGDATA doit être configurée ou sa valeur fournie en premier argument de ce script." 
    exit -1
}

test -z "$2" || export PGPORT=$2

which pg_controldata >/dev/null 2>&1 || \
{
    echo "which ne connaît pas pg_controldata. Merci de corriger la variable PATH."
    exit -1
}

which psql >/dev/null 2>&1 || \
{
    echo "psql non trouvé"
    exit 1
}

## PostgreSQL

echo "# PostgreSQL"
echo
echo "## Version des outils"
psql -V
pg_controldata -V
echo
echo "## Processus"
echo
PGPID=$(head -n1 "$PGDATA/postmaster.pid" 2>/dev/null)        
ps --forest -f --ppid $PGPID --pid $PGPID 
echo
echo "## Répertoire de données"
echo
echo "PGDATA $PGDATA"
echo
pg_controldata
echo
du -sh $PGDATA
echo
echo "## Orphaned Files"
psql $PSQL_OPTIONS -c "
WITH ver AS (
  select 
    current_setting('server_version_num') pgversion, 
    v :: integer / 10000 || '.' || mod(v :: integer, 10000)/ 100 AS version 
  FROM 
    current_setting('server_version_num') v
), 
tbl_paths AS (
  SELECT 
    tbs.oid AS tbs_oid,
    spcname, 
    'pg_tblspc/' || tbs.oid || '/' || (
      SELECT 
        dir 
      FROM 
        pg_ls_dir(
          'pg_tblspc/' || tbs.oid || '/', true, 
          false
        ) dir 
      WHERE 
        dir LIKE E'PG\\_' || ver.version || E'\\_%'
    ) as tbl_path 
  FROM 
    pg_tablespace tbs, 
    ver 
  WHERE 
    tbs.spcname NOT IN ('pg_default', 'pg_global')
), 
files AS (
  SELECT 
    d.oid AS database_oid, 
    0 AS tbs_oid, 
    'base/' || d.oid AS path, 
    file_name AS file_name, 
    substring(
      file_name 
      from 
        E'[0-9]+'
    ) AS base_name 
  FROM 
    pg_database d, 
    pg_ls_dir('base/' || d.oid, true, false) AS file_name 
  WHERE 
    d.datname = current_database() 
  UNION ALL 
  SELECT 
    d.oid, 
    tbp.tbs_oid, 
    tbl_path || '/' || d.oid, 
    file_name, 
    (
      substring(
        file_name 
        from 
          E'[0-9]+'
      )
    ) AS base_name 
  FROM 
    pg_database d, 
    tbl_paths tbp, 
    pg_ls_dir(
      tbp.tbl_path || '/' || d.oid, true, false
    ) AS file_name 
  WHERE 
    d.datname = current_database()
), 
orphans AS (
  SELECT 
    tbs_oid, 
    base_name, 
    file_name, 
    current_setting('data_directory')|| '/' || path || '/' || file_name as orphaned_file, 
    pg_filenode_relation (tbs_oid, base_name :: oid) as rel_without_pgclass 
  FROM 
    ver, 
    files 
    LEFT JOIN pg_class c ON (
      c.relfilenode :: text = files.base_name 
      OR (
        c.oid :: text = files.base_name 
        and c.relfilenode = 0 
        and c.relname like 'pg_%'
      )
    ) 
  WHERE 
    c.oid IS null 
    AND lower(file_name) NOT LIKE 'pg_%'
) 
SELECT 
  orphaned_file, 
  pg_size_pretty(
    (
      pg_stat_file(orphaned_file)
    ).size
  ) as file_size, 
  (
    pg_stat_file(orphaned_file)
  ).modification as modification_date, 
  current_database() 
FROM 
  orphans 
WHERE 
  rel_without_pgclass IS NULL;"
echo
echo "## Configuration"
echo
echo "### ... du moteur"
echo
if [[ -f "$PGDATA/postgresql.conf" ]]; then
	echo "#### $PGDATA/postgresql.conf"
	cat $PGDATA/postgresql.conf
else
	CONFFILE=$(psql -XtAc "SELECT setting FROM pg_settings WHERE name = 'config_file';")
	if [[ -f "$CONFFILE" ]]; then
		echo "#### $CONFFILE"
		cat $CONFFILE
	else
		echo "WARNING: postgresql.conf not found"
	fi
fi
echo
cat $PGDATA/postgresql.auto.conf
echo
echo "### ... des accès"
echo
if [[ -f "$PGDATA/pg_hba.conf" ]]; then
	echo "#### $PGDATA/pg_hba.conf"
	cat $PGDATA/pg_hba.conf
else
	HBAFILE=$(psql -XtAc "SELECT setting FROM pg_settings WHERE name = 'hba_file';")
	if [[ -f "$HBAFILE" ]]; then
		echo "#### $HBAFILE"
		cat $HBAFILE
	else
		echo "WARNING: pg_hba not found"
	fi
fi
echo
if [[ -f "$PGDATA/pg_ident.conf" ]]; then
	echo "#### $PGDATA/pg_ident.conf"
	cat $PGDATA/pg_ident.conf
else
	IDENTFILE=$(psql -XtAc "SELECT setting FROM pg_settings WHERE name = 'ident_file';")
	if [[ -f "$IDENTFILE" ]]; then
		echo "#### $IDENTFILE"
		cat $IDENTFILE
	else
		echo "WARNING: pg_ident not found"
	fi
fi
echo
echo "### ... de la restauration"
echo
test -f $PGDATA/recovery.conf && cat $PGDATA/recovery.conf || echo "WARNING: recovery.conf not found"
echo
echo "## Journaux de transactions"
echo
test -d $PGDATA/pg_xlog && ls -l $PGDATA/pg_xlog/0* | wc -l
test -d $PGDATA/pg_wal  && ls -l $PGDATA/pg_wal/0*  | wc -l
echo
LOGGING_COLLECTOR=$(psql -XtAc "SELECT setting FROM pg_settings WHERE name LIKE 'logging_collector'")
LOG_DIRECTORY=""
if [[ "${LOGGING_COLLECTOR}" == "on" ]]; then
	LOG_DIRECTORY=$(psql -XtAc "SELECT setting FROM pg_settings WHERE name LIKE 'log_directory'")
	if [[ "${LOG_DIRECTORY:0:1}" == "/" ]]; then
		LOG_DIRECTORY="$PGDATA/$LOG_DIRECTORY"
	fi
else
	[[ -d "/var/log/postgresql" ]] || LOG_DIRECTORY="/var/log/postgresql"
	[[ -d "/var/log/pgsql" ]] || LOG_DIRECTORY="/var/log/pgsql"
fi

if [[ ! -z "$LOG_DIRECTORY" ]]; then
	echo "## Traces et erreurs ($LOG_DIRECTORY)"
	ls -al $LOG_DIRECTORY/*.log
	echo
	echo "### PANIC"
	grep "PANIC:" $LOG_DIRECTORY/*.log | sed -e "s/^.* PANIC: \(.*\)$/\1/gI" | sort | uniq -c | sort -r
	echo
	echo "### FATAL"
	grep "FATAL:" $LOG_DIRECTORY/*.log | sed -e "s/^.* FATAL: \(.*\)$/\1/gI" | sort | uniq -c | sort -r
	echo
	echo "### ERROR"
	grep "ERROR:" $LOG_DIRECTORY/*.log | sed -e "s/^.* ERROR: \(.*\)$/\1/gI" | sort | uniq -c | sort -r
else
	echo "## Traces et erreurs (NOT FOUND)"
fi
echo
echo "## Crontab $USER"
echo
crontab -l 2>&1
echo

echo "## Au niveau SQL"
echo

PSQL_OPTIONS="-P pager=off -X"

echo "### version"
psql $PSQL_OPTIONS -c "select version();"
VERSION=$(psql -XtAc "SELECT LEFT(setting, -2) FROM pg_settings WHERE name = 'server_version_num';")

echo "### start time"
psql $PSQL_OPTIONS -c "select pg_postmaster_start_time();"

echo "### configuration sources"
psql $PSQL_OPTIONS -c "select source, sourcefile, count(*)
from pg_settings
group by 1, 2;"

echo "### non default configuration"
psql $PSQL_OPTIONS -c "select source, name, setting, unit
from pg_settings
where source not in ('configuration file', 'default')
order by source, name;"

echo "### Database list"
psql $PSQL_OPTIONS -c "SELECT d.datname as \"Name\",
       pg_catalog.pg_get_userbyid(d.datdba) as \"Owner\",
       pg_catalog.pg_encoding_to_char(d.encoding) as \"Encoding\",
       d.datcollate as \"Collate\",
       d.datctype as \"Ctype\",
       pg_catalog.array_to_string(d.datacl, E'\n') AS \"Access privileges\",
       CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT')
            THEN pg_catalog.pg_size_pretty(pg_catalog.pg_database_size(d.datname))
            ELSE 'No Access'
       END as \"Size\",
       t.spcname as \"Tablespace\",
       pg_catalog.shobj_description(d.oid, 'pg_database') as \"Description\"
FROM pg_catalog.pg_database d
  JOIN pg_catalog.pg_tablespace t on d.dattablespace = t.oid
ORDER BY 1;"

#psql $PSQL_OPTIONS -c "create extension if not exists pg_buffercache;
#select case when datname is null then '<vide>' else datname end as datname,
#       pg_size_pretty(count(*)*8192)
#from pg_buffercache bc
#left join pg_database d on d.oid=bc.reldatabase
#group by 1
#order by count(*) desc;"

echo "### Tablespaces"
psql $PSQL_OPTIONS -c "SELECT spcname AS \"Name\",
  pg_catalog.pg_get_userbyid(spcowner) AS \"Owner\",
  pg_catalog.pg_tablespace_location(oid) AS \"Location\",
  pg_size_pretty(pg_tablespace_size(oid)) AS \"Size\",
  pg_catalog.array_to_string(spcacl, E'\n') AS \"Access privileges\",
  spcoptions AS \"Options\",
  pg_catalog.shobj_description(oid, 'pg_tablespace') AS \"Description\"
FROM pg_catalog.pg_tablespace
ORDER BY 1;"

echo "### users & roles"
psql $PSQL_OPTIONS -c "SELECT r.rolname, r.rolsuper, r.rolinherit,
  r.rolcreaterole, r.rolcreatedb, r.rolcanlogin,
  r.rolconnlimit, r.rolvaliduntil,
  ARRAY(SELECT b.rolname
        FROM pg_catalog.pg_auth_members m
        JOIN pg_catalog.pg_roles b ON (m.roleid = b.oid)
        WHERE m.member = r.oid) as memberof
, r.rolreplication
, r.rolbypassrls
FROM pg_catalog.pg_roles r
WHERE r.rolname !~ '^pg_'
ORDER BY 1;"

echo "### specific user and database config"
psql $PSQL_OPTIONS -c "select datname, rolname, setconfig
from pg_db_role_setting drs
left join pg_database d on d.oid=drs.setdatabase
left join pg_roles r on r.oid=drs.setrole;"

echo "## pg_file_settings"
psql $PSQL_OPTIONS -c "select * from pg_file_settings ;"

echo "## pg_hba_file_rules"
psql $PSQL_OPTIONS -c "select * from pg_hba_file_rules;"

echo "## pg_publication"
psql $PSQL_OPTIONS -c "select * from pg_publication;"

echo "## pg_replication_slots"
psql $PSQL_OPTIONS -c "select * from pg_replication_slots;"

echo "## pg_subscription"
psql $PSQL_OPTIONS -c "select * from pg_subscription;"

echo "## pg_settings"
psql $PSQL_OPTIONS -c "select * from pg_settings;"

for d in $(psql -XAtc "SELECT datname 
    FROM pg_database 
    WHERE datname NOT IN ('template0','template1') 
    ORDER BY 1")
do
    export PGDATABASE=$d
    ALLOWCONN=$(psql -XAtc "SELECT datallowconn FROM pg_database WHERE datname = '$d'" -d postgres)

    if [[ "$ALLOWCONN" != "t" ]]; then 
	echo
	echo "# Audit Database $d (connection not allowed)"
	continue
    fi

echo "# Database $PGDATABASE"

echo "## Database info"
psql $PSQL_OPTIONS <<EOF
SELECT d.datname as "Name",
       pg_catalog.pg_get_userbyid(d.datdba) as "Owner",
       pg_catalog.pg_encoding_to_char(d.encoding) as "Encoding",
       d.datcollate as "Collate",
       d.datctype as "Ctype",
       pg_catalog.array_to_string(d.datacl, E'\n') AS "Access privileges",
       CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT')
            THEN pg_catalog.pg_size_pretty(pg_catalog.pg_database_size(d.datname))
            ELSE 'No Access'
       END as "Size",
       t.spcname as "Tablespace",
       pg_catalog.shobj_description(d.oid, 'pg_database') as "Description"
  FROM pg_catalog.pg_database d
  JOIN pg_catalog.pg_tablespace t on d.dattablespace = t.oid
 WHERE d.datname = '$PGDATABASE'
EOF

echo "### Database cache hit ratio"
psql $PSQL_OPTIONS <<EOF
\x
SELECT datname, 
       blks_hit, 
       blks_read, 
       CASE 
          WHEN (blks_read+blks_hit) > 0 
	  THEN 100 * blks_hit / (blks_read+blks_hit) 
	  ELSE 0 
       END AS hit_ratio
FROM pg_catalog.pg_stat_database
WHERE datname = '$PGDATABASE';
EOF

echo "### Database commit ratio"
psql $PSQL_OPTIONS <<EOF
\x
SELECT datname, 
       xact_commit, 
       xact_rollback, 
       100 * xact_commit / (xact_commit + xact_rollback) as commit_ratio
  FROM pg_stat_database 
 WHERE (xact_commit + xact_rollback) > 0
   AND datname = '$PGDATABASE';
EOF

echo "### Database temp stats"
psql $PSQL_OPTIONS <<EOF
\x
SELECT datname,
       temp_files, 
       pg_size_pretty(temp_bytes) as temp_file_size, 
       pg_size_pretty(case when temp_files = 0 then 0 else temp_bytes/temp_files end) as average_temp_file_size,
       pg_size_pretty( trunc(temp_bytes / case when date_part('day', current_timestamp - stats_reset) = 0 then 1 else date_part('day', current_timestamp - stats_reset) end)::numeric) as average_temp_size_per_day,
       temp_files / case when date_part('day', current_timestamp - stats_reset) = 0 then 1 else date_part('day', current_timestamp - stats_reset) end as average_temp_files_per_day,
       stats_reset
FROM pg_stat_database
WHERE datname = '$PGDATABASE';
EOF

echo "### Database Misc stats"
psql $PSQL_OPTIONS <<EOF
\x
SELECT datname,
       temp_files, 
       pg_size_pretty(temp_bytes), 
       stats_reset, 
       conflicts, 
       deadlocks,
       numbackends
FROM pg_stat_database
WHERE datname = '$PGDATABASE';
EOF

echo "## Schemas"
psql $PSQL_OPTIONS <<EOF
SELECT n.nspname AS "Name",
       pg_catalog.pg_get_userbyid(n.nspowner) AS "Owner"
  FROM pg_catalog.pg_namespace n
 WHERE n.nspname !~ '^pg_' AND n.nspname <> 'information_schema'
 ORDER BY 1;
EOF

echo "### objects per namespace"
psql $PSQL_OPTIONS <<EOF
SELECT nspname, 
       rolname,
       count(*) filter (WHERE relkind='r') as tables,
       count(*) filter (WHERE relkind='i') as index,
       count(*) filter (WHERE relkind='s') as sequences
  FROM pg_namespace n
  JOIN pg_roles r ON r.oid=n.nspowner
  LEFT JOIN pg_class c ON n.oid=c.relnamespace
GROUP BY nspname, rolname
ORDER BY 1, 2;
EOF

echo "### function and procedures per namespace"
if [[ "$VERSION" -ge "1100" ]]; then
psql $PSQL_OPTIONS <<EOF
SELECT nspname, 
       rolname,
       count(*) filter (WHERE prokind='f') as functions,
       count(*) filter (WHERE prokind='p') as procedures,
       count(*) filter (WHERE prokind='a') as aggregates,
       count(*) filter (WHERE prokind='w') as window
  FROM pg_namespace n
  JOIN pg_roles r on r.oid=n.nspowner
  LEFT JOIN pg_proc p on n.oid=p.pronamespace
 GROUP BY nspname, rolname
  ORDER BY 1, 2;
EOF
else
psql $PSQL_OPTIONS <<EOF
select nspname, 
       rolname,
       count(*) filter (where not proisagg and not proiswindow) as functions,
       count(*) filter (where proisagg) as aggregates,
       count(*) filter (where proiswindow) as window
  from pg_namespace n
  join pg_roles r on r.oid=n.nspowner
  left join pg_proc p on n.oid=p.pronamespace
 group by nspname, rolname
 order by 1, 2;
EOF
fi

echo "## List of extensions"
psql $PSQL_OPTIONS <<EOF
SELECT e.extname AS "Name", 
       e.extversion AS "Version", 
       n.nspname AS "Schema", 
       c.description AS "Description"
  FROM pg_catalog.pg_extension e 
  LEFT JOIN pg_catalog.pg_namespace n 
    ON n.oid = e.extnamespace 
  LEFT JOIN pg_catalog.pg_description c 
    ON c.objoid = e.oid 
   AND c.classoid = 'pg_catalog.pg_extension'::pg_catalog.regclass
ORDER BY 1;
EOF

echo "## relations"
echo "### relking size and count"
psql $PSQL_OPTIONS <<EOF
SELECT CASE relkind
          WHEN 'r' THEN 'ordinary table'
          WHEN 'i' THEN 'index'
          WHEN 'S' THEN 'sequence'
          WHEN 't' THEN 'TOAST table'
          WHEN 'v' THEN 'view'
          WHEN 'm' THEN 'materialized view'
          WHEN 'c' THEN 'composite type'
          WHEN 'f' THEN 'foreign table'
          WHEN 'p' THEN 'partitioned table'
          WHEN 'I' THEN 'partitioned index'
	  ELSE relkind::text
      END,  
      count(*), 
      pg_size_pretty(sum(pg_table_size(oid)))
 FROM pg_class
GROUP BY 1;
EOF

echo "### relation depending on an extension"
psql $PSQL_OPTIONS <<EOF
with etypes as
 (
  SELECT classid::regclass,
         objid,
         deptype,
         e.extname
    FROM pg_depend
         JOIN pg_extension e
           on refclassid = 'pg_extension'::regclass
          and refobjid = e.oid
  WHERE classid = 'pg_type'::regclass
 )
 SELECT etypes.extname,
        etypes.objid::regtype as type,
        n.nspname as schema,
        c.relname as table,
        attname as column

  FROM pg_depend
  
       JOIN etypes
         on etypes.classid = pg_depend.refclassid
        and etypes.objid = pg_depend.refobjid
        
       JOIN pg_class c on c.oid = pg_depend.objid
       
       JOIN pg_namespace n on n.oid = c.relnamespace
       
       JOIN pg_attribute attr
         on attr.attrelid = pg_depend.objid
        and attr.attnum = pg_depend.objsubid
 WHERE pg_depend.classid = 'pg_class'::regclass;
EOF

#psql $PSQL_OPTIONS -c "create extension if not exists pg_buffercache;
#SELECT relkind,
#       pg_size_pretty(count(*)*8192)
#FROM pg_buffercache bc
#LEFT JOIN pg_class c on c.relfilenode=bc.relfilenode
#GROUP BY 1
#ORDER BY count(*) desc;"


echo "### size per am type"
psql $PSQL_OPTIONS <<EOF
SELECT amname, 
       count(*), 
       pg_size_pretty(sum(pg_table_size(c.oid)))
  FROM pg_class c
  JOIN pg_am a 
    ON a.oid=c.relam
GROUP BY 1;
EOF

echo "### Large object count"
psql $PSQL_OPTIONS <<EOF
SELECT count(*) 
  FROM pg_largeobject;
EOF

echo "### Large object relpage"
psql $PSQL_OPTIONS <<EOF
SELECT reltuples AS "tuple count", 
       relpages AS "page count", 
       pg_size_pretty(pg_total_relation_size('pg_catalog.pg_largeobject')) AS "relation size"
  FROM pg_class
 WHERE relname = 'pg_largeobject';
EOF

echo "### relation with custom options"
psql $PSQL_OPTIONS <<EOF
SELECT nspname, 
       CASE relkind
          WHEN 'r' THEN 'ordinary table'
          WHEN 'i' THEN 'index'
          WHEN 'S' THEN 'sequence'
          WHEN 't' THEN 'TOAST table'
          WHEN 'v' THEN 'view'
          WHEN 'm' THEN 'materialized view'
          WHEN 'c' THEN 'composite type'
          WHEN 'f' THEN 'foreign table'
          WHEN 'p' THEN 'partitioned table'
          WHEN 'I' THEN 'partitioned index'
          ELSE relkind::text
       END, relname, reloptions
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid=c.relnamespace
 WHERE reloptions IS NOT NULL
 ORDER BY 1, 3, 2;
EOF

echo "## relation needing freezing"
psql $PSQL_OPTIONS <<EOF
SELECT count(*)
  FROM pg_class
 WHERE relkind='r'
   AND age(relfrozenxid) > current_setting('autovacuum_freeze_max_age')::integer;
EOF

echo "## table bloat size"
psql $PSQL_OPTIONS <<EOF
/* WARNING: executed with a non-superuser role, the query inspect only tables and materialized view (9.3+) you are granted to read.
* This query is compatible with PostgreSQL 9.0 and more
*/

SELECT current_database(), 
       pg_size_pretty(sum(real_size)::bigint) AS "total size", 
       pg_size_pretty(sum(bloat_size)::bigint) AS "total bloat", 
       avg(bloat_ratio) AS "avg bloat ratio"  
FROM (

SELECT current_database(), schemaname, tblname, bs*tblpages AS real_size,
  (tblpages-est_tblpages)*bs AS extra_size,
  CASE WHEN tblpages - est_tblpages > 0
    THEN 100 * (tblpages - est_tblpages)/tblpages::float
    ELSE 0
  END AS extra_ratio, fillfactor,
  CASE WHEN tblpages - est_tblpages_ff > 0
    THEN (tblpages-est_tblpages_ff)*bs
    ELSE 0
  END AS bloat_size,
  CASE WHEN tblpages - est_tblpages_ff > 0
    THEN 100 * (tblpages - est_tblpages_ff)/tblpages::float
    ELSE 0
  END AS bloat_ratio, is_na
  -- , tpl_hdr_size, tpl_data_size, (pst).free_percent + (pst).dead_tuple_percent AS real_frag -- (DEBUG INFO)
FROM (
  SELECT ceil( reltuples / ( (bs-page_hdr)/tpl_size ) ) + ceil( toasttuples / 4 ) AS est_tblpages,
    ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil( toasttuples / 4 ) AS est_tblpages_ff,
    tblpages, fillfactor, bs, tblid, schemaname, tblname, heappages, toastpages, is_na
    -- , tpl_hdr_size, tpl_data_size, pgstattuple(tblid) AS pst -- (DEBUG INFO)
  FROM (
    SELECT
      ( 4 + tpl_hdr_size + tpl_data_size + (2*ma)
        - CASE WHEN tpl_hdr_size%ma = 0 THEN ma ELSE tpl_hdr_size%ma END
        - CASE WHEN ceil(tpl_data_size)::int%ma = 0 THEN ma ELSE ceil(tpl_data_size)::int%ma END
      ) AS tpl_size, bs - page_hdr AS size_per_block, (heappages + toastpages) AS tblpages, heappages,
      toastpages, reltuples, toasttuples, bs, page_hdr, tblid, schemaname, tblname, fillfactor, is_na
      -- , tpl_hdr_size, tpl_data_size
    FROM (
      SELECT
        tbl.oid AS tblid, ns.nspname AS schemaname, tbl.relname AS tblname, tbl.reltuples,
        tbl.relpages AS heappages, coalesce(toast.relpages, 0) AS toastpages,
        coalesce(toast.reltuples, 0) AS toasttuples,
        coalesce(substring(
          array_to_string(tbl.reloptions, ' ')
          FROM 'fillfactor=([0-9]+)')::smallint, 100) AS fillfactor,
        current_setting('block_size')::numeric AS bs,
        CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma,
        24 AS page_hdr,
        23 + CASE WHEN MAX(coalesce(s.null_frac,0)) > 0 THEN ( 7 + count(s.attname) ) / 8 ELSE 0::int END
           + CASE WHEN bool_or(att.attname = 'oid' and att.attnum < 0) THEN 4 ELSE 0 END AS tpl_hdr_size,
        sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0) ) AS tpl_data_size,
        bool_or(att.atttypid = 'pg_catalog.name'::regtype)
          OR sum(CASE WHEN att.attnum > 0 THEN 1 ELSE 0 END) <> count(s.attname) AS is_na
      FROM pg_attribute AS att
        JOIN pg_class AS tbl ON att.attrelid = tbl.oid
        JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
        LEFT JOIN pg_stats AS s ON s.schemaname=ns.nspname
          AND s.tablename = tbl.relname AND s.inherited=false AND s.attname=att.attname
        LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
      WHERE NOT att.attisdropped
        AND tbl.relkind in ('r','m')
      GROUP BY 1,2,3,4,5,6,7,8,9,10
      ORDER BY 2,3
    ) AS s
  ) AS s2
) AS s3
-- WHERE NOT is_na
--   AND tblpages*((pst).free_percent + (pst).dead_tuple_percent)::float4/100 >= 1
ORDER BY schemaname, tblname

) AS rqt 
GROUP BY 1;

EOF

echo "## table bloat details"
psql $PSQL_OPTIONS <<EOF
/* WARNING: executed with a non-superuser role, the query inspect only tables you are granted to read.
* This query is compatible with PostgreSQL 9.0 and more
*/
SELECT * FROM (

SELECT current_database(), schemaname, tblname, bs*tblpages AS real_size,
  (tblpages-est_tblpages)*bs AS extra_size,
  CASE WHEN tblpages - est_tblpages > 0
    THEN 100 * (tblpages - est_tblpages)/tblpages::float
    ELSE 0
  END AS extra_ratio, fillfactor,
  CASE WHEN tblpages - est_tblpages_ff > 0
    THEN (tblpages-est_tblpages_ff)*bs
    ELSE 0
  END AS bloat_size,
  CASE WHEN tblpages - est_tblpages_ff > 0
    THEN 100 * (tblpages - est_tblpages_ff)/tblpages::float
    ELSE 0
  END AS bloat_ratio, is_na
  -- , tpl_hdr_size, tpl_data_size, (pst).free_percent + (pst).dead_tuple_percent AS real_frag -- (DEBUG INFO)
FROM (
  SELECT ceil( reltuples / ( (bs-page_hdr)/tpl_size ) ) + ceil( toasttuples / 4 ) AS est_tblpages,
    ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil( toasttuples / 4 ) AS est_tblpages_ff,
    tblpages, fillfactor, bs, tblid, schemaname, tblname, heappages, toastpages, is_na
    -- , tpl_hdr_size, tpl_data_size, pgstattuple(tblid) AS pst -- (DEBUG INFO)
  FROM (
    SELECT
      ( 4 + tpl_hdr_size + tpl_data_size + (2*ma)
        - CASE WHEN tpl_hdr_size%ma = 0 THEN ma ELSE tpl_hdr_size%ma END
        - CASE WHEN ceil(tpl_data_size)::int%ma = 0 THEN ma ELSE ceil(tpl_data_size)::int%ma END
      ) AS tpl_size, bs - page_hdr AS size_per_block, (heappages + toastpages) AS tblpages, heappages,
      toastpages, reltuples, toasttuples, bs, page_hdr, tblid, schemaname, tblname, fillfactor, is_na
      -- , tpl_hdr_size, tpl_data_size
    FROM (
      SELECT
        tbl.oid AS tblid, ns.nspname AS schemaname, tbl.relname AS tblname, tbl.reltuples,
        tbl.relpages AS heappages, coalesce(toast.relpages, 0) AS toastpages,
        coalesce(toast.reltuples, 0) AS toasttuples,
        coalesce(substring(
          array_to_string(tbl.reloptions, ' ')
          FROM 'fillfactor=([0-9]+)')::smallint, 100) AS fillfactor,
        current_setting('block_size')::numeric AS bs,
        CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma,
        24 AS page_hdr,
        23 + CASE WHEN MAX(coalesce(s.null_frac,0)) > 0 THEN ( 7 + count(s.attname) ) / 8 ELSE 0::int END
           + CASE WHEN bool_or(att.attname = 'oid' and att.attnum < 0) THEN 4 ELSE 0 END AS tpl_hdr_size,
        sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0) ) AS tpl_data_size,
        bool_or(att.atttypid = 'pg_catalog.name'::regtype)
          OR sum(CASE WHEN att.attnum > 0 THEN 1 ELSE 0 END) <> count(s.attname) AS is_na
      FROM pg_attribute AS att
        JOIN pg_class AS tbl ON att.attrelid = tbl.oid
        JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
        LEFT JOIN pg_stats AS s ON s.schemaname=ns.nspname
          AND s.tablename = tbl.relname AND s.inherited=false AND s.attname=att.attname
        LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
      WHERE NOT att.attisdropped
        AND tbl.relkind in ('r','m')
      GROUP BY 1,2,3,4,5,6,7,8,9,10
      ORDER BY 2,3
    ) AS s
  ) AS s2
) AS s3
-- WHERE NOT is_na
--   AND tblpages*((pst).free_percent + (pst).dead_tuple_percent)::float4/100 >= 1
ORDER BY schemaname, tblname

 ) as plop order by 9 desc;
EOF

echo "### table access stats"
psql $PSQL_OPTIONS <<EOF
SELECT relname,
       CASE WHEN (seq_scan + idx_scan) = 0 THEN 0 ELSE trunc(100. * seq_scan / (seq_scan + idx_scan), 2) END AS pct_seq_scan,
       CASE WHEN (seq_scan + idx_scan) = 0 THEN 0 ELSE trunc(100. * idx_scan / (seq_scan + idx_scan), 2) END AS pct_idx_scan,
       CASE WHEN seq_scan = 0 THEN 0 ELSE trunc(seq_tup_read / seq_scan, 2) END AS avg_live_row_per_seq_scan,
       CASE WHEN idx_scan = 0 THEN 0 ELSE trunc(idx_tup_fetch / idx_scan, 2) END AS avg_live_row_per_idx_scan,
       seq_scan,
       seq_tup_read,
       idx_scan,
       idx_tup_fetch
  FROM pg_stat_user_tables
 ORDER BY seq_scan + idx_scan DESC
;
EOF

echo "### table operations"
psql $PSQL_OPTIONS <<EOF
SELECT relname,
       CASE WHEN (n_tup_ins + n_tup_upd + n_tup_del) = 0 THEN 0 ELSE trunc(100. * n_tup_ins / (n_tup_ins + n_tup_upd + n_tup_del), 2) END AS pct_insert ,
       CASE WHEN (n_tup_ins + n_tup_upd + n_tup_del) = 0 THEN 0 ELSE trunc(100. * n_tup_upd / (n_tup_ins + n_tup_upd + n_tup_del), 2) END AS pct_update,
       CASE WHEN (n_tup_ins + n_tup_upd + n_tup_del) = 0 THEN 0 ELSE trunc(100. * n_tup_del / (n_tup_ins + n_tup_upd + n_tup_del), 2) END AS pct_delete,
       CASE WHEN n_tup_upd = 0 THEN 0 ELSE  trunc(100. * n_tup_hot_upd / n_tup_upd, 2) END AS pct_hot,
       n_tup_ins,
       n_tup_upd,
       n_tup_del
FROM pg_stat_user_tables
;

EOF

echo "### table cleanup"
psql $PSQL_OPTIONS <<EOF
SELECT relname,
       CASE WHEN n_live_tup = 0 THEN 0 ELSE  trunc(100. * n_live_tup / (n_live_tup + n_dead_tup), 2) END AS pct_alive,
       CASE WHEN n_live_tup = 0 THEN 0 ELSE  trunc(100. * n_dead_tup / (n_live_tup + n_dead_tup), 2) END AS pct_dead,
       n_live_tup,
       n_dead_tup
       autovacuum_count,
       vacuum_count,
       autoanalyze_count,
       analyze_count
FROM pg_stat_user_tables
;
EOF

echo "## indexes"
echo "### index options"
psql $PSQL_OPTIONS <<EOF
SELECT 
       count(*) as total,
       count(*) FILTER (WHERE not indisunique AND not indisprimary) as standard,
       count(*) FILTER (WHERE indisunique AND not indisprimary) as unique,
       count(*) FILTER (WHERE indisprimary) as primary,
       count(*) FILTER (WHERE indisexclusion) as exclusion,
       count(*) FILTER (WHERE indisclustered) as clustered,
       count(*) FILTER (WHERE indisvalid) as valid
FROM pg_index i
JOIN pg_class c ON c.oid=i.indexrelid;
EOF

echo "### btree index bloat"
psql $PSQL_OPTIONS <<EOF
-- This query must be exected by a superuser because it relies on the
-- pg_statistic table.
-- This query run much faster than btree_bloat.sql, about 1000x faster.
--
-- This query is compatible with PostgreSQL 8.2 and after.
SELECT current_database(), 
       pg_size_pretty(sum(real_size)::bigint) AS "total size", 
       pg_size_pretty(sum(bloat_size)::bigint) AS "total bloat", 
       avg(bloat_ratio) AS "avg bloat ratio"  
FROM (

SELECT current_database(), nspname AS schemaname, tblname, idxname, bs*(relpages)::bigint AS real_size,
  bs*(relpages-est_pages)::bigint AS extra_size,
  100 * (relpages-est_pages)::float / relpages AS extra_ratio,
  fillfactor,
  CASE WHEN relpages > est_pages_ff
    THEN bs*(relpages-est_pages_ff)
    ELSE 0
  END AS bloat_size,
  100 * (relpages-est_pages_ff)::float / relpages AS bloat_ratio,
  is_na
  -- , 100-(pst).avg_leaf_density AS pst_avg_bloat, est_pages, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, reltuples, relpages -- (DEBUG INFO)
FROM (
  SELECT coalesce(1 +
         ceil(reltuples/floor((bs-pageopqdata-pagehdr)/(4+nulldatahdrwidth)::float)), 0 -- ItemIdData size + computed avg size of a tuple (nulldatahdrwidth)
      ) AS est_pages,
      coalesce(1 +
         ceil(reltuples/floor((bs-pageopqdata-pagehdr)*fillfactor/(100*(4+nulldatahdrwidth)::float))), 0
      ) AS est_pages_ff,
      bs, nspname, tblname, idxname, relpages, fillfactor, is_na
      -- , pgstatindex(idxoid) AS pst, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, reltuples -- (DEBUG INFO)
  FROM (
      SELECT maxalign, bs, nspname, tblname, idxname, reltuples, relpages, idxoid, fillfactor,
            ( index_tuple_hdr_bm +
                maxalign - CASE -- Add padding to the index tuple header to align on MAXALIGN
                  WHEN index_tuple_hdr_bm%maxalign = 0 THEN maxalign
                  ELSE index_tuple_hdr_bm%maxalign
                END
              + nulldatawidth + maxalign - CASE -- Add padding to the data to align on MAXALIGN
                  WHEN nulldatawidth = 0 THEN 0
                  WHEN nulldatawidth::integer%maxalign = 0 THEN maxalign
                  ELSE nulldatawidth::integer%maxalign
                END
            )::numeric AS nulldatahdrwidth, pagehdr, pageopqdata, is_na
            -- , index_tuple_hdr_bm, nulldatawidth -- (DEBUG INFO)
      FROM (
          SELECT n.nspname, ct.relname AS tblname, i.idxname, i.reltuples, i.relpages,
              i.idxoid, i.fillfactor, current_setting('block_size')::numeric AS bs,
              CASE -- MAXALIGN: 4 on 32bits, 8 on 64bits (and mingw32 ?)
                WHEN version() ~ 'mingw32' OR version() ~ '64-bit|x86_64|ppc64|ia64|amd64' THEN 8
                ELSE 4
              END AS maxalign,
              /* per page header, fixed size: 20 for 7.X, 24 for others */
              24 AS pagehdr,
              /* per page btree opaque data */
              16 AS pageopqdata,
              /* per tuple header: add IndexAttributeBitMapData if some cols are null-able */
              CASE WHEN max(coalesce(s.stanullfrac,0)) = 0
                  THEN 2 -- IndexTupleData size
                  ELSE 2 + (( 32 + 8 - 1 ) / 8) -- IndexTupleData size + IndexAttributeBitMapData size ( max num filed per index + 8 - 1 /8)
              END AS index_tuple_hdr_bm,
              /* data len: we remove null values save space using it fractionnal part from stats */
              sum( (1-coalesce(s.stanullfrac, 0)) * coalesce(s.stawidth, 1024)) AS nulldatawidth,
              max( CASE WHEN a.atttypid = 'pg_catalog.name'::regtype THEN 1 ELSE 0 END ) > 0 AS is_na
          FROM (
              SELECT idxname, reltuples, relpages, tbloid, idxoid, fillfactor,
                  CASE WHEN indkey[i]=0 THEN idxoid ELSE tbloid END AS att_rel,
                  CASE WHEN indkey[i]=0 THEN i ELSE indkey[i] END AS att_pos
              FROM (
                  SELECT idxname, reltuples, relpages, tbloid, idxoid, fillfactor, indkey, generate_series(1,indnatts) AS i
                  FROM (
                      SELECT ci.relname AS idxname, ci.reltuples, ci.relpages, i.indrelid AS tbloid,
                          i.indexrelid AS idxoid,
                          coalesce(substring(
                              array_to_string(ci.reloptions, ' ')
                              from 'fillfactor=([0-9]+)')::smallint, 90) AS fillfactor,
                          i.indnatts,
                          string_to_array(textin(int2vectorout(i.indkey)),' ')::int[] AS indkey
                      FROM pg_index i
                      JOIN pg_class ci ON ci.oid=i.indexrelid
                      WHERE ci.relam=(SELECT oid FROM pg_am WHERE amname = 'btree')
                        AND ci.relpages > 0
                  ) AS idx_data
              ) AS idx_data_cross
          ) i
          JOIN pg_attribute a ON a.attrelid = i.att_rel
                             AND a.attnum = i.att_pos
          JOIN pg_statistic s ON s.starelid = i.att_rel
                             AND s.staattnum = i.att_pos
          JOIN pg_class ct ON ct.oid = i.tbloid
          JOIN pg_namespace n ON ct.relnamespace = n.oid
          GROUP BY 1,2,3,4,5,6,7,8,9,10
      ) AS rows_data_stats
  ) AS rows_hdr_pdg_stats
) AS relation_stats
ORDER BY nspname, tblname, idxname

) AS tbl 
GROUP BY 1;
EOF

echo "### btree index bloat details"
psql $PSQL_OPTIoNS <<EOF

-- This query must be exected by a superuser because it relies on the
-- pg_statistic table.
-- This query run much faster than btree_bloat.sql, about 1000x faster.
--
-- This query is compatible with PostgreSQL 8.2 and after.

SELECT * FROM (

SELECT current_database(), nspname AS schemaname, tblname, idxname, bs*(relpages)::bigint AS real_size,
  bs*(relpages-est_pages)::bigint AS extra_size,
  100 * (relpages-est_pages)::float / relpages AS extra_ratio,
  fillfactor,
  CASE WHEN relpages > est_pages_ff
    THEN bs*(relpages-est_pages_ff)
    ELSE 0
  END AS bloat_size,
  100 * (relpages-est_pages_ff)::float / relpages AS bloat_ratio,
  is_na
  -- , 100-(pst).avg_leaf_density AS pst_avg_bloat, est_pages, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, reltuples, relpages -- (DEBUG INFO)
FROM (
  SELECT coalesce(1 +
         ceil(reltuples/floor((bs-pageopqdata-pagehdr)/(4+nulldatahdrwidth)::float)), 0 -- ItemIdData size + computed avg size of a tuple (nulldatahdrwidth)
      ) AS est_pages,
      coalesce(1 +
         ceil(reltuples/floor((bs-pageopqdata-pagehdr)*fillfactor/(100*(4+nulldatahdrwidth)::float))), 0
      ) AS est_pages_ff,
      bs, nspname, tblname, idxname, relpages, fillfactor, is_na
      -- , pgstatindex(idxoid) AS pst, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, reltuples -- (DEBUG INFO)
  FROM (
      SELECT maxalign, bs, nspname, tblname, idxname, reltuples, relpages, idxoid, fillfactor,
            ( index_tuple_hdr_bm +
                maxalign - CASE -- Add padding to the index tuple header to align on MAXALIGN
                  WHEN index_tuple_hdr_bm%maxalign = 0 THEN maxalign
                  ELSE index_tuple_hdr_bm%maxalign
                END
              + nulldatawidth + maxalign - CASE -- Add padding to the data to align on MAXALIGN
                  WHEN nulldatawidth = 0 THEN 0
                  WHEN nulldatawidth::integer%maxalign = 0 THEN maxalign
                  ELSE nulldatawidth::integer%maxalign
                END
            )::numeric AS nulldatahdrwidth, pagehdr, pageopqdata, is_na
            -- , index_tuple_hdr_bm, nulldatawidth -- (DEBUG INFO)
      FROM (
          SELECT n.nspname, ct.relname AS tblname, i.idxname, i.reltuples, i.relpages,
              i.idxoid, i.fillfactor, current_setting('block_size')::numeric AS bs,
              CASE -- MAXALIGN: 4 on 32bits, 8 on 64bits (and mingw32 ?)
                WHEN version() ~ 'mingw32' OR version() ~ '64-bit|x86_64|ppc64|ia64|amd64' THEN 8
                ELSE 4
              END AS maxalign,
              /* per page header, fixed size: 20 for 7.X, 24 for others */
              24 AS pagehdr,
              /* per page btree opaque data */
              16 AS pageopqdata,
              /* per tuple header: add IndexAttributeBitMapData if some cols are null-able */
              CASE WHEN max(coalesce(s.stanullfrac,0)) = 0
                  THEN 2 -- IndexTupleData size
                  ELSE 2 + (( 32 + 8 - 1 ) / 8) -- IndexTupleData size + IndexAttributeBitMapData size ( max num filed per index + 8 - 1 /8)
              END AS index_tuple_hdr_bm,
              /* data len: we remove null values save space using it fractionnal part from stats */
              sum( (1-coalesce(s.stanullfrac, 0)) * coalesce(s.stawidth, 1024)) AS nulldatawidth,
              max( CASE WHEN a.atttypid = 'pg_catalog.name'::regtype THEN 1 ELSE 0 END ) > 0 AS is_na
          FROM (
              SELECT idxname, reltuples, relpages, tbloid, idxoid, fillfactor,
                  CASE WHEN indkey[i]=0 THEN idxoid ELSE tbloid END AS att_rel,
                  CASE WHEN indkey[i]=0 THEN i ELSE indkey[i] END AS att_pos
              FROM (
                  SELECT idxname, reltuples, relpages, tbloid, idxoid, fillfactor, indkey, generate_series(1,indnatts) AS i
                  FROM (
                      SELECT ci.relname AS idxname, ci.reltuples, ci.relpages, i.indrelid AS tbloid,
                          i.indexrelid AS idxoid,
                          coalesce(substring(
                              array_to_string(ci.reloptions, ' ')
                              from 'fillfactor=([0-9]+)')::smallint, 90) AS fillfactor,
                          i.indnatts,
                          string_to_array(textin(int2vectorout(i.indkey)),' ')::int[] AS indkey
                      FROM pg_index i
                      JOIN pg_class ci ON ci.oid=i.indexrelid
                      WHERE ci.relam=(SELECT oid FROM pg_am WHERE amname = 'btree')
                        AND ci.relpages > 0
                  ) AS idx_data
              ) AS idx_data_cross
          ) i
          JOIN pg_attribute a ON a.attrelid = i.att_rel
                             AND a.attnum = i.att_pos
          JOIN pg_statistic s ON s.starelid = i.att_rel
                             AND s.staattnum = i.att_pos
          JOIN pg_class ct ON ct.oid = i.tbloid
          JOIN pg_namespace n ON ct.relnamespace = n.oid
          GROUP BY 1,2,3,4,5,6,7,8,9,10
      ) AS rows_data_stats
  ) AS rows_hdr_pdg_stats
) AS relation_stats
ORDER BY nspname, tblname, idxname

 ) as plop order by 9 desc;
EOF

echo "### Index stats"
psql $PSQL_OPTIONS <<EOF 
SELECT schemaname, 
       relname, 
       indexrelname, 
       idx_scan, 
       idx_tup_read, 
       idx_tup_fetch,
       pg_get_indexdef(indexrelid)
  FROM pg_stat_user_indexes;
EOF

echo "### Index no access"
psql $PSQL_OPTIONS <<EOF 
SELECT
  current_database() AS datname,
  schemaname,
  relname,
  indexrelname,
  pg_get_indexdef(s.indexrelid) AS ddl
FROM
  pg_stat_user_indexes s
  INNER JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.indexrelname NOT ILIKE '%fk%' -- on filtre les index sur clés étrangères
  AND NOT (i.indisunique OR i.indisprimary OR i.indisexclusion)
  AND s.idx_scan = 0
ORDER BY s.schemaname, s.relname, s.indexrelname;
EOF

echo "## procedures & functions"
psql $PSQL_OPTIONS <<EOF 
SELECT count(*)
  FROM pg_proc
 WHERE pronamespace=2200 or pronamespace>16383;
EOF

echo "### procedures & functions per namespace and kind in user space"
if [[ "$VERSION" -ge "1100" ]]; then
psql $PSQL_OPTIONS <<EOF
SELECT n.nspname, 
       l.lanname, 
       CASE p.prokind 
          WHEN 'f' THEN 'function'
          WHEN 'p' THEN 'procedure'
          WHEN 'a' THEN 'aggregate'
          WHEN 'w' THEN 'window function'
          ELSE p.prokind::text
       END AS "type", 
       count(*)
  FROM pg_proc p
  JOIN pg_namespace n 
    ON n.oid=p.pronamespace
  JOIN pg_language l 
    ON l.oid=p.prolang
 WHERE pronamespace=2200 or pronamespace>16383
 GROUP BY 1, 2, 3
 ORDER BY 1, 2, 3;
EOF
else
psql $PSQL_OPTIONS <<EOF
select n.nspname, 
       l.lanname, 
       CASE
          WHEN not proisagg and not proiswindow THEN 'function'
          WHEN proisagg THEN 'aggregate'
          WHEN proiswindow THEN 'window function'
       END, count(*)
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  join pg_language l on l.oid=p.prolang
 where pronamespace=2200 or pronamespace>16383
 group by 1, 2, 3
 order by 1, 2, 3;
EOF
fi

echo "### procedure per language in user space"
psql $PSQL_OPTIONS <<EOF
SELECT n.nspname, l.lanname, count(*)
  FROM pg_proc p
  JOIN pg_namespace n 
    ON n.oid=p.pronamespace
  JOIN pg_language l 
    ON l.oid=p.prolang
 WHERE pronamespace=2200 or pronamespace>16383
 GROUP BY 1, 2
 ORDER BY 1, 2;
EOF

HAS_PG_STAT_STATEMENTS="$(psql -XtAc "SELECT true FROM pg_extension WHERE extname='pg_stat_statements'")"
echo "## pg_stat_statements top 10 total_time"
if [[ "$HAS_PG_STAT_STATEMENTS" == "t" ]]; then

psql $PSQL_OPTIONS -c "SELECT queryid, calls, total_time, mean_time 
FROM pg_stat_statements ORDER BY total_time desc limit 10;"

psql $PSQL_OPTIONS -c "SELECT queryid, query 
FROM pg_stat_statements ORDER BY total_time desc limit 10;"

else
    echo
    echo "WARNING : pg_stat_statements not found"
fi

done
