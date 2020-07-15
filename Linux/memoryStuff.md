# swap, OVERCOMMIT and Huge Pages

## How to modify 

Modify one of these files : 

* /etc/sysctl.conf
* /etc/sysctl.d/10-postgresql.conf.

Then : 
```
sysctl -p
```

## Swap

swappiness : This control is used to define how aggressive the kernel will swap
memory pages.  Higher values will increase aggressiveness, lower values
decrease the amount of swap.  A value of 0 instructs the kernel not to initiate
swap until the amount of free and file-backed pages is less than the high water
mark in a zone.

For PostgreSQL :

```
vm.swappiness = 10
```

## Huge Page

When a program tries to access it's memory the processor converts the address
of the memory segment  with the Memory Management Unit. It stocks data un the
Page Table (pagination table). One part of the TLB is stored in a cache called
Translation Lookaside Buffer. The TLB is used to convert the addresses into a
physical address.

If the address is not in the TLB, the address must be found into another memory
zone.

When a process is swapped from processor, the TLB must be flushed and the TLB
of the next process must be copied.

Hugepages requiers a processor compatible with pse:
```
pse /proc/cpuinfo 
```

The following parameters govern the use of hugepages : 

* `nr_hugepages` : Change the minimum size of the hugepage pool.
* `nr_hugepages_mempolicy` : Change the size of the hugepage pool at run-time
  on a specific set of NUMA nodes.
* `nr_overcommit_hugepages` : Change the maximum size of the hugepage pool. The
  maximum is `nr_hugepages` + `nr_overcommit_hugepages`.

It is possible to use both `nr_hugepage` and `nr_overcommit_hugepages`.
`nr_hugepage` is always allocated. `nr_overcommit_hugepages` is allocated if
needed.

The values are set in number of pages.

The info is visible in `/proc/meminfo`. 

```
# grep -i huge /proc/meminfo
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
FileHugePages:         0 kB
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
P_HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:               0 kB
```

Where : 

* `HugePages_Total` is the size of the pool of huge pages.
* `HugePages_Free` is the number of huge pages in the pool that are not yet
  allocated.
* `HugePages_Rsvd` is short for "reserved," and is the number of huge pages for
  which a commitment to allocate from the pool has been made, but no allocation
  has yet been made.  Reserved huge pages guarantee that an application will be
  able to allocate a huge page from the pool of huge pages at fault time.
* `HugePages_Surp` is short for "surplus," and is the number of huge pages in
  the pool above the value in /proc/sys/vm/nr_hugepages. The maximum number of
  surplus huge pages is controlled by /proc/sys/vm/nr_overcommit_hugepages
* `AnonHugePages` shows the ammount of memory backed by transparent hugepage.

If transparent hugepage are used, the kernel will transform contiguous
allocation of memory into HP. Il cannot be used for PostgreSQL, therefore THP
should be disabled on a PostgreSQL server.

It is possible to check the usage of memory of a process : 

```
# grep "RssShmem\|VmPTE\|HugetlbPages" /proc/6861/status
RssShmem:	   11016 kB
VmPTE:	     156 kB
HugetlbPages:	       0 kB
```

Where : 

* `RssShmem` show the allocated shared memory.
* `VmPTE` is the pagination table.
* `HugetlbPages` is the memory allocated in Huge Pages.

The memory allocated with hugepage cannot be swapped which is good for
PostgreSQL's `shared_buffers`. Since PG's shared memory is visible to all backends
the PTE is duplicated by the number of backends. For a 8Gb shared buffer size,
it represents 16Mb per backend.

How to do it :

* Add the following to `/etc/rc.local` :

  ```
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
  ```

* Modify grub configuration :


   Edit `/etc/default/grub` : 
   
   ```
   GRUB_CMDLINE_LINUX_DEFAULT="quiet transparent_hugepage=never"
   ```

   Reload the conf : 
   
   ```
   $ sudo update-grub
   Generating grub configuration file ...
   Found linux image: /boot/vmlinuz-4.9.0-7-amd64
   Found initrd image: /boot/initrd.img-4.9.0-7-amd64
   done
   ```

