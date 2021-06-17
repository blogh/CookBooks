DROP TABLE tree;
CREATE TABLE tree(id int, parent_id int, name text);
ALTER TABLE tree ADD PRIMARY KEY (id);
INSERT INTO tree(id, parent_id, name) 
VALUES (1, NULL, 'Albert'),
       (2, 1, 'Bob'),
       (3, 1, 'Barbara'),
       (4, 1, 'Britney'),
       (5, 3, 'Clara'),
       (6, 3, 'Clement'),
       (7, 2, 'Craig'),
       (8, 5, 'Debby'),
       (9, 5, 'Dave'),
       (10, 9, 'Edwin');


-- shows:
--      row_to_json
-- -----------------------
--  {"*DEPTH*":0,"id":1}
--  {"*DEPTH*":1,"id":2}
--  {"*DEPTH*":1,"id":3}
--  {"*DEPTH*":1,"id":4}
--  {"*DEPTH*":2,"id":5}
--  {"*DEPTH*":2,"id":6}
--  {"*DEPTH*":2,"id":7}
--  {"*DEPTH*":3,"id":8}
--  {"*DEPTH*":3,"id":9}
--  {"*DEPTH*":4,"id":10}
-- (10 rows)




WITH RECURSIVE mtree(id, name) AS (
   SELECT id, name
     FROM tree
    WHERE id = 1
   UNION ALL
   SELECT t.id, t.name
     FROM tree AS t
          INNER JOIN mtree AS m ON t.parent_id = m.id
) SEARCH BREADTH FIRST BY id SET breadth
SELECT row_to_json(breadth)
FROM mtree m;

-- shows:
-- psql:/home/benoit/tmp/test.sql:38: ERROR:  CTE m does not have attribute 3

WITH RECURSIVE mtree(id, name) AS (
   SELECT id, name
     FROM tree
    WHERE id = 1
   UNION ALL
   SELECT t.id, t.name
     FROM tree AS t
          INNER JOIN mtree AS m ON t.parent_id = m.id
) SEARCH BREADTH FIRST BY id SET breadth
SELECT (breadth).id   
FROM mtree m;

