#!/usr/bin/env bash
#
# Clean up backups older than N days by parsing the date in the filename.
# This prevents deletion errors if file metadata timestamps changed during transfer.
#
# Also enforces a hard size cap (MAX_SIZE_GB) on the backup directory: if the
# day-based prune above still leaves the set over the cap, the oldest backups
# are removed next regardless of age. Day-based retention alone assumes each
# day's backup stays roughly the same size - if the underlying app data grows,
# a fixed KEEP_DAYS window grows right along with it and can still run the
# disk to 100%. The size cap is the backstop for that.
#
# Usage:
#   ./cleanup-backups.sh [backup_directory] [days_to_keep] [max_size_gb]
# Example:
#   ./cleanup-backups.sh ~/cafe-grader-backups 2 35

set -euo pipefail

TARGET_DIR="${1:-$HOME/cafe-grader-backups}"
KEEP_DAYS="${2:-3}"
MAX_SIZE_GB="${3:-20}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory $TARGET_DIR does not exist."
  exit 1
fi

# Calculate cutoff date in seconds (midnight of the cutoff day)
CUTOFF_SEC=$(date -d "$KEEP_DAYS days ago" +%s)
CUTOFF_DATE=$(date -d "@$CUTOFF_SEC" +%F)

echo "=== Pruning backups older than $KEEP_DAYS days (Cutoff: $CUTOFF_DATE) ==="

# Recursively locate backup files
find "$TARGET_DIR" -type f \( -name "db_*.gz" -o -name "files_*.gz" -o -name "worker_*.gz" -o -name "judge_*.gz" \) | while read -r file; do
  filename=$(basename "$file")
  
  # Match date pattern YYYY-MM-DD from the filename
  if [[ "$filename" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
    file_date="${BASH_REMATCH[1]}"
    file_sec=$(date -d "$file_date" +%s 2>/dev/null || continue)
    
    # Delete if file date is older than cutoff date
    if [ "$file_sec" -lt "$CUTOFF_SEC" ]; then
      echo "  Deleting: $file (Filename Date: $file_date)"
      rm -f "$file"
    fi
  fi
done

# Size cap: even backups still within KEEP_DAYS get pruned oldest-first if the
# backup set as a whole has grown past MAX_SIZE_GB.
MAX_SIZE_KB=$(( MAX_SIZE_GB * 1024 * 1024 ))
CURRENT_SIZE_KB=$(du -sk "$TARGET_DIR" 2>/dev/null | awk '{print $1}')
CURRENT_SIZE_KB="${CURRENT_SIZE_KB:-0}"

if [ "$CURRENT_SIZE_KB" -gt "$MAX_SIZE_KB" ]; then
  echo "=== Backup set is $((CURRENT_SIZE_KB/1024))MB, over the ${MAX_SIZE_GB}GB cap - pruning oldest first ==="
  find "$TARGET_DIR" -type f \( -name "db_*.gz" -o -name "files_*.gz" -o -name "worker_*.gz" -o -name "judge_*.gz" \) | while read -r file; do
    filename=$(basename "$file")
    # Sort key = the date_time embedded in the filename (fixed-width, so lexical sort == chronological)
    if [[ "$filename" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}) ]]; then
      echo "${BASH_REMATCH[1]} $file"
    fi
  done | sort | while read -r _ file; do
    [ "$CURRENT_SIZE_KB" -le "$MAX_SIZE_KB" ] && break
    SIZE_KB=$(du -sk "$file" 2>/dev/null | awk '{print $1}')
    echo "  Size-pruning: $file"
    rm -f "$file"
    CURRENT_SIZE_KB=$(( CURRENT_SIZE_KB - ${SIZE_KB:-0} ))
  done
fi

# Cleanup local /tmp/cafebk files older than 1 day
if [ -d "/tmp/cafebk" ]; then
  echo "=== Cleaning up /tmp/cafebk files older than 1 day ==="
  find /tmp/cafebk -type f -mtime +1 -name '*.gz' -delete 2>/dev/null || true
fi

# Disk Space Safeguard: If disk usage is above 90%, remove backups older than 1 day immediately
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
  echo "WARNING: Disk space is extremely low (${DISK_USAGE}% used). Emergency pruning backups to 1 day."
  EMERGENCY_CUTOFF_SEC=$(date -d "1 days ago" +%s)
  find "$TARGET_DIR" -type f \( -name "db_*.gz" -o -name "files_*.gz" -o -name "worker_*.gz" -o -name "judge_*.gz" \) | while read -r file; do
    filename=$(basename "$file")
    if [[ "$filename" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      file_date="${BASH_REMATCH[1]}"
      file_sec=$(date -d "$file_date" +%s 2>/dev/null || continue)
      if [ "$file_sec" -lt "$EMERGENCY_CUTOFF_SEC" ]; then
        echo "  Emergency Deleting: $file"
        rm -f "$file"
      fi
    fi
  done
  # Also clear all /tmp/cafebk files to free up space
  rm -f /tmp/cafebk/*.gz 2>/dev/null || true
fi

echo "=== Cleanup completed ==="
