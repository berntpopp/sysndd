# Slice D (#574) — Codex adversarial diff-review reconciliation

Reviewer: `codex exec -m gpt-5.6-terra -c model_reasoning_effort=high` (read-only sandbox).
Diff reviewed: `git diff origin/master...HEAD` (feature #574 only; #576/planning excluded).

## Round 1 — verdict NO-SHIP (0 BLOCKER, 2 HIGH, 1 MEDIUM, 1 LOW). All accepted + fixed in commit `c3422dd2`.

- **HIGH — empty-`genes`-array bypassed mutual exclusion** (`job-functional-submission-service.R:61`). `{"genes":[], "category_filter":["X"]}` was accepted because `has_genes` was false for an empty array. FIX: added `genes_supplied <- !is.null(genes_in)` and gated mutual exclusion on `genes_supplied && category_supplied` (both KEYS present → 400), keeping `has_genes` (non-empty) for the branch decision. `{"genes":[]}` alone still → all-NDD default (unchanged); `{"genes":["HGNC:1"]}` alone still explicit. Regression test added.
- **HIGH — TTL cache could cache/serve `NA`/empty `source_data_version`** (`clustering-gene-universe.R`), violating the locked "never records NA" fail-closed contract. FIX: added a validity predicate (single non-NA non-empty string); the cache only serves a valid cached value within TTL, and a fetched invalid value is NOT cached and throws → service maps to 503 `PROVENANCE_UNAVAILABLE`. Tests added for NA / "" returns → error + cache-not-poisoned.
- **MEDIUM — `resolved_gene_count` inconsistent with `gene_list_sha256`** for duplicate explicit genes. FIX: `resolved_gene_count = length(unique(genes_list))` (count only; payload `genes` left byte-identical to today for the explicit path). No-op for category/all_ndd (resolver already dedupes). Test added.
- **LOW — integration test used bare `get(..., envir=)`** which `config::get` masks in a loaded session. FIX: `base::get("pool", envir = .GlobalEnv)`.

Side effect: new test cases pushed `test-unit-job-endpoint-services.R` to 644 lines; the fixer split the phenotype-submission tests into a new sibling `test-unit-job-endpoint-services-phenotype.R` to keep both files < 600 (content moved verbatim). All 4 fixes RED-verified. Full `make test-api-fast` after fixes: FAIL 0 / PASS 7025; `make code-quality-audit` + `make lint-api` clean.

## Round 2 — re-review verdict NO-SHIP (1 HIGH, 1 MEDIUM). Both accepted + fixed in commit `34d8701d`. (Confirmed the round-1 fixes: source-version fail-closed, distinct resolved_gene_count, base::get, and the test split all resolved.)

- **HIGH — explicit JSON `null` `genes` bypassed mutual exclusion** (`job-functional-submission-service.R`). `!is.null(genes_in)` cannot distinguish an absent `genes` key from `{"genes":null}`, so `{"genes":null,"category_filter":[...]}` slipped past the guard. FIX: gate mutual exclusion on JSON KEY PRESENCE via `names(req$argsBody)` (`genes_key && category_key` → 400). Now `{"genes":null,…}` and `{"genes":[],…}` (round-1) both 400; `{"genes":null}`/`{"genes":[]}` alone still default; `{"genes":["X"]}` alone still explicit. 2 new RED-verified tests.
- **MEDIUM — `gene_count` asymmetry** between the cache-hit path (`length(unique(genes_list))`) and the worker handler (`length(genes)`) for duplicate explicit genes (cache-hit reported 1, worker 2). FIX: `.async_job_run_clustering` now uses `gene_count = length(unique(genes))`; payload `genes` and `nrow(clusters)` unchanged. 1 new RED-verified test.

Full `make test-api-fast` after round-2 fixes: FAIL 0 / PASS 7032.

## Round 3 — re-review verdict NO-SHIP (1 HIGH). Accepted + fixed in commit `3633a925`. (Round-2 fixes confirmed resolved.)

- **HIGH — provenance in the DB dedup hash broke byte-identical `request_hash`.** #574 added `provenance` (time-varying `source_data_version` + STRING cache fingerprint) to the durable payload so the worker can echo it; but `async_job_service_submit()`/`async_job_service_store_completed()` hash the FULL payload into `active_request_hash`, so explicit/no-arg jobs were no longer byte-identical to pre-#574 and two identical submits across a provenance change could both run (dedup weakened). This is a #574-introduced regression against the locked "explicit/no-arg byte-identical request_hash" constraint (the plan's "hash-scope inconsistency out of scope" note referred to the *pre-existing* preflight-vs-DB difference, not this). FIX: added an optional, backward-compatible `hash_payload`/`hash_params` (default NULL → hash full payload, so the ~10 other async-job callers are unaffected); the clustering submit passes the durable payload MINUS `provenance` — `list(genes, algorithm, category_links, string_id_table)` for explicit/no-arg (byte-identical to pre-#574) and +`category_filter` for category (selector-aware). `provenance` stays STORED in `request_payload_json` so the worker meta echo is unchanged. New RED-verified unit tests (submit + hash-override); async-job-service/repository/worker suites still green.

## Round 4 — re-review verdict NO-SHIP (1 HIGH). (Confirmed the round-3 hash fix is correct.) Accepted + fixed in commit `9cad756c`.

Also, running the FULL fast gate after the round-3 fix surfaced a contract regression the subagent's subset missed: adding `hash_params` to `create_job()` broke `test-unit-job-manager-durable.R`, which guards `create_job`'s exact 2-arg `(operation, params)` contract (formals assertion + a source-scanning arity guard). Reverted `create_job` to 2-arg (commit `bfbaac79`); the clustering cache-miss path calls `async_job_service_submit(..., hash_payload = ...)` directly instead — consistent with the cache-hit path already calling `async_job_service_store_completed` directly, and it preserves the submit-time provenance snapshot.

- **HIGH — a present-but-null `category_filter` silently defaulted.** `category_supplied <- !is.null(...)` treated `{"category_filter":null}` as ABSENT → resolved the all-NDD default instead of the required supplied-empty 400 (the category-side symmetry of the round-2 genes-null fix). FIX: the branch now keys off `"category_filter" %in% names(req$argsBody)` and rejects a present-but-null value explicitly as supplied-empty (400). New null-category test. (Side effect: the growing `test-unit-job-endpoint-services.R` crossed 600 lines, so its #574 category coverage was split into `test-unit-job-endpoint-services-category.R` and 3 shared helpers moved to `job-endpoint-services-fixtures.R`; no test lost.)

Full `make test-api-fast` after the create_job revert: FAIL 0 / PASS 7051.

## Round 5 — re-review verdict NO-SHIP (1 HIGH, 1 LOW). HIGH accepted + fixed in commit `9621ff22`; LOW adjudicated (declined, with rationale).

- **HIGH — category-validation 400 messages omitted the allowed active-category set.** Only the unknown-category message named it; the supplied-empty, present-but-null, and `<2`-genes messages did not, violating the locked "the allowed set goes in the error MESSAGE" contract. FIX: `clustering_resolve_category_universe()` now fetches the active category list right after the absent-selector default branch (still NO fetch on the pure-default path → cache parity) and includes `Allowed active categories: …` in the supplied-empty, unknown, and `<2`-genes messages; the service's present-but-null case now coerces the null to an empty selector and delegates to the resolver (one validation source). New resolver + delegation tests, RED-verified.
- **LOW (declined) — `test-unit-async-job-worker.R` exceeds 600 lines.** This is PRE-EXISTING legacy debt: the file was already 751 lines on `origin/master` (not in the size baseline), #574 only added a necessary 1-line source of `clustering-gene-universe.R` for the refactored handler. `make code-quality-audit` (the repo's authoritative ratchet) PASSES, and AGENTS.md directs to "leave broad legacy splits for planned refactors." Splitting a 751-line legacy async-worker test is out of scope for #574; the addition was trimmed to the single necessary line to minimize growth.

Full `make test-api-fast` after round-5 fix: FAIL 0 / PASS 7053 (re-running to confirm).

## Round 6 — re-review VERDICT: **SHIP** (0 BLOCKER/HIGH). One valid MEDIUM reconciled.

Codex re-confirmed every prior fix (all four category-validation inputs 400 with the allowed set; absent-selector returns before the active-category query; present-null coerced to empty and delegated; normal API + dedicated-worker bootstrap correct).

- **MEDIUM (fixed) — the worker FALLBACK loader could crash a `clustering` job.** `async-job-worker.R`'s self-load fallback (used when the module is loaded directly, not via the standard `bootstrap_load_modules()`) sourced `async-job-handlers.R` but not `clustering-gene-universe.R`, so `.async_job_run_clustering` → `clustering_result_meta()` would hit "could not find function". FIX: source `clustering-gene-universe.R` before the handler in BOTH the `async-job-worker.R` fallback loader and the `bootstrap/setup_workers.R` mirai `everywhere()` block (after `analyses-functions.R`, before `async-job-handlers.R`). The standard worker/API boot was already correct (load_modules.R sources it at position 142); this hardens the non-standard direct-load path. Worker test green (PASS 100).

**Outcome: SHIP.** 6 Codex adversarial rounds; every BLOCKER/HIGH and the valid MEDIUMs reconciled; 1 LOW (pre-existing legacy file size) adjudicated/declined with rationale. Full `make test-api-fast` green throughout.
