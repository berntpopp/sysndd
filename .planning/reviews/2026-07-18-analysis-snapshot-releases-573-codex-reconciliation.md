# Codex adversarial review — reconciliation

Reviewer: `gpt-5.6-terra`, high reasoning, read-only, non-interactive (one command-line pass).
Raw output: `2026-07-18-analysis-snapshot-releases-573-codex-review.md` (findings printed twice — streaming artifact; the two blocks are identical).

Codex read the **committed** spec/plan. Two findings had already been fixed by an independent verification pass before Codex returned (noted below); the rest are newly applied. All BLOCKER/HIGH findings are resolved in the spec + plan.

| # | Sev | Finding | Resolution |
|---|-----|---------|------------|
| 1 | BLOCKER | `sha256(payload.json) == payload_hash` unachievable (`payload_hash` is over the pre-persistence in-memory object; child rows round-trip `DECIMAL(8,5)`/`(8,7)`). | **Already fixed** (independently confirmed vs `analysis-snapshot-builder.R:502`). `payload.json` now carries its **own** `content_sha256`; the snapshot `payload_hash`/`input_hash`/`snapshot_id` are recorded as **lineage anchors** cross-checkable against live `meta.snapshot`. Spec §6, Plan A4 test. |
| 2 | BLOCKER | `analysis_reproducibility_decode()` returns a **parsed** object; re-serializing drops the `digits=NA` contract → hash mismatch. | Fixed: use `memDecompress(bundle_gzip_json, type="gzip", asChar=TRUE)` (new `analysis_reproducibility_decode_raw()`), hash/store the **raw pre-gzip bytes** verbatim; `sha256(reproducibility.json)==reproducibility_hash` then holds. Spec §6, Plan A4 step 3 + Consumes. |
| 3 | BLOCKER | Plumber 1.3.2 has no `<path:.*>` multi-segment param → nested `/files/<path>` 404s. | Fixed: file retrieval is `GET /releases/<id>/file?path=<file_path>` (query param, exact `(release_id,file_path)` PK lookup, no traversal). Spec §8/§14, Plan A6. |
| 4 | BLOCKER | Startup also enforces `EXPECTED_MIGRATION_COUNT = 42L` (`migration-manifest.R:5`); bumping only `EXPECTED_LATEST_MIGRATION` crashes boot. | Fixed: Plan A1 bumps **both** (`…COUNT 42L→43L`, `…LATEST → 045`) + manifest test. |
| 5 | HIGH | `status_code=="available"` does **not** prove coherence (the #514 gate can be `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false`); an incoherent `public_ready` snapshot could be frozen. | Fixed: build **re-asserts hard coherence** per cluster layer (`analysis_snapshot_assert_partition_coherent(..., require_coherence=TRUE)`, ignoring the env) → 400 `release_source_incoherent`. Spec §7 step 2, Plan A4 step 1b + test. |
| 6 | HIGH | Spec/plan were mutually incompatible (409 vs 400, 48- vs 64-bit id, TOCTOU, no 409 branch in `errorHandler`). | **Already fixed** in the independent pass: spec+plan both use 400 + idempotent-200, 64-bit `release_id`, advisory-lock/consistent-read TOCTOU guard with pre-insert lineage re-assert, and **no new 409 class** (Codex confirms `filters.R:272` has no 409 branch). Spec §7/§10, Plan A4/A5. |
| 7 | HIGH | Reproducibility bundles are **best-effort** (a NULL bundle still activates the snapshot; `reproducibility_hash` nullable), but the release makes `reproducibility.json` mandatory → crash / non-reproducible release. | Fixed: build requires a stored bundle per cluster layer → 400 `release_reproducibility_missing`. Spec §7 step 3, Plan A4 step 1c + test. |
| 8 | MEDIUM | #574 dedupe keyed only on resolved genes; two selectors resolving to the same current genes collapse with mismatched provenance. | Fixed: dedupe key (preflight + durable payload) includes the **normalized selector** + sorted resolved IDs + algorithm + `CLUSTER_LOGIC_VERSION` + source-data version + STRING channel + threshold. Plan D2. |

No finding required Zenodo in-app integration, RO-Crate, object storage, or a topology redesign — scope held to the issues.
