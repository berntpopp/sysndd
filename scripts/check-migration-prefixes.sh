#!/bin/sh
# check-migration-prefixes.sh
#
# Asserts that every file under db/migrations/ has a unique numbered prefix.
#
# Migration files follow the convention `NNN_description.sql`, where NNN is a
# zero-padded integer. migration-runner.R sorts by filename, so duplicate
# prefixes (e.g. two files both starting with `008_`) produce race-condition
# semantics at startup — the apply order becomes dependent on alphabetical
# tiebreakers of the descriptive suffix.
#
# Usage:
#   ./scripts/check-migration-prefixes.sh
#
# Exit codes:
#   0  no duplicates found
#   1  one or more prefixes are duplicated (or db/migrations/ missing)
#
# Refs:
#   - .plans/v11.0/phase-a.md §3 A4
#   - docs/reviews/2026-04-11-codebase-review.md §2

set -eu

# Resolve repo root relative to this script so it works regardless of CWD.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
MIGRATIONS_DIR="$REPO_ROOT/db/migrations"

if [ ! -d "$MIGRATIONS_DIR" ]; then
  printf 'ERROR: migrations directory not found: %s\n' "$MIGRATIONS_DIR" >&2
  exit 1
fi

# Consider only *.sql files; README and other non-migration files are ignored.
# awk splits on underscore and prints the first field (the numbered prefix).
duplicates=$(
  ls "$MIGRATIONS_DIR" \
    | grep -E '\.sql$' \
    | awk -F_ '{print $1}' \
    | sort \
    | uniq -d
)

if [ -n "$duplicates" ]; then
  printf 'ERROR: duplicate migration prefix(es) detected in db/migrations/:\n' >&2
  printf '%s\n' "$duplicates" | while IFS= read -r prefix; do
    printf '  prefix %s is used by:\n' "$prefix" >&2
    ls "$MIGRATIONS_DIR" \
      | grep -E "^${prefix}_.*\.sql$" \
      | while IFS= read -r f; do
          printf '    - db/migrations/%s\n' "$f" >&2
        done
  done
  printf '\n' >&2
  printf 'Each migration must have a unique NNN_ prefix. Rename one of the\n' >&2
  printf 'conflicting files to the next free slot, commit, and re-run this check.\n' >&2
  exit 1
fi

printf 'OK: all %d migration files have unique prefixes.\n' \
  "$(ls "$MIGRATIONS_DIR" | grep -cE '\.sql$')"
exit 0
