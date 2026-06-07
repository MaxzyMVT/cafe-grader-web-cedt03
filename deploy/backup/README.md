# Backups & Crash Recovery — Cafe-Grader on Huawei Cloud

**New here? Read this first.** This folder protects the Cafe-Grader servers so that if
something breaks — a server dies, a database gets wiped, someone deletes the wrong thing —
you can get everything back. You do **not** need to be a backup expert. Follow the steps.

---

## 1. The big picture (in plain words)

Cafe-Grader runs on **3 servers** (called "VMs" — virtual machines):

| Nickname | Job |
|----------|-----|
| **web+db** | Runs the website *and* the MySQL database (students, problems, test cases, submissions). This is the important one. |
| **worker 1** | Compiles and grades student code. |
| **worker 2** | Same as worker 1 — a second grader. |

We protect them **two different ways**, because each catches a different kind of disaster:

| Backup type | Think of it as… | Saves you from… |
|-------------|-----------------|-----------------|
| **A. Disk snapshot (CBR)** | A photo of the *entire* server (operating system + everything on disk) | The whole server dying. You boot a fresh server from the photo. |
| **B. App backup (to OBS)** | A zip file of *just the data* (database + uploads + settings) | "Oops" mistakes — someone deletes data, the DB corrupts. You restore just the data, anywhere. |

**Use both.** Snapshots get you running fast after a crash. App backups let you recover a single
deleted thing, and can be restored onto any server (even a different cloud).

---

## 2. Words you'll see (mini glossary)

You don't have to memorize these — glance back when a term shows up.

- **VM / server / instance** — one computer in the cloud. We have 3.
- **ECS** — Huawei's name for a VM ("Elastic Cloud Server").
- **CBR** — Huawei's backup service for whole servers ("Cloud Backup and Recovery"). Makes the disk snapshots.
- **Vault** — a storage box in CBR that holds your snapshots.
- **OBS** — Huawei's file storage in the cloud ("Object Storage Service"), like a Google Drive bucket. Our zip-file backups live here.
- **Bucket** — one folder/container inside OBS.
- **`obsutil`** — a command-line tool to upload/download files to OBS.
- **`hcloud` (KooCLI)** — Huawei's command-line tool to control the cloud (create vaults, etc.).
- **cron** — the built-in Linux scheduler. It runs our backup script automatically (e.g. every hour).
- **RPO** — "how much recent data could I lose?" If backups run hourly, you could lose up to ~1 hour.
- **EIP** — a public IP address attached to a server.

---

## 3. What actually gets saved (and why it matters)

**On web+db (the important server):**
- The **MySQL databases** `grader` and `grader_queue` — *everything*: users, problems, test cases, submissions, contests.
- `config/master.key` — the key that unlocks the app's encrypted secrets. **If this is lost, the secrets are gone forever.** Always backed up.
- Settings files not stored in Git: `database.yml`, `worker.yml`, `llm.yml`, `credentials.yml.enc`.
- `storage/` — uploaded files (problem attachments, statements).

**On each worker:**
- `config/worker.yml` — the worker's identity (its ID and password to talk to the server).
- The judge folder (any custom grading scripts).
- Workers mostly just do grading work and keep little of their own, so they're backed up lightly.

---

## 4. How often backups happen

You set this up once; then it runs on its own. Here's the schedule we use:

| What | How often | Kept for | Done by |
|------|-----------|----------|---------|
| Whole-server snapshot (all 3) | **every 6 hours** (02:00 / 08:00 / 14:00 / 20:00) | ~7 days | CBR |
| Database only (web+db) | **every hour** | 2 days | cron + script |
| Full app backup (web+db) | **once a day** (02:30) | 30 days | cron + script |
| Worker settings | **once a week** (Sunday 03:00) | 60 days | cron + script |
| *(Optional)* MySQL change-log | every 15 min | 3 days | cron |

All times are **Bangkok time (ICT)**.

**What this means for you:** if disaster strikes, you lose at most **~1 hour** of recent submissions
(because the database is backed up hourly). Turn on the optional change-log (step 7) and that drops to
**almost zero**.

---

## 5. Files in this folder

| File | What it does |
|------|--------------|
| **`install.sh`** | **The one command you run on each server.** Sets up everything (Layer B). |
| `huawei-cbr-setup.sh` | Sets up the whole-server snapshots (Layer A). Run once, from your laptop. |
| `backup-web-db.sh` | The actual web+db backup (the installer schedules this for you). |
| `backup-worker.sh` | The actual worker backup (the installer schedules this for you). |
| `README.md` | This guide. |

