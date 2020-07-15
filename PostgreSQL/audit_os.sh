#!/bin/sh

export LANG=C

## Server
echo "# Serveur"
hostname

## Matériel

# en tant que root
echo "# Matériel"
echo
echo "## CPU"
echo
lscpu
echo
echo "## Mémoire"
echo
grep -e "^Mem\|^Swap" /proc/meminfo
#### Huge page allocation ?
echo
echo "## Disques"
echo
lsblk
echo

## Système d'exploitation

echo "# Système d'exploitation"
echo
test -f /etc/debian-release && cat /etc/debian-version
echo
test -f /etc/redhat-release && cat /etc/redhat-release
echo
test -f /etc/SuSE-release && cat /etc/SuSE-release
echo
uname -a
echo
echo "## Kernel config"
echo
for f in /proc/sys/vm/dirty_ratio \
         /proc/sys/vm/dirty_background_ratio \
         /proc/sys/vm/dirty_bytes \
         /proc/sys/vm/dirty_background_bytes \
	 /proc/sys/vm/nr* \
	 /proc/sys/vm/overcommit* \
	 /proc/sys/vm/swappiness \
	 /proc/sys/vm/zone_reclaim_mode \
	 /proc/sys/kernel/sched_migration_cost_ns \
	 /proc/sys/kernel/sched_autogroup_enabled \
         /sys/kernel/mm/transparent_hugepage/enabled \
         /sys/kernel/mm/transparent_hugepage/defrag
do
    echo "$f : $(cat $f)"
done
### /!\ trier ?? => /proc/sys/vm/nr_pdflush_threads ??
### page size
echo
echo "## FileSystem Config"
echo
df -hT
echo
cat /etc/fstab
echo 
echo "## Packages"
which rpm &>/dev/null && CMD="rpm -qa" || CMD="dpkg -l"
echo
$CMD | grep postgres
echo
$CMD | grep kernel
echo
$CMD | grep glibc
echo

