

```
CREATE TABLE trgm(t text);
INSERT INTO trgm VALUES ('la voiture bleue'), ('le camion bleu'), ('la voyture rose'), ('la maison vert'), ('le vélo vert');

CREATE INDEX trgm_t_idx_gin ON trgm USING GIN (t gin_trgm_ops);
```


```
=# SET enable_seqscan TO off;
SET
=# EXPLAIN (ANALYZE) SELECT * FROM trgm WHERE t LIKE '%voiture%';
                                                       QUERY PLAN
------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on trgm  (cost=28.00..32.01 rows=1 width=32) (actual time=0.050..0.052 rows=1 loops=1)
   Recheck Cond: (t ~~ '%voiture%'::text)
   Heap Blocks: exact=1
   ->  Bitmap Index Scan on trgm_t_idx_gin  (cost=0.00..28.00 rows=1 width=0) (actual time=0.034..0.034 rows=1 loops=1)
         Index Cond: (t ~~ '%voiture%'::text)
 Planning Time: 0.134 ms
 Execution Time: 0.093 ms
(7 rows)

=#  SELECT * FROM trgm WHERE t LIKE '%voiture%';
        t
-----------------
 la voiture bleu
(1 row)
```

```
=# SELECT *, similarity(t, x) FROM trgm, (VALUES ('la voiture bleue')) AS F(x) WHERE t % x;
        t         |        x         | similarity 
------------------+------------------+------------
 la voyture rose  | la voiture bleue |       0.32
 la voiture bleue | la voiture bleue |          1
(2 rows)

-- distance => 1 - similarity
=# SELECT *, t <-> x FROM trgm, (VALUES ('la voiture bleue')) AS F(x) WHERE t % x;
        t         |        x         | ?column? 
------------------+------------------+----------
 la voyture rose  | la voiture bleue |     0.68
 la voiture bleue | la voiture bleue |        0
(2 rows)

=# EXPLAIN (ANALYZE) SELECT *, similarity(t, x) FROM trgm, (VALUES ('la voiture bleue')) AS F(x) WHERE t % x;
                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on trgm  (cost=76.11..86.70 rows=14 width=68) (actual time=0.117..0.133 rows=2 loops=1)
   Recheck Cond: (t % 'la voiture bleue'::text)
   Heap Blocks: exact=1
   ->  Bitmap Index Scan on trgm_t_idx_gin  (cost=0.00..76.10 rows=14 width=0) (actual time=0.077..0.077 rows=3 loops=1)
         Index Cond: (t % 'la voiture bleue'::text)
 Planning Time: 0.192 ms
 Execution Time: 0.184 ms
(7 rows)
```


```
# CREATE INDEX trgm_t_idx_gist ON trgm USING GIST (t gist_trgm_ops);
CREATE INDEX
[local]:5433 postgres@form=# \di+ trgm_t_idx_gi*
                                      List of relations
 Schema |      Name       | Type  |  Owner   | Table | Persistence |    Size    | Description
--------+-----------------+-------+----------+-------+-------------+------------+-------------
 public | trgm_t_idx_gin  | index | postgres | trgm  | permanent   | 24 kB      |
 public | trgm_t_idx_gist | index | postgres | trgm  | permanent   | 8192 bytes |
(2 rows)
```

From the doc : As a rule of thumb, a GIN index is faster to search than a GiST
index, but slower to build or update; so GIN is better suited for static data
and GiST for often-updated data.



