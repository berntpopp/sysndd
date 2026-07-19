# #573 Slice C — review reconciliation

Branch: `feat/analysis-snapshot-releases-573-slice-c` (off `master` @ `d1a5a71a`). Executed with
subagent-driven-development (fresh implementer + task review per task) + a Claude opus whole-branch
review + a Codex (`gpt-5.6-terra`, high) adversarial diff review. Review outputs committed alongside.

## Per-task reviews

- **C1** (packager logic + tests): Spec OK, Quality Approved. Adversarial validator probing passed. 1
  minor reconciled (`base::setdiff` namespacing, commit `ab4d16a2`); a suffix-scan gap noted (later
  hardened in the Codex round). 77 tests.
- **C2** (upload logic + DOI record-back + CLIs + tests): Spec OK. 1 Important reconciled — the
  `nzchar(NA_character_)` gotcha meant an NA DOI field (Zenodo omitting `conceptdoi`) was emitted as
  `"concept_doi": null` instead of omitted; fixed with an `is.na()` guard + tests (commit `9139f48c`).
  63→69 tests.
- **C3** (Makefile targets + marker file + runbook + v0.30.3): covered in the whole-branch review (no
  separate task review). Both R suites green, targets dry-runnable, package-lock diff is version-only.

## Final whole-branch review (Claude opus)

