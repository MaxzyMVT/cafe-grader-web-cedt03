# Cafe-Grader

An online programming-contest and assignment-grading platform. Students submit code; the system compiles it, runs it against test cases, and reports scores. Instructors manage problems, contests, groups, users, and reports.

The project started at Kasetsart University by @jittat and @pkhungurn. The current maintainer is @nattee.

*Primary development happens at Chulalongkorn University on the [`nattee/cafe-grader-web`](https://github.com/nattee/cafe-grader-web) fork. Stable cuts are published to upstream `cafe-grader-team/cafe-grader-web` periodically.*

**This checkout** ([`MaxzyMVT/cafe-grader-web`](https://github.com/MaxzyMVT/cafe-grader-web)) is a further fork of `nattee/cafe-grader-web`, developed by CEDT03 students at Chulalongkorn University. Its version number is tracked separately from upstream — currently **`4.4.2-cedt03.1`** (base `nattee/cafe-grader-web` version `4.4.2`, plus the `-cedt03.1` fork suffix).

### CEDT03 fork additions (on top of nattee v4.4.2)

Gamification and reporting features layered on top of the upstream base, not present in `nattee/cafe-grader-web`:

- **Submission limits** — per-problem cap on submission count (`Problem#max_submissions`), with remaining count shown to students; problem setters/admins exempt.
- **Point-based hints with a loot-box mechanic** — hints have a point cost and a randomized `success_rate`; spending points isn't a guaranteed reveal, with success/failure feedback in the UI.
- **Theme presets** — user-selectable UI themes (Dark, Ocean, Premium, Solarized) stored per-user, switchable from the profile page.
- **Realtime scoreboard** — auto-refreshing scoreboard (individual/group views, CSV export, first-blood bonus display).
- **First-blood bonus** — configurable bonus points for the first N correct submissions on a problem, surfaced on the scoreboard.
- **Extended statistics report** — most-effort, latest-submissions, first-blood counts, shortest-code, and fastest-runtime breakdowns, filterable by language/tags/problems/time range.
- **Group scoring modes** — `GraderConfiguration#group_score_type` toggles group totals between summed and max-per-problem scoring.
- **Tag sorting and colors** — problem tags carry a display order and a hex color for UI rendering.

---

## Heads-up: v4.x is a major leap from what `master` has been since 2019

The `master` branch was effectively frozen on **Rails 4.2 + Bootstrap 3** for ~6.5 years. The current code (v4.x) is on **Rails 8 + Hotwire + Solid Queue + JSON API**. This is the first formal version-tagged release.

If your deployment was tracking `master`, do **not** pull blindly. Read **[MIGRATION.md](MIGRATION.md)** end-to-end before upgrading. The upgrade requires a maintenance window, a full database backup, and several config-file changes that have no automatic conversion.

### Version tags introduced in this release

To give existing deployments a coherent version trail, four retroactive tags now exist:

| Tag      | Era                                                              |
|----------|------------------------------------------------------------------|
| `v1.0.0` | Rails 4.2 + Bootstrap 3 era — what `master` has been since 2019  |
| `v2.0.0` | Rails 5.2 era (~2019 – early 2022, retroactively tagged)         |
| `v3.0.0` | Rails 7 + importmap + Bootstrap 5 + Hotwire era (~2023)          |
| `v4.0.0` and onwards | Current era: Rails 8 + Solid Queue + LLM + JSON API + audit logging |

Most existing users are effectively on `v1.0.0`. The `v2`/`v3` tags exist as historical anchors for stepping-stone upgrades.

### Highlights of v4.x (vs. v1.0.0)

- **Rails 8.0** + **Ruby 3.4.4** + **MySQL 8.0+** — all hard requirements. **MariaDB is NOT supported** (see Tech stack below).
- **Solid Queue / Solid Cache / Solid Cable** — first Active Job backend in project history (no Sidekiq/Redis to retire — there was no third-party queue before).
- **Propshaft + ImportMap + dartsass-rails** replace Sprockets. Node.js is no longer required for the web app. (Webpacker was never adopted.)
- **Hotwire (Turbo + Stimulus)** is the primary front-end interaction model. **Bootstrap 5** throughout (Bootstrap 3 → 5 direct jump — no Bootstrap 4 phase).
- **JSON API at `/api/v1/`** with JWT auth and rswag-generated Swagger docs at `/api-docs`.
- **Audit logging** for sensitive admin actions.
- **LLM-assisted comments / hints** with cost tracking (optional, off by default).
- New **exam mode** controls and tightened submission-visibility rules.
- Rebuilt judge engine under `app/engine/` (the DB-backed `Job`-table architecture is unchanged; only the Rails-side code was rewritten).

### If you cannot upgrade right now

The `v1.0.0` tag points at the same commit that `master` has had since October 2019. That line is frozen:

- No new features.
- Security backports are best-effort only — please don't depend on them.

To pin to it:

```bash
git fetch origin
git checkout v1.0.0
```

---

## Tech stack (v4.x)

- Ruby 3.4.4, Rails 8.0
- **MySQL 8.0+ only** (Oracle MySQL or Percona Server; primary DB `grader`, queue DB `grader_queue`).
  **MariaDB will NOT work**: every table uses the `utf8mb4_0900_ai_ci` collation (MySQL 8's default),
  which MariaDB does not implement — the schema will not even load. This is a deliberate decision
  (performance + modern Unicode/Thai handling); rationale in [doc/decisions.md](doc/decisions.md).
- Propshaft asset pipeline, ImportMap for JS, dartsass-rails for CSS
- Hotwire (Turbo + Stimulus), jQuery (legacy), Bootstrap 5, HAML
- Solid Queue (jobs), Solid Cache, Solid Cable
- Puma (Thruster is bundled but optional)
- External judge workers (separate processes; see `config/worker.yml`)

## Getting started

See the wiki: <https://github.com/cafe-grader-team/cafe-grader-web/wiki>

Quick local dev:

```bash
bundle install
bin/rails db:setup
bin/rails db:migrate:queue       # migrate the queue DB
bin/dev                          # web + dartsass watcher + queue
```

The test suite uses two databases (`grader_test` + `grader_queue_test`). Give the MySQL
user a wildcard grant so all `grader_*` databases work, current and future:

```sql
GRANT ALL PRIVILEGES ON `grader\_%`.* TO 'grader'@'localhost';
```

Run the full test suite (minitest + RSpec API specs + swagger freshness) with:

```bash
bin/rails check
```

## Deployment (production)

Ubuntu 22.04 automated installers live in `script/installation/` — see the
**[Installation Guide](doc/guide/cafe_grader_installation.md)** for details:

```bash
bash script/installation/install_single_server.sh                       # all-in-one
# or 3-server: web/db node, then each worker with a UNIQUE id
bash script/installation/install_web_db_server.sh
bash script/installation/install_worker_server.sh <WEB_DB_IP> 1
```

Add `--cloud` on AWS/GCP/Azure. Shared install steps live in `deploy/lib/common.sh`.

## Documentation

- **[Overview](cafe_grader_overview.md)** — architecture, tech stack, file layout.
- **[Installation Guide](doc/guide/cafe_grader_installation.md)** — single-server & 3-server production setup.
- **[Local Setup Guide](doc/guide/cafe_grader_local_setup.md)** — dev environment (Ubuntu/WSL) via `script/installation/setup_local_wsl.sh`.
- **[Administrator Guide](doc/guide/cafe_grader_admin_guide.md)** — users, problems, contests, grader diagnostics.
- **[MIGRATION.md](MIGRATION.md)** — upgrading from v1.x to v4.x.
- **[Backup & restore](deploy/backup/README.md)** — SSH-pull and Huawei OBS/CBR backups.
- **`/api-docs`** (running app) — Swagger UI for the JSON API.
- **Wiki** — upstream installation and operational guides.

## License

MIT. See `MIT-LICENSE`.

## Contributing

Issues and PRs welcome. For substantial changes, please open an issue first to discuss scope. The maintainer also runs a development line at Chulalongkorn — most new development lands there first and is merged into `master` here periodically.
