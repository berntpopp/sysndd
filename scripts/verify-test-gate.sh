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
#   - On v11.0/phase-c/test-endpoint-* branches only: the default-on transaction
#     rollback audit (plan §3 Phase C.4 / §4.5) is allowed to add
#     skip_if_no_test_db() calls and exemption comments matching the keywords
#     rollback/non-transactional/exempt/catalog to pre-existing
#     test-integration-*.R files. Wrapping existing test_that/it blocks in
#     with_test_db_transaction({...}) is also allowed. This exemption exists
#     for C7/C8/C9 to satisfy Layer B's rollback invariant without mutating
#     test assertions.
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
      # Consider the per-file diff — every ADDED and REMOVED line must match
      # a whitelist for the exemption to apply. This is intentionally a
      # whitelist, not a blacklist: if a PR mixes legitimate Phase-B edits
      # with unrelated changes, the unrelated lines don't match the whitelist
      # and the gate rejects the file. See Copilot review comment #6 on
      # PR #236 for the rationale.
      ADDED=$(git diff "$MERGE_BASE"..HEAD -- "$f" | grep -E '^\+[^+]' || true)
      REMOVED=$(git diff "$MERGE_BASE"..HEAD -- "$f" | grep -E '^-[^-]' || true)

      # Exemption 1: skip_if_not_slow_tests() additions only. Every non-blank,
      # non-comment ADDED line must contain `skip_if_not_slow_tests(`, and
      # there must be zero REMOVED lines.
      exemption1_added_noise=$(
        echo "$ADDED" | grep -vE '^\+[[:space:]]*$' \
                      | grep -vE '^\+[[:space:]]*#' \
                      | grep -vE 'skip_if_not_slow_tests\(' \
                      | grep -c '.' || true
      )
      if [ -z "$REMOVED" ] && \
         echo "$ADDED" | grep -qE 'skip_if_not_slow_tests\(' && \
         [ "${exemption1_added_noise}" -eq 0 ]; then
        continue
      fi

      # Exemption 2: Sys.sleep(N) -> wait_for/wait_stable(..., timeout|duration = N)
      # replacement. Every REMOVED non-blank/non-comment line must be a
      # `Sys.sleep(` call or a probe call that moved into a wait_* probe
      # argument. Every ADDED non-blank/non-comment line must match one of the
      # wait helper's own tokens (function call, named arg, closing paren,
      # baseline assignment, or mailpit helper). The REMOVED diff must contain
      # at least one Sys.sleep and the ADDED diff must contain at least one
      # wait_for or wait_stable call.
      #
      # The token whitelist is deliberately conservative — it covers the
      # actual B5 diff shape ({baseline_var} <- wait_stable(probe = function()
      # mailpit_message_count(), duration = N, label = "..."),
      # mailpit_wait_for_message(...)) plus straightforward wait_for(...)
      # variants. Future B5-style changes that need a new whitelisted token
      # should update this list explicitly rather than widen via regex.
      removed_noise=$(
        echo "$REMOVED" | grep -vE '^-[[:space:]]*$' \
                        | grep -vE '^-[[:space:]]*#' \
                        | grep -vE 'Sys\.sleep\(' \
                        | grep -vE '(final_count|count|message)[[:space:]]*<-[[:space:]]*mailpit_' \
                        | grep -c '.' || true
      )
      added_noise=$(
        echo "$ADDED" | grep -vE '^\+[[:space:]]*$' \
                      | grep -vE '^\+[[:space:]]*#' \
                      | grep -vE 'wait_for\(' \
                      | grep -vE 'wait_stable\(' \
                      | grep -vE '^\+[[:space:]]*\)[,[:space:]]*$' \
                      | grep -vE '^\+[[:space:]]+(probe|timeout|duration|label|interval|tolerate)[[:space:]]*=' \
                      | grep -vE '^\+[[:space:]]+function\(\)[[:space:]]*mailpit_' \
                      | grep -vE '^\+[[:space:]]+mailpit_[A-Za-z_]+\(' \
                      | grep -vE '(final_count|count|message)[[:space:]]*<-[[:space:]]*wait_' \
                      | grep -c '.' || true
      )
      if echo "$REMOVED" | grep -qE 'Sys\.sleep\(' && \
         echo "$ADDED"   | grep -qE '(wait_for|wait_stable)\(' && \
         [ "${removed_noise}" -eq 0 ] && \
         [ "${added_noise}" -eq 0 ]; then
        continue
      fi
    fi

    # v11.0/phase-c/test-endpoint-* exemption: default-on rollback audit.
    # Allows pre-existing test-integration-*.R files to be annotated with
    # skip_if_no_test_db() + an exemption comment (rollback/non-transactional/
    # exempt/catalog) and/or wrapped in with_test_db_transaction({...}). No
    # lines may be REMOVED (pure additive audit) and every non-blank/non-comment
    # ADDED line must match a whitelisted token. See plan §3 Phase C.4 / §4.5.
    if [[ "$BRANCH" == v11.0/phase-c/test-endpoint-* ]]; then
      ADDED=$(git diff "$MERGE_BASE"..HEAD -- "$f" | grep -E '^\+[^+]' || true)
      REMOVED=$(git diff "$MERGE_BASE"..HEAD -- "$f" | grep -E '^-[^-]' || true)

      # Whitelist: skip_if_no_test_db() calls, with_test_db_transaction openings
      # and closings, and exemption comments. Blank lines and generic comments
      # are allowed if they contain one of the exemption keywords.
      exemption_c7_added_noise=$(
        echo "$ADDED" | grep -vE '^\+[[:space:]]*$' \
                      | grep -vE '^\+[[:space:]]*#.*(exempt|rollback|non-transactional|catalog)' \
                      | grep -vE 'skip_if_no_test_db\(' \
                      | grep -vE 'with_test_db_transaction\(' \
                      | grep -vE '^\+[[:space:]]*\}\)[[:space:]]*$' \
                      | grep -c '.' || true
      )
      if [ -z "$REMOVED" ] && \
         echo "$ADDED" | grep -qE '(skip_if_no_test_db\(|with_test_db_transaction\()' && \
         [ "${exemption_c7_added_noise}" -eq 0 ]; then
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
