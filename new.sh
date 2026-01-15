#!/usr/bin/env bash

set -u

TARGET_UID=1008

total_procs=0
user_procs=0
total_kb=0

for dir in /proc/[0-9]*; do
    pid=${dir##*/}

    status_file="$dir/status"

    
    [[ -r "$status_file" ]] || continue

    total_procs=$((total_procs + 1))

    
    uid=$(grep "^Uid:" "$status_file" 2>/dev/null | awk '{print $2}')

    if [[ "$uid" == "$TARGET_UID" ]]; then
        user_procs=$((user_procs + 1))

        
        rss_kb=$(grep "^VmRSS:" "$status_file" 2>/dev/null | awk '{print $2}')
        rss_kb=${rss_kb:-0}

        total_kb=$((total_kb + rss_kb))
    fi
done

total_mb=$((total_kb / 1024))

echo "Συνολικό πλήθος διεργασιών: $total_procs"
echo "Διεργασίες του user ls1 (UID 1008): $user_procs"
echo "Συνολική μνήμη (VmRSS) του ls1: ${total_mb} MB"
