#!/bin/bash

# One liner: for mproc in $(pgrep -d" " postmaster); do echo $mproc $(ps -p $mproc -o cmd --no-headers) $(grep "Swap" /proc/$mproc/status); done

if [[ -n "$1" ]]; then
	PROCESS_NAME="$1"
else
	PROCESS_NAME="postmaster"
fi

for mproc in $(pgrep -d" " $PROCESS_NAME); do 
	echo $mproc $(ps -p $mproc -o cmd --no-headers) $(grep "Swap" /proc/$mproc/status); 
done
