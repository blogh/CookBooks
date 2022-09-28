# CPU

## Architecture

Physical processor => Socket => Core => Thread (= virtual core)

## Were is the info ?

```
lscpu

cat  /proc/cpuinfo
grep "^physical id" /proc/cpuinfo | sort -u | wc -l # Sockets
grep "^core id" /proc/cpuinfo | sort -u | wc -l     # Cores
grep "^core id" /proc/cpuinfo | sort | uniq -c      # Thread per core
```

## Numa

### Architecture

From: https://blog.jcole.us/2010/09/28/mysql-swap-insanity-and-the-numa-architecture/

**The SMP/UMA architecture**

When the PC world first got multiple processors, they were all arranged with
equal access to all of the memory in the system. This is called Symmetric
Multi-processing (SMP), or sometimes Uniform Memory Architecture (UMA,
especially in contrast to NUMA). In the past few years this architecture has
been largely phased out between physical socketed processors, but is still
alive and well today within a single processor with multiple cores: all cores
have equal access to the memory bank.

**The NUMA architecture**

The new architecture for multiple processors, starting with AMD’s Opteron and
Intel’s Nehalem2 processors (we’ll call these “modern PC CPUs”), is a
Non-Uniform Memory Access (NUMA) architecture, or more correctly Cache-Coherent
NUMA (ccNUMA). In this architecture, each processor has a “local” bank of
memory, to which it has much closer (lower latency) access. The whole system
may still operate as one unit, and all memory is basically accessible from
everywhere, but at a potentially higher latency and lower performance.

Fundamentally, some memory locations (“local” ones) are faster, that is, cost
less to access, than other locations (“remote” ones attached to other
processors). For a more detailed discussion of NUMA implementation and its
support in Linux, see https://lwn.net/Articles/254445/.

Linux automatically understands when it’s running on a NUMA architecture system
and does a few things:

* Enumerates the hardware to understand the physical layout.
* Divides the processors (not cores) into “nodes”. With modern PC processors,
  this means one node per physical processor, regardless of the number of cores
  present.
* Attaches each memory module in the system to the node for the processor it is
  local to.
* Collects cost information about inter-node communication (“distance” between
  nodes).

Technically, as long as everything runs just fine, there’s no reason that being
UMA or NUMA should change how things work at the OS level. However, if you’re
to get the best possible performance (and indeed in some cases with extreme
performance differences for non-local NUMA access, any performance at all) some
additional work has to be done, directly dealing with the internals of NUMA.
Linux does the following things which might be unexpected if you think of CPUs
and memory as black boxes:

* Each process and thread inherits, from its parent, a NUMA policy. The
  inherited policy can be modified on a per-thread basis, and it defines the
  CPUs and even individual cores the process is allowed to be scheduled on,
  where it should be allocated memory from, and how strict to be about those
  two decisions.
* Each thread is initially allocated a “preferred” node to run on. The thread
  can be run elsewhere (if policy allows), but the scheduler attempts to ensure
  that it is always run on the preferred node.
* Memory allocated for the process is allocated on a particular node, by
  default “current”, which means the same node as the thread is preferred to
  run on. On UMA/SMP architectures all memory was treated equally, and had the
  same cost, but now the system has to think a bit about where it comes from,
  because accessing non-local memory has implications on performance and may
  cause cache coherency delays.
* Memory allocations made on one node will not be moved to another node,
  regardless of system needs. Once memory is allocated on a node, it will stay
  there.

The NUMA policy of any process can be changed, with broad-reaching effects,
very simply using numactl as a wrapper for the program. With a bit of
additional work, it can be fine-tuned in detail by linking in libnuma and
writing some code yourself to manage the policy. Some interesting things that
can be done simply with the numactl wrapper are:

* Allocate memory with a particular policy:
  + locally on the “current” node — using --localalloc, and also the default
    mode
  + preferably on a particular node, but elsewhere if necessary — using
    --preferred=node
  + always on a particular node or set of nodes — using --membind=nodes
  + interleaved, that is, spread evenly round-robin across all or a set of
    nodes — using --interleaved=all or --interleaved=nodes
* Run the program on a particular node or set of nodes, in this case that means
  physical CPUs (--cpunodebind=nodes) or on a particular core or set of cores
  (--physcpubind=cpus).

Using the default NUMA policy, with two numa nodes, memory was preferentially
allocated in Node 0, but Node 1 was used as a last resort.

One NUMA node car be starved for memory and swap, while the other has free
space.

### zone reclaim mode


**The kernel documentation**

Zone_reclaim_mode allows someone to set more or less aggressive approaches to
reclaim memory when a zone runs out of memory. If it is set to zero then no
zone reclaim occurs. Allocations will be satisfied from other zones / nodes
in the system.

This is value ORed together of

0       = Disable
1	= Zone reclaim on
2	= Zone reclaim writes dirty pages out
4	= Zone reclaim swaps pages

zone_reclaim_mode is disabled by default. For file servers or workloads
that benefit from having their data cached, zone_reclaim_mode should be
left disabled as the caching effect is likely to be more important than
data locality.

>
> A database benefits from having theri data cached.
> 
> Since processes inherit the affinity of the core they run on. If the memory
> bank of a NUMA node is full and zone_reclaim_mode is activated, the memory
> will be reclaimed from the local memory to free some space instead of
> allocating memory in an other memory zone.
>
> It will therefore reduce the effectiveness of the cache. 
>

zone_reclaim may be enabled if it's known that the workload is partitioned
such that each partition fits within a NUMA node and that accessing remote
memory would cause a measurable performance reduction.  The page allocator
will then reclaim easily reusable pages (those page cache pages that are
currently not used) before allocating off node pages.

Allowing zone reclaim to write out pages stops processes that are
writing large amounts of data from dirtying pages on other nodes. Zone
reclaim will write out dirty pages if a zone fills up and so effectively
throttle the process. This may decrease the performance of a single process
since it cannot use all of system memory to buffer the outgoing writes
anymore but it preserve the memory on other nodes so that the performance
of other processes running on other nodes will not be affected.

Allowing regular swap effectively restricts allocations to the local
node unless explicitly overridden by memory policies or cpuset
configurations.

**Pg mailing list**

From : https://www.postgresql.org/message-id/500616CB.3070408@2ndQuadrant.com

There is no true default for this setting.  Linux checks the hardware and turns
this on/off based on what transfer rate it sees between NUMA nodes, where there
are more than one and its test shows some distance between them.  You can tell
if this is turned on like this:

```
echo /proc/sys/vm/zone_reclaim_mode
```

Where 1 means it's enabled. 

`numactl` show the numa zones. If the distance between nodes (cross zone
timing) is big (0>1 & 1>0) zone reclaim is activated.

```
$ numactl --hardware
available: 1 nodes (0)
node 0 cpus: 0 1 2 3 4 5 6 7
node 0 size: 7637 MB
node 0 free: 664 MB
node distances:
node   0
  0:  10

$ numactl --hardware
available: 2 nodes (0-1)
node 0 cpus: 0 1 2 3 4 5 12 13 14 15 16 17
node 0 size: 73718 MB
node 0 free: 419 MB
node 1 cpus: 6 7 8 9 10 11 18 19 20 21 22 23
node 1 size: 73728 MB
node 1 free: 30 MB
node distances:
node   0   1
   0:  10  21
   1:  21  10
```

## Were is the info ?

```
numactl --hardware
```

```
cat /proc/pid/numa_maps
```

In this example, N0 tells the amount of memory on NUMA node 0: 
```
7f589c000000 default anon=19 dirty=19 active=0 N0=19 kernelpagesize_kB=4
```
