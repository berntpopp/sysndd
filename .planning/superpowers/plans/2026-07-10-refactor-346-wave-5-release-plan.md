# Refactor #346 Wave 5 Release and Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the complete refactor on merged code, publish patch release 0.29.6, and close #346 with authoritative evidence.

**Architecture:** Treat the filesystem inventory—not the baseline—as the primary completion proof, then reduce the baseline to the single approved DB exception. Align every application version source in one release commit and close the issue only after CI and merged-state checks are green.

**Tech Stack:** Bash, Git, GitHub CLI, npm lockfile v3, JSON, Markdown, SysNDD Make targets.

**Spec:** `.planning/superpowers/specs/2026-07-10-refactor-346-complete-closure-design.md`

---

### Task 1: Prove the final oversized-file inventory

**Files:**
- Modify: `scripts/code-quality-file-size-baseline.tsv`

- [ ] **Step 1: Generate an independent inventory**

```bash
find api app/src app/scripts db scripts -type f \
  \( -name '*.R' -o -name '*.ts' -o -name '*.vue' -o -name '*.js' -o \
     -name '*.mjs' -o -name '*.cjs' -o -name '*.sh' -o -name '*.sql' -o \
     -name '*.py' \) -print0 |
while IFS= read -r -d '' file; do
  rel=${file#./}
  case "$rel" in
    api/renv/*|api/tests/*|api/layout/node_modules/*|app/node_modules/*|app/dist/*|app/coverage/*|app/tests/*|app/src/test-utils/*|db/migrations/*|db/fixtures/*|scripts/tests/*|*.spec.ts|*.test.ts|*.spec.js|*.test.js) continue ;;
  esac
  lines=$(wc -l < "$file")
  if [ "$lines" -gt 600 ]; then printf '%s\t%s\n' "$rel" "$lines"; fi
done | sort > /tmp/sysndd-final-oversized.tsv
cat /tmp/sysndd-final-oversized.tsv
```

Expected: exactly one row:

```text
db/C_Rcommands_set-table-connections.R	793
```

- [ ] **Step 2: Rewrite and inspect the final baseline**

```bash
bash scripts/code-quality-audit.sh --write-baseline
cat scripts/code-quality-file-size-baseline.tsv
```

Expected: the same single approved DB exception and no non-exempt entry.

- [ ] **Step 3: Run deterministic quality checks**

```bash
make code-quality-audit
bash scripts/tests/test-code-quality-audit.sh
git diff --check
```

Expected: all checks pass.

- [ ] **Step 4: Commit the final ratchet**

```bash
git add scripts/code-quality-file-size-baseline.tsv
git commit -m "chore(quality): complete the #346 file-size ratchet"
```

### Task 2: Apply patch release 0.29.6

**Files:**
- Modify: `app/package.json:3`
- Modify: `app/package-lock.json:3,9`
- Modify: `api/version_spec.json:4`
- Modify: `CHANGELOG.md:7`

- [ ] **Step 1: Update both npm version sources without dependency changes**

```bash
cd app
npm version 0.29.6 --no-git-tag-version --allow-same-version
cd ..
```

Expected: `app/package.json`, the package-lock root `version`, and
`packages[""] .version` all equal `0.29.6`; dependency resolutions are unchanged.

- [ ] **Step 2: Update the API version**

Replace:

```json
"version": "0.29.5"
```

with:

```json
"version": "0.29.6"
```

in `api/version_spec.json`.

- [ ] **Step 3: Add the changelog release section**

Immediately after `## [Unreleased]`, add:

```markdown
## [0.29.6] — 2026-07-10

Maintainability release completing the oversized-source ratchet tracked in #346.

### Changed

- **Completed the 600-line source refactor (#346).** All 38 remaining non-exempt handwritten production files were decomposed by responsibility while preserving public UI, API, worker, curation, and database contracts. The only remaining baseline entry is the documented sequential DB bootstrap exception.
- **Hardened the ratchet baseline.** Removed stale allowances and regenerated the baseline after every thematic wave; no oversized entry increased.

### Fixed

- **Password-reset tests are order-independent.** The reset helper explicitly calls the JOSE JWT implementation, avoiding the `httr2`/`jose` name conflict that made the full R suite fail while the isolated test passed.
```

