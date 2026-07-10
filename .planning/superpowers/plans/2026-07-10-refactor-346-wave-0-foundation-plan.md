# Refactor #346 Wave 0 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore a green parent branch and make the file-size ratchet reflect current source sizes before structural refactors begin.

**Architecture:** Fix the order-dependent password-reset test by qualifying the intended JOSE implementation at the call site, then regenerate the deterministic oversized-file baseline from current source. This wave changes no API behavior and establishes honest downward-only limits for all later waves.

**Tech Stack:** R, jose, httr2, testthat, Docker, Bash, GNU awk, GitHub Actions.

**Spec:** `.planning/superpowers/specs/2026-07-10-refactor-346-complete-closure-design.md`

---

Create the foundation branch from the master that contains this approved plan:

```bash
git switch master
git pull --ff-only origin master
git switch -c refactor/346-wave-0-foundation
```

### Task 0: Repair the existing 0.29.5 lockfile version drift

**Files:**
- Modify: `app/package-lock.json:3,9`

- [ ] **Step 1: Align the npm lock root without changing dependencies**

```bash
cd app
npm version 0.29.5 --no-git-tag-version --allow-same-version
cd ..
git diff -- app/package.json app/package-lock.json
```

Expected: `app/package.json` remains `0.29.5`; only the lockfile root `version` and
`packages[""] .version` change from `0.29.4` to `0.29.5`; dependency resolutions do
not change.

- [ ] **Step 2: Verify and commit the lineage repair**

```bash
node -e "const p=require('./app/package.json'); const l=require('./app/package-lock.json'); if (p.version!==l.version||p.version!==l.packages[''].version) process.exit(1)"
git add app/package-lock.json
git commit -m "chore(app): align lockfile version with v0.29.5"
```

### Task 1: Pin password-reset JWT calls to JOSE

**Files:**
- Modify: `api/tests/testthat/test-unit-password-reset-request.R`
- Modify: `api/functions/user-endpoint-helpers.R:112-125`

- [ ] **Step 1: Add an order-dependence regression test**

Add this test after the existing successful-mail test:

```r
test_that("password reset uses JOSE when httr2 exposes the same JWT names", {
  withr::local_package("httr2")
  calls <- list()

  res <- process_password_reset_request(
    "nuria.braemswig@ukmuenster.de", fake_users, fake_dw,
    send_email = function(email_body, email_subject, email_recipient, ...) {
      calls[[length(calls) + 1L]] <<- list(subject = email_subject, to = email_recipient)
      "sent"
    },
    update_reset_date = noop_update
  )

  expect_equal(res$status, 200L)
  expect_length(calls, 1L)
  expect_equal(calls[[1]]$to, "Nuria.Braemswig@ukmuenster.de")
})
```

- [ ] **Step 2: Run the test in the API container and prove it fails**

```bash
docker cp api/tests sysndd-api-1:/app/
docker exec sysndd-api-1 Rscript -e \
  "testthat::test_dir('/app/tests/testthat', filter='password-reset-request', reporter='summary', stop_on_failure=TRUE)"
```

Expected: FAIL because `conflicted` reports `jwt_claim found in 2 packages`; the injected mailer has zero calls.

Capture the actual caught condition in the PR evidence:

```bash
docker exec sysndd-api-1 Rscript -e \
  "testthat::test_dir('/app/tests/testthat', filter='password-reset-request', reporter='location', stop_on_failure=TRUE)" \
  2>&1 | tee /tmp/sysndd-password-reset-red.log
rg 'jwt_claim found in 2 packages|Expected.*calls.*length 1' \
  /tmp/sysndd-password-reset-red.log
```

Expected: the log shows the `httr2::jwt_claim`/`jose::jwt_claim` conflict caught by the
best-effort reset handler and the zero-mailer-call assertion failure.

- [ ] **Step 2a: Commit the red regression test before the fix**

```bash
git add api/tests/testthat/test-unit-password-reset-request.R
git commit -m "test(api): reproduce password-reset JWT namespace conflict"
```

- [ ] **Step 3: Qualify the intended JWT implementation**

In `process_password_reset_request()`, replace:

```r
claim <- jwt_claim(
```

with:

```r
claim <- jose::jwt_claim(
```

and replace:

```r
jwt <- jwt_encode_hmac(claim, secret = key)
```

with:

```r
jwt <- jose::jwt_encode_hmac(claim, secret = key)
```

- [ ] **Step 4: Verify the isolated and suite-loaded paths**

```bash
docker cp api/tests sysndd-api-1:/app/
docker exec sysndd-api-1 Rscript -e \
  "testthat::test_file('/app/tests/testthat/test-unit-password-reset-request.R')"
docker exec sysndd-api-1 Rscript -e \
  "testthat::test_dir('/app/tests/testthat', filter='password-reset-request', reporter='summary', stop_on_failure=TRUE)"
```

Expected: both commands PASS; the successful mailer is called exactly once even after `httr2` is attached.

