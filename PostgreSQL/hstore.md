
```
CREATE TABLE h(i int, h hstore);
CREATE INDEX h_h_idx_gin ON h USING GIN (h);

INSERT INTO h (i,h) 
  SELECT x, ARRAY['age', (random() * 20)::int::text, 'taille', (random() * 200)::int::text ]::hstore 
  FROM generate_series(1, 10000) AS F(x);

UPDATE h set h = h || 'badboy => yes' WHERE mod(i,2) = 1;
UPDATE h set h = h || 'hacker => yes' WHERE mod(i,3) = 1;
```

```
-- contains the key badboy
# EXPLAIN (ANALYZE) SELECT * FROM h WHERE h ? 'badboy';

                                                     QUERY PLAN                                                      
---------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on h  (cost=304.01..308.02 rows=1 width=37) (actual time=2.598..4.027 rows=5001 loops=1)
   Recheck Cond: (h ? 'badboy'::text)
   Heap Blocks: exact=52
   ->  Bitmap Index Scan on h_h_idx_gin (cost=0.00..304.01 rows=1 width=0) (actual time=2.561..2.562 rows=5001 loops=1)
         Index Cond: (h ? 'badboy'::text)
 Planning Time: 0.189 ms
 Execution Time: 4.581 ms
(7 rows)

-- contains the key age
=# EXPLAIN (ANALYZE) SELECT * FROM h WHERE h ? 'age';
                                              QUERY PLAN
------------------------------------------------------------------------------------------------------
 Seq Scan on h  (cost=0.00..260.02 rows=10001 width=46) (actual time=0.016..4.293 rows=10002 loops=1)
   Filter: (h ? 'age'::text)
 Planning Time: 0.311 ms
 Execution Time: 5.123 ms
(4 rows)

-- contains any key of badboy & hacker
=# EXPLAIN (ANALYZE) SELECT * FROM h WHERE h ?| ARRAY['badboy', 'hacker'];
                                             QUERY PLAN                                             
----------------------------------------------------------------------------------------------------
 Seq Scan on h  (cost=0.00..260.02 rows=4935 width=46) (actual time=0.068..6.586 rows=6668 loops=1)
   Filter: (h ?| '{badboy,hacker}'::text[])
   Rows Removed by Filter: 3334
 Planning Time: 0.356 ms
 Execution Time: 6.924 ms
(5 rows)

-- contains all key of badboy & hacker
# EXPLAIN (ANALYZE) SELECT * FROM h WHERE h ?& ARRAY['badboy', 'hacker'];
                                                      QUERY PLAN                                                       
-----------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on h  (cost=24.88..180.67 rows=1663 width=52) (actual time=1.066..1.693 rows=1668 loops=1)
   Recheck Cond: (h ?& '{badboy,hacker}'::text[])
   Heap Blocks: exact=77
   ->  Bitmap Index Scan on h_h_idx_gin (cost=0.00..24.47 rows=1663 width=0) (actual time=1.029..1.029 rows=1668 loops=1)
         Index Cond: (h ?& '{badboy,hacker}'::text[])
 Planning Time: 0.471 ms
 Execution Time: 1.905 ms
(7 rows)
```

```
-- h contains age => 15
=# EXPLAIN (ANALYZE) SELECT * FROM h WHERE h @> 'age => 15';
                                                     QUERY PLAN
---------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on h  (cost=15.76..156.82 rows=485 width=46) (actual time=0.500..1.265 rows=501 loops=1)
   Recheck Cond: (h @> '"age"=>"15"'::hstore)
   Rows Removed by Index Recheck: 44
   Heap Blocks: exact=132
   ->  Bitmap Index Scan on h_h_idx_gin (cost=0.00..15.64 rows=485 width=0) (actual time=0.441..0.441 rows=545 loops=1)
         Index Cond: (h @> '"age"=>"15"'::hstore)
 Planning Time: 0.200 ms
 Execution Time: 1.362 ms
(8 rows)

=# EXPLAIN (ANALYZE) SELECT * FROM h WHERE h @> 'age => 10, hacker => yes';
                                                     QUERY PLAN
---------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on h  (cost=21.50..165.76 rows=193 width=52) (actual time=0.742..1.074 rows=170 loops=1)
   Recheck Cond: (h @> '"age"=>"10", "hacker"=>"yes"'::hstore)
   Rows Removed by Index Recheck: 15
   Heap Blocks: exact=77
   ->  Bitmap Index Scan on h_h_idx_gin (cost=0.00..21.45 rows=193 width=0) (actual time=0.699..0.700 rows=185 loops=1)
         Index Cond: (h @> '"age"=>"10", "hacker"=>"yes"'::hstore)
 Planning Time: 0.208 ms
 Execution Time: 1.138 ms
(8 rows)

```


```
CREATE INDEX h_h_idx_gist ON h USING GIST (h);

# \di+ h_h_idx*
                                   List of relations
 Schema |     Name     | Type  |  Owner   | Table | Persistence |  Size  | Description 
--------+--------------+-------+----------+-------+-------------+--------+-------------
 public | h_h_idx_gin  | index | postgres | h     | permanent   | 152 kB | 
 public | h_h_idx_gist | index | postgres | h     | permanent   | 472 kB | 
(2 rows)
```

