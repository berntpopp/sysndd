#!/usr/bin/env bash
#
# generate-csr.sh
#
# SAFE, dry-run-by-default helper that builds the openssl command to generate a
# TLS private key + Certificate Signing Request (CSR) for the SysNDD frontend.
#
# This is the FIRST step of the yearly certificate renewal workflow described in
# `.planning/decisions/2026-06-11-tls-certificate-renewal-automation.md` and the
# operator runbook in `documentation/09-deployment.qmd`. It deliberately does NOT
# submit the CSR to a CA, install a signed certificate, or reload the proxy.
# Those steps are CA-/deployment-specific and are left as clearly-marked TODO
# hooks at the end of this file.
#
# Safety properties:
#   * Dry-run is the DEFAULT. Without --apply the script prints the openssl
#     command(s) it WOULD run and exits 0 without touching any key material.
#   * It refuses to write key/CSR material inside the git working tree.
#   * It never logs the private key and creates keys with 0600 permissions.
#   * Subject and SAN are config-/env-driven; nothing is hard-coded as a secret.
#
# Usage:
#   scripts/cert/generate-csr.sh [--config FILE] [--out-dir DIR] [--apply]
#                                [--force] [--print-config] [-h|--help]
#
# Configuration precedence (low -> high):
#   1. Built-in defaults (below)
#   2. Config file (default: scripts/cert/cert-renewal.conf; or --config FILE)
#   3. Environment variables (CERT_* — see cert-renewal.conf.example)
#   4. CLI flags (--out-dir)
#
# Exit codes:
#   0  success (dry-run printed, or --apply generated key + CSR)
#   1  usage / validation error
#   2  openssl missing or generation failed (only reachable with --apply)
#
# Refs:
#   - GitHub issue #25 (automate CSR creation + certificate signing)
#   - .planning/decisions/2026-06-11-tls-certificate-renewal-automation.md

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="${CERT_REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ---------------------------------------------------------------------------
# Built-in defaults (override via config file / env / flags).
# These match the public SysNDD deployment but carry NO secret material.
# ---------------------------------------------------------------------------
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/cert-renewal.conf"

CERT_COMMON_NAME="${CERT_COMMON_NAME:-sysndd.dbmr.unibe.ch}"
CERT_SAN="${CERT_SAN:-sysndd.dbmr.unibe.ch}"
CERT_COUNTRY="${CERT_COUNTRY:-CH}"
CERT_STATE="${CERT_STATE:-Bern}"
CERT_LOCALITY="${CERT_LOCALITY:-Bern}"
CERT_ORG="${CERT_ORG:-Universitaet Bern}"
CERT_ORG_UNIT="${CERT_ORG_UNIT:-DBMR}"
CERT_EMAIL="${CERT_EMAIL:-}"
CERT_KEY_BITS="${CERT_KEY_BITS:-4096}"
# Output directory MUST live outside the repository tree. The default points at
# an operator-managed, gitignored location; never a path inside REPO_ROOT.
CERT_OUT_DIR="${CERT_OUT_DIR:-/etc/sysndd/certs}"

# ---------------------------------------------------------------------------
# CLI state
# ---------------------------------------------------------------------------
APPLY=0
FORCE=0
PRINT_CONFIG=0
CONFIG_FILE="$DEFAULT_CONFIG_FILE"
CLI_OUT_DIR=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# Build an RFC 4514-style subject string for `openssl req -subj`.
# Pure function of the CERT_* values; no side effects. Emits to stdout so it can
# be unit-tested in isolation. Empty optional components are omitted.
#
# Globals read: CERT_COUNTRY CERT_STATE CERT_LOCALITY CERT_ORG CERT_ORG_UNIT
#               CERT_COMMON_NAME CERT_EMAIL
build_subject() {
  local subject=""
  [ -n "${CERT_COUNTRY:-}" ]     && subject+="/C=${CERT_COUNTRY}"
  [ -n "${CERT_STATE:-}" ]       && subject+="/ST=${CERT_STATE}"
  [ -n "${CERT_LOCALITY:-}" ]    && subject+="/L=${CERT_LOCALITY}"
  [ -n "${CERT_ORG:-}" ]         && subject+="/O=${CERT_ORG}"
  [ -n "${CERT_ORG_UNIT:-}" ]    && subject+="/OU=${CERT_ORG_UNIT}"
  [ -n "${CERT_COMMON_NAME:-}" ] && subject+="/CN=${CERT_COMMON_NAME}"
  [ -n "${CERT_EMAIL:-}" ]       && subject+="/emailAddress=${CERT_EMAIL}"
  printf '%s' "$subject"
}