READY TO MERGE, 0 Critical/security. Verified token non-leakage, the safety validator, the publish
double-gate, checksum fail-closed, SHA-256-only, and the DOI opt-in paths. Flagged 1 Important (the
hand-typed publish runbook command's archive path was missing the `archive/` subdir) + minors — all
folded into the Codex reconciliation below.

## Codex adversarial diff review — round 1: NO-SHIP

| Sev | Finding | Decision |
|-----|---------|----------|
| BLOCKER | `unlink(staging_dir, recursive=TRUE)` deletes any existing dir unguarded — an operator typo destroys it. | **FIXED** — ownership-sentinel guard; only a dir this tool created is ever rmtree'd; a pre-existing sentinel-less dir stops the run. |
| HIGH | The resolved/requested `release_id` is used as a filename/path component AND written into `latest.env` which the Makefile shell-`source`s → `../` traversal + newline/`;` shell injection. | **FIXED** — `^asr_[0-9a-f]{16}$` validation on the request arg (allowing `latest`) + the resolved head id; Makefile parses the marker with `sed` instead of `source`. |
| HIGH | Safety validator is case-sensitive (`.ENV`/`.GIT` slip) and only scans a text-suffix allowlist, so `secret.csv`/`key.pem`/extensionless token files pass untouched. | **FIXED** — case-insensitive name/dir matching + a file-type ALLOWLIST (rejects binary/unexpected/extensionless) + symlink rejection. |
| MEDIUM | `extract_and_verify` verifies each checksum line but doesn't require every extracted file to be stamped (a dropped line → unstamped file passes); `../` paths not rejected. | **FIXED** — full checksum coverage (no unstamped files, no dupes) + `..`/absolute-path rejection in members and entries. |
| MEDIUM | Tarball claimed "deterministic" but R's internal tar records mtimes → non-reproducible archive hash. | **FIXED** — staged mtimes normalized to a fixed epoch (R internal tar zeroes the gzip timestamp); byte-identical-rebuild test added. |
| MEDIUM | `--token <secret>` CLI flag leaks the Zenodo token via shell history / `ps` argv. | **FIXED** — flag removed; `ZENODO_TOKEN` env only. |
| Important (final review) | Runbook publish command's archive path missing the `archive/` subdir; step-6 auto DOI record-back missing `--release-id`. | **FIXED** — runbook paths corrected + `--release-id` added; no `--token` in any runbook command. |

All reconciled in commit `e19fcd26`. The fetch/extract-verify helpers + the safety validator were
extracted into a new `analysis-snapshot-release-zenodo-verify.R` to keep every handwritten `.R` file
< 600 (package.R 422, verify.R 487, upload.R 316, docs.R 163). Gates after fix: `package` 69, `verify`
38 (new), `upload` 69 — all pass; `make code-quality-audit` clean; both Make targets dry-runnable.

## Codex adversarial diff review — round 2: NO-SHIP (adjacent issues)

Round 2 confirmed every round-1 fix landed, then expanded scope (as Codex reliably does):

| Sev | Finding | Decision |
|-----|---------|----------|
| HIGH | Bundle symlinks are followed during extraction/checksum/`file.copy()` before the staging validator sees them — a symlinked release member could pull host content into the archive. | **FIXED** — reject symlinks/non-regular files in the extracted bundle immediately after `untar()`, before hashing/copying (`.analysis_release_zenodo_reject_symlinks`, `Sys.readlink`). |
| HIGH | The upload/DOI path never applied the release-id guard, so a crafted `--release-id` injected into the admin PATCH URL and the printed single-quoted `curl` command (copy/paste command injection). | **FIXED** — the `^asr_[0-9a-f]{16}$` validator is shared (`-common.R`) and called on the upload/DOI path before any URL/command is built; the manual command `shQuote()`s its interpolations. |
| MEDIUM | The manual DOI command was printed populated with DRAFT values, bypassing the published-only rule. | **FIXED** — a draft prints post-publication instructions only; the populated command is emitted only when `result$published` is TRUE. |
| MEDIUM | Traversal check split only on `/`, missing `..\` / UNC / drive-letter paths. | **FIXED** — split on `/` and `\`, reject UNC/leading-backslash/drive-letter absolute paths, for members + checksum entries. |

All reconciled in commit `b236b1bd`; the shared validator moved to `analysis-snapshot-release-zenodo-common.R`
and the upload DOI-safety tests split into `test-unit-analysis-release-zenodo-upload-doi-safety.R` to keep
every handwritten `.R` file < 600. Gates: package 69, verify 42, upload 69, upload-doi-safety 38 — all pass;
`make code-quality-audit` + `make lint-api` clean.

## Codex adversarial diff review — round 3: NO-SHIP (converging: 2 findings)

Round 3 confirmed all round-2 fixes resolved. Two remaining defense-in-depth gaps:

| Sev | Finding | Decision |
|-----|---------|----------|
| HIGH | The post-`untar()` guard only rejected symlinks, not other non-regular files — a FIFO would pass then hang `digest::digest(file=...)`. | **FIXED** — the guard (renamed `.analysis_release_zenodo_reject_unsafe_files`) now rejects any non-regular file via `fs::file_info()$type == "file"` (stats without opening, so it can't hang). The implementer verified the brief's suggested `file_test("-f")` is `!isdir` and returns TRUE for a FIFO, and correctly used `fs::` instead; a `mkfifo` regression test (with the FIFO listed in the bundle checksums) proves the guard fires before any hashing. |
| MEDIUM | `download_bundle()` interpolated `release_id` into the URL without validation (a direct caller could bypass the orchestrator's guard). | **FIXED** — validates `^asr_[0-9a-f]{16}$` (`allow_latest = FALSE`) before the URL is built; `../`/quote/`latest` rejection tests added. |

Reconciled in commit `46b5c48f`. Tests: verify 51, package 69, upload 69, verify-round3 4, upload-doi-safety
38 — all pass; lintr clean. The verify tests' shared fixture was extracted to
`analysis-release-zenodo-verify-fixtures.R` to keep every `.R` < 600 (verify.R 587).

## Environment limitation (surfaced, not faked)

The scripts read a PUBLISHED release over the public API and upload to Zenodo. No dev/test DB in this
environment carries a published release, and no `ZENODO_TOKEN`/live Zenodo sandbox account is available
here, so the mandated LIVE end-to-end (package a real release → upload to sandbox.zenodo.org → verify
the draft → recompute checksums) COULD NOT be run. Substitute evidence: the pure logic + safety
validator + checksum-verify + upload request-shape are fully unit-tested (176 assertions across three
suites, with adversarial hardening tests injecting malicious inputs — traversal ids, planted secrets,
symlinks, dropped checksum lines), both CLIs verified to source/parse and fail closed on missing
token/bad id, and two independent adversarial reviews. The live sandbox upload needs an operator with a
`ZENODO_TOKEN` and a data-loaded API.

## Codex adversarial diff review — round 4: SHIP

Re-ran on the post-round-3 branch. Verified both round-3 findings resolved (the non-regular-file guard
runs after `untar()` before any digest and uses metadata-only `fs::file_info()$type`, so FIFO/socket/
device members fail closed rather than hang; `download_bundle` strictly validates its concrete id before
building the URL). The adjacent sweep confirmed every locked control intact — host-only/public-read
packaging, no bootstrap registration, sentinel-guarded staging deletion, `sed` marker extraction (no
`source`), draft-default double-gated publish, published-only opt-in DOI record-back with JSON bodies.
No BLOCKER/HIGH/MEDIUM/LOW. **VERDICT: SHIP.**

Findings converged 6 → 4 → 2 → 0 across the four rounds. Full outputs in
`2026-07-19-573-slice-c-diff-codex-review-round{1,2,3,4}.md`.
