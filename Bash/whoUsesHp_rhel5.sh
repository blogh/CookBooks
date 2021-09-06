#!/bin/bash
# https://access.redhat.com/solutions/74053

which bc >&/dev/null || echo "This script requires bc."

# 50MB difference is what we use as trigger.
LIMIT=51200

if [[ $(cat /proc/meminfo | grep '^HugePages_Total:' | awk '{print $2}') -eq 0 ]]; then 
    echo "According to /proc/meminfo no hugepages are used."; 
    exit 0;
fi

for i in /proc/*/status; do
        if $( grep -q ^Vm $i ); then
                # echo "inspecting $i :";
                # cat $i | egrep 'VmPeak|VmSize';
                PEAK=$( grep ^VmPeak "$i" | awk '{print $2}' );
                SIZE=$( grep ^VmSize "$i" | awk '{print $2}' );
		PROCESS=$(echo "$i" | sed -e 's/^\/proc\/\(.*\)\/status$/\1/')
                if [[ $(($PEAK - $SIZE)) -gt $LIMIT ]]; then
			echo "***************************************"
			ps -fp $PROCESS
                        echo "According to $i a processes VmPeak is more than $LIMIT kb bigger than VmSize."
                        echo "The difference of VmPeak - VmSize is: $(($PEAK - $SIZE)) kb."
                        echo "The process is likely to use HugePages."
                fi
        fi;
done
