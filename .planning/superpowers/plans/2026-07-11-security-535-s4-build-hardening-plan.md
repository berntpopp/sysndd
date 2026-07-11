# S4 — Build/Deploy Hardening (source maps, stats.html, fail-closed restore) — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Stop production from emitting/serving frontend source maps and the `dist/stats.html` bundle-analyzer report, and make the operator `make db-restore-latest` command fail closed instead of masking `gzip`/`mysql` failures. (Issue #535 P1-3/5 "build-side" + "operator restore fail-closed" — the safe items the design flags as pull-forward; the Traefik-socket / writable-prod-mount topology items remain human-gated and are NOT in this PR.)

**Architecture:** Vite stops emitting `.map` files (`sourcemap: false` — there is no source-map upload step, so `hidden` maps are pure leak surface) and only includes the `rollup-plugin-visualizer` when `ANALYZE=true` (so normal/prod builds never write `dist/stats.html`). nginx gains defense-in-depth `return 404` for `*.map` and `/stats.html` in case an artifact ever slips into `dist`. The nginx image build strips any residual maps/stats after copying `dist`. The Makefile restore recipe filters `mysql` stderr noise via process substitution (not an in-pipeline `grep … || true` that defeats `pipefail`) and adds a post-restore readiness probe.

**Tech Stack:** Vite 5 / Rollup, `rollup-plugin-visualizer`, nginx, GNU Make (bash `.ONESHELL`, `-eu -o pipefail`).

## Global Constraints

- Do NOT touch production Compose topology (Traefik socket, writable prod source mounts) — human-gated, out of scope.
- `app/docker/nginx/prod.conf` `location` precedence: exact `=` > regex `~*` (first match) > prefix `/`. The deny blocks must be `=`/`~*` so they beat the `location /` SPA fallback that would otherwise `try_files $uri` and serve the file.
- Keep the frontend build green: `cd app && npm run build` must succeed and produce **no** `dist/stats.html` and **no** `dist/**/*.map`.

---

### Task 1: Vite — stop emitting source maps and prod stats.html

**Files:**
- Modify: `app/vite.config.ts` (`sourcemap` `:215`; `visualizer(...)` `:143-149`)

- [ ] **Step 1: Gate the visualizer behind ANALYZE**

Replace the unconditional `visualizer({ filename: './dist/stats.html', open: process.env.ANALYZE === 'true', gzipSize: true, brotliSize: true, template: 'treemap' }) as unknown as PluginOption,` (last entry in the `plugins` array) with a conditional spread so it is only present when analyzing:

```ts
      ...(process.env.ANALYZE === 'true'
        ? [
            visualizer({
              filename: './dist/stats.html',
              open: true,
              gzipSize: true,
              brotliSize: true,
              template: 'treemap',
            }) as unknown as PluginOption,
          ]
        : []),
```

- [ ] **Step 2: Stop emitting source maps in the build**

Change `sourcemap: 'hidden', // Security: no public source maps` (`:215`) to:

```ts
      sourcemap: false, // #535: no production source maps emitted (no upload step exists)
```

- [ ] **Step 3: Verify build output is clean**

Run: `cd app && npm run build`
Expected: build succeeds; then `find app/dist -name '*.map' | head` prints nothing and `test ! -f app/dist/stats.html` succeeds.
Also verify analyze mode still works: `cd app && ANALYZE=true npm run build && test -f app/dist/stats.html` (then remove it).

- [ ] **Step 4: Commit**

```bash
git add app/vite.config.ts
git commit -m "fix(security): don't emit prod source maps or dist/stats.html (gate visualizer on ANALYZE) (#535)"
```

---

### Task 2: nginx — never serve maps or stats.html (defense in depth)

**Files:**
- Modify: `app/docker/nginx/prod.conf`
- Modify: `app/Dockerfile` (`COPY … /app/dist .` `:70`)

- [ ] **Step 1: Add deny blocks to prod.conf**

Insert immediately after the `location = /manifest.webmanifest { … }` block (before the assets regex), so they win over the SPA fallback:

```nginx
  # Never serve source maps or the bundle-analyzer report (#535). Defense in
  # depth: the prod build no longer emits these, but a stray artifact must 404,
  # not fall through to try_files and be served.
  location ~* \.map$ {
    return 404;
  }
  location = /stats.html {
    return 404;
  }
```

