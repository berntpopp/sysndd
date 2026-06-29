#!/usr/bin/env bash
# app/tests/e2e/fixtures/seed-blocked-ontology.sh
#
# Seeds the blocked-OMIM-update fixture into a running Playwright stack so that
# admin.ontology-blocked-banner.spec.ts (test 1) can observe the persistent
# blocked banner on /ManageAnnotations load.
#
# Two things are seeded:
#   (a) One async_jobs row (omim_update / completed / status:"blocked") from
#       db/fixtures/playwright_blocked_omim_job.sql
#   (b) A fresh pending CSV copied into the API container at the path the row
#       references — /app/data/pending_ontology/pending_ontology_update.2026-06-29.csv
#       The API's .ontology_status_csv_fresh() function checks that this file
#       exists AND is ≤ 48 h old; without it the endpoint returns blocked=false.
#
# Usage
# -----
#   bash app/tests/e2e/fixtures/seed-blocked-ontology.sh
#
# Prerequisites
# -------------
#   make playwright-stack        (stack must be healthy at http://localhost:8088)
#   A local copy of the pending CSV (see PENDING_CSV_SRC below).
#
# Overridable environment variables
# ----------------------------------
#   MYSQL           MySQL container name   (default: sysndd_playwright_mysql)
#   API             API container name     (default: sysndd_playwright_api)
#   MYSQL_USER      DB user                (default: playwright)
#   MYSQL_PASSWORD  DB password            (default: playwright_pw)
#   MYSQL_DATABASE  DB name                (default: sysndd_db)
#   PENDING_CSV_SRC Local path to the source pending CSV file.
#                   Default: /run/media/bernt-popp/1819-E513/sysndd-omim-investigation/pending_ontology_update.2026-06-29.csv
#                   Override if the CSV is located elsewhere on the host.

set -euo pipefail

MYSQL="${MYSQL:-sysndd_playwright_mysql}"
API="${API:-sysndd_playwright_api}"
MYSQL_USER="${MYSQL_USER:-playwright}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-playwright_pw}"
MYSQL_DATABASE="${MYSQL_DATABASE:-sysndd_db}"
PENDING_CSV_SRC="${PENDING_CSV_SRC:-/run/media/bernt-popp/1819-E513/sysndd-omim-investigation/pending_ontology_update.2026-06-29.csv}"

# Resolve paths relative to this script's directory so the script can be
# invoked from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
SQL_FIXTURE="${REPO_ROOT}/db/fixtures/playwright_blocked_omim_job.sql"

# ── Pre-flight checks ────────────────────────────────────────────────────────

if [ ! -f "${SQL_FIXTURE}" ]; then
  echo "ERROR: SQL fixture not found at ${SQL_FIXTURE}" >&2
  exit 1
fi

# The blocked banner only needs the pending CSV to EXIST and be ≤ 48 h old
# (api/functions/ontology-status-service.R::.ontology_status_csv_fresh() checks
# file.exists() + mtime — it never reads the contents). So when a real source
# CSV isn't available on this host (e.g. CI or a fresh checkout without the
# OMIM-investigation drive mounted), synthesize a minimal placeholder rather
# than failing — the freshness gate is satisfied identically.
if [ ! -f "${PENDING_CSV_SRC}" ]; then
  echo "NOTE: Source pending CSV not found at ${PENDING_CSV_SRC}" >&2
  echo "      Synthesizing a minimal placeholder CSV (content is not read by the" >&2
  echo "      blocked-banner freshness check — only existence + mtime ≤ 48 h)." >&2
  PENDING_CSV_SRC="$(mktemp --suffix=.csv)"
  printf 'disease_ontology_id_version,update_type\nOMIM:000000_1,blocked_placeholder\n' \
    > "${PENDING_CSV_SRC}"
fi

# ── Step 1: seed the async_jobs row ─────────────────────────────────────────

echo "[1/3] Seeding blocked omim_update job row into ${MYSQL} (DB: ${MYSQL_DATABASE})..."
docker exec -i "${MYSQL}" \
  mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" \
  < "${SQL_FIXTURE}"
echo "      Done."

# ── Step 2: create the pending_ontology directory in the API container ───────

echo "[2/3] Creating /app/data/pending_ontology in ${API}..."
docker exec "${API}" mkdir -p /app/data/pending_ontology
echo "      Done."

# ── Step 3: copy the pending CSV into the API container ─────────────────────
# The API's .ontology_status_csv_fresh() checks:
#   file.exists("data/pending_ontology/pending_ontology_update.2026-06-29.csv")
# relative to the API container working directory /app — so the absolute target
# path is /app/data/pending_ontology/pending_ontology_update.2026-06-29.csv.
# The file must be ≤ 48 h old (mtime check), which is satisfied by a fresh copy.

echo "[3/3] Copying pending CSV to ${API}:/app/data/pending_ontology/pending_ontology_update.2026-06-29.csv..."
docker cp \
  "${PENDING_CSV_SRC}" \
  "${API}:/app/data/pending_ontology/pending_ontology_update.2026-06-29.csv"
echo "      Done."

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Seed complete. The blocked-banner spec should now pass:"
echo ""
echo "  cd app && npx playwright test tests/e2e/admin.ontology-blocked-banner.spec.ts --project=chromium-desktop"
echo ""
echo "NOTE: the curator-hint test (test 2) additionally requires entity 123 (CHD8)."
echo "      If that test skips, run:  make _playwright-seed-docs-data"
