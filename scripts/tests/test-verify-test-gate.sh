#!/usr/bin/env bash
# test-verify-test-gate.sh
#
# Bash unit tests for scripts/verify-test-gate.sh.
#
# The gate script is driven by git state (merge-base, diff, branch name) so each
# test case spins up a throwaway git repo under a temp directory, stages a base
# commit, checks out a branch with whatever diff the case wants to verify, and
# then invokes scripts/verify-test-gate.sh with VERIFY_GATE_REPO_ROOT pointing
# at the fixture repo and VERIFY_GATE_BRANCH set to the simulated PR branch.
#
# No R, no docker, no network. Runs on host + CI equally.
#
# Usage: ./scripts/tests/test-verify-test-gate.sh
#
# Exit codes:
#   0  all cases passed
#   1  at least one case failed

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
GATE_SCRIPT="$REPO_ROOT/scripts/verify-test-gate.sh"

PASS=0
FAIL=0
FAILED_CASES=""

# -----------------------------------------------------------------------------
# Test helpers
# -----------------------------------------------------------------------------

assert_equal() {
  # assert_equal <expected> <actual> <message>
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    printf '  \033[32mPASS\033[0m  %s\n' "$message"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES="$FAILED_CASES\n    - $message (expected=$expected actual=$actual)"
    printf '  \033[31mFAIL\033[0m  %s (expected=%s actual=%s)\n' "$message" "$expected" "$actual"
  fi
}

make_fixture_repo() {
  # make_fixture_repo <dir>
  # Initializes a git repo with a base commit containing a pre-existing spec
  # file and a pre-existing R test file, so each case can create a PR branch
  # on top and modify (or not) those files.
  local dir="$1"
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -q -b master
    git config user.email "harness@test.local"
    git config user.name "harness"
    git config commit.gpgsign false

    mkdir -p app/src/components api/tests/testthat
    cat > app/src/components/Existing.spec.ts <<'EOF'
// Pre-existing spec file checked into master.
import { describe, it, expect } from 'vitest'
describe('Existing', () => {
  it('works', () => {
    expect(true).toBe(true)
  })
})
EOF
    cat > api/tests/testthat/test-existing.R <<'EOF'
# Pre-existing R test file checked into master.
test_that("does the thing", {
  expect_equal(1 + 1, 2)
})
EOF
    cat > api/tests/testthat/test-integration-good.R <<'EOF'
# Integration test that already opens with with_test_db_transaction.
with_test_db_transaction({
  test_that("reads from db", {
    expect_true(TRUE)
  })
})
EOF
    cat > api/tests/testthat/test-integration-skip-exempt.R <<'EOF'
# skip_if_no_test_db() exemption: this endpoint writes to a non-transactional
# catalog table, so rollback would corrupt other tests.
test_that("exempt case", {
  skip_if_no_test_db()
  expect_true(TRUE)
})
EOF
    git add .
    git commit -q -m "base commit"
  )
}

run_gate() {
  # run_gate <repo_dir> <branch_name> [--extended]
  # Invokes verify-test-gate.sh against the fixture repo and prints stdout+stderr,
  # returning its exit code via $?.
  local repo_dir="$1"
  local branch_name="$2"
  shift 2
  VERIFY_GATE_REPO_ROOT="$repo_dir" \
    VERIFY_GATE_BRANCH="$branch_name" \
    VERIFY_GATE_BASE_REF="master" \
    bash "$GATE_SCRIPT" "$@"
}

# -----------------------------------------------------------------------------
# Test cases
# -----------------------------------------------------------------------------

case_new_spec_allowed() {
  # A Phase C branch that adds a BRAND NEW spec file should pass (exit 0).
  local dir
  dir=$(mktemp -d)
  make_fixture_repo "$dir"
  (
    cd "$dir"
    git checkout -q -b v11.0/phase-c/new-spec
    cat > app/src/components/Brand.spec.ts <<'EOF'
import { describe, it, expect } from 'vitest'
describe('Brand', () => { it('is new', () => { expect(1).toBe(1) }) })
EOF
    git add app/src/components/Brand.spec.ts
    git commit -q -m "add new spec"
  )
  run_gate "$dir" "v11.0/phase-c/new-spec" >/dev/null 2>&1
  assert_equal 0 "$?" "new spec file on phase-c branch is allowed"
  rm -rf "$dir"
}

case_preexisting_spec_rejected() {
  # A Phase D branch that edits a pre-existing spec file (non-.todo) must fail.
  local dir
  dir=$(mktemp -d)
  make_fixture_repo "$dir"
  (
    cd "$dir"
    git checkout -q -b v11.0/phase-d/test-synthetic
    cat > app/src/components/Existing.spec.ts <<'EOF'
// Pre-existing spec file checked into master.
import { describe, it, expect } from 'vitest'
describe('Existing', () => {
  it('works', () => {
    expect(true).toBe(false) // MUTATION
  })
})
EOF
    git add app/src/components/Existing.spec.ts
    git commit -q -m "mutate existing spec"
  )
  run_gate "$dir" "v11.0/phase-d/test-synthetic" >/dev/null 2>&1
  assert_equal 1 "$?" "pre-existing spec edit on phase-d branch is rejected"
  rm -rf "$dir"
}

