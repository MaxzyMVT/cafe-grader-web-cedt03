#!/usr/bin/env bash
#
# cafe-cleanup-judge - remove stale per-submission sandbox directories on a
# grader worker:  <judge_path>/isolate_submission/<submission_id>
#
# Why a standalone script (not `rails runner Grader.cleanup_judge`):
#   * runs as root, so it can delete files/dirs owned by isolate sandbox uids
#     (200001..) that grader_admin cannot remove
#   * no rbenv/bundler/Rails boot, so it cannot silently fail on PATH problems
#   * lives in /etc/cron.d, outside the `whenever` managed crontab block, so a
#     regenerated crontab cannot drop it (that is how cleanup vanished in July)
#   * reports real failures: `find ... -exec rm -rf {} \;` exits 0 even when rm
#     fails, so Grader.cleanup_judge logs "completed successfully" regardless
#
# What "stale" means (is_stale below):
#   directory entry: its own mtime is older than 60 min AND no regular file
#   inside it was modified within the age window.
#   Judging by the files inside, not the directory mtime, matters because
#     - a re-judge reuses an old <id> dir and rewrites files without touching
#       the top-level mtime (would be deleted while in use), and
#     - a half-finished removal bumps directory mtimes (would hide its own
#       leftovers for another full window).
#   non-directory entry: its own mtime is older than the age window.
#
# Safety:
#   * refuses unless JUDGE_DIR is an absolute, non-symlink dir named
#     isolate_submission; refuses ages under 60 minutes
#   * never removes JUDGE_DIR itself
#   * rm --one-file-system, never follows symlinks, handles any file name
#   * flock: overlapping runs exit quietly
#   * under disk pressure (used >= PRESSURE_PCT) the age drops to
#     PRESSURE_AGE_MIN so a burst of submissions cannot fill the disk between
#     two normal runs
#
# Env: JUDGE_DIR AGE_MIN(1440) PRESSURE_PCT(80) PRESSURE_AGE_MIN(180)
#      DRY_RUN(0) LOG LOCK
# Exit: 0 ok | 1 some entries could not be removed | 2 refused / bad config

set -u
PATH=/usr/sbin:/usr/bin:/sbin:/bin

JUDGE_DIR="${JUDGE_DIR:-/var/local/cafe_grader/judge/isolate_submission}"
AGE_MIN="${AGE_MIN:-1440}"
PRESSURE_PCT="${PRESSURE_PCT:-80}"
PRESSURE_AGE_MIN="${PRESSURE_AGE_MIN:-180}"
DRY_RUN="${DRY_RUN:-0}"
LOG="${LOG:-/var/log/cafe-cleanup-judge.log}"
LOCK="${LOCK:-/run/lock/cafe-cleanup-judge.lock}"
AGE_FLOOR=60

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG" 2>/dev/null
  printf '%s\n' "$*"
}
die() { log "ABORT: $*"; exit 2; }

# keep the log bounded
if [ -f "$LOG" ] && [ "$(stat -c %s "$LOG" 2>/dev/null || echo 0)" -gt 5242880 ]; then
  tail -n 2000 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
fi

for v in AGE_MIN PRESSURE_PCT PRESSURE_AGE_MIN; do
  [[ "${!v}" =~ ^[0-9]+$ ]] || die "$v must be a non-negative integer (got '${!v}')"
done
[ "$AGE_MIN" -ge "$AGE_FLOOR" ] || die "AGE_MIN=$AGE_MIN is below the safety floor of $AGE_FLOOR minutes"
[ "$PRESSURE_AGE_MIN" -ge "$AGE_FLOOR" ] || die "PRESSURE_AGE_MIN=$PRESSURE_AGE_MIN is below the safety floor of $AGE_FLOOR minutes"

