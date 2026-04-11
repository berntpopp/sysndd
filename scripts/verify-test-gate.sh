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
#   - On v11.0/phase-c/* branches (including the combined integration branch):
#     the default-on transaction rollback audit (plan §3 Phase C.4 / §4.5) is
#     allowed to add any skip_if_*() call (skip_if_no_test_db, skip_if_api_not_running,
#     skip_if_no_api, skip_if_not_slow_tests) plus an exemption comment block
#     documenting the rationale, and/or to wrap existing blocks in
#     with_test_db_transaction({...}). The allowed comment content is deliberately
#     permissive within this branch scope so multi-line audit headers that
#     contextualize why a file is HTTP-only / read-only / non-transactional
#     don't need every line to carry an exemption keyword. No REMOVED lines are
#     allowed (the audit is purely additive). At least one ADDED line must be
#     a skip_if_*() call or a with_test_db_transaction() call — this is the
#     "declare the exemption" requirement. This exemption covers C7/C8/C9's
#     per-unit branches AND v11.0/phase-c/combined, which lands the cherry-picks.
#
# Extended mode (--extended): grep every api/tests/testthat/test-integration-*.R
# file and assert each opens with EITHER `with_test_db_transaction` OR a
# documented skip_if_*() call (skip_if_no_test_db / skip_if_api_not_running /
# skip_if_no_api) paired with an exempt-keyword comment explaining why rollback
# isn't usable. The widened skip helpers cover HTTP-only integration tests
# that legitimately skip based on server reachability rather than DB availability.
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

    # v11.0/phase-c/* exemption: B1 infrastructure smoke test updates.
    # Allows modifications to app/src/test-utils/mocks/*.spec.ts files on
    # phase-c branches. These are Phase B's B1 handler smoke tests that
    # assert handler wire shapes. When a Phase C batch-review Q3 finds a
    # B1 shape drift (e.g. reviewByIdOk returning a bare object where
    # the real R/Plumber API returns a 1-row array), fixing the drift
    # in handlers.ts necessarily cascades to updating the corresponding
    # smoke-test assertion. The scope is narrow (test-utils/mocks only)
    # so it can't cover up view-spec tautology.
    if [[ "$BRANCH" == v11.0/phase-c/* ]] && \
       [[ "$f" == app/src/test-utils/mocks/*.spec.ts ]]; then
      continue
    fi

    # v11.0/phase-c/* exemption: default-on rollback audit.
    # Allows pre-existing test-integration-*.R files to be annotated with
    # any skip_if_*() call (skip_if_no_test_db, skip_if_api_not_running,
    # skip_if_no_api, skip_if_not_slow_tests) plus an exemption comment
    # block, and/or wrapped in with_test_db_transaction({...}). No lines
    # may be REMOVED (purely additive audit). The file's POST-PATCH state
    # must contain a skip_if_*() call or a with_test_db_transaction() call
    # — that is the "declare the exemption" requirement. Checking the
    # post-patch state (not just the diff's ADDED lines) lets a pure
    # comment-only audit pass as long as the file already contains a valid
    # skip helper from before the audit (which is the common case for
    # HTTP-only integration tests that were already using skip_if_no_api
    # or skip_if_api_not_running). Comments are accepted without a keyword
    # filter because the branch prefix v11.0/phase-c/* already scopes this
    # exemption tightly to Phase C audit work. See plan §3 Phase C.4 / §4.5.
    # Covers C7/C8/C9 per-unit branches AND the v11.0/phase-c/combined
    # cherry-pick branch.
    if [[ "$BRANCH" == v11.0/phase-c/* ]]; then
      ADDED=$(git diff "$MERGE_BASE"..HEAD -- "$f" | grep -E '^\+[^+]' || true)
      REMOVED=$(git diff "$MERGE_BASE"..HEAD -- "$f" | grep -E '^-[^-]' || true)

      # Whitelist: blank lines, ANY comment line, any skip_if_*() call,
      # with_test_db_transaction() openings, and closing `})` of a wrap.
      exemption_phase_c_added_noise=$(
        echo "$ADDED" | grep -vE '^\+[[:space:]]*$' \
                      | grep -vE '^\+[[:space:]]*#' \
                      | grep -vE 'skip_if_[a-z_]+\(' \
                      | grep -vE 'with_test_db_transaction\(' \
                      | grep -vE '^\+[[:space:]]*\}\)[[:space:]]*$' \
                      | grep -c '.' || true
      )
      # Post-patch declaration check: the file must declare its exemption
      # in one of two ways after the patch lands:
      #   (a) contain a skip_if_*() or with_test_db_transaction() call
      #       somewhere in the file (common — file already has a skip
      #       helper from before the audit), OR
      #   (b) contain an exempt-keyword comment (exempt|rollback|
      #       non-transactional|catalog|http-only|read-only|audit) — this
      #       covers pure comment-audit files like test-integration-auth.R
      #       where the JWT-crypto tests don't need a skip helper at all
      #       but still must be catalogued by the audit.
      # The branch-prefix scope (v11.0/phase-c/*) plus the added-line
      # whitelist (blank, comment, skip_if_*, with_test_db_transaction,
      # or closing `})`) prevents drift from bleeding into other phases.
      if [ -z "$REMOVED" ] && \
         { grep -qE '(skip_if_[a-z_]+\(|with_test_db_transaction\()' "$f" || \
           grep -qE '^#.*(exempt|rollback|non-transactional|catalog|http-only|read-only|audit)' "$f"; } && \
         [ "${exemption_phase_c_added_noise}" -eq 0 ]; then
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
    # skip_if_*() call (skip_if_no_test_db / skip_if_api_not_running /
    # skip_if_no_api) AND a comment with an exemption keyword explaining why
    # rollback isn't used. HTTP-only integration tests legitimately skip based
    # on server reachability (`skip_if_no_api`, `skip_if_api_not_running`)
    # rather than DB availability and have no client-side transaction to roll
    # back — the server under test owns its own persistence.
    if grep -q 'with_test_db_transaction' "$f"; then continue; fi
    if grep -qE '(skip_if_no_test_db|skip_if_api_not_running|skip_if_no_api)\(' "$f" && \
       grep -qE '^#.*(exempt|rollback|non-transactional|catalog|http-only|read-only)' "$f"; then continue; fi
    printf 'gate: REJECT integration test missing rollback wrapper: %s\n' "$f" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  done
fi

if [ "$VIOLATIONS" -gt 0 ]; then
  printf 'gate: %d violation(s) — see above\n' "$VIOLATIONS" >&2
  exit 1
fi
exit 0
