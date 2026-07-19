# Adversarial diff review ROUND 2 — #573 Slice C (Zenodo operator scripts)

You reviewed this branch in round 1 and returned NO-SHIP (1 BLOCKER, 2 HIGH, 3 MEDIUM). Those are now
addressed in commit `e19fcd26`. Fresh independent re-review of the CURRENT full branch diff:

1. **Verify each round-1 finding is genuinely resolved** (not papered over):
   - BLOCKER (unguarded staging-dir rmtree): now guarded by an ownership sentinel
     (`.analysis-release-zenodo-staging`) — a pre-existing dir without it is NOT deleted (the function
     stops). Confirm no bypass.
   - HIGH (release_id injection): now validated `^asr_[0-9a-f]{16}$` on both the request arg (allowing
     `latest`) and the resolved head id, before it touches any path/filename/marker; the Makefile parses
     `latest.env` with `sed` instead of shell-`source`. Confirm a `../`/newline/`;`-bearing id is rejected
     and the marker can't inject shell.
   - HIGH (validator gaps): now case-INSENSITIVE forbidden-name/dir matching + a file-type ALLOWLIST
     (`.md/.json/.sha256/.cff/.txt/.sql`) that rejects binary/unexpected-suffix/extensionless files +
     symlink rejection. Confirm `.ENV`, `.pem`, `.csv`, an extensionless file, and a symlink are all
     caught, and it runs before tarring.
   - MEDIUM (checksum coverage): `extract_and_verify` now requires every extracted regular file to be
     checksummed (no unstamped files, no dupes) and rejects `..`/absolute paths. Confirm a dropped
     checksum line or a traversal path fails closed.
   - MEDIUM (nondeterministic tarball): staged mtimes normalized to a fixed epoch (R internal tar zeroes
     the gzip timestamp) — a determinism test asserts byte-identical rebuilds. Confirm.
   - MEDIUM (--token leak): the `--token` CLI flag is removed; `ZENODO_TOKEN` env only.
   The logic now lives across `analysis-snapshot-release-zenodo-{package,verify,docs}.R` (the validator +
   extract-verify moved to `-verify.R`), tests in `test-unit-analysis-release-zenodo-{package,verify,upload}.R`.

2. **Hunt for any NEW or adjacent issues** the fixes introduced — same adversarial rigor (the extraction/
   refactor could have broken a call site; the new validator/checksum logic could have an off-by-one or a
   regex gap; the mtime normalization could miss a file; the sed marker-parse could mis-handle a path with
   spaces).

## The diff to review
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
Context: `AGENTS.md` "Analysis-snapshot releases (#573)"; sibling `/home/bernt-popp/development/nddscore/`;
DOI endpoint `api/endpoints/admin_analysis_snapshot_endpoints.R`.

## Locked decisions (do NOT flag; flag violations)
Public-API read only (host-run, DI seams). Publish DOUBLE-gated (`require_publish_confirmation`, Makefile
never passes `--publish`). DOI record-back OPT-IN (`--record-doi` + `SYSNDD_ADMIN_TOKEN`, published-only,
only-supplied-non-empty-fields incl. the `nzchar(NA)` fix, JSON body, manual-command placeholder). Safety
validator runs last before tarring. Content-addressed ids (`asr_<16hex>`). No manuscript references. Every
handwritten `.R` < 600 lines. Operator scripts exempt from the external-budget guard.

## Output
Findings grouped by **BLOCKER / HIGH / MEDIUM / LOW** with file:line + failure scenario + fix direction.
End with `VERDICT: SHIP` or `VERDICT: NO-SHIP`. If the round-1 findings are resolved and nothing new is
ship-blocking, say `VERDICT: SHIP` plainly.
