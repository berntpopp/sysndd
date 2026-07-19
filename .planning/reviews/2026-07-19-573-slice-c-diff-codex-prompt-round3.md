# Adversarial diff review ROUND 3 — #573 Slice C (Zenodo operator scripts)

Rounds 1 and 2 returned NO-SHIP; all findings are now addressed (round-2 fixes in commit `b236b1bd`).
Fresh independent re-review of the CURRENT full branch diff.

1. **Verify each round-2 finding is genuinely resolved:**
   - HIGH (bundle symlink follow): `extract_and_verify` now rejects symlinks/non-regular files in the
     extracted bundle IMMEDIATELY after `untar()`, BEFORE any hashing or `file.copy()`
     (`.analysis_release_zenodo_reject_symlinks`, uses `Sys.readlink`). Confirm the ordering (a
     symlinked member fails on "symlinks", not on a hash mismatch).
   - HIGH (upload-path release_id injection): the `^asr_[0-9a-f]{16}$` validator is now shared
     (`analysis-snapshot-release-zenodo-common.R`) and called on the upload/DOI path before any admin
     PATCH URL or printed `curl` command is built; the manual command `shQuote()`s its interpolations.
     Confirm a release_id with a quote/`;`/newline/`../` is rejected on BOTH the automatic and manual
     DOI paths before anything is built/printed.
   - MEDIUM (draft manual command): a DRAFT upload now prints only post-publication instructions, no
     populated `PATCH .../doi` command. Confirm.
   - MEDIUM (backslash/UNC traversal): the traversal check now splits on `/` and `\` and rejects
     UNC/leading-backslash/drive-letter paths, for tar members and checksum entries. Confirm.

2. **Final adjacent sweep** — any remaining or newly-introduced issue (the new shared `-common.R`
   guard-source, the `print_doi_record_back` extraction, the symlink helper's type handling, the
   test-file split). Same rigor as rounds 1-2.

## The diff to review
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
Files now: `analysis-snapshot-release-zenodo-{common,package,verify,docs,upload}.R`, the two CLI
scripts, and `test-unit-analysis-release-zenodo-{package,verify,upload,upload-doi-safety}.R`, plus
Makefile/.gitignore/docs/AGENTS/version. Context: `AGENTS.md`, sibling `/home/bernt-popp/development/nddscore/`,
DOI endpoint `api/endpoints/admin_analysis_snapshot_endpoints.R`.

## Locked decisions (do NOT flag; flag violations)
Public-API read only, host-run, DI seams. Publish DOUBLE-gated; Makefile never publishes. DOI
record-back OPT-IN, PUBLISHED-only (both auto AND the printed manual command), only-supplied-non-empty
fields, JSON body, placeholder token in any printed command. Safety validator (case-insensitive, file-type
allowlist, symlink + traversal rejection) runs before tarring; bundle extraction fails closed. Staging
rmtree sentinel-guarded. release_id `^asr_[0-9a-f]{16}$` everywhere it touches a path/URL/command/marker.
Content-addressed ids. No manuscript refs. Every handwritten `.R` < 600. Operator scripts exempt from the
external-budget guard.

## Output
Findings by **BLOCKER / HIGH / MEDIUM / LOW** with file:line + failure scenario + fix. End with
`VERDICT: SHIP` or `VERDICT: NO-SHIP`. If round-2 findings are resolved and nothing new is ship-blocking,
say `VERDICT: SHIP` plainly — do not manufacture issues.
