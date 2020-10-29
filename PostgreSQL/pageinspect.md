# PageHeadearData - `pageheader(txt, int)`

## Source 

`src/include/storage/bufpage.h`

## Data
```
pd_lsn;          
```
* LSN: next byte after last byte of xlog record for last change to this page
* The LSN is used by the buffer manager to enforce the basic rule of WAL: "thou
  shalt write xlog before data".  A dirty buffer cannot be dumped to disk until
  xlog has been flushed at least as far as the page's LSN.

```
pd_checksum; 
```
* The checksum is dependant on the block number - page_checksum(bytea, int)

```
pd_flags;               
```
* `PD_HAS_FREE_LINES       0x0001  /* are there any unused line pointers? */`
* `PD_PAGE_FULL            0x0002  /* not enough free space for new tuple? */`
* `PD_ALL_VISIBLE          0x0004  /* all tuples on page are visible to everyone */`
* `PD_VALID_FLAG_BITS      0x0007  /* OR of all valid pd_flags bits */`

```
pd_lower;         /* offset to start of free space */        
pd_upper;         /* offset to end of free space */          
```
* The space available for tuple is located between pd_lower & pd_upper

```
pd_special;
```
* offset to start of special space

```
pd_pagesize_version;                                    
```
* 4 is the version for 8.3

```
pd_prune_xid; 
```
* oldest prunable XID, or zero if none
* it helps determine whether pruning will be useful.  It is currently unused
  in index pages.

```
pd_linp[FLEXIBLE_ARRAY_MEMBER]; /* line pointer array */
```

# Heap page items `heap_page_items(bytea)` - `heap_page_item_attrs(bytea, regclass)`

## Source 
`src/include/storage/itemid.h`
`src/include/access/htup_details.h`

## Data 

```
lp_off (ItemData)
```
* offset to tuple (from start of page)

```
lp_flags (ItemData)
```
* state of line pointer, see below
  * `LP_UNUSED   0               /* unused (should always have lp_len=0) */`
  * `LP_NORMAL   1               /* used (should always have lp_len>0) */`
  * `LP_REDIRECT 2               /* HOT redirect (should have lp_len=0) */`
  * `LP_DEAD     3               /* dead, may or may not have storage */`

```
lp_len (ItemData)
```
* byte length of tuple


```
t_xmin (HeapTupleHeaderData -> HeapTupleFields)
```
* inserting xact ID

```
t_xmax (HeapTupleHeaderData -> HeapTupleFields)
```
* deleting or locking xact ID

```
(???) t_cid (HeapTupleHeaderData -> HeapTupleFields)
```
* inserting or deleting command ID, or both 

```
(???) t_xvac (HeapTupleHeaderData -> HeapTupleFields)
```
* old-style VACUUM FULL xact ID

