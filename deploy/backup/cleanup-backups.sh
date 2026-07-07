#!/usr/bin/env bash
#
# Clean up backups older than N days by parsing the date in the filename.
# This prevents deletion errors if file metadata timestamps changed during transfer.
#
# Usage:
#   ./cleanup-backups.sh [backup_directory] [days_to_keep]
# Example:
#   ./cleanup-backups.sh ~/cafe-grader-backups 3

set -euo pipefail

TARGET_DIR="${1:-$HOME/cafe-grader-backups}"
KEEP_DAYS="${2:-3}"

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

echo "=== Cleanup completed ==="
