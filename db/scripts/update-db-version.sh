#!/bin/sh
# update-db-version.sh
#
# Issue #22 release helper: capture the SysNDD database semantic version and the
# last db/-folder-related git commit short hash, and print them as shell exports
# so deployment can inject DB_VERSION / DB_COMMIT into the API container.
#
# The running API container has no git checkout, so the db-folder commit must be
# resolved at release time on a host that DOES have the repo. The API reads
# DB_VERSION / DB_COMMIT from its environment at startup and upserts the single
# db_version row (id = 1) via db_version_sync_from_env(); the migration seeds a
# baseline row so the surface still works if these are never set.
#
# Usage:
#   # Print exports for the current checkout (version defaults to the seeded one):
#   ./db/scripts/update-db-version.sh
#
#   # Pin a specific semantic version:
#   ./db/scripts/update-db-version.sh 1.1.0
#
#   # Inject into a running deployment via .env, then redeploy:
#   ./db/scripts/update-db-version.sh 1.1.0 >> .env
#
# Output (stdout):
#   DB_VERSION=<semver>
#   DB_COMMIT=<short-hash>
#
# Exit codes:
#   0  exports printed
#   1  not a git repository / db/ folder not found

set -eu

# Resolve repo root relative to this script so it works regardless of CWD.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)

if [ ! -d "${REPO_ROOT}/db" ]; then
  echo "error: db/ folder not found under ${REPO_ROOT}" >&2
  exit 1
fi

if ! git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: ${REPO_ROOT} is not a git work tree" >&2
  exit 1
fi

# Last commit that touched the db/ folder, short hash. Falls back to "unknown".
DB_COMMIT=$(git -C "${REPO_ROOT}" log -1 --format=%h -- db/ 2>/dev/null || true)
if [ -z "${DB_COMMIT}" ]; then
  DB_COMMIT="unknown"
fi

# Semantic version: first CLI arg wins; otherwise reuse the version currently
# seeded in the latest db_version migration so the export stays self-consistent.
DB_VERSION="${1:-}"
if [ -z "${DB_VERSION}" ]; then
  SEED_FILE=$(ls "${REPO_ROOT}"/db/migrations/*_add_db_version.sql 2>/dev/null | sort | tail -1 || true)
  if [ -n "${SEED_FILE}" ]; then
    DB_VERSION=$(grep -Eo "'[0-9]+\.[0-9]+\.[0-9]+'" "${SEED_FILE}" | head -1 | tr -d "'" || true)
  fi
fi
if [ -z "${DB_VERSION}" ]; then
  DB_VERSION="unknown"
fi

echo "DB_VERSION=${DB_VERSION}"
echo "DB_COMMIT=${DB_COMMIT}"
