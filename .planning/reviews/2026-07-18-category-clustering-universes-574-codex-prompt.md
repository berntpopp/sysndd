You are a hostile staff-level engineer reviewer for the SysNDD repository (R/Plumber API, MySQL, dbplyr). Adversarially review BOTH of these documents against the CURRENT repository state:

- Spec: `.planning/superpowers/specs/2026-07-18-category-clustering-universes-574-design.md`
- Plan: `.planning/superpowers/plans/2026-07-18-category-clustering-universes-574-plan.md`

They design GitHub #574: a server-side `category_filter` (e.g. `["Definitive"]`) on `POST /api/jobs/clustering/submit` that resolves the functional-clustering gene universe from curated confidence categories at the ENTITY level. Inspect real repository files — do NOT trust the docs' claims; verify them.

Use high reasoning. Read at minimum:
- `api/services/job-functional-submission-service.R` (the submit handler)
- `api/functions/analyses-functions.R` (`generate_ndd_hgnc_ids`, `select_network_gene_category`, `build_string_subgraph`, `gen_string_clust_obj`, `set.seed`)
- `api/functions/async-job-service.R` (`async_job_service_submit`, `async_job_service_request_hash`, `async_job_service_find_duplicate`, capacity), `api/functions/async-job-repository.R` (`active_request_hash` unique + race handler), `db/migrations/020_add_async_job_schema.sql`
- `api/functions/async-job-handlers.R` (`.async_job_run_clustering`)
- `db/migrations/025_create_core_views.sql` (`ndd_entity_view` category join), `db/migrations/033_add_metadata_lookup_admin_columns.sql` (`ndd_entity_status_categories_list.is_active`), `db/migrations/000_initialize_base_schema.sql` (category seed)
- `api/core/errors.R` (`stop_for_bad_request`), `api/functions/clustering-submit-throttle.R`
- `api/tests/testthat/test-unit-job-endpoint-services.R`

Report ONLY exploitable, correctness-breaking, or implementation-blocking findings, ordered BLOCKER / HIGH / MEDIUM / LOW. For each: exact file/section, concrete failure scenario (inputs → wrong result/crash/leak), and the minimal fix. Pressure-test in particular:

1. **Entity-level resolution correctness.** Does the resolver truly include a gene with a Definitive entity AND a Limited entity for `["Definitive"]`, and exclude a Limited-only gene and a Definitive-but-non-NDD entity? Is `ndd_entity_view.category` actually per-entity (verify the view join)? Does filtering entity rows + `distinct(hgnc_id)` give the union semantics for multi-value selectors? Is there any hidden gene-level aggregation?

2. **Dedup mechanism.** Verify the claim that the preflight `{genes, algorithm}` hash cannot match the stored full-payload `request_hash`, so the DB `active_request_hash` unique constraint is the real dedup. Does adding `category_filter` to the durable payload actually make two same-gene selectors distinct jobs? Does the `active_request_hash` generated column (only queued/running/retryable) mean a completed cache-hit job does NOT dedup a later identical submit — is that acceptable? Any regression to the existing all-genes/explicit-list dedup? Does the cache-hit `store_completed` path also need `category_filter` in its payload/hash?

3. **Cache parity.** Does routing the NULL default through `generate_ndd_hgnc_ids() |> pull(hgnc_id)` produce the byte-identical gene vector/order as today's inline query (so `gen_string_clust_obj_mem` cache keys don't all miss)? Any difference (tibble vs vector, ordering, `unique()` semantics)?

4. **Validation + injection.** Is validating tokens against `ndd_entity_status_categories_list WHERE is_active=1` correct (does that column exist post-033)? Is `dplyr::filter(category %in% !!selector)` injection-safe under dbplyr against MySQL? Any collation/case mismatch between the request token and the stored category? Empty/too-small-universe guard sensible (min 2)?

5. **Provenance / determinism.** Are `CLUSTER_LOGIC_VERSION`, `analysis_snapshot_source_data_version()`, `attr(clusters,"weight_channel")`, seed=42, threshold=400 the right sources, and available at submit vs only at compute time (weight_channel is a result attr — does the plan capture it in the right place for BOTH cache-hit and worker paths)? Is `analysis_snapshot_source_data_version()` safe/cheap to call on the public submit path (no external calls)?

6. **Error contract + scope.** Is introducing a `stop_for_bad_request` 400 on this endpoint (which today has zero request validation and returns direct-status 409/503 plain-JSON) going to be caught by the mounted error handler as problem+json, or become an opaque 500? Does the endpoint's sub-router have the RFC-9457 handler? Are non-goals (phenotype submit, category GET, public_ready) actually preserved?

7. **Anything under-specified** that blocks a fresh engineer, or any #574 acceptance criterion not satisfied.

Do not require phenotype-clustering symmetry, a public category GET, a snapshot preset, or fixing the pre-existing preflight/DB hash-scope inconsistency unless a concrete #574 requirement demands it.
