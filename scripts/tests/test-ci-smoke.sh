#!/usr/bin/env bash
# test-ci-smoke.sh
#
# Bash harness for scripts/ci-smoke.sh.
#
# This test stubs make/docker/curl so it can verify the script's control flow
# without building containers. The pinned regression is that the script must
# retry the SPA header probe until it gets a real 200 response instead of
# failing immediately on a transient 404/empty response while the frontend
# router is still starting up.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
SMOKE_SCRIPT="$REPO_ROOT/scripts/ci-smoke.sh"

PASS=0
FAIL=0

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    printf '  \033[32mPASS\033[0m  %s\n' "$message"
  else
    FAIL=$((FAIL + 1))
    printf '  \033[31mFAIL\033[0m  %s (expected=%s actual=%s)\n' "$message" "$expected" "$actual"
  fi
}

case_spa_probe_retries_until_headers_ready() {
  local dir
  local fakebin
  local state
  local exit_code
  dir=$(mktemp -d)
  fakebin="$dir/fakebin"
  state="$dir/state"
  mkdir -p "$fakebin" "$state/api"

  cp "$REPO_ROOT/.env.example" "$state/.env"
  cp "$REPO_ROOT/api/config.yml.example" "$state/api/config.yml"

  cat > "$fakebin/make" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "$fakebin/docker" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "$fakebin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "$fakebin/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
state_dir="${TEST_STATE_DIR:?}"
url="${@: -1}"

if [[ "$url" == *"/api/health/ready" ]]; then
  count_file="$state_dir/health_count"
  count=0
  if [ -f "$count_file" ]; then
    count=$(cat "$count_file")
  fi
  count=$((count + 1))
  printf '%s' "$count" > "$count_file"
  if [ "$count" -lt 2 ]; then
    exit 22
  fi
  printf 'ok\n'
  exit 0
fi

if [[ "$url" == *"http://localhost/"* ]]; then
  count_file="$state_dir/spa_count"
  count=0
  if [ -f "$count_file" ]; then
    count=$(cat "$count_file")
  fi
  count=$((count + 1))
  printf '%s' "$count" > "$count_file"
  if [ "$count" -lt 3 ]; then
    printf 'HTTP/1.1 404 Not Found\r\nX-Content-Type-Options: nosniff\r\n\r\n'
    exit 0
  fi
  cat <<'HEADERS'
HTTP/1.1 200 OK
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=()
Content-Security-Policy: default-src 'none'
Server: nginx

HEADERS
  exit 0
fi

exit 0
EOF

  chmod +x "$fakebin/make" "$fakebin/docker" "$fakebin/sleep" "$fakebin/curl"

  (
    cd "$state" || exit 1
    PATH="$fakebin:$PATH" \
      TEST_STATE_DIR="$state" \
      SMOKE_RETRIES=2 \
      SMOKE_RETRY_SLEEP_SECONDS=0 \
      SMOKE_SPA_RETRIES=4 \
      SMOKE_SPA_RETRY_SLEEP_SECONDS=0 \
      bash "$SMOKE_SCRIPT" >/dev/null 2>&1
  )
  exit_code=$?

  assert_equal 0 "$exit_code" "ci-smoke succeeds once SPA returns 200 with headers"
  assert_equal 3 "$(cat "$state/spa_count")" "ci-smoke retries SPA probe until the third attempt"

  rm -rf "$dir"
}

printf 'Running ci-smoke harness tests\n\n'
case_spa_probe_retries_until_headers_ready

printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mAll ci-smoke harness tests passed (%d assertions).\033[0m\n' "$PASS"
  exit 0
fi

printf '\033[31mci-smoke harness failed: %d assertion(s) failed.\033[0m\n' "$FAIL"
exit 1
