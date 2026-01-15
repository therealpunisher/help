#!/usr/bin/env bash
# new.sh
# Υπολογισμός πλήθους διεργασιών & χρήσης μνήμης από procfs (/proc) μόνο.
# Επιλογή μνήμης: VmRSS (kB) από /proc/<pid>/status.
# (Έκδοση με grep για Uid/VmRSS.)

set -u

TARGET_UID=1008

total_procs=0
ls1_procs=0
ls1_rss_kb=0

# Loop μόνο σε αριθμητικούς καταλόγους /proc/[0-9]*
for d in /proc/[0-9]*; do
  [[ -d "$d" ]] || continue

  status="$d/status"

  # Μετράμε διεργασία αν υπάρχει ο κατάλογος /proc/<pid>
  ((total_procs++))

  # Races/permissions: αν δεν διαβάζεται, συνέχισε
  [[ -r "$status" ]] || continue

  # UID (1ο numeric πεδίο μετά το Uid:)
  uid=$(grep '^Uid:' "$status" 2>/dev/null | awk '{print $2}')
  [[ "${uid:-}" =~ ^[0-9]+$ ]] || continue

  if (( uid == TARGET_UID )); then
    ((ls1_procs++))

    # VmRSS σε kB (αν λείπει, θεωρείται 0)
    rss_kb=$(grep '^VmRSS:' "$status" 2>/dev/null | awk '{print $2}')
    rss_kb=${rss_kb:-0}
    [[ "$rss_kb" =~ ^[0-9]+$ ]] || rss_kb=0

    ((ls1_rss_kb += rss_kb))
  fi

done

# Μετατροπή σε MB (KB/1024) με 2 δεκαδικά
ls1_rss_mb=$(awk -v kb="$ls1_rss_kb" 'BEGIN{printf "%.2f", kb/1024.0}')

printf "Σύνολο διεργασιών: %d\n" "$total_procs"
printf "Διεργασίες του χρήστη ls1 (UID %d): %d\n" "$TARGET_UID" "$ls1_procs"
printf "Συνολική μνήμη διεργασιών ls1 (VmRSS): %s MB\n" "$ls1_rss_mb"
