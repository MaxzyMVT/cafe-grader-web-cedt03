#!/usr/bin/env bash
#
# Cafe-Grader — one-shot backup installer (Layer B: app backups -> Huawei OBS).
#
# Run this ONCE on each server. It does everything:
#   - installs obsutil (if missing) and connects it to your OBS account
#   - sets the clock to Asia/Bangkok
#   - copies the right backup script to /opt/cafe-backup
#   - installs the cron schedule (hourly+daily for web+db, weekly for a worker)
#   - runs one backup immediately so you know it works
#
# Usage:
#   sudo ./install.sh                 # interactive — it asks a few questions
#   sudo ROLE=web-db OBS_BUCKET=... OBS_AK=... OBS_SK=... ./install.sh   # non-interactive
#
# (Whole-VM disk snapshots = Layer A = a separate one-time step; see huawei-cbr-setup.sh / README.)

set -euo pipefail

# --- must be root ------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo:  sudo ./install.sh"; exit 1; }

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="/opt/cafe-backup"

ask() { # ask VAR "Prompt" "default"   (skips if VAR already set in env)
  local var="$1" prompt="$2" def="${3:-}" cur ans
  cur="$(eval "printf '%s' \"\${$var:-}\"")"
  if [ -n "$cur" ]; then return; fi
  if [ -n "$def" ]; then read -rp "$prompt [$def]: " ans; ans="${ans:-$def}"
  else read -rp "$prompt: " ans; fi
  eval "$var=\$ans"
}
ask_secret() { # ask_secret VAR "Prompt"  (no echo)
  local var="$1" prompt="$2" cur ans
  cur="$(eval "printf '%s' \"\${$var:-}\"")"
  if [ -n "$cur" ]; then return; fi
  read -rsp "$prompt: " ans; echo; eval "$var=\$ans"
}

echo "=== Cafe-Grader backup installer ==="

# --- gather settings ---------------------------------------------------------
ask ROLE         "Server role — type 'web-db' or 'worker'" "web-db"
case "$ROLE" in web-db|worker) ;; *) echo "ROLE must be web-db or worker"; exit 1;; esac

ask APP_DIR      "Path to the Rails app" "/home/grader/cafe-grader-web"
[ -d "$APP_DIR" ] || echo "  (note: $APP_DIR not found yet — make sure it's correct)"

ask OBS_BUCKET   "OBS bucket name to store backups" "cafe-grader-backups"
ask OBS_ENDPOINT "OBS endpoint for your region" "obs.ap-southeast-2.myhuaweicloud.com"
ask OBS_AK       "OBS Access Key (AK)"
ask_secret OBS_SK "OBS Secret Key (SK)"

DB_PASS="${DB_PASS:-}"
if [ "$ROLE" = "web-db" ]; then
  ask DB_USER    "MySQL username" "grader"
  ask_secret DB_PASS "MySQL password (leave blank if ~/.my.cnf already set)"
fi

# --- 1. timezone -------------------------------------------------------------
echo "==> Setting timezone to Asia/Bangkok"
timedatectl set-timezone Asia/Bangkok || echo "  (could not set timezone; set it manually)"

# --- 2. obsutil --------------------------------------------------------------
if ! command -v obsutil >/dev/null; then
  echo "==> Installing obsutil"
  tmp="$(mktemp -d)"; pushd "$tmp" >/dev/null
  wget -q https://obs-community.obs.cn-north-1.myhuaweicloud.com/obsutil/current/obsutil_linux_amd64.tar.gz
  tar xzf obsutil_linux_amd64.tar.gz
  install -m 0755 obsutil_linux_amd64_*/obsutil /usr/local/bin/obsutil
  popd >/dev/null; rm -rf "$tmp"
fi
echo "==> Connecting obsutil to your account"
obsutil config -i="$OBS_AK" -k="$OBS_SK" -e="$OBS_ENDPOINT" >/dev/null
# create the bucket (ignore error if it already exists)
obsutil mb "obs://$OBS_BUCKET" >/dev/null 2>&1 || true

# --- 3. MySQL credentials (web-db only) --------------------------------------
if [ "$ROLE" = "web-db" ] && [ -n "$DB_PASS" ]; then
  echo "==> Writing /root/.my.cnf (chmod 600)"
  umask 077
  printf '[client]\nuser=%s\npassword=%s\n' "${DB_USER:-grader}" "$DB_PASS" > /root/.my.cnf
  umask 022
fi

# --- 4. install backup scripts ----------------------------------------------
echo "==> Installing backup scripts to $DEST_DIR"
mkdir -p "$DEST_DIR" /var/backups/cafe-grader
install -m 0755 "$SRC_DIR/backup-web-db.sh" "$DEST_DIR/backup-web-db.sh"
install -m 0755 "$SRC_DIR/backup-worker.sh" "$DEST_DIR/backup-worker.sh"

# --- 5. cron schedule (idempotent — one file in /etc/cron.d) -----------------
CRON_FILE="/etc/cron.d/cafe-grader-backup"
echo "==> Writing schedule to $CRON_FILE"
{
  echo "# Cafe-Grader backups — managed by install.sh. Edit timing here if needed."
  echo "SHELL=/bin/bash"
  echo "PATH=/usr/local/bin:/usr/bin:/bin"
  echo "APP_DIR=$APP_DIR"
  echo "OBS_BUCKET=$OBS_BUCKET"
  echo
  if [ "$ROLE" = "web-db" ]; then
    echo "# hourly — database only (light, no table locks)"
    echo "15 * * * * root BACKUP_LABEL=db INCLUDE_STORAGE=0 INCLUDE_DATA=0 OBS_PREFIX=web-db/hourly KEEP_LOCAL_DAYS=2 $DEST_DIR/backup-web-db.sh >> /var/log/cafe-backup.log 2>&1"
    echo "# daily 02:30 — full (database + storage/ + configs)"
    echo "30 2 * * * root BACKUP_LABEL=full INCLUDE_STORAGE=1 OBS_PREFIX=web-db/daily KEEP_LOCAL_DAYS=7 $DEST_DIR/backup-web-db.sh >> /var/log/cafe-backup.log 2>&1"
  else
    echo "# weekly Sun 03:00 — worker config + judge dir"
    echo "0 3 * * 0 root $DEST_DIR/backup-worker.sh >> /var/log/cafe-backup.log 2>&1"
  fi
} > "$CRON_FILE"
chmod 0644 "$CRON_FILE"

# --- 6. run one backup now ---------------------------------------------------
echo "==> Running a first backup now (proves it works)"
if [ "$ROLE" = "web-db" ]; then
  APP_DIR="$APP_DIR" OBS_BUCKET="$OBS_BUCKET" BACKUP_LABEL=full \
    OBS_PREFIX=web-db/daily INCLUDE_STORAGE=1 "$DEST_DIR/backup-web-db.sh"
else
  APP_DIR="$APP_DIR" OBS_BUCKET="$OBS_BUCKET" "$DEST_DIR/backup-worker.sh"
fi

cat <<EOF

=== DONE ===
  Role     : $ROLE
  Backups  : obs://$OBS_BUCKET/
  Schedule : $CRON_FILE
  Log      : /var/log/cafe-backup.log

Next:
  - Set up whole-VM snapshots (Layer A) once — see README "Whole-server snapshots".
  - In OBS console, add Lifecycle Rules to auto-delete old backups (see README step 6).
  - Check it landed:  obsutil ls obs://$OBS_BUCKET/
EOF
