```
apst
t-cache search postgresql 9.4

echo c | sudo tee /proc/sysrq-trigger  ==> kernel panic + /etc/sysconfig.conf => kernel.panic = 20 (20 secs avant reboot)

git config --global user.name "NAME"
git config --global user.email "EMAIL"
git config --global core.editor vi

fuser
lsof
lsof -p
ldd

echo 3 > /proc/sys/vm/drop_caches

ssh ${X_CLIENT} "bash -s - ${X_CLIENT} ${X_INSTANCE} ${X_BKPTYPE}" < $ME"_script"

HISTTIMEFORMAT="%d/%m/%y %T "

iostat -xm

# espace

du -ch core.*
du -sh ...

df -k
df -ih

update-rc.d sncf_cluster defaults 20 80
update-rc.d sncf_cluster remove
```

# CPU INFOS

```
lscpu
nuproc
less /proc/cpuinfo
```

# Infos systeme

## LINUX

```
vmstat
sar -W -f
sar -B

export LC_ALL=C
sar -A -f /var/log/sysstat/sa04 > /tmp/$(hostname)_$(date +'%Y%m%d_%H%M')_01.txt
sar -A -f /var/log/sysstat/sa01 > /tmp/$(hostname)_$(date +'%Y%m%d_%H%M')_01.txt

for file in /var/log/sa/sar*; do sar -A -f "$file"  >> /tmp/sar.data3.txt; done


sysctl kernel | grep shm

kernel.shmmax = 33554432	-> Taille max dâ€™un segment de mÃ©moire paratagÃ©e (32 Mo) 
kernel.shmall = 2097152		-> Nbre max de pages pouvant Ãªtre allouÃ©es (8 Go)
kernel.shmmni = 4096		-> Taille dâ€™une page (4 Mo)


ipcs -s -l

------ Semaphore Limits --------
max number of arrays = 128
max semaphores per array = 250
max semaphores system wide = 32000
max ops per semop call = 32
semaphore max value = 32767
```

## AIX

```
prtconf : Displays system configuration information
psrinfo : - displays information about processors
swap -l
vmstat
```

