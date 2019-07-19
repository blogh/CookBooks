#!/bin/bash

### Should run with the user running postgres

TOTAL=0

while read PROC
do
        PID=`echo $PROC | awk '{print $1}'`
        CMD=`echo $PROC | awk '{print substr($0, index($0,$2))}'`
        MEM_PCLEAN=`cat /proc/$PID/smaps | grep 'Private_Clean:' | awk '{print $2}' | awk '{s+=$1} END {print s}'`
        MEM_PDIRTY=`cat /proc/$PID/smaps | grep 'Private_Dirty:' | awk '{print $2}' | awk '{s+=$1} END {print s}'`
        MEM=`expr $MEM_PCLEAN + $MEM_PDIRTY`
        TOTAL=`expr $TOTAL + $MEM`
        echo "[$PID][$CMD][$MEM kB]"
done < <(ps -u postgres o pid= o cmd= | grep 'postgres:' | grep -v grep)
echo "[Total][$TOTAL kB]"
