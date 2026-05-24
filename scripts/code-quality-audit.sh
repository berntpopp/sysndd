#!/usr/bin/env bash
#
# Fast deterministic code-quality audit.
#
# The current repository has legacy source files above the 600-line soft
# ceiling. This script enforces a ratchet instead of a hard global cap:
# new handwritten source files cannot exceed the ceiling, and existing
# oversized files cannot grow beyond their committed baseline.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="${CODE_QUALITY_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MAX_LINES="${CODE_QUALITY_MAX_LINES:-600}"
BASELINE="${CODE_QUALITY_BASELINE:-$REPO_ROOT/scripts/code-quality-file-size-baseline.tsv}"

usage() {
  cat <<EOF
Usage: scripts/code-quality-audit.sh [--write-baseline]

Checks handwritten source file sizes against a ${MAX_LINES}-line soft ceiling.

Environment overrides:
  CODE_QUALITY_REPO_ROOT   repository root
  CODE_QUALITY_BASELINE    baseline TSV path
  CODE_QUALITY_MAX_LINES   line ceiling, default 600
EOF
}

collect_counts() {
  local roots=()
  local root
  for root in api app/src app/scripts db scripts; do
    if [ -d "$REPO_ROOT/$root" ]; then
      roots+=("$REPO_ROOT/$root")
    fi
  done

  if [ "${#roots[@]}" -eq 0 ]; then
    return 0
  fi

  find "${roots[@]}" -type f \
    \( -name '*.R' -o -name '*.ts' -o -name '*.vue' -o -name '*.js' -o \
       -name '*.mjs' -o -name '*.cjs' -o -name '*.sh' -o -name '*.sql' -o \
       -name '*.py' \) -print0 |
    while IFS= read -r -d '' file; do
      local rel
      rel=${file#"$REPO_ROOT"/}

      case "$rel" in
        api/renv/*|api/tests/*|api/layout/node_modules/*|app/node_modules/*|app/dist/*|app/coverage/*)
          continue
          ;;
        app/tests/*|app/src/test-utils/*|db/migrations/*|db/fixtures/*|scripts/tests/*)
          continue
          ;;
        app/src/*.spec.ts|app/src/*.test.ts|app/src/*.spec.js|app/src/*.test.js)
          continue
          ;;
      esac

      local lines
      lines=$(wc -l < "$file")
      lines=${lines//[[:space:]]/}
      printf '%s\t%s\n' "$rel" "$lines"
    done | sort -k1,1
}

write_baseline() {
  local tmp
  tmp=$(mktemp)
  collect_counts | awk -F '\t' -v max="$MAX_LINES" '$2 > max { print $1 "\t" $2 }' > "$tmp"
  mkdir -p "$(dirname "$BASELINE")"
  mv "$tmp" "$BASELINE"
  printf 'code-quality-audit: wrote baseline %s\n' "${BASELINE#"$REPO_ROOT"/}"
}

run_audit() {
  local counts
  counts=$(mktemp)
  collect_counts > "$counts"

  local baseline_source
  baseline_source=$(mktemp)
  if [ -f "$BASELINE" ]; then
    cp "$BASELINE" "$baseline_source"
  else
    : > "$baseline_source"
  fi

  local report
  report=$(mktemp)

  awk -F '\t' -v max="$MAX_LINES" -v baseline_file="$baseline_source" '
    FILENAME == baseline_file {
      if ($1 != "" && $2 ~ /^[0-9]+$/) baseline[$1] = $2 + 0
      next
    }
    {
      path = $1
      lines = $2 + 0
      if (lines <= max) next

      if (!(path in baseline)) {
        printf("new oversized source file: %s has %d lines (limit %d)\n", path, lines, max)
        violations++
        next
      }

      if (lines > baseline[path]) {
        printf("oversized source file grew: %s has %d lines (baseline %d, limit %d)\n", path, lines, baseline[path], max)
        violations++
      }
    }
    END { exit violations > 0 ? 1 : 0 }
  ' "$baseline_source" "$counts" > "$report" || {
    cat "$report" >&2
    printf 'code-quality-audit: failed. Extract cohesive code or update the baseline only after reducing/justifying legacy size.\n' >&2
    rm -f "$counts" "$baseline_source" "$report"
    return 1
  }

  rm -f "$counts" "$baseline_source" "$report"
  printf 'code-quality-audit: OK\n'
}

case "${1:-}" in
  --help|-h)
    usage
    ;;
  --write-baseline)
    write_baseline
    ;;
  '')
    run_audit
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