> The IP addresses of your servers are **never written in these files**. You type them in when you run the setup.

---

## 6. Setup — do this once

You'll need: access to the **Huawei Cloud Console** (the website), and a terminal on each server
(via SSH). Take it one part at a time.

### Part A — Whole-server snapshots (the easy, safest layer)

**Easiest way: use the Console (point-and-click).** Recommended for beginners.

1. Log in to Huawei Cloud Console → search for **CBR** → **Cloud Server Backup**.
2. Click **Buy Server Backup Vault**. Pick a capacity at least as big as your servers' total disk usage.
3. Open the vault → **Associate Servers** → tick all **3** servers.
4. Go to **Policies → Create Policy**:
   - Type: **Backup**
   - Times: `02:00, 08:00, 14:00, 20:00`
   - Retention: keep the latest **28** backups (that's ~7 days at 4/day)
5. **Apply** that policy to your vault. Done — it now snapshots automatically.
   Click **Perform Backup** if you want the first one right now.

**Advanced way (optional): use the script.** Only if you have the `hcloud` tool installed.
```bash
hcloud configure init        # one-time: enter your Huawei keys + region
# Type your real server IPs in place of the <...> below:
REGION=ap-southeast-2 ./huawei-cbr-setup.sh <web-db-ip> <worker1-ip> <worker2-ip>
```
If the script errors out, just use the Console steps above — they always work.

> **Tip:** For the database server, "app-consistent" backups are safest (they pause the DB for a clean snapshot), but that needs Huawei's backup *agent* installed on that server. The default "crash-consistent" works fine without it.

### Part B — Data backups to OBS — **one command per server**

The installer does the whole job: installs the upload tool, connects it to your account, sets the
clock, copies the backup script, schedules it, and runs the first backup. Do this on **each** server.

1. Get this `deploy/backup/` folder onto the server (via `git pull` or `scp`).
2. Run the installer — **the only thing it asks is the server role**:
   ```bash
   cd deploy/backup
   sudo ./install.sh            # then type:  web-db   (or  worker)
   # ...or pass the role directly and answer nothing:
   sudo ./install.sh web-db
   sudo ./install.sh worker
   ```

Everything else (app path, bucket name, endpoint) is **auto-filled** from the defaults at the top of
`install.sh`. Two things just need to exist first:

- **obsutil connected to your account** — if it's already configured, great; otherwise give the keys
  once: `sudo OBS_AK=YOUR_AK OBS_SK=YOUR_SK ./install.sh web-db` (keys: Console → *My Credentials*).
- **MySQL access (web-db only)** — a `~/.my.cnf`, or pass it: `sudo DB_PASS=YOUR_DB_PASSWORD ./install.sh web-db`.

To change a default for good (e.g. the app path or bucket name), edit the **AUTO-FILLED DEFAULTS**
block at the top of `install.sh`.

When it finishes you'll see a `.tar.gz` land in your OBS bucket and the schedule is live. Run it again
on the other two servers and pick `worker` for those.

**What the installer set up** (so you know where things are):
- backup scripts → `/opt/cafe-backup/`
- schedule → `/etc/cron.d/cafe-grader-backup` (hourly + daily on web-db; weekly on a worker)
- log → `/var/log/cafe-backup.log`

**One manual step left — auto-delete old backups (once, in the Console).**
**OBS → your bucket → Lifecycle Rules**, add one rule per folder so backups don't pile up forever:

| Folder (prefix) | Delete after |
|-----------------|--------------|
| `web-db/hourly/` | 2 days |
| `web-db/daily/` | 30 days |
| `worker-*/` | 60 days |

(The scripts already clean up the *local* copies on each server; this rule cleans the *cloud* copies.)

---

## 7. (Optional) Lose almost zero data

The hourly database backup means you could lose up to ~1 hour of submissions. If you run live contests
and that's too much, turn on MySQL's **binary log** ("binlog") on the web+db server — it records every
change, so you can rewind to *any second*.

```ini
# Add to /etc/mysql/mysql.conf.d/mysqld.cnf, then restart MySQL
[mysqld]
log_bin          = /var/lib/mysql/binlog
binlog_format    = ROW
expire_logs_days = 3
```
```cron
# Ship the change-logs to OBS every 15 minutes
*/15 * * * *  mysqladmin flush-logs && obsutil cp -r -f -flat /var/lib/mysql/ obs://cafe-grader-backups/web-db/binlog/ -include='binlog.*'
```
Skip this if losing up to ~1 hour is acceptable.

---

## 8. Check it's actually working

**A backup you've never tested is just a hope.** Do this once after setup:

1. **Did the file upload?** In the Console, open your OBS bucket and confirm a `.tar.gz` appeared
   under `web-db/`. Or run: `obsutil ls obs://cafe-grader-backups/web-db/`.
2. **Is the file intact?** Download it plus its `.sha256` file and run `sha256sum -c <file>.sha256` —
   it should say `OK`.
3. **Can you actually restore the database?** Load a backup into a throwaway database and check the
   data is there (see step 9).
4. **Did the schedule fire?** After a day, check `/var/log/cafe-backup.log` on the server, and the
   CBR snapshot timestamps in the Console.

---

## 9. Restoring (when something goes wrong)

### The whole server died → restore from a snapshot (CBR)
1. Console → **CBR** → find the latest backup of that server.
2. Choose **Restore Data** (overwrite the existing disk) or **Create Image** (build a new server).
3. Reattach the original public IP (EIP). The server comes back exactly as it was at snapshot time.

### Data got deleted/corrupted → restore from an OBS app-backup (web+db)
Pick which backup you want:
- `web-db/daily/cafe-web_full_<host>_<time>.tar.gz` — full restore (DB + uploads + settings)
- `web-db/hourly/cafe-web_db_<host>_<time>.tar.gz` — just the freshest database

```bash
# 1. Download and verify the backup
ART=web-db/daily/cafe-web_full_<host>_<time>.tar.gz   # or the hourly one
obsutil cp "obs://cafe-grader-backups/$ART"        . -f
obsutil cp "obs://cafe-grader-backups/$ART.sha256" . -f
sha256sum -c "$(basename "$ART").sha256"             # should print: OK

# 2. Unpack it
mkdir restore && tar -C restore -xzf "$(basename "$ART")"

# 3. Load the databases back
zcat restore/db/grader.sql.gz       | mysql -u grader -p
zcat restore/db/grader_queue.sql.gz | mysql -u grader -p

# 4. Restore settings + the all-important master.key
cp -a restore/config/master.key restore/config/credentials.yml.enc \
      restore/config/database.yml restore/config/worker.yml restore/config/llm.yml \
      /home/grader/cafe-grader-web/config/

# 5. Restore uploaded files (only present in the daily/full backup)
[ -f restore/storage.tar.gz ] && tar -C /home/grader/cafe-grader-web -xzf restore/storage.tar.gz
```

### A worker needs restoring
```bash
obsutil cp obs://cafe-grader-backups/worker-<host>/cafe-worker_<host>_<time>.tar.gz . -f
mkdir restore && tar -C restore -xzf cafe-worker_<host>_<time>.tar.gz
cp -a restore/config/worker.yml /home/grader/cafe-grader-web/config/   # restores its ID/password
[ -f restore/judge.tar.gz ] && tar -C /home/grader/cafe-grader-web/.. -xzf restore/judge.tar.gz
```

---

## 10. Common problems

| Symptom | Likely cause / fix |
|---------|--------------------|
| `obsutil: command not found` | Not installed on this server — redo step B-2. |
| Upload fails / "access denied" | Wrong AK/SK keys or endpoint — re-run `obsutil config`. |
| `mysqldump: Access denied` | DB password missing — re-run `sudo ./install.sh` and enter it (it writes `/root/.my.cnf`). |
| Backups run at the wrong time | Clock isn't on Bangkok time — `sudo timedatectl set-timezone Asia/Bangkok`, or just re-run the installer. |
| CBR setup script errors | Use the Console steps instead (Part A) — they're the reliable path. |
| Nothing in the log | Schedule missing — check `/etc/cron.d/cafe-grader-backup` exists; re-run `sudo ./install.sh` if not. |

---

## Quick reference (cheat sheet)

```bash
# Run a backup right now (web+db, full)
sudo APP_DIR=/home/grader/cafe-grader-web OBS_BUCKET=cafe-grader-backups \
     BACKUP_LABEL=full OBS_PREFIX=web-db/daily /opt/cafe-backup/backup-web-db.sh

# See what's in the cloud
obsutil ls obs://cafe-grader-backups/web-db/

# Watch the backup log
tail -f /var/log/cafe-backup.log

# See your schedule
cat /etc/cron.d/cafe-grader-backup
```
