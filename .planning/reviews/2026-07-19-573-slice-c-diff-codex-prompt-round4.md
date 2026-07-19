# Adversarial diff review ROUND 4 — #573 Slice C (Zenodo operator scripts)

Rounds 1-3 returned NO-SHIP; findings have converged (6 → 4 → 2). Round-3 fixes are in commit
`46b5c48f`. Fresh independent re-review of the CURRENT full branch diff.

1. **Verify the two round-3 findings are genuinely resolved:**
   - HIGH (non-regular files): the post-`untar()` guard (`analysis-snapshot-release-zenodo-verify.R`,
     `.analysis_release_zenodo_reject_unsafe_files`) now rejects symlinks AND any non-regular file (via
     `fs::file_info()$type == "file"`, which stats without opening — so a FIFO can't hang it), before
     any `digest` read. Confirm a FIFO/socket/device bundle member fails closed, not by hanging.
   - MEDIUM (download_bundle): `analysis_release_zenodo_download_bundle()` now validates `release_id`
     (`^asr_[0-9a-f]{16}$`, `allow_latest = FALSE`) before interpolating it into the URL. Confirm a
     `../`/quote/newline id is rejected before any HTTP call.

2. **Final adjacent sweep** — any remaining or newly-introduced issue. Same rigor as prior rounds. Note
   the fixer used `fs::file_info()$type` rather than `file_test("-f")` (correct: `file_test("-f")` is
   `!isdir` and returns TRUE for a FIFO) — confirm the chosen check is sound.

## The diff to review
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
Files: `analysis-snapshot-release-zenodo-{common,package,verify,docs,upload}.R`, the two CLI scripts,
and `test-unit-analysis-release-zenodo-{package,verify,verify-round3,upload,upload-doi-safety}.R` (+ a
shared `analysis-release-zenodo-verify-fixtures.R`), plus Makefile/.gitignore/docs/AGENTS/version.
Context: `AGENTS.md`, sibling `/home/bernt-popp/development/nddscore/`, DOI endpoint
`api/endpoints/admin_analysis_snapshot_endpoints.R`.

## Locked decisions (do NOT flag; flag violations)
Public-API read only, host-run, DI seams. Publish DOUBLE-gated; Makefile never publishes. DOI
record-back OPT-IN, PUBLISHED-only (auto + printed manual command), only-supplied-non-empty fields, JSON
body, placeholder token in printed commands. Safety validator (case-insensitive, file-type allowlist,
symlink + non-regular-file + traversal rejection) runs before tarring; bundle extraction fails closed.
Staging rmtree sentinel-guarded. release_id `^asr_[0-9a-f]{16}$` everywhere it touches a
path/URL/command/marker (including `download_bundle`). Content-addressed ids. No manuscript refs. Every
handwritten `.R` < 600. Operator scripts exempt from the external-budget guard.

## Output
Findings by **BLOCKER / HIGH / MEDIUM / LOW** with file:line + failure scenario + fix. End with
`VERDICT: SHIP` or `VERDICT: NO-SHIP`. If the round-3 findings are resolved and nothing new is
ship-blocking, say `VERDICT: SHIP` plainly — do not manufacture issues to avoid a clean pass.
