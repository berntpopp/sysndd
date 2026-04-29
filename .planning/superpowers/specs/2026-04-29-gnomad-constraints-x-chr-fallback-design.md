# gnomAD constraints — chrX/Y/M fallback (design)

Date: 2026-04-29
Status: Approved
Related: filter-pushdown audit (`.planning/perf/2026-04-27-filter-pushdown-audit.md`) — separate planning track

## 1. Problem

`non_alt_loci_set.gnomad_constraints` is `NULL` for **every gene on chrX, chrY, and chrM**. This omits ~700 protein-coding genes including major NDD genes (FMR1, MECP2, CDKL5, ATRX, KDM5C, HUWE1, OFD1, PHF6, SMC1A, IL1RAPL1, RPS6KA3, DMD, HPRT1, ARX, MED12, …). User-visible effect: `GeneConstraintCard` shows nothing on these gene pages.

Root cause (verified by `awk` on the v4.1 TSV): the gnomAD bulk constraint metrics TSV at `https://storage.googleapis.com/gcp-public-data--gnomad/release/4.1/constraint/gnomad.v4.1.constraint_metrics.tsv` only contains rows for chr1–chr22. There are zero rows for chrX, chrY, or chrM. This is an upstream gnomAD limitation — the constraint TSV is autosomes-only.

The gnomAD GraphQL API at `https://gnomad.broadinstitute.org/api` *does* return constraint data for these genes (verified live for MECP2 and CDKL5). gnomAD computes one set of constraint values per release (currently v4.1, October 2024); the values are precomputed and frozen until the next release.

## 2. Goal

Backfill `gnomad_constraints` for every gene that exists in HGNC but is missing from the bulk TSV, by querying the gnomAD GraphQL API as a fallback. Make this transparent to operators: clicking the existing "Update HGNC Data" button must be the only step required.

Success criteria:
- After one HGNC update job, MECP2 and CDKL5 (and the other ~700 chrX/Y/M HGNC genes that gnomAD knows about) have non-NULL `gnomad_constraints`.
- The HGNC update job's wall-clock time grows by less than 30 seconds.
- A gnomAD GraphQL outage during the fallback step does not fail the HGNC update; it logs a warning and writes NULL, matching today's behaviour.
- No new admin UI, no new endpoint, no new button.

