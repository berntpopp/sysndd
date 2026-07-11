## BLOCKER

None.

## HIGH

- [Makefile:439](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/Makefile:439) — legacy/cross-user `DEFINER` errors now abort restoration before [db-views-rebuild at line 445](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/Makefile:445). A dump containing `DEFINER=user@host` that `$MYSQL_USER` cannot create produces `SUPER or SET_ANY_DEFINER`, exits nonzero, and `pipefail` correctly stops—preventing the intended DEFINER-stripped repair. The grep also hides the decisive error.  
  **Fix:** strip `DEFINER=...` safely in the restore stream while retaining `pipefail`, or restore using an account authorized for those definers; do not merely suppress the diagnostic.

## MEDIUM

- [app/vite.config.ts:40](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/vite.config.ts:40), [app/Dockerfile:74](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/Dockerfile:74) — Workbox precaches every HTML file, including analyzer-generated `stats.html`; the inspected generated `dist/sw.js` contains that entry. The image then deletes `stats.html`, and nginx returns 404, so an analyzed/regressed image can fail service-worker installation on the missing mandatory precache resource.  
  **Fix:** add `**/stats.html` to `workbox.globIgnores`.

- [Makefile:454](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/Makefile:454) — `db-views-rebuild` does not reject zero extracted views. If the R source’s quoting/call shape changes, the regex emits only the diagnostic SQL comment; mysql exits 0 and line 461 prints `✓ Views rebuilt` without rebuilding anything.  
  **Fix:** fail when `matches` is empty; preferably validate the expected view-name set.

## LOW

- [.github/workflows/ci.yml:475](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/.github/workflows/ci.yml:475), [scripts/ci-smoke.sh:97](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/scripts/ci-smoke.sh:97) — CI checks artifact absence and the smoke test checks only SPA-root headers. Nothing asserts `/stats.html` and `/assets/probe.js.map` return 404 with security headers. A future location regression could silently restore SPA fallback behavior.  
  **Fix:** add those two HTTP assertions to the production-stack smoke test.

## Ship readiness

**FIX-FIRST** — the restore command can reject exactly the legacy DEFINER-bearing dump class its chained view rebuild is intended to repair.

## Confirmed fixed

- Active [local.conf:24](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/docker/nginx/local.conf:24) has both deny locations and security-header includes; [Dockerfile:59](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/Dockerfile:59) copies it. Exact/regex locations beat `location /`; no duplicate locations. `add_header ... always` makes headers valid on returned 404s.
- No tracked legitimate frontend `*.map` asset or `/stats.html` route exists. The broad deny/delete therefore breaks no current app asset.
- Both MySQL paths use stderr process substitution, not a status-masking pipeline: [Makefile:439](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/Makefile:439), [Makefile:457](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/Makefile:457). Async grep output may interleave slightly, but cannot alter mysql/gzip status or allow progress before mysql exits.
- Readiness queries `non_alt_loci_set` at [Makefile:442](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/Makefile:442), gates the success echo, and fails under `-e`; that table is foundational at [migration 000:107](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/db/migrations/000_initialize_base_schema.sql:107). It detects missing core schema, though not every logically incomplete dump.
- `set -u` introduces no host-variable break; MySQL variables expand inside the container. Replacing `cat | mysql` with `mysql < file` preserves input bytes and removes an unnecessary pipeline stage.
- CI assertion is in the same build job, with correct `app/dist` resolution, and recursive `find` covers nested maps: [.github/workflows/ci.yml:452](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/.github/workflows/ci.yml:452).
- `sourcemap:false` and conditional visualizer are correct at [vite.config.ts:145](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/vite.config.ts:145) and [vite.config.ts:221](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/vite.config.ts:221). Import usage and plugin order remain valid; normal dev, SEO, and Workbox map generation do not require source maps.
- Residual cleanup occurs after `dist` copy and before `USER nginx`: [app/Dockerfile:70](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/Dockerfile:70).

Static review only; no edits, tests, builds, or services run.