#!/bin/bash

for i in /proc/*/smaps; do
    if [[ $(grep '^AnonHugePages' $i | grep -v '0 kB$') ]]; then
        echo -ne "$i procees maybe running THP mode if you are using THP mode in kernel:\n";
    fi;
done
