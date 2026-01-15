#!/usr/bin/env bash




set -u

TARGET_UID=1008

total_procs=0
ls1_procs=0
ls1_rss_kb=0


for d in /proc/[0-9]*; do
  
  [[ -d "$d" ]] || continue

  pid=${d##*/}
  status="$d/status"

  
  ((total_procs++))

  
  [[ -r "$status" ]] || continue

  
  
  read -r uid rss_kb < <(
    awk '
      $1=="Uid:"   {uid=$2}
      $1=="VmRSS:" {rss=$2}
      END { if (uid=="") uid=-1; if (rss=="") rss=0; print uid, rss }
    ' "$status" 2>/dev/null
  ) || continue

  
  [[ "$uid" =~ ^[0-9]+$ ]] || continue

  if (( uid == TARGET_UID )); then
    ((ls1_procs++))
    
    if [[ "$rss_kb" =~ ^[0-9]+$ ]]; then
      ((ls1_rss_kb += rss_kb))
    fi
  fi

done


ls1_rss_mb=$(awk -v kb="$ls1_rss_kb" 'BEGIN{printf "%.2f", kb/1024.0}')

printf "Σύνολο διεργασιών: %d\n" "$total_procs"
printf "Διεργασίες του χρήστη ls1 (UID %d): %d\n" "$TARGET_UID" "$ls1_procs"
printf "Συνολική μνήμη διεργασιών ls1 (VmRSS): %s MB\n" "$ls1_rss_mb"
