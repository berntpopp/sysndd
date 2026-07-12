Static review only; no edits, builds, tests, or services run.

## BLOCKER

None.

## HIGH

- [Plan:65-94](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/.planning/superpowers/plans/2026-07-11-security-535-s4-build-hardening-plan.md:65>) hardens the wrong nginx configuration. The production image copies [app/Dockerfile:59](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/Dockerfile:59) `local.conf`; `prod.conf` is explicitly legacy/unwired per [documentation/09-deployment.qmd:338](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/documentation/09-deployment.qmd:338). Thus the current deployed nginx would still return the SPA for absent maps/stats and serve any residual file.  
  **Fix:** add deny locations to [app/docker/nginx/local.conf:20](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/docker/nginx/local.conf:20); optionally mirror them in legacy `prod.conf`.

- [Makefile:444](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/Makefile:444) invokes `db-views-rebuild`, whose MySQL pipeline still ends in `|| true` at [Makefile:456](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/Makefile:456). Therefore the complete `db-restore-latest` workflow can still print success after view replay fails.  
  **Fix:** apply the same stderr process-substitution pattern to `db-views-rebuild`, remove its masking `|| true`, and print final restore success only after view rebuilding succeeds.

## MEDIUM

- Proposed deny locations omit `include /etc/nginx/security-headers.conf;` at [Plan:75-85](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/.planning/superpowers/plans/2026-07-11-security-535-s4-build-hardening-plan.md:75>). This violates the repository’s per-location header invariant documented at [security-headers.conf:5](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/docker/nginx/security-headers.conf:5); the 404s would omit HSTS/CSP and related headers.  
  **Fix:** include the security-header file in both deny blocks, with its existing `always` directives.

- The fallback nginx verification at [Plan:98-99](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/.planning/superpowers/plans/2026-07-11-security-535-s4-build-hardening-plan.md:98>) is invalid: standalone `prod.conf` requires both the security-header include and TLS certificate files at [prod.conf:14](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/docker/nginx/prod.conf:14). Missing files are fatal `nginx -t` errors, not warnings.  
  **Fix:** test the built production image/config, then assert HTTP 404 for `/stats.html` and `/assets/probe.js.map`.

- [Plan:132](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/.planning/superpowers/plans/2026-07-11-security-535-s4-build-hardening-plan.md:132>) overclaims `make -n`: it verifies expansion/inspection, not Bash syntax or failure propagation. There is also no automated clean-artifact assertion before CI uploads `app/dist` at [.github/workflows/ci.yml:475](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/.github/workflows/ci.yml:475).  
  **Fix:** add non-destructive mocked failure checks for gzip/MySQL and CI assertions rejecting `dist/**/*.map` and `dist/stats.html`.

## LOW

- `SELECT 1` at [Plan:123](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/.planning/superpowers/plans/2026-07-11-security-535-s4-build-hardening-plan.md:123>) proves connectivity only. A valid but logically incomplete dump can pass it. `>/dev/null` suppresses stdout only; real MySQL stderr remains visible.  
  **Fix:** describe it as connectivity/readiness, or query an expected core-table/migration sentinel for limited structural assurance.

- [Plan:9](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/.planning/superpowers/plans/2026-07-11-security-535-s4-build-hardening-plan.md:9>) says Vite 5, but [app/package.json:100](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/package.json:100) uses Vite 7.3.6.  
  **Fix:** correct the plan metadata.

## Corrections to apply

1. Harden `local.conf`; optionally mirror legacy `prod.conf`.
2. Include security headers in both 404 locations.
3. Make `db-views-rebuild` fail closed too.
4. Add CI artifact assertions and runtime 404 checks.
5. Replace the invalid standalone `prod.conf` test.
6. Treat `SELECT 1` as connectivity, not restore-integrity proof.
7. Correct Vite version.

## Confirmed correct

- `sourcemap: false` is appropriate. No active Sentry/error-monitoring upload or source-map consumer exists; repository matches find only archived optional-Sentry discussion.
- `vite-plugin-pwa` inherits Vite’s `build.sourcemap` when `workbox.sourcemap` is unset, so changing it to `false` also disables generated service-worker maps. No separate CSS `devSourcemap` or other map emitter is configured. [Official vite-plugin-pwa behavior](https://vite-pwa-org.netlify.app/guide/prompt-for-update.html).
- The conditional visualizer spread type-checks: [vite.config.ts:27](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/vite.config.ts:27) is a mutable array literal, and the cast produces `PluginOption[]`.
- Normal `npm run build` cleans `dist`; with the visualizer absent it will not create `stats.html`.
- nginx precedence is sound once applied to the active config: exact `/stats.html` wins; the `.map` regex wins over `location /`. The assets regex does not match `.js.map`. Currently, existing maps are served by `try_files`; absent maps/stats return `index.html` with 200.
- Docker cleanup runs in `/usr/share/nginx/html` after the dist copy, as root before [USER nginx:80](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/app/Dockerfile:80). Missing files and `--chown=nginx` cause no failure.
- Bash/process-substitution semantics are correct: [Makefile:8-10](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s4-build-hardening/Makefile:8) selects Bash, `.ONESHELL`, `set -eu`, and `pipefail`; the proposed redirection preserves gzip/MySQL pipeline status. The readiness command runs only after that pipeline succeeds, and failure prevents the success echo.
- The Vite/plugin changes should not affect type-checking, SEO generation, or application behavior.
- Traefik-socket and writable production-mount topology changes are correctly excluded as human-gated scope.