case_skip_slow_exemption_phase_b() {
  # On a phase-b branch, adding skip_if_not_slow_tests() to a pre-existing
  # test-*.R file is allowed.
  local dir
  dir=$(mktemp -d)
  make_fixture_repo "$dir"
  (
    cd "$dir"
    git checkout -q -b v11.0/phase-b/skip-slow-wiring
    cat > api/tests/testthat/test-existing.R <<'EOF'
# Pre-existing R test file checked into master.
test_that("does the thing", {
  skip_if_not_slow_tests()
  expect_equal(1 + 1, 2)
})
EOF
    git add api/tests/testthat/test-existing.R
    git commit -q -m "add skip wrapper"
  )
  run_gate "$dir" "v11.0/phase-b/skip-slow-wiring" >/dev/null 2>&1
  assert_equal 0 "$?" "skip_if_not_slow_tests exemption on phase-b branch is allowed"
  rm -rf "$dir"
}

case_sys_sleep_exemption_phase_b() {
  # On a phase-b branch, replacing Sys.sleep(N) with wait_for(..., timeout = N)
  # in a pre-existing test file is allowed.
  local dir
  dir=$(mktemp -d)
  make_fixture_repo "$dir"
  (
    cd "$dir"
    # first, stage a base version that CONTAINS Sys.sleep so the exemption diff
    # is a real sleep->wait_for replacement rather than a bare addition.
    cat > api/tests/testthat/test-existing.R <<'EOF'
# Pre-existing R test file checked into master.
test_that("does the thing", {
  Sys.sleep(5)
  expect_equal(1 + 1, 2)
})
EOF
    git add api/tests/testthat/test-existing.R
    git commit -q -m "reset base to sleepy version"
    git checkout -q -b v11.0/phase-b/sys-sleep-eviction
    cat > api/tests/testthat/test-existing.R <<'EOF'
# Pre-existing R test file checked into master.
test_that("does the thing", {
  wait_for(Sys.time() > 0, timeout = 5)
  expect_equal(1 + 1, 2)
})
EOF
    git add api/tests/testthat/test-existing.R
    git commit -q -m "replace Sys.sleep with wait_for"
  )
  run_gate "$dir" "v11.0/phase-b/sys-sleep-eviction" >/dev/null 2>&1
  assert_equal 0 "$?" "Sys.sleep->wait_for exemption on phase-b branch is allowed"
  rm -rf "$dir"
}

case_skip_slow_rejected_on_phase_d() {
  # Sanity: the skip exemption must NOT leak into phase-d.
  local dir
  dir=$(mktemp -d)
  make_fixture_repo "$dir"
  (
    cd "$dir"
    git checkout -q -b v11.0/phase-d/rogue-skip
    cat > api/tests/testthat/test-existing.R <<'EOF'
test_that("does the thing", {
  skip_if_not_slow_tests()
  expect_equal(1 + 1, 2)
})
EOF
    git add api/tests/testthat/test-existing.R
    git commit -q -m "rogue skip wrapper on phase-d"
  )
  run_gate "$dir" "v11.0/phase-d/rogue-skip" >/dev/null 2>&1
  assert_equal 1 "$?" "skip_if_not_slow_tests exemption does NOT leak into phase-d"
  rm -rf "$dir"
}

case_extended_mode_catches_missing_rollback() {
  # Extended mode greps test-integration-*.R files and asserts each opens with
  # with_test_db_transaction or a documented skip_if_no_test_db exemption.
  local dir
  dir=$(mktemp -d)
  make_fixture_repo "$dir"
  (
    cd "$dir"
    # Add a new integration test that has NEITHER.
    cat > api/tests/testthat/test-integration-bad.R <<'EOF'
# No rollback wrapper and no documented exemption.
test_that("writes to db", {
  expect_true(TRUE)
})
EOF
    git add api/tests/testthat/test-integration-bad.R
    git commit -q -m "bad integration test"
  )
  # Extended mode runs on the master branch since it's a repo-wide invariant.
  run_gate "$dir" "master" --extended >/dev/null 2>&1
  assert_equal 1 "$?" "extended mode rejects integration test without with_test_db_transaction"
  rm -rf "$dir"
}

case_extended_mode_accepts_good_repo() {
  # The base fixture contains one good integration test and one exemption test,
  # both should pass extended mode.
  local dir
  dir=$(mktemp -d)
  make_fixture_repo "$dir"
  run_gate "$dir" "master" --extended >/dev/null 2>&1
  assert_equal 0 "$?" "extended mode accepts well-formed integration tests"
  rm -rf "$dir"
}

# -----------------------------------------------------------------------------
# Driver
# -----------------------------------------------------------------------------

printf '==> Running verify-test-gate.sh harness\n\n'
case_new_spec_allowed
case_preexisting_spec_rejected
case_skip_slow_exemption_phase_b
case_sys_sleep_exemption_phase_b
case_skip_slow_rejected_on_phase_d
case_extended_mode_catches_missing_rollback
case_extended_mode_accepts_good_repo

printf '\n==> Summary: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'Failed cases:%b\n' "$FAILED_CASES"
  exit 1
fi
exit 0
