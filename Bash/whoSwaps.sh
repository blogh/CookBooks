#! /bin/bash

find /proc \
     -maxdepth 2 \
     -path "/proc/[0-9]*/status" \
     -readable \
     -exec awk \
     -v FS=":" '{process[$1]=$2;sub(/^[ \t]+/,"",process[$1]);} END {if(process["VmSwap"] && process["VmSwap"] != "0 kB") 	printf "%10s | %-30s | %20s | %20s\n",process["Pid"],process["State"],process["Name"],process["VmSwap"]}' '{}' \; | sort -n -k4 -t'|'