Non-goals:
- A separate "refresh gnomAD only" admin endpoint. (May be added later if operational experience shows a need; explicitly out of scope here.)
- Per-gene live-fallback inside `GeneConstraintCard` at page-render time.
- Refreshing the live constraint values between gnomAD releases (they don't change).

## 3. Approach (chosen: Approach 3 from brainstorm)

A new public helper `fetch_gnomad_constraints_batch(symbols)` returns a named character vector of JSON-or-NA aligned to the input. Internally it consults the existing `cache_static` disk cache per symbol (30-day TTL), batches cache misses 25-at-a-time through aliased GraphQL queries, dispatches batches concurrently with a small worker pool, and writes results back to cache.

`enrich_gnomad_constraints` (Step 7 of `update_process_hgnc_data`) calls it once after the bulk join, with the symbols of all rows that came out of the bulk path with NA. It replaces those NA values, leaves everything else alone, and reports recovered/failed counts via `progress_fn` and the job result.

### 3.1 New module

File: `api/functions/external-proxy-gnomad-batch.R`

Public function:

```r
fetch_gnomad_constraints_batch <- function(
  symbols,
  max_concurrency = 5L,
  cache = cache_static
) -> named character vector
```

- `symbols`: character vector of HGNC gene symbols. May be empty.
- Returns a character vector of the same length, names equal to `symbols`. Each element is either:
  - a JSON string in the same shape the bulk path emits (19 fields: `pLI`, `oe_lof`, `oe_lof_lower`, `oe_lof_upper`, `oe_mis`, `oe_mis_lower`, `oe_mis_upper`, `oe_syn`, `oe_syn_lower`, `oe_syn_upper`, `exp_lof`, `obs_lof`, `exp_mis`, `obs_mis`, `exp_syn`, `obs_syn`, `lof_z`, `mis_z`, `syn_z`); or
  - `NA_character_` if the gene is unknown to gnomAD, the GraphQL response was missing constraint data, or the batch transport failed.

Private helpers (also in the new file):

- `.build_aliased_constraint_query(symbols)` — pure string builder; one alias per input symbol.
- `.parse_batched_constraint_response(parsed_json, symbols)` — pure mapper; takes an already-parsed GraphQL response and the symbols in the original batch order, returns a named character vector of JSON-or-NA. Handles partial nulls (gene exists but `gnomad_constraint` field is null), embedded "Gene not found" GraphQL errors, and unexpected response shapes.
- `.fetch_gnomad_constraints_chunk(symbols)` — fires one HTTP request for ≤25 symbols, returns the named character vector for that chunk. Wraps the network call in `tryCatch`; on failure returns all-NA for the chunk.

### 3.2 Caching

- Cache backend: existing `cache_static` (filesystem, 30-day TTL). Same store the per-user `fetch_gnomad_constraints_mem` already uses, so a user lookup that already cached MECP2 will give us a cache hit during the bulk pipeline, and vice versa.
- Cache key: `gnomad_constraint_v1::<UPPERCASE_SYMBOL>`. The `_v1` prefix lets us bump and invalidate cleanly when the JSON shape changes.
- Cache value: the JSON string we'd return, OR a sentinel for NA. Sentinel choice: literal string `"__GNOMAD_NA__"`. We chose a sentinel rather than caching `NA_character_` directly because the `cachem`/`memoise` filesystem cache treats `NULL` and missing key identically, and we need to distinguish "we asked, gnomAD said no" from "we never asked". The sentinel is decoded back to `NA_character_` on read.
- The cache is consulted on every call. Misses are batched. Successful and "Gene not found" results are both written back. Batches that failed transport-level write **nothing** back (so a transient gnomAD outage doesn't poison the cache for 30 days).

### 3.3 Network layer

- Endpoint: `https://gnomad.broadinstitute.org/api?raw` (the `?raw` flag bypasses gnomAD's GraphiQL HTML wrapper that would otherwise be served when the Accept header doesn't survive a proxy).
- Method: POST with `Content-Type: application/json`.
- Body: `{"query": "query Batch { g0: gene(gene_symbol: \"X\", reference_genome: GRCh38) { ... } g1: ... }"}`.
- Concurrency: `httr2::reqs_perform_parallel(reqs, pool = max_concurrency, on_error = "continue")`. Pool default 5 — measured to deliver ~3.5 s for 700 genes; gnomAD tolerated bursts of 20 without rate-limiting in benchmarks, so 5 is well-mannered.
- Per-request retry: `httr2::req_retry(max_tries = 3, max_seconds = 30, is_transient = ~ resp_status(.x) %in% c(429, 503, 504))`.
- Timeout: 30 s per request.
- No throttle on this code path. The existing `EXTERNAL_API_THROTTLE$gnomad` (10 req/min) is intentionally bypassed because that throttle was sized for one-at-a-time per-user calls. The pool ceiling is the rate limiter here.

### 3.4 Pipeline integration

Edit: `api/functions/hgnc-enrichment-gnomad.R`, function `enrich_gnomad_constraints`.

After the existing bulk-join (current line 195: `hgnc_tibble$gnomad_constraints <- unname(constraint_lookup[toupper(hgnc_tibble$symbol)])`):

1. Identify rows where `gnomad_constraints` is NA. Skip the fallback entirely if zero rows are missing.
2. Bump `enrich_gnomad_constraints`'s internal `total_steps` from 3 to 4. Call `progress_fn("gnomad-fallback", "gnomAD: querying API for X missing genes", current = 4, total = 4)` where `X` is the missing-row count. (Steps 1–3 remain the bulk download / parse / join, unchanged.)
3. `fallback_results <- fetch_gnomad_constraints_batch(missing_symbols)`.
4. Replace NA values where `fallback_results` came back non-NA. Leave the rest alone.
5. Log: `[gnomAD enrichment] Fallback recovered M / N missing genes (K still NA)`, where `M = sum(!is.na(fallback_results))`, `K = N - M`.
6. The public function returns the same tibble shape it returns today. Metrics (M, K) are surfaced via the metrics wrapper in §3.6 — see there.

The function silently no-ops when `length(missing_symbols) == 0` (e.g. a future gnomAD release that ships X-chr in the bulk TSV).

### 3.5 Step labelling

`update_process_hgnc_data` currently reports Step 7/9 as "gnomAD constraint enrichment". We extend the running message inside `enrich_gnomad_constraints` to report the substep — the outer step counter is unchanged. The job result's progress payload exposes both substeps in order:

- `step_id = "gnomad"`, label `"gnomAD: parsing TSV"`
- `step_id = "gnomad"`, label `"gnomAD: joining data"`
- `step_id = "gnomad-fallback"`, label `"gnomAD: querying API for X missing genes"` (only emitted if `X > 0`)

### 3.6 Job result metrics

Edit: `.async_job_run_hgnc_update` in `api/functions/async-job-handlers.R`. Augment its return value (currently `list(rows_processed, columns_written, db_write_completed_at)`) with two new keys:

- `gnomad_fallback_recovered`: integer count, M from §3.4 step 5
- `gnomad_fallback_unresolved`: integer count, K from §3.4 step 5

These flow into `jobs.result` (the durable job table) and surface in the job-history detail view automatically. They're informational, not asserted on.

To pass the counts from `enrich_gnomad_constraints` up to the job handler: return a list `list(tibble = …, fallback_recovered = M, fallback_unresolved = K)` from a new internal companion `enrich_gnomad_constraints_with_metrics` that wraps the existing function. The existing public `enrich_gnomad_constraints` keeps its (tibble-in, tibble-out) signature. The async handler calls the metrics-returning variant.

Naming note: "unresolved" rather than "failed" because the count includes both transport failures (transient) and clean negatives (gene genuinely unknown to gnomAD — most cases). The cache distinguishes the two internally so re-running won't repeatedly hit gnomAD for confirmed-unknown symbols.

### 3.7 UI copy fix

Edit: `app/src/components/annotations/HgncAnnotationsCard.vue` line 30. Replace:

```
Downloading HGNC data and enriching with gnomAD constraints (this may take hours on first run)...
```

with:

```
Downloading HGNC data; enriching with gnomAD constraints, AlphaFold IDs, and Ensembl coordinates. Typically a few minutes.
```

(The "may take hours on first run" claim was true before the v11.x bulk-TSV switch; it has been stale ever since.) No structural changes to the card.

## 4. Data flow

```
update_process_hgnc_data (mirai async job)
└── Step 7/9: enrich_gnomad_constraints(tibble, progress_fn)
    ├── 7a: download TSV                 (~4.4 s,  17 487 autosomal MANE-Select rows)
    ├── 7b: bulk left-join by symbol     (~0 s)
    ├── 7c: identify N missing rows
    └── 7d: fetch_gnomad_constraints_batch(missing_symbols)   ⬅ new
            ├── per-symbol cache_static lookup     (typically 0 hits on first run, 100% on subsequent runs within 30 days)
            ├── chunk misses to ≤25 per batch
            ├── reqs_perform_parallel(pool = 5)    POST {?raw} with aliased GraphQL
            ├── per-batch parse → named char vec
            ├── write each result back to cache
            └── return aligned named char vec
       ↓
       merge non-NA fallback values into tibble; report counts
```

## 5. Error handling

| Scenario | Behaviour |
|---|---|
| HGNC has zero NA rows after bulk | Fallback step is a no-op. Counts both 0. |
| GraphQL says "Gene not found" for one symbol in a batch | That symbol gets `NA_character_`. Cached as NA-sentinel. Other 24 in batch unaffected. |
| GraphQL response has gene but `gnomad_constraint` is null (non-coding, etc.) | Same as above — NA, cached as NA-sentinel. |
| HTTP 429 / 503 / 504 on a batch | `req_retry` handles up to 3 attempts. If all fail → batch-level failure (next row). |
| Non-retryable HTTP error (e.g. 400 from a malformed query) | Batch-level failure. |
| Network outage / DNS failure / TLS error | Batch-level failure. |
| Batch-level failure | All ≤25 symbols in that batch return `NA_character_`. **Not** written to cache. Counted in `gnomad_fallback_unresolved`. Single warning log line per batch with the count and the first error message. |
| Total fallback unavailability (every batch fails) | The function still returns; HGNC pipeline still completes. `gnomad_fallback_recovered = 0`, `gnomad_fallback_unresolved = N`. One high-visibility log line. **No regression vs today** — today these genes are already NA. |
| `cache_static` write failure | Logged at debug, otherwise ignored — affected gene's value still flows back to caller. |

## 6. Testing

### 6.1 Unit (no network)

`api/tests/testthat/test-unit-gnomad-batch.R` (new file):

1. `.build_aliased_constraint_query` produces well-formed GraphQL with one alias per input. Empty input → empty query body. Symbols with apostrophes/special chars are rejected/escaped (or, more cleanly, the function asserts via `validate_gene_symbol` on each input and stops with a clear error). Reuses `validate_gene_symbol` from `external-proxy-functions.R` for consistency.
2. `.parse_batched_constraint_response` covers:
   - All-success — every alias has a constraint object → all JSON.
   - Partial null — alias `g3` has `gene` but `gnomad_constraint = null` → that symbol NA, others OK.
   - Embedded GraphQL error at one alias path → that symbol NA, others OK.
   - Top-level GraphQL error (whole response has `errors` and `data` partial) → returned NA only for the failing aliases.
   - Empty input → empty named vector.
3. `fetch_gnomad_constraints_batch` with `httr2::with_mocked_responses`:
   - Cache miss + successful 200 → request sent, cache populated, NA-sentinel decoded correctly.
   - Cache hit on every symbol → no request sent.
   - Mixed cache state (10 cached, 15 uncached) → exactly one batch fired with 15 aliases.
   - 25-symbol cap respected — given 60 input symbols, exactly three requests (25 + 25 + 10).
   - Transport failure → all symbols in failing batch returned as NA, NOT cached.
   - "Gene not found" → returned NA, IS cached as NA-sentinel.

### 6.2 Pipeline integration (no network)

Extend `api/tests/testthat/test-unit-helper-functions.R` (or new `test-unit-gnomad-enrichment.R`):

- Mock `fetch_gnomad_constraints_batch` to return a fixed map for two symbols.
- Hand `enrich_gnomad_constraints` a tibble where one row has a symbol present in the bulk fixture (autosomal) and two rows have symbols absent (chrX-style).
- Assert: bulk rows untouched; the two NA rows are now populated with the mocked JSON; the function logs a "Fallback recovered 2 / 2" line.

### 6.3 Live integration (env-gated)

`api/tests/testthat/test-integration-gnomad-batch.R`:

```r
testthat::skip_if_not(Sys.getenv("RUN_GNOMAD_INTEGRATION") == "1")
testthat::skip_if_offline()
```

- `fetch_gnomad_constraints_batch(c("MECP2","CDKL5","FMR1"))` returns three non-NA JSON strings.
- `fetch_gnomad_constraints_batch(c("DEFINITELY_NOT_A_REAL_GENE_XYZ"))` returns `NA_character_` for that one symbol.
- 28-batch real run (using a list of known X-linked symbols) completes in under 30 s with `max_concurrency = 5`.

Default CI lane keeps the env var unset and skips. Run locally before each release.

### 6.4 Job-handler test

Extend `api/tests/testthat/test-unit-async-job-service.R` (or wherever `.async_job_run_hgnc_update` is currently tested) to assert the result list contains `gnomad_fallback_recovered` and `gnomad_fallback_unresolved` integer fields when the fallback executed, and zeros when there were no missing rows.

### 6.5 Frontend

`app/src/components/annotations/__tests__/HgncAnnotationsCard.spec.ts` — assert the idle message text matches the new copy.

## 7. Rollout

1. Ship the change in v11.4.
2. After deploy, an admin runs the existing "Update HGNC Data" button once. The Step-7 progress shows "gnomAD: querying API for ~700 missing genes" briefly; total job time grows by single-digit seconds.
3. After the job completes, `non_alt_loci_set.gnomad_constraints` is populated for chrX/Y/M genes that gnomAD knows about. `GeneConstraintCard` on `/Genes/MECP2`, `/Genes/CDKL5`, etc. now renders constraint data instead of being hidden.
4. Job history shows `gnomad_fallback_recovered: <N>` / `gnomad_fallback_unresolved: <K>`. If `K > 0`, admin can re-run the HGNC update later; the per-symbol cache means previously-recovered genes won't re-hit the network.

No DB migration. No schema change. No new endpoint. The same change covers backfilling current prod and any future runs.

## 8. Out-of-scope (deliberate)

- A surgical `PUT /api/admin/refresh_gnomad_fallback` endpoint. The full HGNC update is the right granularity given how often constraints actually change (i.e. on gnomAD releases, ~yearly). If operational experience shows we need a finer-grained tool, it's a small follow-up.
- Per-card live fallback in `GeneConstraintCard.vue`. Splitting the data source between bulk and live invites consistency drift; the right layer is the pipeline.
- Refreshing the live values between gnomAD releases. The values are precomputed and frozen until the next release.
- Adding the same fallback to ClinVar variants (`fetch_gnomad_clinvar_variants`). Different data, different shape, different consumers — separate problem.

## 9. References

- Bulk TSV (autosomal-only): `https://storage.googleapis.com/gcp-public-data--gnomad/release/4.1/constraint/gnomad.v4.1.constraint_metrics.tsv`
- GraphQL endpoint: `https://gnomad.broadinstitute.org/api` (use `?raw` to bypass the GraphiQL HTML wrapper)
- Existing per-gene proxy: `api/functions/external-proxy-gnomad.R` (`fetch_gnomad_constraints`, `_mem`)
- Existing pipeline: `api/functions/hgnc-enrichment-gnomad.R` (`enrich_gnomad_constraints`)
- Existing pipeline driver: `api/functions/hgnc-functions.R` (`update_process_hgnc_data`, Step 7/9)
- Existing async job: `api/functions/async-job-handlers.R` (`.async_job_run_hgnc_update`)
- Existing admin UI: `app/src/components/annotations/HgncAnnotationsCard.vue`, `app/src/views/admin/ManageAnnotations.vue`
- Bench data and approach selection: this document, §3