- [ ] **Step 4: Verify version equality and lockfile scope**

```bash
node -e "const fs=require('fs'); const p=require('./app/package.json'); const l=require('./app/package-lock.json'); const a=JSON.parse(fs.readFileSync('./api/version_spec.json')); if (p.version!=='0.29.6'||l.version!=='0.29.6'||l.packages[''].version!=='0.29.6'||a.version!=='0.29.6') process.exit(1)"
git diff -- app/package.json app/package-lock.json api/version_spec.json CHANGELOG.md
```

Expected: exit 0; the lockfile changes only its two root version fields.

- [ ] **Step 5: Commit the release**

```bash
git add app/package.json app/package-lock.json api/version_spec.json CHANGELOG.md
git commit -m "chore(release): v0.29.6 — complete #346 source refactor"
```

### Task 3: Final review, verification, merge, and issue closure

**Files:** none beyond Tasks 1-2.

- [ ] **Step 1: Run the full local gates**

```bash
make pre-commit
make ci-local
```

Expected: both pass. If a local infrastructure dependency prevents `ci-local`, record the exact failing prerequisite and require the equivalent GitHub lane to pass; test failures are not waivable.

- [ ] **Step 2: Obtain final independent reviews**

Claude Code reviews the cumulative diff from the pre-#346-closure master SHA through the release head. Codex independently runs the SysNDD code-quality and security/bug review checklists. Every material finding is fixed and re-reviewed.

- [ ] **Step 3: Push, open, and merge the release PR**

```bash
git push -u origin refactor/346-wave-5-release
gh pr create \
  --title "chore(release): v0.29.6 — complete #346 source refactor" \
  --body "$(printf '%s\n' \
    '## Summary' \
    '- Release the complete behavior-preserving #346 refactor as v0.29.6.' \
    '- Leave only the documented sequential DB bootstrap exception in the baseline.' \
    '- Align app, lockfile, API, and changelog versions.' \
    '' \
    '## Verification' \
    '- independent source inventory' \
    '- make code-quality-audit + harness' \
    '- make pre-commit' \
    '- make ci-local' \
    '- Claude Code and Codex cumulative review' \
    '' \
    'Closes #346.')"
gh pr checks --watch
gh pr merge --squash --delete-branch
```

Expected: every check is green and the PR merges.

- [ ] **Step 4: Audit merged master**

```bash
git switch master
git pull --ff-only origin master
git status --short --branch
make code-quality-audit
bash scripts/tests/test-code-quality-audit.sh
node -e "const fs=require('fs'); const p=require('./app/package.json'); const l=require('./app/package-lock.json'); const a=JSON.parse(fs.readFileSync('./api/version_spec.json')); if (p.version!==a.version||p.version!==l.version||p.version!==l.packages[''].version) process.exit(1); console.log(p.version)"
```

Expected: clean `master` at `origin/master`; audits pass; version output is `0.29.6`.

- [ ] **Step 5: Comment on and close #346**

```bash
closure_prs=$(gh pr list --state merged --search '#346 in:title,body' --limit 100 \
  --json number,title,url --jq '.[] | select(.title | test("Wave|wave|600 lines|v0.29.6")) | "- PR #\(.number): \(.url) — \(.title)"')
release_sha=$(git rev-parse HEAD)
gh issue comment 346 --body "$(printf '%s\n' \
  'Completed and released in v0.29.6.' \
  '' \
  '- Independent inventory: every non-exempt handwritten production source file is at or below 600 lines.' \
  '- Remaining baseline: db/C_Rcommands_set-table-connections.R only (documented sequential bootstrap exception).' \
  '- Verification: code-quality audit + harness, frontend/API gates, pre-commit, ci-local, and green GitHub Actions.' \
  '- Reviews: Claude Code adversarial plan/PR reviews and independent Codex security/correctness/code-quality reviews; all material findings resolved.' \
  "- Release commit: $release_sha" \
  '' \
  'Merged delivery PRs:' \
  "$closure_prs" \
  '' \
  'Closing #346 as completed.')"
gh issue close 346 --reason completed
gh issue view 346 --json state,closedAt,url
```

Expected: issue state `CLOSED` with a non-null `closedAt`.
