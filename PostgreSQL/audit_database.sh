#!/bin/sh

export LANG=C

test -z "$1" || export PGDATA=$1
test -d "$PGDATA" || \
  {
    echo "La variable PGDATA doit être configurée ou sa valeur fournie en premier argument de ce script." ;
    exit -1;
  }

test -z "$2" || export PGDATABASE=$2
test -z "$PGDATABASE" && \
  {
    echo "La variable PGDATABASE doit être configurée ou sa valeur fournie en deuxième argument de ce script." ;
    exit -1;
  }

which pg_controldata >/dev/null 2>&1 || \
  {
    echo "which ne connaît pas pg_controldata. Merci de corriger la variable PATH."
    exit -1;
  }

PSQL_OPTIONS="-P pager=off -X"

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

HAS_PG_STAT_STATEMENTS="$(psql -XtAc "SELECT true FROM pg_extension WHERE extname='pg_stat_statements'")"
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

echo "## procedures & functions"
psql $PSQL_OPTIONS <<EOF 
SELECT count(*)
  FROM pg_proc
 WHERE pronamespace=2200 or pronamespace>16383;
EOF

echo "### procedures & functions per namespace and kind in user space"
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

