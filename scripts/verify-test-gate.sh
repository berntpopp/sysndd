#!/usr/bin/env bash
# verify-test-gate.sh
#
# Protects Phase D / Phase E PRs from silently mutating pre-existing test files
# to "pin" behavior to whatever the refactor produced. Rule summary:
#
#   For every *.spec.ts or test-*.R file modified in this PR (vs merge-base with
#   master):
#     1. If the file was CREATED in this PR: ALLOWED (new unit/composable specs
#        are how Phase C etc. legitimately add coverage).
#     2. If the file is PRE-EXISTING and the diff touches anything, it is
#        REJECTED — unless an exemption applies.
#
# Exemptions (gated on branch prefix so they cannot leak into other phases):
#   - On v11.0/phase-b/* branches only: adding skip_if_not_slow_tests() calls
#     to pre-existing test-*.R files is allowed. This exemption exists for B3.
#   - On v11.0/phase-b/* branches only: replacing Sys.sleep(N) with
#     wait_for(..., timeout = N) in pre-existing test-*.R or helper-*.R files
#     is allowed. This exemption exists for B5.
#
# Extended mode (--extended): grep every api/tests/testthat/test-integration-*.R
# file and assert each opens with EITHER `with_test_db_transaction` OR a
# documented `skip_if_no_test_db()` exemption explaining why rollback isn't
# usable.
#
# Test overrides (used by scripts/tests/test-verify-test-gate.sh):
#   VERIFY_GATE_REPO_ROOT  override the repo root (default: auto-detect)
#   VERIFY_GATE_BRANCH     override the current branch name
#   VERIFY_GATE_BASE_REF   override the base ref (default: origin/master, then master)
#
# Exit codes: 0 = clean, 1 = violation.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT="${VERIFY_GATE_REPO_ROOT:-$DEFAULT_REPO_ROOT}"
cd "$REPO_ROOT" || { echo "gate: cannot cd $REPO_ROOT" >&2; exit 1; }

EXTENDED=0
for arg in "$@"; do
  [ "$arg" = "--extended" ] && EXTENDED=1
done

# Resolve current branch (env override for harness).
BRANCH="${VERIFY_GATE_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)}"

# Resolve base ref: prefer env, then origin/master, then master.
if [ -n "${VERIFY_GATE_BASE_REF:-}" ]; then
  BASE_REF="$VERIFY_GATE_BASE_REF"
elif git rev-parse --verify -q origin/master >/dev/null; then
  BASE_REF="origin/master"
else
  BASE_REF="master"
fi

VIOLATIONS=0

# ---- Layer A: modified-spec-file gate (skipped if branch == base) -----------
if [ "$BRANCH" != "$BASE_REF" ] && [ "$BRANCH" != "master" ]; then
  MERGE_BASE=$(git merge-base "$BASE_REF" HEAD 2>/dev/null || git rev-parse HEAD)

  # All *.spec.ts and test-*.R files touched since merge-base (any status).
  CHANGED=$(git diff --name-only "$MERGE_BASE"..HEAD -- \
    '*.spec.ts' 'app/**/*.spec.ts' \
    'api/tests/testthat/test-*.R' 'api/tests/testthat/helper-*.R' 2>/dev/null || true)

  for f in $CHANGED; do
    # Status A=added, M=modified, D=deleted, R=renamed. Added files are allowed.
    STATUS=$(git diff --name-status "$MERGE_BASE"..HEAD -- "$f" | awk '{print $1}' | head -n1)
    [ "$STATUS" = "A" ] && continue
    [ "$STATUS" = "D" ] && continue

    # Exemptions: only on v11.0/phase-b/* branches.
    if [[ "$BRANCH" == v11.0/phase-b/* ]]; then
      # Consider the per-file diff — if every ADDED line matches a permitted
      # pattern and every REMOVED line matches its paired pattern, exempt.
      ADDED=$(git diff "$MERGE_BASE"..HEAD -- "$f" | grep -E '^\+[^+]' || true)
      REMOVED=$(git diff "$MERGE_BASE"..HEAD -- "$f" | grep -E '^-[^-]' || true)

      # Exemption 1: skip_if_not_slow_tests() additions, no corresponding deletions.
      if [ -z "$REMOVED" ] && echo "$ADDED" | grep -qE 'skip_if_not_slow_tests\(' && \
         ! echo "$ADDED" | grep -vE '^\+\s*$|skip_if_not_slow_tests\(' | grep -q .; then
        continue
      fi

      # Exemption 2: Sys.sleep(N) -> wait_for(..., timeout = N) replacement.
      # The regex matches any wait_for(...) call with a timeout= kwarg; we
      # deliberately don't constrain the args, since the condition expression
      # may itself contain parentheses.
      if echo "$REMOVED" | grep -qE 'Sys\.sleep\(' && \
         echo "$ADDED"   | grep -qE 'wait_for\(.*timeout[[:space:]]*='; then
        continue
      fi
    fi

    printf 'gate: REJECT pre-existing spec/test file modified: %s (status=%s, branch=%s)\n' \
      "$f" "$STATUS" "$BRANCH" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  done
fi

# ---- Layer B (extended): integration-test rollback invariant ----------------
if [ "$EXTENDED" = "1" ]; then
  for f in api/tests/testthat/test-integration-*.R; do
    [ -f "$f" ] || continue
    # Accept if with_test_db_transaction appears anywhere, OR if there is a
    # skip_if_no_test_db() call AND a comment explaining why rollback isn't used.
    if grep -q 'with_test_db_transaction' "$f"; then continue; fi
    if grep -q 'skip_if_no_test_db()' "$f" && \
       grep -qE '^#.*(exempt|rollback|non-transactional|catalog)' "$f"; then continue; fi
    printf 'gate: REJECT integration test missing rollback wrapper: %s\n' "$f" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  done
fi

if [ "$VIOLATIONS" -gt 0 ]; then
  printf 'gate: %d violation(s) — see above\n' "$VIOLATIONS" >&2
  exit 1
fi
exit 0