JUDGE_DIR="${JUDGE_DIR%/}"
[[ "$JUDGE_DIR" == /* ]]                      || die "JUDGE_DIR must be absolute (got '$JUDGE_DIR')"
[ "${JUDGE_DIR##*/}" = "isolate_submission" ] || die "JUDGE_DIR must end in /isolate_submission (got '$JUDGE_DIR')"
[ ! -L "$JUDGE_DIR" ]                         || die "JUDGE_DIR is a symlink: $JUDGE_DIR"
if [ ! -d "$JUDGE_DIR" ]; then
  # the grader recreates it (Pathname#mkpath) on the next submission
  [ -d "${JUDGE_DIR%/*}" ] || die "parent of JUDGE_DIR does not exist: ${JUDGE_DIR%/*}"
  log "nothing to do: $JUDGE_DIR does not exist yet"
  exit 0
fi
[ "$(readlink -f "$JUDGE_DIR")" = "$JUDGE_DIR" ] || die "JUDGE_DIR resolves elsewhere: $(readlink -f "$JUDGE_DIR")"

exec 9> "$LOCK" || die "cannot open lock $LOCK"
flock -n 9 || { log "another run is active, exiting"; exit 0; }

used_pct() { df --output=pcent "$JUDGE_DIR" 2>/dev/null | tail -1 | tr -dc '0-9'; }
avail_b()  { df -B1 --output=avail "$JUDGE_DIR" 2>/dev/null | tail -1 | tr -dc '0-9'; }

mode=normal; age=$AGE_MIN
before_pct=$(used_pct); before_avail=$(avail_b)
if [ "${before_pct:-0}" -ge "$PRESSURE_PCT" ]; then mode=pressure; age=$PRESSURE_AGE_MIN; fi

# is_stale <entry>  (uses $age)
is_stale() {
  local e=$1
  if [ -d "$e" ] && [ ! -L "$e" ]; then
    [ -z "$(find "$e" -maxdepth 0 -mmin -"$AGE_FLOOR" -print 2>/dev/null)" ] || return 1
    [ -z "$(find "$e" -mindepth 1 ! -type d -mmin -"$age" -print -quit 2>/dev/null)" ]
  else
    [ -n "$(find "$e" -maxdepth 0 -mmin +"$age" -print 2>/dev/null)" ]
  fi
}

removed=0; kept=0; failed=0; unexpected=0
while IFS= read -r -d '' entry; do
  if ! is_stale "$entry"; then kept=$((kept + 1)); continue; fi
  name=${entry##*/}
  if [ -L "$entry" ] || [ ! -d "$entry" ] || [[ ! "$name" =~ ^[0-9]+$ ]]; then
    unexpected=$((unexpected + 1))
    log "note: unexpected entry (removing, it is stale): $(printf '%q' "$name")"
  fi
  if [ "$DRY_RUN" = "1" ]; then removed=$((removed + 1)); continue; fi

  rm -rf --one-file-system -- "$entry" 2>/dev/null
  if [ -e "$entry" ] || [ -L "$entry" ]; then
    chmod -R u+rwX -- "$entry" 2>/dev/null
    rm -rf --one-file-system -- "$entry" 2>/dev/null
  fi
  if [ -e "$entry" ] || [ -L "$entry" ]; then
    failed=$((failed + 1))
    log "FAILED to remove $(printf '%q' "$entry"); first blocker: $(find "$entry" ! -writable -print -quit 2>/dev/null)"
  else
    removed=$((removed + 1))
  fi
done < <(find "$JUDGE_DIR" -mindepth 1 -maxdepth 1 -print0)

# independent recount with the same predicate: anything still stale must be a reported failure
remaining=0
if [ "$DRY_RUN" != "1" ]; then
  while IFS= read -r -d '' entry; do is_stale "$entry" && remaining=$((remaining + 1)); done \
    < <(find "$JUDGE_DIR" -mindepth 1 -maxdepth 1 -print0)
fi
unaccounted=$((remaining > failed ? remaining - failed : 0))
after_pct=$(used_pct); after_avail=$(avail_b)
freed_mb=$(( (${after_avail:-0} - ${before_avail:-0}) / 1048576 ))
verb=removed; [ "$DRY_RUN" = "1" ] && verb=would_remove

log "mode=$mode age=${age}min dry_run=$DRY_RUN $verb=$removed kept(fresh_or_in_use)=$kept failed=$failed unexpected=$unexpected remaining_stale=$remaining unaccounted=$unaccounted disk=${before_pct}%->${after_pct}% freed=${freed_mb}MB"

[ "$failed" -eq 0 ] && [ "$unaccounted" -le 0 ] && exit 0
exit 1
