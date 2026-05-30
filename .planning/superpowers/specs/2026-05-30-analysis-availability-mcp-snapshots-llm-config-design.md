# Analysis Availability, MCP Snapshots, And LLM Config Design

Date: 2026-05-30

Repository: `/home/bernt-popp/development/sysndd`

Issues: #344, #353, #347, #348

## Sprint Objective

Make SysNDD's public analysis, external-provider, and MCP read paths availability-first.
Cheap public/API/MCP routes must not be blocked by slow external calls, heavy derived
analysis, cold cache misses, broad job result payloads, or model-provider
configuration failures.

The sprint has two tracks:

1. Integrated analysis availability and public data contract track for #344, #353,
   and #347.
2. Smaller LLM model configuration hardening track for #348.

## Decision

Implement #344, #353, and #347 together as one integrated "analysis availability
and public data contract" track. These issues share the same root problem: public
and MCP clients need bounded, deterministic reads from prepared public artifacts,
not request-path analysis computation or fragile memoise cache discovery.

Implement #348 as a parallel config-hardening track. It is production-reliability
work, but it should stay smaller and isolated from the snapshot architecture.

Do not reintroduce Redis in this sprint. The current architecture already has the
right primitives: MySQL-backed async jobs, a worker service with egress, durable
database migrations, memoise/cachem for local acceleration, and a read-only MCP
sidecar. The missing piece is a public snapshot/fingerprint contract plus stricter
request-path budgets.

## Non-Goals

- Do not build a large platform rewrite, new queueing system, Redis layer, or new
  external service.
- Do not make MCP write-capable.
- Do not allow MCP to trigger heavy analysis, external provider calls, Gemini/LLM
  generation, admin workflows, raw SQL/R execution, or broad exports.
- Do not expose draft reviews, re-review state, admin/user/log/job data, curation
  comments, or private data through MCP snapshots.
- Do not change curated SysNDD classifications based on NDDScore, derived analyses,
  or LLM summaries.
- Do not remove existing public endpoints in the first rollout; add snapshot-backed
  behavior and compatibility metadata first.
- Do not implement code as part of this spec/plan generation step.

## Current-State Findings

### Repository And Planning Context

Recent git history shows reliability hardening and analysis groundwork already in
place:

