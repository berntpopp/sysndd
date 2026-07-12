# S3 — DB Restore Fencing — Design (DESIGN-ONLY, human-gated)

Date: 2026-07-12
Issue: [#535](https://github.com/berntpopp/sysndd/issues/535) — umbrella hardening, slice **S3**
(audit finding P1-2, restore safety). Parent design:
`.planning/superpowers/specs/2026-07-11-security-hardening-535-design.md` §3 (S3 — "Spec only;
human-gated").
Status: **Design for human decision. NOT a code change.** Production topology + a maintenance-mode
policy call are involved; those must not be changed autonomously from a dev checkout.

## 1. Scope — the ONE open gap

Restore already has real safety: Administrator-only (`backup_endpoints.R:133`), path-traversal +
extension validation of the filename (`is_valid_backup_filename`), a duplicate-restore 409, a
**mandatory pre-restore safety backup** that must succeed first (`async-job-maintenance-handlers.R:51-64`),
and — from the shipped **S2/#535 P1-1** — no DB credential in the job payload or in `mysql`/`mysqldump`
argv (mode-0600 option file). The shipped **S4** made the *operator* path (`make db-restore-latest`)
fail-closed. **None of that is re-proposed here.**

The restore is a plain client-side import: the `worker-maintenance` container pipes the dump into the
`mysql` service over the internal `backend` network (`gunzip -c … | mysql --defaults-extra-file=…`,
`backup-functions.R:257-271,479-524`). No Docker socket, no privileged container, no `docker exec`
(the only socket mount is Traefik's read-only one).

**The gap (P1-2): there is no *runtime fencing* of the restore against live traffic.** Concretely:

1. **No advisory lock / maintenance mode.** Grep confirms backup/restore use **no** `GET_LOCK`
   (unlike comparators/ontology/pubtatornidd). Serialization is only (a) a best-effort, explicitly
   non-atomic submit-time duplicate check (`check_backup_in_progress`), and (b) the single-worker
   maintenance lane (so two restores can't run concurrently). Nothing stops the `api` and the
   interactive `worker` from **reading and writing the database while a restore is dropping and
   recreating every table.** During an import a client can observe half-restored state, hit missing
   tables, or write rows that the very next `DROP TABLE` discards.
2. **The restore deletes its own bookkeeping.** A full restore replaces the `async_jobs` table, so
   the running restore job's own row vanishes; the worker's completion `UPDATE` matches 0 rows and
   `result_json` (including the S2 `post_restore_scrub` outcome) is lost
   (`async-job-maintenance-handlers.R:91-101`). The operation "succeeds" but is unobservable and the
   post-restore credential scrub result is dropped.
3. **Deferred topology (from S4, still open):** writable prod source mounts and the Traefik
   read-only socket were explicitly left for a human topology review. Fencing touches this because a
   robust maintenance mode may want a proxy-level gate.

## 2. Design options (for the fencing gap)

### Option A — Advisory-lock fencing that the request path respects (app-level, no topology change)
Introduce a single named MySQL advisory lock, e.g. `sysndd_db_restore`. The restore handler takes it
(`GET_LOCK('sysndd_db_restore', 0)`) for the entire import; a lightweight **preroute hook** checks a
cheap "restore in progress" flag and returns `503 + Retry-After` for DB-touching routes while it is
held.
- *Pros:* no compose/topology change; mirrors the existing `GET_LOCK` pattern already used elsewhere;
  purely additive.
- *Cons:* the lock lives in the DB being restored — a full restore that replaces the connection/kills
  sessions can drop the lock mid-import (advisory locks are session-scoped). Needs a flag that
  survives the restore (e.g. a file on the shared `mysql_backup` volume, or a Redis-less
  filesystem sentinel the api/worker check), not a DB row (which the restore would wipe). **The
  sentinel must live outside the DB.**

### Option B — Filesystem sentinel + maintenance mode (recommended core)
The restore handler writes a `RESTORE_IN_PROGRESS` sentinel file to the shared `mysql_backup` volume
(already mounted rw in api + both workers) **before** the import and removes it in a `finally`
(and a bounded TTL/heartbeat so a crashed restore self-clears). The API preroute hook (already the
place `REMOTE_ADDR` is read) returns `503 { "error": "maintenance", retry_after }` for non-health,
non-auth DB routes while the sentinel exists; the worker refuses to claim new jobs. This is
DB-independent (survives the table swap), needs no schema and no compose topology change (reuses the
existing shared volume), and is observable (the sentinel encodes who/when).
- *Pros:* survives the DB replacement; no topology change; cheap; self-clearing.
- *Cons:* a shared-volume sentinel is coarse (whole-app maintenance) and per-host if the volume is
  not shared across all app replicas — **decision needed on the deployment's volume topology.**

### Option C — Restore into a staging schema + atomic swap (eliminates both downtime AND self-deletion)
Import the dump into a **staging database** (`sysndd_db_restore_staging`), validate it (`SELECT 1`,
row-count sanity, migration-manifest check), then swap atomically via `RENAME TABLE` (or a schema
switch). Live traffic keeps hitting the current schema until the instant of swap.
- *Pros:* near-zero downtime; the running job's `async_jobs` row is **not** deleted (staging is a
  different schema), so `result_json`/scrub survive; a bad dump never touches production.
- *Cons:* biggest change (needs a staging schema, `RENAME TABLE` of every table, and grants); the
  `mysql-cron-backup` sidecar and grants assume one schema; more moving parts to get right. This is
  the "right" long-term answer but is a real project, not a hardening slice.

### Recommendation
**B now (fencing + observability), C later (true zero-downtime).** Option B closes the exposure
(clients can't read/write mid-restore; the sentinel survives the table swap) with no topology or
schema change, and it fixes the async_jobs self-deletion **observability** by persisting the run
summary to the sentinel/volume instead of only to the about-to-be-deleted row. Option C is the
durable design but should be its own project with a migration + grant review. Option A alone is
insufficient because a DB-resident lock/flag does not survive the restore.

## 3. The async_jobs self-deletion sub-fix (independent of the fencing option)
Regardless of A/B/C, persist the restore run summary **outside** `async_jobs` before the import (the
sentinel file, or a dedicated `restore_audit` table in a schema the restore does not replace, or the
worker log), so a full restore that deletes the job row does not lose the outcome. Today it is a
documented known-loss (`async-job-maintenance-handlers.R:91-101`). Minimal fix: write the
`post_restore_scrub` + timing to the shared-volume sentinel/log and reconcile on the next worker tick.

## 4. Decision questions for the human (blockers to implementation)
1. **Volume topology:** is `mysql_backup` (or any writable path) shared across *all* app/worker
   replicas in production, or per-host? (Determines whether a filesystem sentinel is globally
   effective or needs a shared store.) If the prod app is single-replica, Option B is trivially
   correct.
2. **Maintenance-mode UX:** during a restore, should DB routes return `503 + Retry-After`
   (recommended), or should the whole app be taken down at the proxy? Is a brief public "maintenance"
   window acceptable, and should `/health`, `/auth`, and static pages stay up?
3. **Scope of the fence:** all DB-touching routes, or only writes? (Reads during a table swap can
   still error; recommend fencing all DB routes for the import window, which is short.)
4. **Option C appetite:** is a staging-schema + `RENAME TABLE` zero-downtime restore worth a
   dedicated project (migration, grants, cron-backup schema assumptions), or is Option B's short
   maintenance window acceptable operationally?
5. **Sentinel TTL / crash recovery:** acceptable max restore duration to bound the sentinel's
   self-clear TTL (so a crashed restore can't wedge the app in maintenance forever)?
6. **Deferred S4 topology:** should this slice also take on the writable-prod-mount / Traefik-socket
   review S4 deferred, or keep that separate?

## 5. Out of scope / already done
- Credential handling, argv/shell leakage, option-file mode, payload scrub — done in **S2/S2b**.
- Operator `make db-restore-latest` fail-closed + build source-map/`stats.html` suppression — done
  in **S4**.
- Administrator gate, filename validation, pre-restore safety backup, duplicate-restore check —
  already present.
