#!/usr/bin/env bash
# new.sh
# Υπολογισμός πλήθους διεργασιών & χρήσης μνήμης από procfs (/proc) μόνο.
# Επιλογή μνήμης: VmRSS (kB) από /proc/<pid>/status (πιο ρεαλιστική για RAM).

set -u

TARGET_UID=1008

total_procs=0
ls1_procs=0
ls1_rss_kb=0

# Loop μόνο σε αριθμητικούς καταλόγους /proc/[0-9]*
for d in /proc/[0-9]*; do
  # Αν δεν είναι κατάλογος, αγνόησε
  [[ -d "$d" ]] || continue

  pid=${d##*/}
  status="$d/status"

  # Μετράμε τη διεργασία αν υπάρχει ο κατάλογος /proc/<pid>
  ((total_procs++))

  # Διαχειριζόμαστε races/permissions: αν δεν διαβάζεται, συνέχισε
  [[ -r "$status" ]] || continue

  # Διαβάζουμε Uid και VmRSS από το status με ένα awk πέρασμα
  # Αν λείπει VmRSS (μερικές kernel threads), θεωρείται 0.
  read -r uid rss_kb < <(
    awk '
      $1=="Uid:"   {uid=$2}
      $1=="VmRSS:" {rss=$2}
      END { if (uid=="") uid=-1; if (rss=="") rss=0; print uid, rss }
    ' "$status" 2>/dev/null
  ) || continue

  # uid μπορεί να είναι -1 αν το awk δεν βρήκε Uid λόγω race
  [[ "$uid" =~ ^[0-9]+$ ]] || continue

  if (( uid == TARGET_UID )); then
    ((ls1_procs++))
    # rss_kb μπορεί να μην είναι αριθμός αν status άλλαξε κατά την ανάγνωση
    if [[ "$rss_kb" =~ ^[0-9]+$ ]]; then
      ((ls1_rss_kb += rss_kb))
    fi
  fi

done

# Μετατροπή σε MB (KB/1024). Κρατάμε 2 δεκαδικά.
ls1_rss_mb=$(awk -v kb="$ls1_rss_kb" 'BEGIN{printf "%.2f", kb/1024.0}')

printf "Σύνολο διεργασιών: %d\n" "$total_procs"
printf "Διεργασίες του χρήστη ls1 (UID %d): %d\n" "$TARGET_UID" "$ls1_procs"
printf "Συνολική μνήμη διεργασιών ls1 (VmRSS): %s MB\n" "$ls1_rss_mb"
