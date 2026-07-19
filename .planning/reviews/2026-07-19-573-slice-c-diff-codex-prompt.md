# Adversarial diff review — #573 Slice C (Zenodo operator scripts)

You are a staff-level adversarial reviewer. Review the R operator scripts on this branch that package
and upload an immutable analysis-snapshot release (#573) to Zenodo. Be skeptical: hunt for real
correctness bugs, security issues (secret leakage, path traversal, unsafe uploads), contract
mismatches, and weak tests. Expand scope to adjacent same-class issues.

## The diff to review
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
7 commits. New R: `api/functions/analysis-snapshot-release-zenodo-{package,docs,upload}.R` (operator
helpers, NOT in `bootstrap/load_modules.R`), `api/scripts/{package,upload}-analysis-release-zenodo.R`
(host-run CLIs), `api/tests/testthat/test-unit-analysis-release-zenodo-{package,upload}.R`. Plus
`Makefile` targets, `.gitignore`, `documentation/09-deployment.qmd` runbook, `AGENTS.md`, and a version
bump to 0.30.3. Context: `AGENTS.md` "Analysis-snapshot releases (#573)"; the sibling being mirrored is
`/home/bernt-popp/development/nddscore/scripts/{package,upload}_sysndd_zenodo_dataset.py` +
`src/models/sysndd_export.py`; the reuse idioms are in `api/functions/nddscore-release-source.R`; the
DOI PATCH endpoint contract is `api/endpoints/admin_analysis_snapshot_endpoints.R`.

## What Slice C does
- **Packager** (`-package.R`): reads a PUBLISHED release over the public HTTP API (`GET
  /api/analysis/releases/{latest|<id>}` + `/<id>/bundle`), verifies the download against the head's
  `bundle_sha256` (SHA-256), extracts + verifies the bundle's inner `checksums.sha256`, re-stages the
  files under `analysis_snapshot_release/`, writes Zenodo docs (README/DATA_CARD/SCHEMA/CHANGELOG/
  CITATION.cff) + `zenodo_metadata.json` + `datapackage.json` + a staging-wide `checksums.sha256`, runs
  a SAFETY VALIDATOR, and builds a deterministic `<release_id>.tar.gz` + `.sha256`.
- **Uploader** (`-upload.R`): Zenodo deposit REST (get-or-create draft → set metadata → PUT archive to
  bucket → optional publish), then an opt-in DOI record-back to the SysNDD admin PATCH endpoint.

## LOCKED decisions (do NOT flag; DO flag violations)
1. **Read path is public HTTP API only** — no DB, no `docker exec`, host-runnable with httr2/jsonlite/
   digest. DI seams (injectable http/put/patch) with real defaults so unit tests use no mocking library.
2. **Publish is DOUBLE-gated**: `require_publish_confirmation(publish, confirm_publish)` STOPS unless
   BOTH `--publish` AND `--confirm-publish`. Draft-only default. The Makefile must NEVER make publishing
   one keystroke.
3. **DOI record-back is OPT-IN**: only fires with `--record-doi` + `SYSNDD_ADMIN_TOKEN` set (and only
   after an actual publish); otherwise it PRINTS the manual PATCH command. Additive endpoint, outside
   the content hash. Only the SUPPLIED non-empty DOI fields are sent (NULL/NA/"" all dropped).
4. **The SAFETY VALIDATOR** runs last before tarring: forbidden files (.env etc. + forbidden dir
   segments), sensitive-text scan (host paths `/home/`, username `bernt-popp`, token-shaped text,
   internal repo names, git_sha), extract-layout sanity.
5. Operator scripts are EXEMPT from `external_proxy_budget()` (confirmed — not in the guard scan set).
6. Content-addressed release ids (`asr_<16hex>`), not date-versioned. No manuscript references anywhere.

## Focus your adversarial energy on
- **Secret leakage**: is `ZENODO_TOKEN` or `SYSNDD_ADMIN_TOKEN` EVER printed to stdout/stderr, embedded
  in the printed manual `curl` command, or written into any staged file? The manual command must use a
  placeholder, not the real token. Could a token end up in the tarball (the validator should catch it —
  does it actually)?
- **The safety validator**: can a sensitive string slip past? Consider files whose suffix is outside the
  scanned set, binary files, deeply nested files, case variations, a `.env` inside the release subdir.
  Does it fire BEFORE tarring, and does a failure actually abort (not warn)?
- **Checksum/verify correctness**: does the packager FAIL closed on a corrupted bundle download, a wrong
  `bundle_sha256`, or a tampered inner `checksums.sha256`? SHA-256 (not md5) throughout?
- **Upload safety**: `req_body_file` streams (not memory-loads) the archive; the bucket PUT URL is
  `{bucket}/{basename}`; publish truly cannot happen without both flags; the get-or-create reuse path
  is correct.
- **DOI record-back**: only supplied fields sent (NULL/NA/empty dropped — the `nzchar(NA)` gotcha);
  JSON body (robust to slashes in the DOI); never fires without the flag+token; never onto a draft.
- **R footguns**: masked base verbs (`setdiff`/`get`/`merge` — namespaced?), `library()` at file top
  (should be none, so tests don't need httr2), `DBI::dbBind` unname (N/A here), main-guard so sourcing
  the CLI doesn't run network calls, error paths exit non-zero.
- **Test quality**: real assertions vs shallow. Are the validator's 3 failure modes, the checksum
  fail-closed paths, the bucket-PUT body, and the DOI-only-supplied-fields all covered?
- **Runbook accuracy**: does `09-deployment.qmd` describe the REAL flags, and never instruct a one-step
  publish? Could an operator following it accidentally publish or leak a token?
- **File size**: any handwritten source (.R) file > 600 lines? (`-package.R` is ~597 — confirm it's under.)

## Output
Findings grouped by **BLOCKER / HIGH / MEDIUM / LOW**, each with file:line + concrete failure scenario
+ fix direction. End with `VERDICT: SHIP` or `VERDICT: NO-SHIP`. If nothing is ship-blocking, say so
plainly — do not manufacture issues.