- [ ] **Step 2: Strip any residual maps/stats from the image**

In `app/Dockerfile`, immediately after `COPY --chown=nginx:nginx --from=builder /app/dist .` (`:70`), add:

```dockerfile
# Belt-and-suspenders: ensure no source maps or analyzer report ship (#535).
RUN find . -name '*.map' -delete && rm -f stats.html
```

- [ ] **Step 3: Verify**

`docker build -f app/Dockerfile app` (or at least `docker build --target <nginx-stage>` if the stage is named). If a full build is too slow locally, verify the `RUN` line is syntactically valid and that `nginx -t` accepts prod.conf via a throwaway container:
`docker run --rm -v "$PWD/app/docker/nginx/prod.conf:/etc/nginx/conf.d/default.conf:ro" nginx:alpine nginx -t` (expect "syntax is ok" / "test is successful"; a missing `security-headers.conf`/cert include may warn — confirm the syntax error, if any, is only the missing include, not our blocks).

- [ ] **Step 4: Commit**

```bash
git add app/docker/nginx/prod.conf app/Dockerfile
git commit -m "fix(security): nginx 404s *.map and /stats.html; strip them from the image (#535)"
```

---

### Task 3: Makefile — fail-closed `db-restore-latest`

**Files:**
- Modify: `Makefile` (`db-restore-latest` `:431-443`)

- [ ] **Step 1: Rewrite the restore recipe to preserve failure + probe readiness**

Replace the pipeline that ends `… | grep -vE "…" >&2 || true` with one that (a) filters `mysql` stderr noise via **process substitution** (so `grep`'s exit status is NOT on the pipeline and `pipefail` still catches a real `gzip`/`mysql` failure), and (b) runs a post-restore `SELECT 1` readiness probe:

```makefile
	docker run --rm -v sysndd_mysql_backup:/data alpine sh -c "gzip -dc $$LATEST" \
		| docker exec -i sysndd_mysql sh -c 'mysql -u "$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"' \
		2> >(grep -vE "Using a password|SUPER or SET_ANY_DEFINER" >&2 || true)
	@docker exec -i sysndd_mysql sh -c 'mysql -u "$$MYSQL_USER" -p"$$MYSQL_PASSWORD" -e "SELECT 1" "$$MYSQL_DATABASE"' >/dev/null \
		|| { printf "$(RED)✗ Restore readiness probe failed$(RESET)\n"; exit 1; }
	@printf "$(GREEN)✓ Backup restored$(RESET)\n"
```

(The recipe already validates `$$LATEST` is non-empty and exits 1 otherwise — keep that. `.SHELLFLAGS := -eu -o pipefail -c` + `.ONESHELL` mean a `gzip`/`mysql` non-zero now aborts the recipe.)

- [ ] **Step 2: Verify syntax (do NOT run a real restore — it clobbers the dev DB)**

Run: `make -n db-restore-latest` (dry-run — expands the recipe, confirms no syntax error). Confirm the expanded recipe contains `2> >(grep` (process substitution) and the `SELECT 1` probe, and no `| grep … || true` on the restore pipeline.

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "fix(security): make db-restore-latest fail closed (pipefail-safe stderr filter + readiness probe) (#535)"
```

---

### Task 4: Docs + verify

- [ ] **Step 1: Document** in `documentation/09-deployment.qmd`: production builds emit no source maps or `dist/stats.html`; use `ANALYZE=true npm run build` for the bundle report; nginx 404s both; `make db-restore-latest` now fails closed with a readiness probe.
- [ ] **Step 2: Full verify** — `cd app && npm run build` (clean dist), `npm run type-check` (config change compiles), `make -n db-restore-latest`.
- [ ] **Step 3: Codex adversarial diff review; fold; open PR referencing #535 (do-not-auto-merge for the deploy-facing change).**

## Self-Review

- Spec coverage: source maps → Task 1 (`sourcemap:false`) + Task 2 (nginx 404 + image strip); `stats.html` → Task 1 (ANALYZE gate) + Task 2; operator restore fail-closed → Task 3 (pipefail-safe + readiness probe). Topology items (Traefik socket, writable prod mounts) explicitly deferred/human-gated.
- No placeholders; each step has concrete code + verification commands.
- Consistency: `ANALYZE=true` is the single gate for the visualizer; `sourcemap:false` is the single build flag.
