#!/usr/bin/env bash
# ci-smoke.sh
#
# CI smoke test: build the production image, bring the stack up, and curl
# /api/health/ready until it returns 200. Used by the `smoke-test` job in
# .github/workflows/ci.yml (Phase B B4) and also runnable locally:
#
#   ./scripts/ci-smoke.sh
#
# The heavy lifting (build + compose up + health poll + teardown) is already
# implemented as `make preflight`. This wrapper adds an extra belt-and-braces
# retry loop against the same endpoint once preflight finishes, which catches
# the pathological case where preflight passes its own health loop but the
# container dies between the probe and the teardown. It also fails loudly with
# context (docker ps / docker logs) so CI logs are immediately actionable.
#
# Exit codes:
#   0 — health endpoint responded 200
#   1 — preflight failed
#   2 — health endpoint never returned 200 after retries

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

log() { printf '[ci-smoke] %s\n' "$*"; }
fail() { printf '[ci-smoke] FAIL: %s\n' "$*" >&2; }

# Seed gitignored files from their committed templates if missing. This is
# what lets `make preflight` build the prod Docker image on a fresh CI
# checkout: the Dockerfile does `COPY config.yml config.yml` and the
# compose file consumes env vars from `.env`, but both `api/config.yml` and
# `.env` are gitignored because they hold real credentials on dev machines.
# The templates (`api/config.yml.example`, `.env.example`) ship safe dummy
# values; a developer running this script locally with real secrets in
# place will NOT have either file overwritten.
seed_from_template() {
  # seed_from_template <target> <template>
  local target="$1"
  local template="$2"
  if [ -f "$target" ]; then
    return 0
  fi
  if [ ! -f "$template" ]; then
    fail "neither $target nor its template $template exists"
    return 1
  fi
  log "seeding $target from $template (missing on this checkout)"
  cp "$template" "$target"
}

seed_from_template "$REPO_ROOT/api/config.yml" "$REPO_ROOT/api/config.yml.example"
seed_from_template "$REPO_ROOT/.env"           "$REPO_ROOT/.env.example"

HEALTH_URL="${SMOKE_HEALTH_URL:-http://localhost/api/health/ready}"
# Traefik Host header. The prod docker-compose.yml routes by Host(...) ONLY
# on the real hostname — without this header curl hits traefik but gets a
# 404 because no router matches. See the preflight block in the Makefile
# for the matching config. Override with SMOKE_HOST_HEADER=... if you
# re-point HEALTH_URL at a different stack.
HEALTH_HOST_HEADER="${SMOKE_HOST_HEADER:-sysndd.dbmr.unibe.ch}"
# Total retries = RETRIES, sleep = RETRY_SLEEP_SECONDS.
RETRIES="${SMOKE_RETRIES:-30}"
RETRY_SLEEP_SECONDS="${SMOKE_RETRY_SLEEP_SECONDS:-2}"
SPA_RETRIES="${SMOKE_SPA_RETRIES:-30}"
SPA_RETRY_SLEEP_SECONDS="${SMOKE_SPA_RETRY_SLEEP_SECONDS:-2}"

dump_context() {
  fail "dumping diagnostic context"
  (cd "$REPO_ROOT" && docker ps -a || true) >&2
  (cd "$REPO_ROOT" && docker compose -f docker-compose.yml logs --tail=80 api || true) >&2
}

log "step 1/3: make preflight (builds prod image + compose up + internal health poll)"
if ! (cd "$REPO_ROOT" && make preflight); then
  dump_context
  exit 1
fi

# preflight tears the stack down on success. To exercise the actual smoke loop
# we bring the stack back up briefly and re-probe. This catches race conditions
# where the container died between preflight's probe and teardown.
log "step 2/3: re-up prod stack for independent curl probe"
if ! (cd "$REPO_ROOT" && docker compose -f docker-compose.yml up -d); then
  dump_context
  exit 1
fi
trap '(cd "$REPO_ROOT" && docker compose -f docker-compose.yml down) || true' EXIT

log "step 3/4: curl -f -H 'Host: $HEALTH_HOST_HEADER' $HEALTH_URL (retries=$RETRIES, sleep=${RETRY_SLEEP_SECONDS}s)"
i=0
health_ok=0
while [ "$i" -lt "$RETRIES" ]; do
  if curl -fsS -H "Host: $HEALTH_HOST_HEADER" "$HEALTH_URL" >/dev/null 2>&1; then
    log "health endpoint OK on attempt $((i + 1))"
    health_ok=1
    break
  fi
  i=$((i + 1))
  sleep "$RETRY_SLEEP_SECONDS"
done

if [ "$health_ok" -ne 1 ]; then
  fail "health endpoint did not return 200 after $RETRIES attempts"
  dump_context
  exit 2
fi

# Step 4: assert the SPA root emits the security headers declared in
# app/docker/nginx/security-headers.conf. Guards against two regression
# classes:
#   1. A new location{} block in local.conf/prod.conf forgetting the
#      `include /etc/nginx/security-headers.conf;` line (nginx's add_header
#      inheritance would silently drop the headers — this is exactly what
#      #296 was).
#   2. `server_tokens off` being reverted, leaking the nginx version.
log "step 4/4: assert SPA security headers"
SPA_URL="${SMOKE_SPA_URL:-http://localhost/}"
SPA_HEADERS=""
i=0
while [ "$i" -lt "$SPA_RETRIES" ]; do
  SPA_HEADERS=$(curl -fsSI -H "Host: $HEALTH_HOST_HEADER" "$SPA_URL" 2>/dev/null || true)
  if printf '%s' "$SPA_HEADERS" | grep -Eq '^HTTP/[0-9.]+ 200'; then
    break
  fi
  i=$((i + 1))
  sleep "$SPA_RETRY_SLEEP_SECONDS"
done

if ! printf '%s' "$SPA_HEADERS" | grep -Eq '^HTTP/[0-9.]+ 200'; then
  fail "could not fetch 200 headers from $SPA_URL after $SPA_RETRIES attempts"
  if [ -n "$SPA_HEADERS" ]; then
    printf '%s\n' "$SPA_HEADERS" >&2
  fi
  dump_context
  exit 3
fi

missing=0
for h in \
    "Strict-Transport-Security" \
    "X-Content-Type-Options" \
    "X-Frame-Options" \
    "Referrer-Policy" \
    "Permissions-Policy" \
    "Content-Security-Policy"; do
  if ! printf '%s' "$SPA_HEADERS" | grep -iq "^${h}:"; then
    fail "missing security header on $SPA_URL: $h"
    missing=1
  fi
done

# server_tokens off → Server: nginx (no /version). A leak like `Server: nginx/1.30.0`
# means server_tokens has regressed.
if printf '%s' "$SPA_HEADERS" | grep -Eiq "^server:[[:space:]]*nginx/[0-9]"; then
  fail "Server header leaks nginx version — server_tokens off regressed"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  fail "security-header assertion failed. Received headers:"
  printf '%s\n' "$SPA_HEADERS" >&2
  dump_context
  exit 3
fi

log "all security headers present, nginx version not leaked"
exit 0