```
t_ctid (HeapTupleHeaderData)
```
* current TID of this or newer tuple (or a speculative insertion token

```
t_infomask2 (HeapTupleHeaderData)
```
* number of attributes + various flags
  * `HEAP_NATTS_MASK             0x07FF  /* 11 bits for number of attributes */
                                         /* bits 0x1800 are available */`
  * `HEAP_KEYS_UPDATED           0x2000  /* tuple was updated and key cols
                                         * modified, or tuple deleted */`
  * `HEAP_HOT_UPDATED            0x4000  /* tuple was HOT-updated */`
  * `HEAP_ONLY_TUPLE             0x8000  /* this is heap-only tuple */`
  * `HEAP2_XACT_MASK             0xE000  /* visibility-related bits */`

```
t_infomask (HeapTupleHeaderData)
```
* various flag bits, see below 
  * `HEAP_HASNULL                0x0001  /* has null attribute(s) */`        
  * `HEAP_HASVARWIDTH            0x0002  /* has variable-width attribute(s) */`
  * `HEAP_HASEXTERNAL            0x0004  /* has external stored attribute(s) */`
  * `HEAP_HASOID_OLD             0x0008  /* has an object-id field */`       
  * `HEAP_XMAX_KEYSHR_LOCK       0x0010  /* xmax is a key-shared locker */`          
  * `HEAP_COMBOCID               0x0020  /* t_cid is a combo cid */`     
  * `HEAP_XMAX_EXCL_LOCK         0x0040  /* xmax is exclusive locker */`
  * `HEAP_XMAX_LOCK_ONLY         0x0080  /* xmax, if valid, is only a locker */`
  * `HEAP_XMIN_COMMITTED         0x0100  /* t_xmin committed */`
  * `HEAP_XMIN_INVALID           0x0200  /* t_xmin invalid/aborted */`
  * `HEAP_XMAX_COMMITTED         0x0400  /* t_xmax committed */`
  * `HEAP_XMAX_INVALID           0x0800  /* t_xmax invalid/aborted */`
  * `HEAP_XMAX_IS_MULTI          0x1000  /* t_xmax is a MultiXactId */`
  * `HEAP_UPDATED                0x2000  /* this is UPDATEd version of row */`
  * `HEAP_MOVED_OFF              0x4000  /* moved to another place by pre-9.0
                                         * VACUUM FULL; kept for binary
                                         * upgrade support */`
  * `HEAP_MOVED_IN               0x8000  /* moved from another place by pre-9.0
                                         * VACUUM FULL; kept for binary
                                         * upgrade support */`
  * `HEAP_XACT_MASK              0xFFF0  /* visibility-related bits */`

  * `HEAP_XMIN_FROZEN            (HEAP_XMIN_COMMITTED|HEAP_XMIN_INVALID)`
  * `HEAP_MOVED                  (HEAP_MOVED_OFF | HEAP_MOVED_IN)`
  * `HEAP_XMAX_SHR_LOCK          (HEAP_XMAX_EXCL_LOCK | HEAP_XMAX_KEYSHR_LOCK)`
  * `HEAP_LOCK_MASK              (HEAP_XMAX_SHR_LOCK | HEAP_XMAX_EXCL_LOCK | HEAP_XMAX_KEYSHR_LOCK)`

```
t_hoff (HeapTupleHeaderData)
```
* sizeof header incl. bitmap, padding

```
t_bits[FLEXIBLE_ARRAY_MEMBER]; (HeapTupleHeaderData)
```
* bitmap of NULLs

## Queries for `t_infomask` & `t_infomask2`

Useless since pg13 where `heap_tuple_infomask_flags(t_infomask, t_infomask2)` was
introduced.

```
\set t_infomask 2306
SELECT txt, details, :t_infomask AS t_infomask
FROM (VALUES
  ('HEAP_HASNULL'         ,x'0001' ,'has null attribute(s)'),
  ('HEAP_HASVARWIDTH'     ,x'0002' ,'has variable-width attribute(s)'),
  ('HEAP_HASEXTERNAL'     ,x'0004' ,'has external stored attribute(s)'),
  ('HEAP_HASOID_OLD'      ,x'0008' ,'has an object-id field'),
  ('HEAP_XMAX_KEYSHR_LOCK',x'0010' ,'xmax is a key-shared locker'),
  ('HEAP_COMBOCID'        ,x'0020' ,'t_cid is a combo cid'),
  ('HEAP_XMAX_EXCL_LOCK'  ,x'0040' ,'xmax is exclusive locker'),
  ('HEAP_XMAX_LOCK_ONLY'  ,x'0080' ,'xmax, if valid, is only a locker'),
  ('HEAP_XMIN_COMMITTED'  ,x'0100' ,'t_xmin committed'),
  ('HEAP_XMIN_INVALID'    ,x'0200' ,'t_xmin invalid/aborted'),
  ('HEAP_XMAX_COMMITTED'  ,x'0400' ,'t_xmax committed'),
  ('HEAP_XMAX_INVALID'    ,x'0800' ,'t_xmax invalid/aborted'),
  ('HEAP_XMAX_IS_MULTI'   ,x'1000' ,'t_xmax is a MultiXactId'),
  ('HEAP_UPDATED'         ,x'2000' ,'this is UPDATEd version of row'),
  ('HEAP_MOVED_OFF'       ,x'4000' ,'moved to another place by pre-9.0 VACUUM FULL; kept for binary upgrade support'),
  ('HEAP_MOVED_IN'        ,x'8000' ,'moved from another place by pre-9.0 VACUUM FULL; kept for binary upgrade support'),
  ('HEAP_XACT_MASK'       ,x'FFF0' ,'visibility-related bits'),
  ('HEAP_XMIN_FROZEN'     ,x'0100' | x'0200' ,'(HEAP_XMIN_COMMITTED|HEAP_XMIN_INVALID)'),
  ('HEAP_MOVED'           ,x'4000' | x'8000' ,'(HEAP_MOVED_OFF | HEAP_MOVED_IN)'),
  ('HEAP_XMAX_SHR_LOCK'   ,x'0040' | x'0010' ,'(HEAP_XMAX_EXCL_LOCK | HEAP_XMAX_KEYSHR_LOCK)'),
  ('HEAP_LOCK_MASK'       ,x'0040' | x'0010' | x'0040' | x'0010', '(HEAP_XMAX_SHR_LOCK | HEAP_XMAX_EXCL_LOCK | HEAP_XMAX_KEYSHR_LOCK)')
) AS F(txt, mask, details)
WHERE (:t_infomask::bit(16) & mask)::int <> 0
;
```

```
\set t_infomask2 2
SELECT txt, details, :t_infomask2 AS t_infomask2
FROM (VALUES
  ('HEAP_NATTS_MASK'      ,x'07FF' ,'11 bits for number of attributes bits 0x1800 are available'),
  ('HEAP_KEYS_UPDATED'    ,x'2000' ,'tuple was updated and key cols modified, or tuple deleted '),
  ('HEAP_HOT_UPDATED'     ,x'4000' ,'tuple was HOT-updated'),
  ('HEAP2_XACT_MASK'      ,x'E000' ,'visibility-related bits')
) AS F(txt, mask, details)
WHERE (:t_infomask2::bit(16) & mask)::int <> 0
;
```