- [ ] **Step 5: Commit the focused CI repair separately**

```bash
git add api/functions/user-endpoint-helpers.R
git commit -m "fix(api): qualify password-reset JOSE calls"
```

### Task 2: Ratchet stale file-size allowances to current values

**Files:**
- Modify: `scripts/code-quality-file-size-baseline.tsv`

- [ ] **Step 1: Capture the pre-write baseline and current inventory**

```bash
cp scripts/code-quality-file-size-baseline.tsv /tmp/sysndd-size-baseline.before.tsv
while IFS=$'\t' read -r path baseline; do
  actual=$(wc -l < "$path")
  printf '%s\t%s\t%s\n' "$path" "$baseline" "$actual"
done < scripts/code-quality-file-size-baseline.tsv \
  > /tmp/sysndd-size-baseline.before-actual.tsv
```

Expected: 46 baseline rows; 20 have `actual < baseline`.

- [ ] **Step 2: Generate the current baseline**

```bash
bash scripts/code-quality-audit.sh --write-baseline
```

Expected: 39 rows. These seven now-compliant files disappear:

```text
api/functions/llm-batch-generator.R
api/functions/llm-cache-repository.R
api/functions/llm-judge.R
app/src/components/analyses/AnalysesCurationUpset.vue
app/src/components/analyses/AnalysesPhenotypeClusters.vue
app/src/views/admin/ManageAnnotations.vue
app/src/views/admin/ManageNDDScore.vue
```

- [ ] **Step 3: Prove every baseline change is downward**

```bash
awk -F '\t' '
  NR == FNR { old[$1] = $2 + 0; next }
  { seen[$1] = 1; if (!($1 in old) || $2 + 0 > old[$1]) bad = 1 }
  END { exit bad }
' /tmp/sysndd-size-baseline.before.tsv scripts/code-quality-file-size-baseline.tsv
git diff -- scripts/code-quality-file-size-baseline.tsv
```

Expected: exit 0; no new entry and no increased value. `AnalyseGeneClusters.vue` tightens from 1251 to 607; all other retained rows equal their current line counts.

Also require exactly seven removals, zero additions, and zero increases. The regression
test file is excluded by the audit's test policy, but must remain below 600 lines:

```bash
test "$(wc -l < api/tests/testthat/test-unit-password-reset-request.R)" -le 600
awk -F '\t' '
  NR == FNR { old[$1] = $2 + 0; next }
  { current[$1] = $2 + 0; if (!($1 in old)) added++; if (($1 in old) && $2 + 0 > old[$1]) increased++ }
  END {
    for (path in old) if (!(path in current)) removed++
    if (removed != 7 || added != 0 || increased != 0) exit 1
  }
' /tmp/sysndd-size-baseline.before.tsv scripts/code-quality-file-size-baseline.tsv
```

- [ ] **Step 4: Verify the ratchet and harness**

```bash
make code-quality-audit
bash scripts/tests/test-code-quality-audit.sh
git diff --check
```

Expected: `code-quality-audit: OK`, all four harness assertions pass, and `git diff --check` is silent.

- [ ] **Step 5: Commit the downward ratchet**

```bash
git add scripts/code-quality-file-size-baseline.tsv
git commit -m "chore(quality): ratchet #346 baseline to current sizes"
```

### Task 3: Publish and merge the foundation PR

**Files:** none beyond Tasks 1-2.

- [ ] **Step 1: Run the pre-push gate**

```bash
make pre-commit
make test-api
```

Expected: PASS. The full R API suite—not only the filtered file—is green.

- [ ] **Step 2: Push and open the PR**

```bash
git push -u origin refactor/346-wave-0-foundation
gh pr create \
  --title "refactor: #346 closure foundation and honest size baseline" \
  --body "$(printf '%s\n' \
    '## Summary' \
    '- Qualify the password-reset JOSE calls so the full R suite is order-independent.' \
    '- Ratchet the oversized-source baseline from 46 to 39 current entries.' \
    '- No route, response, permission, or runtime behavior change.' \
    '' \
    '## Verification' \
    '- password-reset isolated and suite-loaded test paths' \
    '- make code-quality-audit' \
    '- scripts/tests/test-code-quality-audit.sh' \
    '- make pre-commit' \
    '' \
    'Part of #346.')"
```

Expected: the PR body lists the CI repair, the 46→39 baseline change, the verification
gates, and `Part of #346`.

- [ ] **Step 3: Complete reviews and checks**

Run Claude Code against the PR diff, perform the independent Codex security/correctness/code-quality review, fix every material finding, re-run the affected checks, and wait for GitHub Actions to report green.

- [ ] **Step 4: Merge and verify master**

```bash
gh pr merge --squash --delete-branch
git switch master
git pull --ff-only origin master
make code-quality-audit
```

Expected: PR merged, local `master` equals `origin/master`, and the audit passes with 39 baseline rows.