# Build the comma-separated SAN extension value (subjectAltName) from CERT_SAN,
# which is a space- and/or comma-separated list of DNS names. The CN is always
# included so legacy verifiers that ignore SAN still match. Pure function.
#
# Globals read: CERT_SAN CERT_COMMON_NAME
build_san() {
  local raw="${CERT_SAN:-} ${CERT_COMMON_NAME:-}"
  local name out=""
  # Normalise commas to spaces, then de-duplicate while preserving order.
  for name in ${raw//,/ }; do
    [ -n "$name" ] || continue
    case ",$out," in
      *",DNS:$name,"*) continue ;;
    esac
    [ -n "$out" ] && out+=","
    out+="DNS:$name"
  done
  printf '%s' "$out"
}

# Build the openssl arg vector (one arg per line) that generates key + CSR in a
# single invocation. Pure function of the resolved config + paths; prints the
# args so the dry-run path and the unit test can both inspect them without ever
# executing openssl.
#
# Args: $1 = key path, $2 = csr path, $3 = subject, $4 = san value
build_openssl_args() {
  local key_path="$1" csr_path="$2" subject="$3" san="$4"
  printf '%s\n' \
    "req" \
    "-new" \
    "-newkey" "rsa:${CERT_KEY_BITS}" \
    "-nodes" \
    "-keyout" "$key_path" \
    "-out" "$csr_path" \
    "-subj" "$subject" \
    "-addext" "subjectAltName=${san}"
}

# Render an argv (passed on stdin, one arg per line) as a copy-pasteable,
# shell-quoted command line for dry-run display. Pure function.
render_command() {
  local rendered="openssl"
  local arg
  while IFS= read -r arg; do
    rendered+=" $(printf '%q' "$arg")"
  done
  printf '%s\n' "$rendered"
}

