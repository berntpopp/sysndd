# Codex re-review — #573 Slice A, verify DO-NOT-SHIP findings are resolved

You previously reviewed this branch (#573 Slice A, immutable public analysis-snapshot releases backend) and returned DO-NOT-SHIP with 1 BLOCKER + 3 HIGH + 1 MEDIUM + 1 LOW. Fix commits were then applied. Re-review `git diff 67cf6003..HEAD` (whole Slice A) and specifically CONFIRM each prior finding is now correctly resolved, AND scan the fix commits (git log 49eb025b..HEAD) for any REGRESSION or NEW issue the fixes introduced (e.g. the layer-resolution, the public-head projection allowlist, the 503 lock path, the duplicate-key insert seam, the reproducibility-hash assertion, the db_release provenance, the pagination clamp).

Prior findings to verify RESOLVED:
- BLOCKER: caller `layers` redefining `has_reproducibility`/`files_prefix` (gate-bypass + path traversal). Now `analysis_snapshot_release_resolve_layers()` resolves to the authoritative registry (caller policy fields ignored; unknown/dup -> 400) + `.analysis_release_assert_safe_path()` in the tar builder. Verify no residual path an Admin body could use to skip a gate or write outside the archive root; verify duplicate/omission handling.
- HIGH: public list/detail/latest leaking `created_by_user_id`/`last_error_message`. Now `analysis_release_public_head()` allowlist in `svc_release_list`/`svc_release_get`. Verify the admin path still returns full head and NO public path returns internal fields (incl. the manifest object and the `layers` summary).
- HIGH: build not asserting `sha256(repro bytes)==reproducibility_hash`. Now asserted at build. Verify it uses the RAW decoded bytes (not the parsing decode) and rejects on mismatch.
- HIGH: idempotency race (unlocked-proceed + raw-500 on PK collision). Now failed lock on a real conn -> 503; duplicate-key insert -> re-read -> idempotent-200-or-500. Verify the lock is actually required on the real path, the 503 maps correctly, and the dup-key path returns the existing row only when content_digest matches.
- MEDIUM: db_release_version/commit unpopulated. Now sourced from pinned snapshot manifests. Verify consistency handling.
- LOW: unbounded pagination. Now clamped. Verify bounds.

Focus areas unchanged from the first pass (authz/exposure, SQL/injection, gate soundness, hashing invariants, byte-serving, resource/lock/pool safety, adjacent same-class siblings). Group findings BLOCKER/HIGH/MEDIUM/LOW; for each `file:line` + failure scenario + fix. If all prior findings are resolved and no new BLOCKER/HIGH exists, say so and end with SHIP. Read-only; do not modify files.
