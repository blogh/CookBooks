#!/bin/sh

export LANG=C

Help()
{
   # Display Help
   echo "Syntax: $0 [-h]"
   echo "Description: This script extract data a from the OS. On debian you might want to use a root user besauce we list the content of dmesg."
   echo "Options:"
   echo " -h   Print the help message."
}

# fetch option values
while getopts "h" option; do
   case $option in
      h) # display Help
         Help
         exit;;
#      *)
#         Help
#         exit 2;;
   esac
done

## Server
echo "# Serveur"
hostname

## Matériel

# en tant que root
echo "# Matériel"
echo
echo "## Matériel/CPU"
echo
lscpu
echo 
echo "## Matériel/NUMA"
echo
numactl --show
echo
echo "## Matériel/Mémoire"
echo
cat /proc/meminfo
echo
free -m
echo
echo "## Matériel/Disques"
echo
lsblk -o NAME,TYPE,SIZE,SCHED,ROTA,MOUNTPOINT
echo
echo
echo "## Matériel/Réseau"
echo
ip ad
echo

## Système d'exploitation

echo "# OS"
echo
test -f /etc/os-release && cat /etc/os-release
echo
test -f /etc/debian-release && cat /etc/debian-version
echo
test -f /etc/redhat-release && cat /etc/redhat-release
echo
test -f /etc/SuSE-release && cat /etc/SuSE-release
echo
uname -a
echo
echo "## OS/Kernel config"
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
echo "## OS/FileSystem Config"
echo
df -hT
echo
cat /etc/fstab
echo 
echo "## OS/Packages"
echo 
which rpm &>/dev/null && CMD="rpm -qa" || CMD="dpkg -l"
echo
$CMD | grep postgres
echo
$CMD | grep kernel
echo
echo "## OS/glibc"
echo
ldd --version
echo
echo "## OS/dmesg"
echo
dmesg
