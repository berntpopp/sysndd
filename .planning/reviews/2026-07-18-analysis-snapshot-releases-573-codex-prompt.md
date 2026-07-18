You are a hostile staff-level engineer + security reviewer for the SysNDD repository (R/Plumber API, MySQL migrations, Vue 3 SPA). Adversarially review BOTH of these documents against the CURRENT repository state:

- Spec: `.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md`
- Plan: `.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md`

These design a new feature (GitHub #573): immutable, content-addressed PUBLIC "analysis-snapshot releases" with verifiable lineage (compare `../nddscore` Zenodo flow), plus companions #574 (category-selected clustering universes) and #572 (production lineage runbook). Inspect real repository files — do NOT trust the docs' claims about existing code; verify them.

Use high reasoning. Read the code the docs depend on, at minimum:
- `db/migrations/024_add_public_analysis_snapshots.sql`, `037_*`, `041_add_analysis_reproducibility.sql`, `023_add_nddscore_prediction_release.sql`
- `api/functions/analysis-snapshot-builder.R`, `analysis-snapshot-coherence.R`, `analysis-snapshot-dependencies.R`, `analysis-snapshot-repository.R`, `analysis-snapshot-presets.R`, `analysis-reproducibility.R`, `nddscore-release-source.R`
- `api/services/analysis-snapshot-service.R`, `analysis-snapshot-refresh-service.R`
- `api/endpoints/analysis_endpoints.R`, `admin_analysis_snapshot_endpoints.R`, `backup_endpoints.R`, `api/services/backup-endpoint-service.R`
- `api/bootstrap/load_modules.R`, `api/core/errors.R`, `api/core/filters.R`, `api/bootstrap/mount_endpoints.R`
- the cheap-route / external-budget / endpoint-error-handler guard tests
- `AGENTS.md` invariants relevant to snapshots, migrations, external proxy, and the `config::get` masking footgun

Report ONLY exploitable, correctness-breaking, or implementation-blocking findings, ordered BLOCKER / HIGH / MEDIUM / LOW. For each: the exact file/section, the concrete failure scenario (inputs → wrong result/crash/leak), and the minimal fix. Be specific and skeptical. In particular, pressure-test:

1. **Determinism & hashing.** Is `sha256(payload.json) == payload_hash` actually achievable given how `analysis-snapshot-builder.R` computes `payload_hash` (which object, which serializer, which excluded keys)? Is the deterministic ustar/tar approach in Task A2 correct and stable, or will base-R/`utils::tar` reintroduce nondeterminism (mtime, ordering, uid/gid, gzip header timestamp via `memCompress`)? Does `memCompress(type="gzip")` embed a timestamp that breaks `bundle_sha256` stability? Does `content_digest` truly exclude volatile fields, and is `release_id`'s 12-hex (48-bit) space collision-safe enough for a content identity?

2. **Fail-closed build gate.** Can an incoherent, stale, `source_version_mismatch`, `schema_version_mismatch`, or `dependency_snapshot_mismatch` snapshot slip into a release? Is `analysis_snapshot_get_public`'s `status_code` the right gate for ALL three layers (note it only applies the #571 dependency gate to `phenotype_functional_correlations`)? Is there a TOCTOU window between reading the active snapshots and inserting the release (an axis refresh mid-build)? Should the build take an advisory lock or read all layers in one transaction/consistent snapshot?

3. **Immutability & retention.** Do frozen release blobs truly decouple from `analysis_snapshot_prune`? Does the prune-guard subquery cover all deletion paths? Can a DOI `PATCH` or `updated_at ON UPDATE` change any hashed bytes? Is storing full gzipped payload copies in `LONGBLOB` sound (size limits, `max_allowed_packet`, `dbBind` raw binding)?

4. **Public retrieval-only surface.** Are the new public routes truly DB-only (no external fetcher, no compute, no LLM, no write)? Is the `<path:.*>` capture safe when resolved by exact DB lookup — any injection or draft-leak path? Does `latest`-before-`<release_id>` ordering actually prevent shadowing in Plumber? Are drafts unreachable publicly? Is `mount_endpoint()` wrapping correct so errors return problem+json not opaque 500s?

5. **Repo footguns.** `config::get` masking `base::get`; `biomaRt::select` masking `dplyr::select`; `merge()` masking; `DBI::dbBind` needing `unname()`; `TRUNCATE` auto-commit; `EXPECTED_LATEST_MIGRATION` manifest + minimum file count; container mount boundary (`api/tests/` not bind-mounted); worker not needed since build is synchronous (verify that claim — does anything the build calls require worker-only sourcing?). Is the synchronous admin build safe if it reads/decodes several MB, or should it be a durable job?

6. **#574 correctness.** Entity-level vs gene-level category resolution; mixed-confidence gene inclusion; mutual exclusion; dedupe-key extension collision; approved-public-only universe (`ndd_entity_view`); not activating as `public_ready`.

7. **Anything the plan under-specifies** that would block a fresh engineer, and any acceptance criterion in #573 not actually satisfied by the design.

Do not require a full Zenodo in-app integration, RO-Crate, object storage, a message queue, or a topology redesign unless a concrete #573 requirement cannot be met otherwise. Keep the scope to what the issues demand.
