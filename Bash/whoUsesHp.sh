#!/bin/bash
# https://access.redhat.com/solutions/320303?sc_cid=cp

set -o pipefail

if [[ $(grep '^HugePages_Total:' /proc/meminfo | awk '{print $2}') -eq 0 ]]; then 
    echo "According to /proc/meminfo no hugepages are used."; 
    exit 0;
fi

for i in /proc/*/smaps; do
	PROCESS=$(echo "$i" | sed -e 's/^\/proc\/\(.*\)\/smaps$/\1/')
	HPSIZE=$(grep -B 11 'KernelPageSize:     2048 kB' "$i" | grep "^Size:" | awk 'BEGIN{sum=0}{sum+=$2}END{print sum/1024}')
	RC=$?
	if [[ "$RC" -eq "0" ]]; then
		echo "LOG ***************************************"
		echo "LOG process $PROCESS is using $HPSIZE huge pages (data from :$i)"
		echo "LOG $(ps -fp "$PROCESS" | tail -n1)"
        fi;
done
