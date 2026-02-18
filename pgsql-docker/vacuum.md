```sql
-- account table
DROP TABLE account CASCADE;
CREATE TABLE account(
    account_id serial PRIMARY KEY,
    name text NOT NULL,
    dob date
);
```

```sql
-- thread table
DROP TABLE thread CASCADE;
CREATE TABLE thread(
    thread_id serial PRIMARY KEY,
    account_id integer NOT NULL REFERENCES account(account_id),
    title text NOT NULL
);
```

```sql
-- post table
DROP TABLE post CASCADE;
CREATE TABLE post(
    post_id serial PRIMARY KEY,
    thread_id integer NOT NULL REFERENCES thread(thread_id),
    account_id integer NOT NULL REFERENCES account(account_id),
    created timestamp with time zone NOT NULL DEFAULT now(),
    visible boolean NOT NULL DEFAULT TRUE,
    comment text NOT NULL
);
```


```sql
-- word table create with word in linux file
DROP TABLE words;
CREATE TABLE words (word TEXT) ;
\copy words (word) FROM '/data/words';
```

```sql
-- create account data
INSERT INTO account (name, dob)
SELECT
    substring('AEIOU', (random()*4)::int + 1, 1) ||
    substring('ctdrdwftmkndnfnjnknsntnyprpsrdrgrkrmrnzslstwl', (random()*22*2 + 1)::int, 2) ||
    substring('aeiou', (random()*4 + 1)::int, 1) || 
    substring('ctdrdwftmkndnfnjnknsntnyprpsrdrgrkrmrnzslstwl', (random()*22*2 + 1)::int, 2) ||
    substring('aeiou', (random()*4 + 1):: int, 1),
    Now() + ('1 days':: interval * random() * 365)
FROM generate_series (1, 100)
;
```

```sql
-- create thread data 
INSERT INTO thread (account_id, title)
WITH random_titles AS (
    -- 1. สร้างชื่อ Title สุ่มเตรียมไว้ 1,000 ชุด (หรือเท่ากับจำนวนที่ต้องการ insert)
    -- วิธีนี้จะทำการสุ่มคำเพียงครั้งเดียวต่อหนึ่ง title
    SELECT 
        row_number() OVER () as id,
        initcap(sentence) as title
    FROM (
        SELECT (SELECT string_agg(word, ' ') FROM (SELECT word FROM words ORDER BY random() LIMIT 5) AS w) as sentence
        FROM generate_series(1, 1000)
    ) s
)
SELECT
    (RANDOM() * 99 + 1)::int,
    rt.title
FROM generate_series(1, 1000) AS s(n)
JOIN random_titles rt ON rt.id = s.n
;
```

```sql
-- create post data
INSERT INTO post (thread_id, account_id, created, visible, comment)
WITH random_comments AS (
    SELECT row_number() OVER () as id, sentence
    FROM (
        SELECT (SELECT string_agg(word, ' ') FROM (SELECT word FROM words ORDER BY random() LIMIT 20) AS w) as sentence
        FROM generate_series(1, 1000)
    ) s
),
source_data AS (
    -- สร้างโครงข้อมูล 100,000 แถว พร้อมสุ่ม ID สำหรับเลือก comment
    SELECT 
        (RANDOM() * 999 + 1)::int AS t_id,
        (RANDOM() * 99 + 1)::int AS a_id,
        NOW() - ('1 days'::interval * random() * 1000) AS c_date,
        (RANDOM() > 0.1) AS vis,
        floor(random() * 1000 + 1)::int AS comment_id
    FROM generate_series(1, 100000)
)
SELECT 
    sd.t_id, 
    sd.a_id, 
    sd.c_date, 
    sd.vis, 
    rc.sentence
FROM source_data sd
JOIN random_comments rc ON sd.comment_id = rc.id -- ใช้ JOIN เพื่อการันตีว่าข้อมูลต้องมีค่า
;
```

## Step 1: Baseline Analysis
```sql
SELECT pg_size_pretty(pg_relation_size('post')) AS initial_size;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'post';

-- Output
 initial_size 
--------------
 26 MB
(1 row)

 n_live_tup | n_dead_tup 
------------+------------
     100000 |          0
```

