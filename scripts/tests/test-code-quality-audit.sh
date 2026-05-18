#!/usr/bin/env bash
# Bash harness for scripts/code-quality-audit.sh.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
AUDIT_SCRIPT="$REPO_ROOT/scripts/code-quality-audit.sh"

PASS=0
FAIL=0

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$label" "$expected" "$actual" >&2
  fi
}

make_lines() {
  local count="$1"
  local path="$2"
  mkdir -p "$(dirname "$path")"
  awk -v n="$count" 'BEGIN { for (i = 1; i <= n; i++) print "line " i }' > "$path"
}

run_audit() {
  local repo="$1"
  CODE_QUALITY_REPO_ROOT="$repo" \
    CODE_QUALITY_BASELINE="$repo/scripts/code-quality-file-size-baseline.tsv" \
    CODE_QUALITY_MAX_LINES=5 \
    "$AUDIT_SCRIPT" >/tmp/code-quality-audit.out 2>/tmp/code-quality-audit.err
}

with_fixture() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/scripts"
  printf '%s\n' "$dir"
}

test_passes_when_oversized_file_matches_baseline() {
  local repo
  repo=$(with_fixture)
  make_lines 7 "$repo/app/src/views/LargeView.vue"
  printf 'app/src/views/LargeView.vue\t7\n' > "$repo/scripts/code-quality-file-size-baseline.tsv"

  run_audit "$repo"
  assert_equal 0 "$?" "baseline oversized file at recorded size passes"
  rm -rf "$repo"
}

test_fails_when_baseline_file_grows() {
  local repo
  repo=$(with_fixture)
  make_lines 8 "$repo/api/endpoints/large_endpoints.R"
  printf 'api/endpoints/large_endpoints.R\t7\n' > "$repo/scripts/code-quality-file-size-baseline.tsv"

  run_audit "$repo"
  assert_equal 1 "$?" "baseline oversized file growth fails"
  rm -rf "$repo"
}

test_fails_when_new_source_exceeds_limit() {
  local repo
  repo=$(with_fixture)
  make_lines 6 "$repo/app/src/components/NewLarge.vue"
  : > "$repo/scripts/code-quality-file-size-baseline.tsv"

  run_audit "$repo"
  assert_equal 1 "$?" "new oversized source file fails"
  rm -rf "$repo"
}

test_ignores_tests_migrations_fixtures_and_generated_output() {
  local repo
  repo=$(with_fixture)
  make_lines 20 "$repo/api/tests/testthat/test-large.R"
  make_lines 20 "$repo/app/src/components/Large.spec.ts"
  make_lines 20 "$repo/app/src/test-utils/mocks/handlers.ts"
  make_lines 20 "$repo/db/migrations/999_large.sql"
  make_lines 20 "$repo/db/fixtures/large.sql"
  make_lines 20 "$repo/app/dist/generated.js"
  : > "$repo/scripts/code-quality-file-size-baseline.tsv"

  run_audit "$repo"
  assert_equal 0 "$?" "non-production and generated files are ignored"
  rm -rf "$repo"
}

printf '==> Running code-quality-audit harness\n\n'

test_passes_when_oversized_file_matches_baseline
test_fails_when_baseline_file_grows
test_fails_when_new_source_exceeds_limit
test_ignores_tests_migrations_fixtures_and_generated_output

if [ "$FAIL" -gt 0 ]; then
  printf '\n%d failed, %d passed\n' "$FAIL" "$PASS" >&2
  exit 1
fi

printf '\nAll code-quality-audit harness tests passed (%d assertions).\n' "$PASS"
