#!/usr/bin/env bash
# Bash harness for scripts/cert/generate-csr.sh.
#
# Tests the PURE logic (subject/SAN/argv/command building) and the dry-run +
# safety guards WITHOUT ever invoking live openssl key generation. The target
# script is sourced with CERT_SKIP_MAIN=1 so main() does not run on source.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
CSR_SCRIPT="$REPO_ROOT/scripts/cert/generate-csr.sh"

PASS=0
FAIL=0

assert_equal() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$label" "$expected" "$actual" >&2
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in
    *"$needle"*) PASS=$((PASS + 1)) ;;
    *)
      FAIL=$((FAIL + 1))
      printf 'FAIL: %s\n  expected to contain: %s\n  in: %s\n' "$label" "$needle" "$haystack" >&2
      ;;
  esac
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in
    *"$needle"*)
      FAIL=$((FAIL + 1))
      printf 'FAIL: %s\n  expected NOT to contain: %s\n  in: %s\n' "$label" "$needle" "$haystack" >&2
      ;;
    *) PASS=$((PASS + 1)) ;;
  esac
}

# Source the script's pure functions without executing main().
# shellcheck source=/dev/null
CERT_SKIP_MAIN=1 . "$CSR_SCRIPT"

# --- build_subject -------------------------------------------------------
test_build_subject_full() {
  local got
  CERT_COUNTRY="CH" CERT_STATE="Bern" CERT_LOCALITY="Bern" \
    CERT_ORG="Universitaet Bern" CERT_ORG_UNIT="DBMR" \
    CERT_COMMON_NAME="sysndd.dbmr.unibe.ch" CERT_EMAIL="" \
    got=$(build_subject)
  assert_equal "/C=CH/ST=Bern/L=Bern/O=Universitaet Bern/OU=DBMR/CN=sysndd.dbmr.unibe.ch" \
    "$got" "build_subject emits ordered RFC4514 subject and omits empty email"
}

test_build_subject_includes_email_when_set() {
  local got
  CERT_COUNTRY="CH" CERT_STATE="" CERT_LOCALITY="" CERT_ORG="" CERT_ORG_UNIT="" \
    CERT_COMMON_NAME="example.org" CERT_EMAIL="ops@example.org" \
    got=$(build_subject)
  assert_equal "/C=CH/CN=example.org/emailAddress=ops@example.org" \
    "$got" "build_subject includes email and omits empty components"
}

# --- build_san -----------------------------------------------------------
test_build_san_adds_cn_and_dedupes() {
  local got
  CERT_SAN="a.example.org, b.example.org" CERT_COMMON_NAME="a.example.org" \
    got=$(build_san)
  assert_equal "DNS:a.example.org,DNS:b.example.org" \
    "$got" "build_san normalises commas, dedupes, and folds in the CN"
}

test_build_san_space_separated() {
  local got
  CERT_SAN="sysndd.org www.sysndd.org" CERT_COMMON_NAME="sysndd.org" \
    got=$(build_san)
  assert_equal "DNS:sysndd.org,DNS:www.sysndd.org" \
    "$got" "build_san handles space-separated SAN lists"
}

# --- build_openssl_args / render_command ---------------------------------
test_openssl_args_shape() {
  local args
  CERT_KEY_BITS="4096" args=$(build_openssl_args \
    "/etc/sysndd/certs/k.pem" "/etc/sysndd/certs/c.pem" \
    "/CN=sysndd.dbmr.unibe.ch" "DNS:sysndd.dbmr.unibe.ch")
  assert_contains "$args" "rsa:4096" "openssl args carry the configured key size"
  assert_contains "$args" "-nodes" "openssl args use -nodes (no passphrase prompt in automation)"
  assert_contains "$args" "subjectAltName=DNS:sysndd.dbmr.unibe.ch" "openssl args carry the SAN extension"
  assert_contains "$args" "/etc/sysndd/certs/k.pem" "openssl args carry the key output path"
}

test_render_command_quotes_spaces() {
  local args rendered
  args=$(build_openssl_args "/tmp/k.pem" "/tmp/c.pem" "/O=Universitaet Bern/CN=x" "DNS:x")
  rendered=$(printf '%s\n' "$args" | render_command)
  assert_contains "$rendered" "openssl req -new" "rendered command starts with openssl req -new"
  # printf '%q' shell-escapes the embedded space so the command stays paste-safe.
  assert_contains "$rendered" 'Universitaet\ Bern' "rendered command escapes the space in the subject for paste-safety"
}

# --- assert_out_dir_outside_repo (safety guard) --------------------------
test_rejects_out_dir_inside_repo() {
  local out
  out=$( (assert_out_dir_outside_repo "$REPO_ROOT/scripts/cert/secrets") 2>&1 ) && rc=0 || rc=$?
  assert_equal 1 "$rc" "writing inside the repo tree is rejected"
  assert_contains "$out" "refusing to write" "rejection explains why"
}

test_accepts_out_dir_outside_repo() {
  local rc
  (assert_out_dir_outside_repo "/etc/sysndd/certs") >/dev/null 2>&1 && rc=0 || rc=$?
  assert_equal 0 "$rc" "an out-dir outside the repo is accepted"
}

# --- end-to-end dry-run (no openssl execution, no files written) ---------
test_dry_run_prints_command_and_writes_nothing() {
  local out tmp
  tmp=$(mktemp -d)
  out=$(
    CERT_SKIP_MAIN=0 CERT_OUT_DIR="$tmp/certs" \
      bash "$CSR_SCRIPT" --config /nonexistent-config 2>&1
  )
  assert_contains "$out" "DRY-RUN" "default run is a dry-run"
  assert_contains "$out" "openssl req -new" "dry-run prints the openssl command it would run"
  assert_contains "$out" "TODO(#25)" "dry-run surfaces the operator submit TODO hook"
  # The dry-run must not create the output directory or any key material.
  if [ -e "$tmp/certs" ]; then
    FAIL=$((FAIL + 1))
    printf 'FAIL: dry-run created output dir %s\n' "$tmp/certs" >&2
  else
    PASS=$((PASS + 1))
  fi
  rm -rf "$tmp"
}

test_print_config_exits_clean() {
  local out rc
  out=$(CERT_SKIP_MAIN=0 bash "$CSR_SCRIPT" --config /nonexistent --print-config 2>&1) && rc=0 || rc=$?
  assert_equal 0 "$rc" "--print-config exits 0"
  assert_contains "$out" "Resolved configuration" "--print-config shows resolved config"
  assert_not_contains "$out" "BEGIN" "--print-config never prints key material"
}

printf '==> Running generate-csr harness\n\n'

test_build_subject_full
test_build_subject_includes_email_when_set
test_build_san_adds_cn_and_dedupes
test_build_san_space_separated
test_openssl_args_shape
test_render_command_quotes_spaces
test_rejects_out_dir_inside_repo
test_accepts_out_dir_outside_repo
test_dry_run_prints_command_and_writes_nothing
test_print_config_exits_clean

if [ "$FAIL" -gt 0 ]; then
  printf '\n%d failed, %d passed\n' "$FAIL" "$PASS" >&2
  exit 1
fi

printf '\nAll generate-csr harness tests passed (%d assertions).\n' "$PASS"