## Step 2: Create Massive Bloat
```sql
-- Run this UPDATE 5 times to create 500,000 dead tuples
UPDATE post SET comment = comment || ' [bloat]';
UPDATE post SET comment = comment || ' [bloat]';
UPDATE post SET comment = comment || ' [bloat]';
UPDATE post SET comment = comment || ' [bloat]';
UPDATE post SET comment = comment || ' [bloat]';


SELECT pg_size_pretty(pg_relation_size('post')) AS initial_size;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'post';


-- Output
 initial_size 
--------------
 169 MB
(1 row)

 n_live_tup | n_dead_tup
------------+------------
     100000 |     499964
```

## Step 3: Verify the Performance Hit
```sql
EXPLAIN ANALYZE SELECT count(*) FROM post;
-- Note the increased Execution Time due to scanning dead rows.

-- Output 
                                                                QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=25979.16..25979.17 rows=1 width=8) (actual time=32.565..36.587 rows=1.00 loops=1)
   Buffers: shared hit=21604
   ->  Gather  (cost=25978.95..25979.16 rows=2 width=8) (actual time=32.441..36.578 rows=3.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=21604
         ->  Partial Aggregate  (cost=24978.95..24978.96 rows=1 width=8) (actual time=22.876..22.877 rows=1.00 loops=3)
               Buffers: shared hit=21604
               ->  Parallel Seq Scan on post  (cost=0.00..24303.96 rows=269996 width=0) (actual time=8.098..21.213 rows=33333.33 loops=3)
                     Buffers: shared hit=21604
 Planning:
   Buffers: shared hit=6
 Planning Time: 0.230 ms
 Execution Time: 36.770 ms
```

## Step 4: Run Standard VACUUM
```sql
VACUUM (VERBOSE, ANALYZE) post;
-- Check size: It won't shrink, but n_dead_tup will go to 0.

-- Output
INFO:  vacuuming "db_6610301003.public.post"
INFO:  finished vacuuming "db_6610301003.public.post": index scans: 0
pages: 0 removed, 21604 remain, 1 scanned (0.00% of total), 0 eagerly scanned
tuples: 0 removed, 100000 remain, 0 are dead but not yet removable
removable cutoff: 6323, which was 0 XIDs old when operation ended
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
visibility map: 0 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan not needed: 0 pages from table (0.00% of total) had 0 dead item identifiers removed
avg read rate: 0.000 MB/s, avg write rate: 0.000 MB/s
buffer usage: 25 hits, 0 reads, 0 dirtied
WAL usage: 0 records, 0 full page images, 0 bytes, 0 buffers full
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
INFO:  vacuuming "db_6610301003.pg_toast.pg_toast_27274"
INFO:  finished vacuuming "db_6610301003.pg_toast.pg_toast_27274": index scans: 0
pages: 0 removed, 0 remain, 0 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 6323, which was 0 XIDs old when operation ended
new relfrozenxid: 6323, which is 19 XIDs ahead of previous value
frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
visibility map: 0 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
avg read rate: 14.741 MB/s, avg write rate: 0.000 MB/s
buffer usage: 25 hits, 1 reads, 0 dirtied
WAL usage: 1 records, 0 full page images, 258 bytes, 0 buffers full
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
INFO:  analyzing "public.post"
INFO:  "post": scanned 21604 of 21604 pages, containing 100000 live rows and 0 dead rows; 30000 rows in sample, 100000 estimated total rows
INFO:  finished analyzing table "db_6610301003.public.post"
avg read rate: 0.000 MB/s, avg write rate: 0.000 MB/s
buffer usage: 21832 hits, 0 reads, 0 dirtied
WAL usage: 8 records, 0 full page images, 3429 bytes, 0 buffers full
system usage: CPU: user: 0.08 s, system: 0.00 s, elapsed: 0.09 s
VACUUM
```

```sql

SELECT pg_size_pretty(pg_relation_size('post')) AS initial_size;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'post';


-- Output
 initial_size 
--------------
 169 MB
(1 row)

 n_live_tup | n_dead_tup
------------+------------
     100000 |          0
```
## Step 5: Run VACUUM FULL
```sql
VACUUM FULL post;
-- Check final size: The file will finally shrink on disk.
SELECT pg_size_pretty(pg_relation_size('post')) AS initial_size;
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'post';
 

```