# Reject output directories that live inside the repository working tree so we
# never write key material that could be committed. Reads REPO_ROOT.
assert_out_dir_outside_repo() {
  local out_dir="$1" abs
  # Normalise without requiring the directory to exist yet.
  abs=$(cd "$(dirname "$out_dir")" 2>/dev/null && printf '%s/%s' "$(pwd)" "$(basename "$out_dir")") \
    || abs="$out_dir"
  case "$abs/" in
    "$REPO_ROOT"/*)
      die "refusing to write key/CSR inside the repo tree: $abs
       Set CERT_OUT_DIR (or --out-dir) to an operator-managed path outside $REPO_ROOT." ;;
  esac
}

load_config_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  # Config files are operator-owned shell fragments of KEY=value assignments.
  # shellcheck source=/dev/null
  . "$file"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --config)        CONFIG_FILE="${2:-}"; shift 2 ;;
      --config=*)      CONFIG_FILE="${1#*=}"; shift ;;
      --out-dir)       CLI_OUT_DIR="${2:-}"; shift 2 ;;
      --out-dir=*)     CLI_OUT_DIR="${1#*=}"; shift ;;
      --apply)         APPLY=1; shift ;;
      --force)         FORCE=1; shift ;;
      --print-config)  PRINT_CONFIG=1; shift ;;
      -h|--help)       usage; exit 0 ;;
      *)               die "unknown argument: $1 (try --help)" ;;
    esac
  done
}

print_resolved_config() {
  log "Resolved configuration (no secrets):"
  log "  CERT_COMMON_NAME = $CERT_COMMON_NAME"
  log "  CERT_SAN         = $(build_san)"
  log "  subject          = $(build_subject)"
  log "  CERT_KEY_BITS    = $CERT_KEY_BITS"
  log "  CERT_OUT_DIR     = $CERT_OUT_DIR"
  log "  config file      = ${CONFIG_FILE} ($([ -f "$CONFIG_FILE" ] && echo present || echo absent))"
}

# ---------------------------------------------------------------------------
# TODO hooks — deployment-/CA-specific. Intentionally NOT implemented here.
# Each prints guidance under dry-run and refuses to proceed silently under
# --apply until an operator wires up the real transport for their authority.
# ---------------------------------------------------------------------------
submit_csr_to_ca() {
  local csr_path="$1"
  cat >&2 <<EOF
TODO(#25): submit_csr_to_ca is not implemented.
  CSR ready for submission: $csr_path
  Wire up ONE of the following for your certificate authority:
    - ACME (preferred if a public CA is acceptable): let Traefik or certbot
      handle issuance/renewal automatically — no manual CSR needed.
    - Institutional CA: submit $csr_path via the authority's portal/API/email,
      then place the returned chain at CERT_OUT_DIR/cert.pem.
  See .planning/decisions/2026-06-11-tls-certificate-renewal-automation.md.
EOF
}

install_signed_cert() {
  cat >&2 <<EOF
TODO(#25): install_signed_cert is not implemented.
  After receiving the signed certificate (+ intermediate chain):
    1. Validate it matches the generated key (the two MD5s must be identical):
         openssl x509 -noout -modulus -in cert.pem | openssl md5
         openssl rsa  -noout -modulus -in key.pem  | openssl md5
    2. Atomically place cert.pem (+ chain) and key.pem at the proxy's mount.
    3. Keep the PREVIOUS cert/key as .bak for rollback.
EOF
}

reload_proxy() {
  cat >&2 <<EOF
TODO(#25): reload_proxy is not implemented.
  Reload TLS without dropping connections, e.g.:
    - nginx:   docker compose exec <proxy> nginx -s reload
    - Traefik file-provider: certs hot-reload automatically on file change.
  Verify post-reload:
    echo | openssl s_client -connect ${CERT_COMMON_NAME}:443 \\
      -servername ${CERT_COMMON_NAME} 2>/dev/null | openssl x509 -noout -dates
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  parse_args "$@"

  load_config_file "$CONFIG_FILE"
  # CLI --out-dir overrides config/env for the output directory.
  CERT_OUT_DIR="${CLI_OUT_DIR:-$CERT_OUT_DIR}"

  if [ "$PRINT_CONFIG" -eq 1 ]; then
    print_resolved_config
    exit 0
  fi

  [ -n "$CERT_COMMON_NAME" ] || die "CERT_COMMON_NAME must not be empty."
  case "$CERT_KEY_BITS" in
    2048|3072|4096) ;;
    *) die "CERT_KEY_BITS must be one of 2048, 3072, 4096 (got: $CERT_KEY_BITS)." ;;
  esac

  assert_out_dir_outside_repo "$CERT_OUT_DIR"

  local stamp key_path csr_path subject san
  stamp=$(date +%Y%m%d)
  key_path="$CERT_OUT_DIR/${CERT_COMMON_NAME}.${stamp}.key.pem"
  csr_path="$CERT_OUT_DIR/${CERT_COMMON_NAME}.${stamp}.csr.pem"
  subject=$(build_subject)
  san=$(build_san)

  local args rendered
  args=$(build_openssl_args "$key_path" "$csr_path" "$subject" "$san")
  rendered=$(printf '%s\n' "$args" | render_command)

  if [ "$APPLY" -eq 0 ]; then
    log "DRY-RUN (default): no key or CSR was generated."
    log ""
    print_resolved_config
    log ""
    log "Would create:"
    log "  key: $key_path  (mode 0600)"
    log "  csr: $csr_path"
    log ""
    log "Would run:"
    log "  $rendered"
    log ""
    log "Re-run with --apply to generate the key + CSR for real."
    log "Subsequent steps (submit / install / reload) are operator TODO hooks:"
    submit_csr_to_ca "$csr_path"
    exit 0
  fi

  # --- live path (--apply) -------------------------------------------------
  command -v openssl >/dev/null 2>&1 || { printf 'ERROR: openssl not found on PATH.\n' >&2; exit 2; }

  if [ -e "$key_path" ] && [ "$FORCE" -eq 0 ]; then
    die "key already exists: $key_path (use --force to overwrite)."
  fi

  mkdir -p "$CERT_OUT_DIR"
  # Tighten umask so the freshly written private key is not group/other readable.
  (
    umask 077
    log "Generating key + CSR (this is the only live operation)..."
    # Re-build argv as a bash array so paths/subjects with spaces survive.
    local -a argv=()
    while IFS= read -r line; do argv+=("$line"); done <<< "$args"
    openssl "${argv[@]}" || { printf 'ERROR: openssl generation failed.\n' >&2; exit 2; }
  )
  chmod 600 "$key_path" 2>/dev/null || warn "could not chmod 600 $key_path"

  log "Generated:"
  log "  key: $key_path (KEEP SECRET; never commit)"
  log "  csr: $csr_path (safe to send to the signing authority)"
  log ""
  log "Next operator steps (not automated — see runbook):"
  submit_csr_to_ca "$csr_path"
  install_signed_cert
  reload_proxy
}

# Allow sourcing for unit tests without executing main().
if [ "${CERT_SKIP_MAIN:-0}" != "1" ]; then
  main "$@"
fi
