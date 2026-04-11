#!/usr/bin/env bash
#
# scripts/verify-msw-against-openapi.sh
#
# Phase B.B1 (v11.0): statically verifies that every MSW handler in
# app/src/test-utils/mocks/handlers.ts targets a real plumber annotation
# (@get/@post/@put/@delete) in the corresponding api/endpoints/*.R file.
#
# Fails loudly when a handler drifts away from the real API. Pair this with
# `onUnhandledRequest: 'error'` in vitest.setup.ts — together they give us
# "MSW is always a faithful mirror of the live API". If you intentionally
# mock an endpoint the R API does not expose (e.g. the handler table in
# .plans/v11.0/phase-b.md lists it as a known spec bug), add an explicit
# entry to scripts/msw-openapi-exceptions.txt.
#
# Usage:
#   scripts/verify-msw-against-openapi.sh [--help]
#
# Wired into: `make lint-app` via the root Makefile.
#
# Exit codes:
#   0 — every handler maps to a real plumber annotation (or to an exception)
#   1 — at least one handler drifted and is not in the exception file

set -euo pipefail

# Require Bash 3.2+ (the floor that still ships as /bin/bash on macOS). The
# script deliberately avoids Bash 4+ associative arrays so it runs unmodified
# on a stock macOS developer machine. The version check here is defensive —
# if a future edit introduces a Bash 4-only construct, the error message
# points the user at the fix instead of throwing a cryptic syntax error.
if (( BASH_VERSINFO[0] < 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  echo "verify-msw-against-openapi: requires Bash 3.2+ (detected ${BASH_VERSION})" >&2
  echo "  macOS users: install a newer bash via 'brew install bash' and re-run with it." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HANDLERS_FILE="${REPO_ROOT}/app/src/test-utils/mocks/handlers.ts"
ENDPOINTS_DIR="${REPO_ROOT}/api/endpoints"
EXCEPTIONS_FILE="${SCRIPT_DIR}/msw-openapi-exceptions.txt"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '3,30p' "$0"
  exit 0
fi

if [[ ! -f "${HANDLERS_FILE}" ]]; then
  echo "verify-msw-against-openapi: handlers.ts not found at ${HANDLERS_FILE}" >&2
  exit 1
fi

if [[ ! -d "${ENDPOINTS_DIR}" ]]; then
  echo "verify-msw-against-openapi: endpoints dir not found at ${ENDPOINTS_DIR}" >&2
  exit 1
fi

# Mount-point → endpoint file map (from api/start_sysndd_api.R pr_mount calls).
# Longest prefixes first so `/api/auth` wins over any shorter match.
declare -a MOUNTS=(
  "/api/statistics:statistics_endpoints.R"
  "/api/comparisons:comparisons_endpoints.R"
  "/api/publication:publication_endpoints.R"
  "/api/phenotype:phenotype_endpoints.R"
  "/api/re_review:re_review_endpoints.R"
  "/api/external:external_endpoints.R"
  "/api/ontology:ontology_endpoints.R"
  "/api/analysis:analysis_endpoints.R"
  "/api/version:version_endpoints.R"
  "/api/logging:logging_endpoints.R"
  "/api/variant:variant_endpoints.R"
  "/api/backup:backup_endpoints.R"
  "/api/search:search_endpoints.R"
  "/api/health:health_endpoints.R"
  "/api/entity:entity_endpoints.R"
  "/api/review:review_endpoints.R"
  "/api/status:status_endpoints.R"
  "/api/panels:panels_endpoints.R"
  "/api/admin:admin_endpoints.R"
  "/api/about:about_endpoints.R"
  "/api/gene:gene_endpoints.R"
  "/api/jobs:jobs_endpoints.R"
  "/api/hash:hash_endpoints.R"
  "/api/logs:logging_endpoints.R"
  "/api/list:list_endpoints.R"
  "/api/user:user_endpoints.R"
  "/api/auth:authentication_endpoints.R"
  "/api/llm:llm_admin_endpoints.R"
)

# --- Load exceptions ---------------------------------------------------------
#
# Uses a plain indexed array, not an associative array (declare -A), so this
# script works on Bash 3.2 — still the default /bin/bash on macOS as of 2025.
# Lookup is O(n) but n is tiny (4 entries today, a handful max ever). See
# Copilot review comment #4 on PR #236 for the rationale.
EXCEPTIONS=()
if [[ -f "${EXCEPTIONS_FILE}" ]]; then
  while IFS= read -r line; do
    [[ -z "${line// }" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue
    # Format: METHOD /api/<path>#reason
    key="${line%%#*}"
    # Trim trailing whitespace (spaces and tabs).
    key="${key%"${key##*[![:space:]]}"}"
    EXCEPTIONS+=("${key}")
  done < "${EXCEPTIONS_FILE}"
fi

# Portable membership check: returns 0 if $1 is an element of EXCEPTIONS, 1 otherwise.
# Works on Bash 3.2+ (no associative arrays).
is_exception() {
  local needle="$1"
  local e
  for e in "${EXCEPTIONS[@]:-}"; do
    if [[ "${e}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}

# --- Extract handlers from handlers.ts --------------------------------------
# Match lines like:   http.get('/api/auth/signin', ... )
# Captures METHOD and PATH. Skips commented-out lines (leading //).
mapfile -t HANDLER_LINES < <(
  grep -nE "^[[:space:]]*http\.(get|post|put|delete|patch)\('/api/" "${HANDLERS_FILE}" || true
)

if [[ ${#HANDLER_LINES[@]} -eq 0 ]]; then
  echo "verify-msw-against-openapi: no handlers found in ${HANDLERS_FILE}" >&2
  exit 1
fi

# --- Helper: given a handler path, find the endpoint file --------------------
resolve_endpoint_file() {
  local path="$1"
  for entry in "${MOUNTS[@]}"; do
    local prefix="${entry%%:*}"
    local file="${entry##*:}"
    if [[ "${path}" == "${prefix}" || "${path}" == "${prefix}/"* ]]; then
      echo "${file}"
      return 0
    fi
  done
  return 1
}

# --- Helper: normalize path params -------------------------------------------
# Convert "/api/review/:id/phenotypes"  → sub = "/<param>/phenotypes"
# Convert "/api/user/bulk_approve"      → sub = "/bulk_approve"
# Convert "/api/review/approve/:id"     → sub = "/approve/<param>"
normalize_subpath() {
  local path="$1"
  local prefix="$2"
  local sub="${path#"${prefix}"}"
  # Replace ":<name>" with a plumber-style placeholder
  echo "${sub}" | sed -E 's#:[A-Za-z_][A-Za-z0-9_]*#<param>#g'
}

# --- Helper: check that R file has an annotation for method+subpath ---------
# Plumber annotations look like:
#   #* @get signin
#   #* @put /update
#   #* @get /<sysndd_id>/phenotypes
#   #* @get <user_id>/contributions
#   #* @delete delete
# We normalize both sides to compare robustly:
#   - strip a leading "/"
#   - replace any `<name>` placeholder with `<param>`
#   - lowercase the method
normalize_annotation_path() {
  local raw="$1"
  local stripped="${raw#/}"
  echo "${stripped}" | sed -E 's#<[A-Za-z_][A-Za-z0-9_]*>#<param>#g'
}

has_annotation() {
  local endpoint_file="$1"
  local method="$2"
  local subpath="$3"

  local want
  want="$(normalize_annotation_path "${subpath}")"

  # Empty subpath corresponds to "/" — plumber files use "@get /"
  if [[ -z "${want}" ]]; then
    want="/"
  fi

  # Pull every annotation line and normalize
  while IFS= read -r line; do
    # Line looks like: "#* @get /<review_id_requested>/phenotypes"
    # Strip leading "#* @", then split on whitespace into [method, path]
    local trimmed="${line#*@}"
    local ann_method="${trimmed%% *}"
    local ann_path="${trimmed#* }"
    # Guard against annotations with no path (e.g., "@tag review")
    if [[ "${ann_method}" == "${ann_path}" ]]; then
      continue
    fi
    if [[ "${ann_method,,}" != "${method,,}" ]]; then
      continue
    fi
    local ann_norm
    ann_norm="$(normalize_annotation_path "${ann_path%% *}")"
    # ann_norm empty => "/"
    if [[ -z "${ann_norm}" ]]; then
      ann_norm="/"
    fi
    if [[ "${ann_norm}" == "${want}" ]]; then
      return 0
    fi
  done < <(grep -E "^#\*[[:space:]]+@(get|post|put|delete|patch)[[:space:]]" "${endpoint_file}" || true)

  return 1
}

# --- Main loop ---------------------------------------------------------------
fail_count=0
handler_count=0

for record in "${HANDLER_LINES[@]}"; do
  # record format:  <lineno>:<content>
  content="${record#*:}"
  method="$(echo "${content}" | sed -nE "s#^[[:space:]]*http\.(get|post|put|delete|patch)\('/api/.*#\1#p")"
  path="$(echo "${content}" | sed -nE "s#^[[:space:]]*http\.(get|post|put|delete|patch)\('(/api/[^']*)'.*#\2#p")"

  if [[ -z "${method}" || -z "${path}" ]]; then
    continue
  fi

  handler_count=$((handler_count + 1))
  method_upper="$(echo "${method}" | tr '[:lower:]' '[:upper:]')"
  key="${method_upper} ${path}"

  # 1. Allowed via exception?
  if is_exception "${key}"; then
    continue
  fi

  # 2. Resolve endpoint file
  if ! endpoint_basename="$(resolve_endpoint_file "${path}")"; then
    echo "FAIL: ${key} — no /api/* mount prefix matches (unknown resource)" >&2
    fail_count=$((fail_count + 1))
    continue
  fi
  endpoint_file="${ENDPOINTS_DIR}/${endpoint_basename}"
  if [[ ! -f "${endpoint_file}" ]]; then
    echo "FAIL: ${key} — resolved endpoint file does not exist: ${endpoint_file}" >&2
    fail_count=$((fail_count + 1))
    continue
  fi

  # 3. Extract the sub-path (after the mount prefix) and check annotation
  prefix=""
  for entry in "${MOUNTS[@]}"; do
    p="${entry%%:*}"
    if [[ "${path}" == "${p}" || "${path}" == "${p}/"* ]]; then
      prefix="${p}"
      break
    fi
  done
  subpath="$(normalize_subpath "${path}" "${prefix}")"

  if ! has_annotation "${endpoint_file}" "${method}" "${subpath}"; then
    echo "FAIL: ${key} — no matching @${method} ${subpath} annotation in ${endpoint_basename}" >&2
    echo "      (add an exception in scripts/msw-openapi-exceptions.txt if this is a known spec-table bug)" >&2
    fail_count=$((fail_count + 1))
  fi
done

if [[ ${fail_count} -gt 0 ]]; then
  echo "" >&2
  echo "verify-msw-against-openapi: ${fail_count} handler(s) drifted out of ${handler_count} total" >&2
  exit 1
fi

echo "verify-msw-against-openapi: ${handler_count} handler(s) OK"
exit 0