- `2026-05-25` metadata refresh rollback safety (#364).
- `2026-05-25` first-wave hardening.
- `2026-05-24` GeneNetworks fCoSE layout artifacts (#362).
- `2026-05-21` PubTator typed-client boundary work (#361).

Relevant planning docs already define constraints that this sprint should reuse:

- `.planning/superpowers/specs/2026-05-17-read-only-mcp-api-design.md`:
  MCP is a separate read-only sidecar, not a Plumber mirror.
- `.planning/superpowers/specs/2026-05-18-mcp-analysis-research-context-design.md`:
  MCP 1.2 analysis tools are compact, cache-only, and data-class labeled.
- `.planning/superpowers/specs/2026-05-24-gene-network-fcose-layout-artifact-design.md`:
  GeneNetworks display layouts are worker-computed artifacts, with browser fallback.
- `.planning/reviews/2026-05-24-gene-networks-algorithm-performance-review.md`:
  cold `network_edges` computation was observed around 55 seconds locally, and
  public request paths still compute STRING/network data on cache miss.

The benchmark review named in #353,
`.planning/reviews/2026-05-19-mcp-tool-benchmark.md`, is not present on current
`master`; the issue body is treated as the available benchmark source of truth.

### #344 Slow Public Request Paths

The problem remains in code:

- `api/endpoints/analysis_endpoints.R` still computes functional clustering,
  phenotype clustering, phenotype-functional correlation, and network data
  synchronously on cold cache miss.
- `api/functions/analysis-network-functions.R` calls `gen_network_edges_mem()` from
  `generate_network_edges_response()`, so `/api/analysis/network_edges` can still
  perform heavy STRING/network work in the API process before any fCoSE display
  artifact is used.
- `api/endpoints/jobs_endpoints.R` preloads large default clustering inputs in the
  API request, stores full completed results on cache hits, and currently triggers
  LLM batch generation for cache-hit submissions.
- `api/functions/job-manager.R` always calls `async_job_service_status(...,
  include_result = TRUE)`, so completed job status can deserialize and return large
  result payloads.
- `api/functions/external-proxy-functions.R` uses up to 5 tries, 120 seconds total,
  and 30 seconds per attempt. MGI and RGD helpers have separate 30-second direct
  httr2 request paths.
- `api/endpoints/external_endpoints.R` aggregates external sources serially in
  `/api/external/gene/<symbol>`.

Partially implemented:

- External errors are not memoised permanently through
  `memoise_external_success_only()`.
- Durable async jobs exist and worker startup binds memoised analysis helpers.
- fCoSE display layouts can be precomputed by a worker for the exact displayed
  GeneNetworks graph.

Remaining:

- Public endpoints need snapshot/cache-hit-only behavior for heavy analysis.
- External proxy endpoints need shorter provider budgets and timing diagnostics.
- Public job status needs summary/default result modes.
- Public request paths must stop triggering Gemini/LLM generation.

### #353 MCP Benchmark, Search, And Cache Diagnostics

Partially implemented:

- `api/start_sysndd_mcp.R` runs a dedicated sidecar and avoids Plumber routes,
  migrations, workers, Gemini, and external provider modules.
- MCP tools use read-only annotations, output schemas, stable error envelopes, and
  JSON serialization with `null = "null"` in `api/services/mcp-tool-core.R`.
- MCP analysis tools already perform cache-hit checks before some heavy helpers,
  and phenotype correlations do not call live generation on cache miss.

Remaining:

- `search_sysndd` search is too narrow. `api/functions/mcp-repository.R` uses
  `search_non_alt_loci_view` and `search_disease_ontology_set` in a way that does
  not cover gene names, alias/previous symbols, disease crossrefs, or tokenized
  multi-word ranking.
- `get_gene_network_context` and phenotype analysis tools return generic
  `temporarily_unavailable` instead of actionable initialization/snapshot errors.
- `api/functions/mcp-analysis-cache-repository.R` scans disk RDS files by payload
  shape, which is fragile and not a public data contract.
- `publication_type` is selected for entity publication links but not for
  standalone publication context.
- `get_phenotype_analysis_context(mode = "correlations")` accepts `gene` even
  though that mode is global and the gene parameter is ignored.
- `drop_diagonal` and `triangle_only` are missing for correlation-style payloads.
- MCP smoke does not yet assert benchmark phrases, snapshot diagnostics,
  `publication_type`, null serialization regressions, or zero-result diagnostics.

### #347 Public Derived-Analysis Snapshots

Not implemented:

- No `analysis_run`, `analysis_snapshot_manifest`, `public_ready`, or equivalent
  snapshot tables exist.
- No migration exists after `023_add_nddscore_prediction_release.sql`.
- MCP and public analysis reads still depend on memoise disk state or direct
  analysis helpers.

Partially implemented foundation:

- Durable async jobs and a worker process already exist.
- Worker-executed code can precompute analysis artifacts.
- fCoSE layout artifacts already introduced a data-aware layout key pattern.
- MCP data-class labeling and cache-only analysis boundaries already exist.

Remaining:

- Add durable public snapshot metadata and payload tables.
- Add worker refresh jobs that compute snapshots outside request paths.
- Make API and MCP read the single public-ready snapshot for each supported
  `(analysis_type, parameter_fingerprint)` key.
- Return explicit recoverable errors for missing, stale, or incompatible snapshots.

### #348 Gemini/LLM Model Config

Partially implemented:

- `api/functions/llm-client.R` now defines `get_default_gemini_model()` and defaults
  to `gemini-3.5-flash`.
- `api/functions/llm-service.R`,
  `api/functions/llm-endpoint-helpers.R`, and
  `api/endpoints/llm_admin_endpoints.R` use the default helper rather than the old
  preview literal in runtime paths.

Remaining:

- Model catalog, validation, default resolution, and deployment fallback are still
  concentrated in `llm-client.R`, not a clear central config contract.
- Stale comments and test fixtures still reference `gemini-3-pro-preview`.
- `GEMINI_MODEL` is not documented in durable deployment/development docs.
- Preview/stable policy is not explicit.
- Invalid configured models are not cleanly rejected before generation attempts.

Official Gemini documentation checked during design:

- Gemini model docs list `gemini-3.5-flash` as a current stable model and state
  stable models are preferred for most production apps:
  https://ai.google.dev/gemini-api/docs/models
- Gemini deprecations list `gemini-3-pro-preview` shutdown on 2026-03-09 and
  recommend `gemini-3.1-pro-preview` as its replacement:
  https://ai.google.dev/gemini-api/docs/deprecations

## User-Facing Behavior Changes

- Public analysis pages should load from prepared data when available.
- If a derived-analysis snapshot is missing or stale, public pages should show a
  bounded unavailable/degraded state instead of causing long API stalls.
- Gene external cards may show per-source unavailable states faster when upstream
  providers are slow.
- Job polling should remain responsive and should not download large completed
  analysis results unless the caller explicitly asks for them.
- Cached LLM summaries remain visible where already generated and validated, but
  public page requests must not trigger Gemini generation.
- Admin/operator workflows should expose enough status to know which snapshots need
  refresh, without exposing that operational state through public MCP tools.

## API Behavior Changes

### Heavy Analysis Endpoints

Public heavy analysis endpoints should become snapshot-first and request-bounded:

- `/api/analysis/network_edges`
- `/api/analysis/functional_clustering`
- `/api/analysis/phenotype_clustering`
- `/api/analysis/phenotype_functional_cluster_correlation`
- phenotype correlation endpoints used by public/MCP analysis surfaces

Expected behavior:

- If a matching `public_ready` snapshot exists, return it with manifest metadata.
- If no snapshot exists, return a recoverable 503/424-style problem response with
  `code = "snapshot_missing"` and operator-oriented `detail`.
- If the snapshot is past its cheap freshness policy, return
  `code = "snapshot_stale"`.
- If a cheap stored source-data version comparison is available and does not match,
  return `code = "source_version_mismatch"`.
- Do not compute STRING, phenotype clustering, phenotype correlations, fCoSE, or
  LLM summaries in these public request paths.
- Keep compatibility fields where practical, but add `meta.snapshot` metadata so
  clients can distinguish snapshot-backed data from legacy cache-backed data.

Read-path staleness checks must stay cheap. Public and MCP reads must not recompute
full input fingerprints, sorted source entity/gene/review lists, STRING graphs, or
broad joins to decide whether a snapshot is stale. The read path may inspect only:

- manifest status and `public_ready`.
- parameter/fingerprint keys already stored on the manifest.
- `stale_after` / `expires_at`.
- a stored cheap source-data version value, if implemented.

Full `input_hash` and `payload_hash` mismatch detection belongs in the worker
refresh/admin diagnostics path. If no cheap source-data version exists yet, the
read path uses time-based staleness and exposes that policy in `meta.snapshot`.

### Supported Parameter Matrix

Snapshot-only reads require an explicit supported parameter matrix. Public and MCP
callers may request only parameter combinations that the worker is configured to
precompute. Unsupported combinations should fail fast with
`code = "unsupported_parameter"` or `invalid_input`, not `snapshot_missing`.
`snapshot_missing` is reserved for a supported preset whose artifact has not been
prepared yet.

Initial public snapshot presets:

- `functional_clusters`: `algorithm = "leiden"`.
- `phenotype_clusters`: no public parameters.
- `phenotype_correlations`: the current approved-public phenotype correlation
  filter; `min_abs_correlation`, `drop_diagonal`, and `triangle_only` are read-time
  shaping filters over the stored rows, not separate snapshot keys.
- `phenotype_functional_correlations`: current default functional algorithm
  `leiden` plus current phenotype-cluster defaults.
- `gene_network_edges`: `cluster_type = "clusters"`, `min_confidence = 400`,
  `max_edges = 10000`.

Non-default public combinations, such as `algorithm = "walktrap"`, arbitrary
network confidence thresholds, `max_edges = 0`, or alternate display edge caps,
are unsupported until added to the configured preset matrix and precomputed by the
worker. The plan should confirm current frontend consumers and add only the
minimal extra presets actually used in production.

For MCP, response caps such as `max_edges = 100` may trim a supported network
snapshot for token budgeting. They must not imply that an exact public display
layout exists for an unsupported `max_edges` snapshot key.

### External Provider Endpoints

External proxy behavior should be fast-fail and observable:

- Add per-source timeout budgets and retry caps.
- Preserve successful and true not-found caching.
- Continue refusing to cache transient `error = TRUE` upstream failures.
- Emit structured timing logs with source, status, elapsed time, cache status, and
  budget/degraded indicators.
- The frontend hot path appears to call per-source external routes rather than the
  aggregate `/api/external/gene/<symbol>` route. The sprint should prioritize
  tighter per-source budgets first.
- Do not make aggregate-endpoint parallel fanout a sprint requirement unless a real
  consumer is confirmed. If the aggregate endpoint is touched, cap it with a short
  total budget and partial/degraded response semantics rather than introducing a new
  async/fanout subsystem.

### Jobs

Public job status should support result modes:

- Default: summary status, no full result payload.
- `result_mode = "summary"`: include counts, metadata, and status only.
- `result_mode = "full"`: return full result only where still intentionally
  supported.

Cluster job submission should avoid public request-path LLM chaining. LLM generation
should remain a worker/admin action after explicit job completion policy, not a
side effect of cache-hit public submissions.

Removing the current cache-hit LLM trigger must be paired with a replacement so
cluster summaries do not silently stop appearing. The replacement is snapshot
refresh ownership:

- Functional and phenotype cluster snapshot refresh jobs should enqueue or run the
  existing worker LLM generation flow for missing summaries when Gemini is
  configured and the operator policy enables summary generation.
- Public analysis reads and MCP reads only consume current, validated cached
  summaries and must report `summary_available = false` or a snapshot/summary
  status when generation is pending, disabled, or not configured.
- Snapshot activation should not require Gemini availability unless an operator
  explicitly configures that policy; deterministic derived-analysis freshness must
  not be coupled to model-provider uptime.

## MCP Behavior Changes

MCP remains read-only and public-data-only.

Expected changes:

- Analysis tools read the public-ready snapshot for the requested supported
  parameter key, not broad REST routes, not live external providers, not Gemini,
  and not memoise cache misses.
- Disk RDS scan fallback should be removed or demoted to temporary compatibility
  during rollout, then replaced by snapshot repository reads.
- Missing analysis data returns stable tool-result JSON with `isError = true`,
  `schema_version`, `error.code`, and recovery hints.
- New/updated error codes:
  - `snapshot_missing`
  - `snapshot_stale`
  - `source_version_mismatch`
  - `unsupported_parameter`
  - `needs_admin_initialization`
  - `temporarily_unavailable`
  - `invalid_input`
- `search_sysndd` keeps the current MCP service default of all allowed result
  types, including the existing phenotype and variant branches, and gains
  tokenized ranked search across:
  - gene symbol
  - HGNC ID
  - gene name
  - alias/previous symbols from `hgnc_symbol_lookup`
  - entity symbol/disease text
  - disease name and available crossrefs
  - phenotype ID, term, and synonyms
  - variation ID/name
- Search implementation should use deterministic per-token SQL/R scoring for this
  sprint, not MySQL `FULLTEXT`. The repository should normalize the query into a
  capped token list, build bounded candidate queries with `LIKE`/exact/prefix
  predicates, assign weighted scores, then sort deterministically by score, type,
  label, and ID. Do not mutate legacy search views in
  `db/C_Rcommands_set-table-connections.R` for this sprint; broaden the
  `mcp-repository.R` logic and join `hgnc_symbol_lookup` from migration 018 for
  aliases/previous symbols.
- Zero-result search responses include query echo, searched types, tokenization
  metadata, and suggestions to try identifiers or narrower entity/phenotype tools.
- `get_phenotype_analysis_context(mode = "correlations")` should reject `gene` with
  `invalid_input` unless gene scoping is deliberately implemented later. The sprint
  should prefer rejection/documentation because the current correlation payload is
  global.
- Add `drop_diagonal` and `triangle_only` to correlation-style modes.
- Standalone publication context includes per-link `publication_type` on each
  approved entity/publication join row. If an envelope-level summary is added, it
  must be a deduped array of observed publication types, not a single dominant
  value.
- JSON null regressions remain covered by tests; null scalar fields must serialize
  as JSON `null`, not `{}`.

## Worker, Job, Cache, And Snapshot Architecture

### Snapshot Refresh Flow

1. API/admin submits a durable async job, likely `analysis_snapshot_refresh`.
2. Worker claims the job from the existing MySQL-backed async job queue.
3. Worker computes analysis payloads using existing deterministic helpers and the
   approved-public data gate.
4. Worker writes a pending manifest row and type-specific snapshot rows.
5. Worker validates row counts, payload hashes, and schema versions.
6. Worker atomically marks the snapshot `public_ready = 1` for the matching
   `analysis_type` and parameter fingerprint.
7. API and MCP read only `public_ready` snapshots.

Snapshots must be computed only from approved public inputs: active records from
`ndd_entity_view` and review-derived synopsis/phenotype/variation/publication data
only from primary approved reviews (`is_primary = 1` and `review_approved = 1`).
This mirrors the MCP repository gate and prevents snapshot payloads from leaking
draft or non-approved data.

### Public-Ready Uniqueness

Snapshot lookup and activation are scoped by `(analysis_type, parameter_hash)`.
The contract is exactly one `public_ready` snapshot for each supported key. The
word "latest" is only a defensive query ordering during rollout; it is not the
business rule.

The atomic public-ready switch should reuse the spirit of the NDDScore release
pattern from migration `023_add_nddscore_prediction_release.sql`, but not the
table-wide unique key shape. Use a scoped generated-column unique key, for example:

- `public_ready_slot` generated as `CASE WHEN public_ready = 1 THEN 1 ELSE NULL END`.
- unique key on `(analysis_type, parameter_hash, public_ready_slot)`.

This permits many pending/superseded rows for a key, many different keys to be
public-ready at the same time, and at most one public-ready row per key.

Advisory locks should also be scoped, not global. Default lock name:
`analysis_snapshot_refresh:<analysis_type>:<parameter_hash>`. This allows
independent snapshot types or parameter keys to refresh without blocking each
other while still preventing concurrent activation races for the same key.

### Snapshot Types

Initial sprint snapshot types:

- `functional_clusters` (`data_class = "curated_derived_analysis"`)
- `phenotype_clusters` (`data_class = "curated_derived_analysis"`)
- `phenotype_correlations` (`data_class = "curated_derived_analysis"`)
- `phenotype_functional_correlations`
  (`data_class = "curated_derived_analysis"`)
- `gene_network_edges` (`data_class = "curated_derived_analysis"`)

Optional in the same design, but only if implementation stays focused:

- `gene_network_display_layout_manifest` bridge metadata for existing fCoSE layout
  artifacts. If this is metadata-only, label it `operational_metadata`; if exposed
  as part of the public analysis payload, label it `curated_derived_analysis`.

### Cache Role

Memoise/cachem remains an acceleration layer for workers and internal helpers. It
must not be the public data contract for API or MCP.

The cache may be used while building snapshots, but public/MCP reads should not
depend on cache file names, RDS payload shape scans, or whether an API process has
warmed a memoised key.

Snapshot retention should be explicit. Default policy for this sprint:

- keep the latest 3 public-ready snapshots per `(analysis_type, parameter_hash)`;
- keep superseded non-public snapshots for a short operator-debug window, for
  example 14 days;
- prune type-specific rows through foreign-key cascade or repository cleanup after
  the manifest retention decision;
- never prune the currently public-ready snapshot.

## Snapshot, Fingerprint, And Manifest Contract

Each public snapshot manifest should expose:

- `snapshot_id`
- `analysis_type`
- `schema_version`
- `data_class`
- `parameter_hash`
- `status`
- `public_ready`
- `public_ready_slot`
- `generated_at`
- `generated_by_job_id`
- `source_versions_json`
- `source_data_version`
- `parameters_json`
- `input_hash`
- `payload_hash`
- `algorithm_name`
- `algorithm_version`
- `package_versions_json`
- `row_counts_json`
- `warnings_json`
- `expires_at` or `stale_after`

Fingerprint inputs should include:

- sorted source entity/gene/review identifiers used as analysis input
- source table or view version hints where available
- approved primary review boundary
- `cluster_type`
- `min_confidence`
- `max_edges`
- edge filtering policy and tie-breakers
- layout options where layout-derived payloads are included
- STRING version
- Cytoscape/fCoSE versions for display layout artifacts
- analysis helper schema version
- package/library versions that affect output shape or deterministic ordering

These inputs define the worker/admin full fingerprint, not the default public read
cost. The read path should compare precomputed manifest keys and cheap freshness
fields only.

`parameter_hash` is a canonical hash of the supported public parameter preset for
the analysis type. It is part of the public lookup key and the scoped uniqueness
constraint; it is distinct from `input_hash`, which represents the full worker-side
source/input fingerprint.

Snapshot rows should be normalized enough for bounded filtering:

- network nodes by `snapshot_id`, `hgnc_id`, symbol, cluster, category, degree,
  optional layout positions, and display flags.
- network edges by `snapshot_id`, source, target, confidence, and rank/order.
- cluster rows by `snapshot_id`, cluster ID, hash, size, labels, and compact
  metadata.
- cluster members by `snapshot_id`, cluster ID, entity ID and/or HGNC ID.
- correlation rows by `snapshot_id`, x, y, value, absolute value, rank, and source
  mode.

Large nested legacy payloads may be stored as compact JSON where normalization
would not improve bounded public access, but the manifest must still carry
fingerprints and counts.

## Search And Cache Diagnostics Expectations

MCP benchmark fixes should be deterministic and testable:

- Search for phrases like `NMDA receptor` and `epilepsy aphasia` should produce
  useful ranked results when corresponding public records exist.
- Ranking should prefer exact identifiers, exact labels, aliases, phrase matches,
  prefix matches, then token-overlap matches.
- Search should not become a broad export: keep caps and SQL-side limits.
- Analysis dry-run/diagnostics responses should distinguish:
  - snapshot available
  - snapshot missing
  - snapshot stale
  - source version mismatch
  - admin initialization needed
  - unsupported parameter combination
- Diagnostics should include operator hints without exposing admin/job tables
  through MCP.
- `api/scripts/mcp-smoke.R` should cover search phrases, snapshot diagnostics,
  correlation shape flags, `publication_type`, null serialization, and error codes.

## LLM Model Configuration Contract

Centralize model configuration behind one helper module or clearly separated
helpers:

- default model: `gemini-3.5-flash`
- env override: `GEMINI_MODEL`
- optional config fallback: deployment config key, documented in
  `api/config.yml.example`, `documentation/08-development.qmd`, and
  `documentation/09-deployment.qmd`
- model catalog: current text-output model IDs with stable/preview/deprecated
  status
- validation: reject unknown or shut-down models before generation
- preview policy: preview models require explicit allow/config flag or are clearly
  marked as non-default in admin UI
- operator escape hatch: support a deployment-controlled allowlist such as
  `GEMINI_ALLOWED_MODELS_EXTRA` for newly released models before a code deploy
  updates the built-in catalog. Unknown models remain rejected unless they are
  explicitly allowlisted by the operator, and admin config should surface that the
  model is operator-allowed but not in the built-in catalog.
- admin config response: include current model, source, default, valid/invalid
  status, and available model metadata

Runtime behavior:

- Invalid LLM model configuration should fail with a clear recoverable/admin-visible
  error before calling Gemini.
- A model configured through the operator escape hatch should generate an
  admin-visible warning, not a hard failure.
- Public API and MCP routes should not call Gemini generation.
- Worker/admin LLM generation may use configured Gemini model only after validation.
- Existing historical cache rows with old model names may remain readable as
  historical metadata; the issue is generation defaults and current config, not
  rewriting past audit records.

## Failure Modes And Recoverable Errors

Expected API problem/error codes:

- `snapshot_missing`: no public-ready snapshot exists for requested analysis and
  parameters.
- `snapshot_stale`: snapshot exists but is past freshness policy.
- `source_version_mismatch`: a cheap stored source-data version check indicates
  that the snapshot was built from a different source version. Full fingerprint
  mismatch detection remains a worker/admin refresh responsibility.
- `unsupported_parameter`: requested analysis parameters are outside the configured
  public snapshot preset matrix.
- `analysis_unavailable`: generic fallback only when a more specific code does not
  apply.
- `external_provider_timeout`: provider exceeded configured budget.
- `external_provider_unavailable`: provider returned transient failure.
- `llm_model_invalid`: configured model is not allowed/current.
- `llm_not_configured`: generation requested without provider credentials.

Expected MCP behavior:

- Recoverable failures return JSON tool results with `isError = true`.
- Error payloads include `schema_version`, `error.code`, `error.message`, and
  `recovery` or `operator_hint` where useful.
- MCP must not surface raw R errors, JSON-RPC `-32603`, stack traces, SQL, or
  private operational rows for expected validation/cache/snapshot failures.

## Rollout And Migration Plan

1. Add snapshot schema migration after `023_add_nddscore_prediction_release.sql`,
   update `EXPECTED_LATEST_MIGRATION`, and bump `EXPECTED_MIGRATION_COUNT` from
   `24L` to `25L` in `api/functions/migration-manifest.R`.
2. Add the supported parameter preset matrix and repository/service helpers for
   writing and reading public snapshots.
3. Add worker job handler for snapshot refresh.
4. Add snapshot-read paths behind compatibility metadata.
5. Add admin/operator trigger or documented job submission path for refresh.
6. Run initial refresh in development/staging.
7. Switch public analysis and MCP tools to snapshot-first behavior.
8. Keep degraded/missing snapshot responses explicit during first deploy.
9. Update durable docs for development, deployment, and agent guidance if behavior
   changes persistently.

Planning should carve this into independently shippable phases rather than one
mega-PR:

1. Snapshot schema, scoped public-ready uniqueness, manifest constants, parameter
   preset matrix, repository, and retention tests.
2. Worker refresh handler and fixture-backed snapshot generation.
3. API snapshot read switch and no-compute-on-miss tests.
4. MCP snapshot read switch, diagnostics, search, and smoke updates.
5. External provider budgets and job result modes.
6. LLM config hardening and documentation.

Rollback:

- Schema migration should be additive.
- Public endpoints should tolerate no snapshot rows.
- Existing memoise-backed helper code should remain available to the worker.
- If snapshot refresh fails, public/MCP routes degrade with explicit snapshot error
  instead of computing synchronously.

## Test Strategy

API and worker:

- Unit tests for fingerprint generation and manifest status transitions.
- Unit tests for parameter preset canonicalization and unsupported-parameter
  rejection.
- Transaction-backed repository tests for snapshot insert, public-ready switch, stale
  detection, source mismatch, and the scoped uniqueness constraint allowing one
  public-ready row per `(analysis_type, parameter_hash)`.
- Worker handler tests with small fixture payloads.
- Endpoint tests that assert heavy analysis public routes do not call compute
  helpers when snapshots are missing.
- Endpoint tests that unsupported analysis parameters fail fast without computing.
- External proxy tests using mocked slow providers to verify timeout/degraded
  response behavior and no error caching.
- Job status tests for `result_mode = "summary"` and explicit full-result opt-in.
- Tests that removing public cache-hit LLM chaining is paired with worker/admin
  snapshot refresh LLM enqueue/status behavior.
- LLM config tests for env/config/default resolution, invalid model rejection, and
  deprecated/shut-down model handling.

MCP:

- Unit tests for snapshot-backed analysis repository reads.
- Tool tests for `snapshot_missing`, `snapshot_stale`, `needs_admin_initialization`,
  invalid global-correlation `gene`, `drop_diagonal`, and `triangle_only`.
- Search tests for exact identifiers, aliases, gene names, phrase tokens, disease
  crossrefs, phenotype synonyms, zero-result diagnostics, and deterministic ranking
  order.
- Publication context test for per-link `publication_type` and optional deduped
  envelope summary.
- Null serialization regression tests.
- Extend `api/scripts/mcp-smoke.R` for benchmark search/cache diagnostics.

Frontend, only where touched:

- Typed API client tests if external or analysis client boundaries change.
- Component tests for degraded analysis/external states if response shape changes.
- Type check: `cd app && npm run type-check`.

Deterministic verification gates:

- `make code-quality-audit`
- focused API test files first
- `make test-api-fast`
- `make test-mcp-smoke`
- `cd app && npm run type-check` if frontend clients/components are touched
- `make pre-commit` for normal handoff
- `make ci-local` if the implementation spans API, worker, DB, MCP, and frontend
  behavior

## Success Criteria

- Cheap health/auth/entity/public/MCP routes are not blocked by cold analysis,
  slow external providers, broad job result payloads, or Gemini configuration
  failures.
- Public derived-analysis endpoints and MCP tools read explicit public-ready
  snapshots or return actionable recoverable errors.
- Unsupported analysis parameters fail fast with `unsupported_parameter` instead
  of causing cold compute or ambiguous cache misses.
- Snapshot manifests expose stable schema versions, fingerprints, source versions,
  parameters, counts, and public readiness state.
- At most one snapshot is public-ready per `(analysis_type, parameter_hash)`.
- MCP search resolves benchmark phrase use cases better than exact-ish search and
  reports useful zero-result diagnostics.
- MCP analysis cache diagnostics distinguish missing/stale/uninitialized states.
- MCP remains read-only and cache/snapshot-hit-only for analysis data.
- Public request paths do not trigger Gemini/LLM generation; cluster-summary
  generation is owned by worker/admin snapshot refresh policy.
- Gemini model configuration is centralized, deployment-configurable, validated,
  and free of stale hardcoded preview-model assumptions.
- Tests cover the new behavior, and code-quality/file-size checks remain within
  SysNDD expectations.
