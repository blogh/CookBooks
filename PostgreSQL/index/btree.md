# Documentation

* [doc btree](https://www.postgresql.org/docs/current/btree-implementation.html)
* [src/backend/access/nbtree/README](https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/backend/access/nbtree/README;hb=HEAD)
* [pageinspect](https://www.postgresql.org/docs/current/pageinspect.html)
* [Btree structure (postgrespro)](https://postgrespro.com/blog/pgsql/4161516)

## structure & inner working

> Compared to a classic B-tree, L&Y adds a right-link pointer to each page, to
> the page's right sibling.  It also adds a "high key" to each page, which is
> an upper bound on the keys that are allowed on that page.  These two
> additions make it possible detect a concurrent page split, which allows the
> tree to be searched without holding any read locks (except to keep a single
> page from being modified while reading it).
> (readme)

Each page as a:
* _right-link pointer_ (bt_page_stats.btpo_next)
* _high key_ of the current page

> When a search follows a downlink to a child page, it compares the page's high
> key with the search key.  If the search key is greater than the high key, the
> page must've been split concurrently, and you must follow the right-link to
> find the new page containing the key range you're looking for.  This might
> need to be repeated, if the page has been split more than once.
> (readme)

Eache page's _high key_ must be compared with the search value. If search value
is :
* greater: follow _right link pointer_ we might have a split while we were
  reading the page.
* lower or equal: you 're in the right page

> Lehman and Yao talk about alternating "separator" keys and downlinks in
> internal pages rather than tuples or records.  We use the term "pivot" tuple
> to refer to tuples which don't point to heap tuples, that are used only for
> tree navigation.  All tuples on non-leaf pages and high keys on leaf pages
> are pivot tuples.  Since pivot tuples are only used to represent which part
> of the key space belongs on each page, they can have attribute values copied
> from non-pivot tuples that were deleted and killed by VACUUM some time ago.
> A pivot tuple may contain a "separator" key and downlink, just a separator
> key (i.e. the downlink value is implicitly undefined), or just a downlink
> (i.e. all attributes are truncated away).
>
> The requirement that all btree keys be unique is satisfied by treating heap
> TID as a tiebreaker attribute.  Logical duplicates are sorted in heap TID
> order.  This is necessary because Lehman and Yao also require that the key
> range for a subtree S is described by Ki < v <= Ki+1 where Ki and Ki+1 are
> the adjacent keys in the parent page (Ki must be _strictly_ less than v,
> which is assured by having reliably unique keys).  Keys are always unique on
> their level, with the exception of a leaf page's high key, which can be fully
> equal to the last item on the page.
> (readme)

_Separator_ (L&Y terminology) = _pivot tuples_ in postgres = tuples which don't
point to heap tuples :
* all tuples in non root page
* _hight key_ on leaf page 

The data is stored in non decreasing order both between and inside a page.

The root and internal pages store links to pages lower in the tree (other
internal pages or leaf pages) in the `ctid` first part of the tuple (the other
one contains info about the tuple).

The `data` field stored in thoses tuples corresponds to the "smallest" data in
the page.  In non unique indexes, it's possible that a key has many different
values and theses values can overflow to the next page (even with
deduplication). Therefore, if the search key is <= to the lowest value pointed
by a internal/root page, we must start in the preceding page and once we hit
the leaf page continue in the next one. (search key will equal _hight key_
in that case).

Example :

```
-- Index meta page to get the root page (fastroot)
-- see : [BTMetaPageData](https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/include/access/nbtree.h;hb=HEAD#l101)
=# SELECT * FROM bt_metap('ventes_y2001_date_vente_idx');

 magic  | version | root | level | fastroot | fastlevel | last_cleanup_num_delpages | last_cleanup_num_tuples | allequalimage
--------+---------+------+-------+----------+-----------+---------------------------+-------------------------+---------------
 340322 |       4 |    3 |     1 |        3 |         1 |                         0 |                      -1 | t
(1 row)

-- Root page metadata
-- The type can be one of r (root), i (internal), l (leaf)
=# SELECT * FROM bt_page_stats('ventes_y2001_date_vente_idx', 3);

 blkno | type | live_items | dead_items | avg_item_size | page_size | free_size | btpo_prev | btpo_next | btpo_level | btpo_flags 
-------+------+------------+------------+---------------+-----------+-----------+-----------+-----------+------------+------------
     3 | r    |         92 |          0 |            23 |      8192 |      5588 |         0 |         0 |          1 |          2
(1 row)

-- Root page data
-- lowest value in page 2 x'0171' ih we are looking for it we have to scan page 1
=# SELECT * FROM bt_page_items('ventes_y2001_date_vente_idx', 3);

 itemoffset |   ctid    | itemlen | nulls | vars |          data           | dead |   htid    | tids 
------------+-----------+---------+-------+------+-------------------------+------+-----------+------
          1 | (1,0)     |       8 | f     | f    |                         | ¤    | ¤         | ¤
          2 | (2,4097)  |      24 | f     | f    | 71 01 00 00 00 00 00 00 | ¤    | (611,72)  | ¤
          3 | (4,4097)  |      24 | f     | f    | 75 01 00 00 00 00 00 00 | ¤    | (611,76)  | ¤
          4 | (5,4097)  |      24 | f     | f    | 79 01 00 00 00 00 00 00 | ¤    | (611,80)  | ¤

-- page 1 metadata (leaf page)
=# SELECT * FROM bt_page_stats('ventes_y2001_date_vente_idx', 1);

 blkno | type | live_items | dead_items | avg_item_size | page_size | free_size | btpo_prev | btpo_next | btpo_level | btpo_flags
-------+------+------------+------------+---------------+-----------+-----------+-----------+-----------+------------+------------
     1 | l    |         12 |          0 |           598 |      8192 |       916 |         0 |         2 |          0 |          1
(1 row)

-- page 1 data
-- _hight key_ (first tuple) is also x'0171' if that's the key we where looking or we have to read both pages. 
=# SELECT * FROM bt_page_items('ventes_y2001_date_vente_idx', 1);

 itemoffset |   ctid    | itemlen | nulls | vars |          data           | dead |   htid    |   tids
------------+-----------+---------+-------+------+-------------------------+------+-----------+--------------
          1 | (16,4097) |      24 | f     | f    | 71 01 00 00 00 00 00 00 | ¤    | (611,72)  | ¤
          t | (16,8324) |     808 | f     | f    | 6e 01 00 00 00 00 00 00 | f    | (0,1)     | {"(0,1)", ...
...
         12 | (16,8324) |     808 | f     | f    | 71 01 00 00 00 00 00 00 | f    | (306,142) | {"(306,142)", ...
(12 rows)

-- page 2 data
-- as expected the lowest value is x'0171', so we have more data to fetch
=# SELECT * FROM bt_page_items('ventes_y2001_date_vente_idx', 2);

 itemoffset |   ctid    | itemlen | nulls | vars |          data           | dead |   htid    |   tids
------------+-----------+---------+-------+------+-------------------------+------+-----------+--------------
          1 | (16,4097) |      24 | f     | f    | 75 01 00 00 00 00 00 00 | ¤    | (611,76)  | ¤
          2 | (16,8228) |     232 | f     | f    | 71 01 00 00 00 00 00 00 | f    | (613,123) | {"(613,123)", ...
...
         13 | (16,8324) |     808 | f     | f    | 75 01 00 00 00 00 00 00 | f    | (306,146) | {"(306,146)", ...
(13 rows)
```

## scans 

> We support the notion of an ordered "scan" of an index as well as insertions,
> deletions, and simple lookups.  A scan in the forward direction is no
> problem, we just use the right-sibling pointers that L&Y require anyway.
> (Thus, once we have descended the tree to the correct start point for the
> scan, the scan looks only at leaf pages and never at higher tree levels.)  To
> support scans in the backward direction, we also store a "left sibling" link
> much like the "right sibling".  (This adds an extra step to the L&Y split
> algorithm: while holding the write lock on the page being split, we also lock
> its former right sibling to update that page's left-link.  This is safe since
> no writer of that page can be interested in acquiring a write lock on our
> page.)  A backwards scan has one additional bit of complexity: after
> following the left-link we must account for the possibility that the left
> sibling page got split before we could read it.  So, we have to move right
> until we find a page whose right-link matches the page we came from.
> (Actually, it's even harder than that; see page deletion discussion below.)
> (readme)

* Forward scans are no problem we follow the _right link_ pointer.
  (bt_page_stats.btpo_next)
* For backward scan we have a _left link pointer_ (bt_page_stats.btpo_prev)

## Splitting of the root and internal pages

> Lehman and Yao fail to discuss what must happen when the root page becomes
> full and must be split.  Our implementation is to split the root in the same
> way that any other page would be split, then construct a new root page
> holding pointers to both of the resulting pages (which now become siblings on
> the next level of the tree).  The new root page is then installed by altering
> the root pointer in the meta-data page (see below).  This works because the
> root is not treated specially in any other way --- in particular, searches
> will move right using its link pointer if the link is set.  Therefore,
> searches will find the data that's been moved into the right sibling even if
> they read the meta-data page before it got updated.  This is the same
> reasoning that makes a split of a non-root page safe.  The locking
> considerations are similar too.
> (readme)

Splitting the root page :
* split like a leaf page
* create a root page
* point to the tho resulting (internal type) pages

An other example with internal pages
```
-- Index meta page to get the root page (fastroot)
-- see : [BTMetaPageData](https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/include/access/nbtree.h;hb=HEAD#l101)

=# SELECT * FROM bt_metap('idx_nummultiranges_btree');
 magic  | version | root | level | fastroot | fastlevel | last_cleanup_num_delpages | last_cleanup_num_tuples | allequalimage
--------+---------+------+-------+----------+-----------+---------------------------+-------------------------+---------------
 340322 |       4 | 4042 |     3 |     4042 |         3 |                         0 |                      -1 | f
(1 row)

-- Root page metadata
-- The type can be one of r (root), i (internal), l (leaf)
=# SELECT * FROM bt_page_stats('idx_nummultiranges_btree', 4042);

 blkno | type | live_items | dead_items | avg_item_size | page_size | free_size | btpo_prev | btpo_next | btpo_level | btpo_flags
-------+------+------------+------------+---------------+-----------+-----------+-----------+-----------+------------+------------
  4042 | r    |          4 |          0 |            84 |      8192 |      7796 |         0 |         0 |          3 |          2
(1 row)

-- Root page data
=# SELECT itemoffset, ctid, itemlen, nulls, vars, 
          substr(data,1 ,15) || '...' as data, dead, htid, 
          tids[1]::text || ', ...' as tids
   FROM bt_page_items('idx_nummultiranges_btree', 4042); 

 itemoffset |   ctid    | itemlen | nulls | vars |        data        | dead | htid | tids 
------------+-----------+---------+-------+------+--------------------+------+------+------
          1 | (68,0)    |       8 | f     | f    | ...                | ¤    | ¤    | ¤
          2 | (4041,1)  |     136 | f     | t    | fb b4 11 00 00 ... | ¤    | ¤    | ¤
          3 | (7616,1)  |     112 | f     | t    | c3 b4 11 00 00 ... | ¤    | ¤    | ¤
          4 | (11239,1) |      80 | f     | t    | 8b b4 11 00 00 ... | ¤    | ¤    | ¤
(4 rows)


-- page 68 metadata (internal page)
=# SELECT * FROM bt_page_stats('idx_nummultiranges_btree', 68);

 blkno | type | live_items | dead_items | avg_item_size | page_size | free_size | btpo_prev | btpo_next | btpo_level | btpo_flags 
-------+------+------------+------------+---------------+-----------+-----------+-----------+-----------+------------+------------
    68 | i    |         63 |          0 |            87 |      8192 |      2376 |         0 |      4041 |          2 |          0
(1 row)

-- page 68 data
=# SELECT itemoffset, ctid, itemlen, nulls, vars, 
          substr(data,1 ,15) || '...' as data, dead, htid, 
          tids[1]::text || ', ...' as tids
   FROM bt_page_items('idx_nummultiranges_btree', 68); 

 itemoffset |   ctid   | itemlen | nulls | vars |        data        | dead | htid | tids
------------+----------+---------+-------+------+--------------------+------+------+------
          1 | (3914,1) |     136 | f     | t    | fb b4 11 00 00 ... | ¤    | ¤    | ¤
          2 | (3,0)    |       8 | f     | f    | ...                | ¤    | ¤    | ¤
...
         62 | (3788,1) |      80 | f     | t    | 8b b4 11 00 00 ... | ¤    | ¤    | ¤
         63 | (3851,1) |      80 | f     | t    | 83 b4 11 00 00 ... | ¤    | ¤    | ¤
(63 rows)
```

Note : on small indexes the first page can also be a leaf page :

```
-- Index meta page to get the root page (fastroot)
=# SELECT * FROM bt_metap('dropme_i_idx');
 magic  | version | root | level | fastroot | fastlevel | oldest_xact | last_cleanup_num_tuples
--------+---------+------+-------+----------+-----------+-------------+-------------------------
 340322 |       4 |    1 |     0 |        1 |         0 |           0 |                      -1
(1 row)

-- page 1 (fastroot) is a leaf page
=# SELECT * FROM bt_page_stats('dropme_i_idx',1);
 blkno | type | live_items | dead_items | avg_item_size | page_size | free_size | btpo_prev | btpo_next | btpo | btpo_flags
-------+------+------------+------------+---------------+-----------+-----------+-----------+-----------+------+------------
     1 | l    |        100 |          0 |            16 |      8192 |      6148 |         0 |         0 |    0 |          3
(1 row)
```

## Properties

See (https://postgrespro.com/blog/pgsql/4161264)


Properties of an index method (`pg_indexam_has_property`):

```
=# select a.amname, p.name, pg_indexam_has_property(a.oid,p.name)
from pg_am a,
     unnest(array['can_order','can_unique','can_multi_col','can_exclude']) p(name)
where pg_indexam_has_property(a.oid,p.name) and a.name = 'btree' order by a.amname;
 amname |     name      | pg_indexam_has_property
--------+---------------+-------------------------
 btree  | can_unique    | t
 btree  | can_multi_col | t
 btree  | can_order     | t
 btree  | can_exclude   | t
(4 rows)
```

Properties of a specific index (`pg_index_has_property`):

```
=#select p.name, pg_index_has_property('lookup_a_idx'::regclass,p.name)
from unnest(array[
       'clusterable','index_scan','bitmap_scan','backward_scan'
     ]) p(name);
     name      | pg_index_has_property
---------------+-----------------------
 clusterable   | t
 index_scan    | t
 bitmap_scan   | t
 backward_scan | t
(4 rows)
```

Properies of a column (`pg_index_column_has_property`):

```
=# select p.name,
     pg_index_column_has_property('lookup_a_idx'::regclass,1,p.name)
from unnest(array[
       'asc','desc','nulls_first','nulls_last','orderable','distance_orderable',
       'returnable','search_array','search_nulls'
     ]) p(name);
        name        | pg_index_column_has_property
--------------------+------------------------------
 asc                | t
 desc               | f
 nulls_first        | f
 nulls_last         | t
 orderable          | t
 distance_orderable | f
 returnable         | t
 search_array       | t
 search_nulls       | t
(9 rows)
```

## Operators

Supported operator for btree :

```
=# select opcname, opcintype::regtype
-# from pg_opclass
-# where opcmethod = (select oid from pg_am where amname = 'btree')
-# order by opcintype::regtype::text;
       opcname       |          opcintype
---------------------+-----------------------------
 char_ops            | "char"
 array_ops           | anyarray
 enum_ops            | anyenum
 range_ops           | anyrange
 int8_ops            | bigint
 bit_ops             | bit
 varbit_ops          | bit varying
 bool_ops            | boolean
 bytea_ops           | bytea
 bpchar_pattern_ops  | character
 bpchar_ops          | character
 date_ops            | date
 float8_ops          | double precision
 inet_ops            | inet
 cidr_ops            | inet
 int4_ops            | integer
 interval_ops        | interval
 jsonb_ops           | jsonb
 macaddr_ops         | macaddr
 macaddr8_ops        | macaddr8
 money_ops           | money
 name_ops            | name
 numeric_ops         | numeric
 oid_ops             | oid
 oidvector_ops       | oidvector
 pg_lsn_ops          | pg_lsn
 float4_ops          | real
 record_ops          | record
 record_image_ops    | record
 int2_ops            | smallint
 text_pattern_ops    | text
 varchar_pattern_ops | text
 varchar_ops         | text
 text_ops            | text
 tid_ops             | tid
 timetz_ops          | time with time zone
 time_ops            | time without time zone
 timestamptz_ops     | timestamp with time zone
 timestamp_ops       | timestamp without time zone
 tpt_opclass         | tpt
 tsquery_ops         | tsquery
 tsvector_ops        | tsvector
 uuid_ops            | uuid
 xid8_ops            | xid8
(44 rows)
```

Supported operations for an am & opclass :

```
=# select amop.amopopr::regoperator
   from pg_opclass opc, pg_opfamily opf, pg_am am, pg_amop amop
   where opc.opcname = 'array_ops'
   and opf.oid = opc.opcfamily
   and am.oid = opf.opfmethod
   and amop.amopfamily = opc.opcfamily
   and am.amname = 'btree'
   and amop.amoplefttype = opc.opcintype;

        amopopr
-----------------------
 <(anyarray,anyarray)
 <=(anyarray,anyarray)
 =(anyarray,anyarray)
 >=(anyarray,anyarray)
 >(anyarray,anyarray)
(5 rows)
```


Difference between text_pattern_ops and text_ops :

```
[local]:5433 postgres@postgres=# select opfname, opcname, amop.amopopr::regoperator, amop.amoppurpose
from pg_opclass opc, pg_opfamily opf, pg_am am, pg_amop amop
where opc.opcname IN('text_ops', 'text_pattern_ops')
and opf.oid = opc.opcfamily
and am.oid = opf.opfmethod
and amop.amopfamily = opc.opcfamily
and am.amname = 'btree'
and amop.amoplefttype = opc.opcintype
order by 1, 2;
     opfname      |     opcname      |     amopopr
------------------+------------------+-----------------
 text_ops         | text_ops         | <(text,name)
 text_ops         | text_ops         | <=(text,name)
 text_ops         | text_ops         | =(text,name)
 text_ops         | text_ops         | >=(text,name)
 text_ops         | text_ops         | >(text,name)
 text_ops         | text_ops         | <(text,text)
 text_ops         | text_ops         | <=(text,text)
 text_ops         | text_ops         | =(text,text)
 text_ops         | text_ops         | >=(text,text)
 text_ops         | text_ops         | >(text,text)
 text_pattern_ops | text_pattern_ops | ~<~(text,text)
 text_pattern_ops | text_pattern_ops | ~<=~(text,text)
 text_pattern_ops | text_pattern_ops | =(text,text)
 text_pattern_ops | text_pattern_ops | ~>=~(text,text)
 text_pattern_ops | text_pattern_ops | ~>~(text,text)
(15 rows)

-- t.t as fr_FR.utf8 collation
-- classic index
---- < works
[local]:5433 postgres@postgres=# EXPLAIN (ANALYZE) SELECT * FROM t WHERE t  < '15';
                                                     QUERY PLAN
---------------------------------------------------------------------------------------------------------------------
 Index Only Scan using t_t_idx on t  (cost=0.29..18.05 rows=558 width=4) (actual time=0.449..0.718 rows=557 loops=1)
   Index Cond: (t < '15'::text)
   Heap Fetches: 0
 Planning Time: 0.139 ms
 Execution Time: 0.807 ms
(5 rows)

---- LIKE doesn't
[local]:5433 postgres@postgres=# EXPLAIN (ANALYZE) SELECT * FROM t WHERE t LIKE '15%';
                                           QUERY PLAN
-------------------------------------------------------------------------------------------------
 Seq Scan on t  (cost=0.00..170.00 rows=101 width=4) (actual time=0.030..5.069 rows=111 loops=1)
   Filter: (t ~~ '15%'::text)
   Rows Removed by Filter: 9889
 Planning Time: 0.160 ms
 Execution Time: 5.108 ms
(5 rows)

-- index with text_pattern_ops
---- < doesn't work (the operator doesnt exist for this class)
[local]:5433 postgres@postgres=# EXPLAIN (ANALYZE) SELECT * FROM t WHERE t  < '15';
                                           QUERY PLAN
-------------------------------------------------------------------------------------------------
 Seq Scan on t  (cost=0.00..170.00 rows=558 width=4) (actual time=0.023..6.121 rows=557 loops=1)
   Filter: (t < '15'::text)
   Rows Removed by Filter: 9443
 Planning Time: 0.162 ms
 Execution Time: 6.203 ms
(5 rows)

---- LIKE does
[local]:5433 postgres@postgres=# EXPLAIN (ANALYZE) SELECT * FROM t WHERE t LIKE '15%';
                                                     QUERY PLAN
--------------------------------------------------------------------------------------------------------------------
 Index Only Scan using t_t_idx on t  (cost=0.29..6.51 rows=101 width=4) (actual time=0.040..0.070 rows=111 loops=1)
   Index Cond: ((t ~>=~ '15'::text) AND (t ~<~ '16'::text))
   Filter: (t ~~ '15%'::text)
   Heap Fetches: 0
 Planning Time: 0.225 ms
 Execution Time: 0.094 ms
(6 rows)
```

Difference between jsonb_ops & jsonb_path_ops:

```
[local]:5432 postgres@postgres=# select opfname, opcname, amop.amopopr::regoperator, amop.amoppurpose, am.amname
from pg_opclass opc, pg_opfamily opf, pg_am am, pg_amop amop
where opc.opcname LIKE 'json%'
and opf.oid = opc.opcfamily
and am.oid = opf.opfmethod
and amop.amopfamily = opc.opcfamily
and amop.amoplefttype = opc.opcintype
order by 1, 2;
    opfname     |    opcname     |      amopopr       | amoppurpose | amname
----------------+----------------+--------------------+-------------+--------
 jsonb_ops      | jsonb_ops      | <(jsonb,jsonb)     | s           | btree
 jsonb_ops      | jsonb_ops      | <=(jsonb,jsonb)    | s           | btree
 jsonb_ops      | jsonb_ops      | =(jsonb,jsonb)     | s           | btree
 jsonb_ops      | jsonb_ops      | >=(jsonb,jsonb)    | s           | btree
 jsonb_ops      | jsonb_ops      | >(jsonb,jsonb)     | s           | btree
 jsonb_ops      | jsonb_ops      | =(jsonb,jsonb)     | s           | hash
 jsonb_ops      | jsonb_ops      | ?(jsonb,text)      | s           | gin
 jsonb_ops      | jsonb_ops      | ?|(jsonb,text[])   | s           | gin
 jsonb_ops      | jsonb_ops      | ?&(jsonb,text[])   | s           | gin
 jsonb_ops      | jsonb_ops      | @>(jsonb,jsonb)    | s           | gin
 jsonb_ops      | jsonb_ops      | @?(jsonb,jsonpath) | s           | gin
 jsonb_ops      | jsonb_ops      | @@(jsonb,jsonpath) | s           | gin
 jsonb_path_ops | jsonb_path_ops | @>(jsonb,jsonb)    | s           | gin
 jsonb_path_ops | jsonb_path_ops | @?(jsonb,jsonpath) | s           | gin
 jsonb_path_ops | jsonb_path_ops | @@(jsonb,jsonpath) | s           | gin
(15 rows)
```