## Pg & memory

The parameter `vm.overcommit_memory` controls the overcommit policy : 

0. Heuristic overcommit handling.  
1. Always overcommit.  
2. Don't overcommit.  The total address space commit for the system is not
   permitted to exceed swap + a configurable amount (default is 50%) of
   physical RAM.

For PostgreSQL, 2 is advised because we don't want the postmaster to be OOM
Killed.

The overcommit amount can be set via `vm.overcommit_ratio' (percentage) or
`vm.overcommit_kbytes' (absolute value).

the result can be seen in `/proc/meminfo` :
```
$ grep Commit /proc/meminfo 
CommitLimit:    11987092 kB
Committed_AS:    9295072 kB
```

Where :

* `CommitLimit`: Based on the overcommit ratio (`vm.overcommit_ratio`), this is
  the total amount of  memory currently available to be allocated on the
  system. This limit is only adhered to if strict overcommit accounting is
  enabled (mode 2 in `vm.overcommit_memory`).  The CommitLimit is calculated
  with the following formula:
  ```
      CommitLimit = ([total RAM pages] - [total huge TLB pages]) *
                      overcommit_ratio / 100 + [total swap pages]
  ```
  For example, on a system with 1G of physical RAM and 7G of swap with a
  `vm.overcommit_ratio` of 30 it would yield a CommitLimit of 7.3G.  For more
  details, see the memory overcommit documentation in vm/overcommit-accounting.

  This is the limit we set.

* `Committed_AS`: The amount of memory presently allocated on the system.  The
  committed memory is a sum of all of the memory which has been allocated by
  processes, even if it has not been "used" by them as of yet. A process which
  malloc()'s 1G of memory, but only touches 300M of it will show up as using
  1G. This 1G is memory which has been "committed" to by the VM and can be used
  at any time by the allocating application. With strict overcommit enabled on
  the system (mode 2 in `vm.overcommit_memory`), allocations which would exceed
  the `CommitLimit` (detailed above) will not be permitted. This is useful if
  one needs to guarantee that processes will not fail due to lack of memory
  once that memory has been successfully allocated.

  This is what is allocated.

### No Huge pages

To compute `CommitLimit` :  

```
CommitLimit = swap_size + ( RAM * overcommit_ratio / 100 )
```

To compute `overcommit_ratio` :

```
overcommit_ratio = ( CommitLimit - swap_size ) * 100 / RAM
```

Or if the swapspace >> 1Gb (usually not advised for Pg) (for a target of 80%) :

```
overcommit_ratio = 80 - 100 (swap_size / RAM_size)
```

For PostgreSQL : 

```
# sysctl vm | grep overcommit
vm.overcommit_memory = 2		# no overcommit
vm.overcommit_ratio = 80		# 20% of the memory is kept for the 
                                        # system to use, 80% for the 
					# applications
vm.overcommit_kbytes = 80% of memory
```
### Huge pages

Huge pages are not part of CommitLimit, therefore to compute CommitLimit :

```
CommitLimit = swap_size + ( RAM - HP_Total_Size ) * overcommit_ratio / 100)

HP_Total_Size = (vm.nr_hugepages + vm.nr_overcommit_hugepages) * Hugepagesize
Hugepagesize = 2Mb
```

To compute `overcommit_ratio` :

```
overcommit_ratio = 100 * ( CommitLimit - swap_size ) / ( RAM - HP_Total_Size )

HP_Total_Size = (vm.nr_hugepages + vm.nr_overcommit_hugepages) * Hugepagesize
```

If there are huge pages of different size the info is in
/sys/kernel/mm/hugepages/hugepages-<size>/*

## Reference

* https://www.kernel.org/doc/Documentation/filesystems/proc.txt
* https://www.kernel.org/doc/Documentation/vm/overcommit-accounting
* https://www.kernel.org/doc/Documentation/sysctl/vm.txt
* https://www.kernel.org/doc/Documentation/vm/hugetlbpage.txt
* https://www.postgresql.org/docs/current/kernel-resources.html#LINUX-HUGE-PAGES
