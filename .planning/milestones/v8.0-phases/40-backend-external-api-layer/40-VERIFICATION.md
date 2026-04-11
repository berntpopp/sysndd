---
phase: 40-backend-external-api-layer
verified: 2026-01-27T21:30:00Z
status: passed
score: 12/12 must-haves verified
re_verification: false
---

# Phase 40: Backend External API Layer Verification Report

**Phase Goal:** Users can access gnomAD, UniProt, Ensembl, AlphaFold, and MGI/RGD data through cached R/Plumber endpoints with rate limiting and error isolation

**Verified:** 2026-01-27T21:30:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Shared proxy infrastructure exists with per-source cache backends, retry logic, and rate limiting | ✓ VERIFIED | `external-proxy-functions.R` (247 lines) exports 3 cache backends (cache_static 30d, cache_stable 14d, cache_dynamic 7d), EXTERNAL_API_THROTTLE config for 6 APIs, make_external_request() with req_retry/req_throttle/req_timeout |
| 2 | gnomAD GraphQL proxy returns constraint scores and ClinVar variants | ✓ VERIFIED | `external-proxy-gnomad.R` (327 lines) implements fetch_gnomad_constraints() and fetch_gnomad_clinvar_variants() with GraphQL queries to gnomAD v4 API, memoised wrappers with cache_static (30d) and cache_dynamic (7d) |
| 3 | UniProt REST proxy returns protein domains with two-step lookup | ✓ VERIFIED | `external-proxy-uniprot.R` (211 lines) implements fetch_uniprot_domains() with symbol→accession→features lookup, filters to 18 domain types, memoised with cache_stable (14d) |
| 4 | Ensembl REST proxy returns gene structure with canonical transcript exons | ✓ VERIFIED | `external-proxy-ensembl.R` (213 lines) implements fetch_ensembl_gene_structure() with symbol→gene_id→structure lookup, extracts canonical transcript (is_canonical=1), memoised with cache_stable (14d) |
| 5 | AlphaFold proxy returns 3D structure metadata and file URLs | ✓ VERIFIED | `external-proxy-alphafold.R` (170 lines) implements fetch_alphafold_structure() with UniProt accession→AlphaFold metadata lookup, returns PDB/CIF/BCIF URLs, memoised with cache_static (30d) |
| 6 | MGI proxy returns mouse phenotype data with defensive error handling | ✓ VERIFIED | `external-proxy-mgi.R` (203 lines) implements fetch_mgi_phenotypes() with defensive parsing (returns found=FALSE on unexpected format), memoised with cache_stable (14d) |
| 7 | RGD proxy returns rat phenotype data with human-to-rat ortholog lookup | ✓ VERIFIED | `external-proxy-rgd.R` (260 lines) implements fetch_rgd_phenotypes() with human→rat ortholog lookup or direct rat search, defensive parsing, memoised with cache_stable (14d) |
| 8 | Individual proxy endpoints exist at /api/external/{source}/{type}/{symbol} | ✓ VERIFIED | `external_endpoints.R` has 7 per-source GET endpoints: gnomad/constraints, gnomad/variants, uniprot/domains, ensembl/structure, alphafold/structure, mgi/phenotypes, rgd/phenotypes (lines 61-458) |
| 9 | Combined aggregation endpoint at /api/external/gene/{symbol} returns all sources with error isolation | ✓ VERIFIED | `external_endpoints.R` line 460-545: GET gene/<symbol> endpoint with tryCatch per source, returns partial data when some sources fail, returns 503 only when ALL sources fail |
| 10 | When one external API fails, other sources still return data | ✓ VERIFIED | Aggregation endpoint lines 506-527: tryCatch wraps each source fetch, errors collected separately, successful sources preserved in results$sources |
| 11 | All external proxy endpoints are publicly accessible without authentication | ✓ VERIFIED | `middleware.R` lines 40-47: AUTH_ALLOWLIST includes all 8 external paths (/api/external/gnomad/constraints, etc.) |
| 12 | Error responses follow RFC 9457 format with source identification | ✓ VERIFIED | create_external_error() in external-proxy-functions.R lines 196-211 returns {type, title, status, detail, source, instance} structure matching RFC 9457 |

**Score:** 12/12 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `api/functions/external-proxy-functions.R` | Shared proxy helpers: make_external_request, create_external_error, cache backends, throttle configs | ✓ VERIFIED | 247 lines, exports cache_static/stable/dynamic, EXTERNAL_API_THROTTLE (6 APIs), make_external_request (httr2 with req_retry/req_throttle/req_timeout), create_external_error (RFC 9457), validate_gene_symbol |
| `api/functions/external-proxy-gnomad.R` | fetch_gnomad_constraints(), fetch_gnomad_clinvar_variants() + memoised versions | ✓ VERIFIED | 327 lines, 2 functions with GraphQL queries, memoised with cache_static (constraints) and cache_dynamic (ClinVar) |
| `api/functions/external-proxy-uniprot.R` | fetch_uniprot_domains() + memoised version | ✓ VERIFIED | 211 lines, two-step lookup (symbol→accession→features), filters to 18 domain types, memoised with cache_stable |
| `api/functions/external-proxy-ensembl.R` | fetch_ensembl_gene_structure() + memoised version | ✓ VERIFIED | 213 lines, two-step lookup (symbol→gene_id→structure), extracts canonical transcript exons, memoised with cache_stable |
| `api/functions/external-proxy-alphafold.R` | fetch_alphafold_structure() + memoised version | ✓ VERIFIED | 170 lines, two-step lookup (gene→UniProt accession→AlphaFold metadata), returns structure URLs, memoised with cache_static |
| `api/functions/external-proxy-mgi.R` | fetch_mgi_phenotypes() + memoised version | ✓ VERIFIED | 203 lines, defensive parsing for undocumented MGI API, memoised with cache_stable |
| `api/functions/external-proxy-rgd.R` | fetch_rgd_phenotypes() + memoised version | ✓ VERIFIED | 260 lines, human→rat ortholog lookup with fallback, defensive parsing, memoised with cache_stable |
| `api/endpoints/external_endpoints.R` | 8 Plumber endpoints: 7 per-source + 1 aggregation | ✓ VERIFIED | 549 lines total, 7 per-source GET endpoints (lines 61-458), 1 aggregation GET endpoint (lines 460-545), all with validation + RFC 9457 error responses |
| `api/core/middleware.R` | AUTH_ALLOWLIST with external endpoint paths | ✓ VERIFIED | Lines 40-47: 8 external paths added to AUTH_ALLOWLIST |
| `api/start_sysndd_api.R` | Sources external-proxy-functions.R and loads ghql library | ✓ VERIFIED | Lines 63-64: library(httr2) + library(ghql), lines 129-135: sources all 7 external proxy files |
| `api/tests/testthat/test-external-proxy-functions.R` | Unit tests for external-proxy-functions.R | ✓ VERIFIED | 163 lines, tests validate_gene_symbol (6+ cases incl. injection), create_external_error (RFC 9457 format), cache backends (existence), EXTERNAL_API_THROTTLE (6 APIs) |
| `api/tests/testthat/test-external-proxy-endpoints.R` | Unit tests for proxy endpoint logic | ✓ VERIFIED | 324 lines, tests aggregation error isolation (partial data, all-fail, mixed scenarios), AUTH_ALLOWLIST (8 paths), RFC 9457 error formatting |
| `api/tests/testthat/helper-mock-apis.R` | Mock helpers for testing | ✓ VERIFIED | Lines 88-131: mock_gnomad_constraints_success, mock_source_not_found, mock_source_error |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| external-proxy-gnomad.R | EXTERNAL_API_THROTTLE$gnomad | Rate limiting config | ✓ WIRED | Lines 99, 239: req_throttle uses EXTERNAL_API_THROTTLE$gnomad (10 req/min) |
| external-proxy-gnomad.R | cache_static, cache_dynamic | Memoised wrappers | ✓ WIRED | Lines 308-311: fetch_gnomad_constraints_mem uses cache_static (30d), lines 324-327: fetch_gnomad_clinvar_variants_mem uses cache_dynamic (7d) |
| external-proxy-uniprot.R | make_external_request | HTTP request helper | ✓ WIRED | Lines 85-89: calls make_external_request with EXTERNAL_API_THROTTLE$uniprot |
| external-proxy-ensembl.R | make_external_request | HTTP request helper | ✓ WIRED | Lines 72-76: calls make_external_request with EXTERNAL_API_THROTTLE$ensembl |
| external-proxy-alphafold.R | make_external_request | HTTP request helper | ✓ WIRED | Lines 65-69, 100-104: calls make_external_request for UniProt and AlphaFold APIs |
| external-proxy-mgi.R | cache_stable | Memoised wrapper | ✓ WIRED | Lines 200-203: fetch_mgi_phenotypes_mem uses cache_stable (14d) |
| external-proxy-rgd.R | cache_stable | Memoised wrapper | ✓ WIRED | Lines 257-260: fetch_rgd_phenotypes_mem uses cache_stable (14d) |
| external_endpoints.R | fetch_gnomad_constraints_mem | Endpoint calls memoised function | ✓ WIRED | Line 88: calls fetch_gnomad_constraints_mem(symbol) |
| external_endpoints.R | fetch_gnomad_clinvar_variants_mem | Endpoint calls memoised function | ✓ WIRED | Line 145: calls fetch_gnomad_clinvar_variants_mem(symbol) |
| external_endpoints.R | fetch_uniprot_domains_mem | Endpoint calls memoised function | ✓ WIRED | Line 202: calls fetch_uniprot_domains_mem(symbol) |
| external_endpoints.R | fetch_ensembl_gene_structure_mem | Endpoint calls memoised function | ✓ WIRED | Line 259: calls fetch_ensembl_gene_structure_mem(symbol) |
| external_endpoints.R | fetch_alphafold_structure_mem | Endpoint calls memoised function | ✓ WIRED | Line 316: calls fetch_alphafold_structure_mem(symbol) |
| external_endpoints.R | fetch_mgi_phenotypes_mem | Endpoint calls memoised function | ✓ WIRED | Line 373: calls fetch_mgi_phenotypes_mem(symbol) |
| external_endpoints.R | fetch_rgd_phenotypes_mem | Endpoint calls memoised function | ✓ WIRED | Line 430: calls fetch_rgd_phenotypes_mem(symbol) |
| external_endpoints.R aggregation | Error isolation pattern | tryCatch per source | ✓ WIRED | Lines 508-512: each source wrapped in tryCatch, errors converted to RFC 9457 format, partial data returned on success |
| middleware.R | external_endpoints.R | AUTH_ALLOWLIST for public access | ✓ WIRED | Lines 40-47: all 8 external paths in AUTH_ALLOWLIST |
| start_sysndd_api.R | external-proxy-functions.R | Source statement | ✓ WIRED | Line 129: source("functions/external-proxy-functions.R", local = TRUE) |
| start_sysndd_api.R | All 6 proxy files | Source statements | ✓ WIRED | Lines 130-135: sources gnomad, uniprot, ensembl, alphafold, mgi, rgd proxy files |

### Requirements Coverage

| Requirement | Status | Supporting Evidence |
|-------------|--------|---------------------|
| PROXY-01: gnomAD GraphQL proxy for constraint scores and ClinVar variants | ✓ SATISFIED | external-proxy-gnomad.R implements both functions, external_endpoints.R exposes at /gnomad/constraints and /gnomad/variants |
| PROXY-02: UniProt REST proxy for protein domains and features | ✓ SATISFIED | external-proxy-uniprot.R implements fetch_uniprot_domains with feature filtering, external_endpoints.R exposes at /uniprot/domains |
| PROXY-03: Ensembl REST proxy for gene structure (exons, transcripts) | ✓ SATISFIED | external-proxy-ensembl.R implements fetch_ensembl_gene_structure with canonical transcript extraction, external_endpoints.R exposes at /ensembl/structure |
| PROXY-04: AlphaFold proxy for 3D structure metadata and file URLs | ✓ SATISFIED | external-proxy-alphafold.R implements fetch_alphafold_structure with PDB/CIF/BCIF URLs, external_endpoints.R exposes at /alphafold/structure |
| PROXY-05: MGI/JAX proxy for mouse phenotype data | ✓ SATISFIED | external-proxy-mgi.R implements fetch_mgi_phenotypes with defensive parsing, external_endpoints.R exposes at /mgi/phenotypes |
| PROXY-06: RGD proxy for rat phenotype data | ✓ SATISFIED | external-proxy-rgd.R implements fetch_rgd_phenotypes with ortholog lookup, external_endpoints.R exposes at /rgd/phenotypes |
| PROXY-07: Combined aggregation endpoint for single-request gene data | ✓ SATISFIED | external_endpoints.R line 460-545: GET /gene/<symbol> aggregates all 7 sources with error isolation |
| PROXY-08: Server-side disk caching with configurable TTL per source | ✓ SATISFIED | cache_static (30d), cache_stable (14d), cache_dynamic (7d) in external-proxy-functions.R, used by memoised wrappers |
| PROXY-09: httr2 retry logic with exponential backoff for external calls | ✓ SATISFIED | make_external_request() lines 116-121: req_retry with max_tries=5, backoff=~2^.x, transient errors (429/503/504) |
| PROXY-10: Rate limiting protection via req_throttle | ✓ SATISFIED | EXTERNAL_API_THROTTLE config for 6 APIs, make_external_request() line 113-115: req_throttle with capacity/fill_time_s |
| PROXY-11: External API endpoints are publicly accessible (AUTH_ALLOWLIST) | ✓ SATISFIED | middleware.R lines 40-47: all 8 external paths in AUTH_ALLOWLIST |
| PROXY-12: RFC 9457 error format with source identification | ✓ SATISFIED | create_external_error() returns {type, title, status, detail, source, instance} structure, used by all endpoints |

### Success Criteria Validation

| Criterion | Status | Evidence |
|-----------|--------|----------|
| 1. Developer can call `/api/external/gene/<symbol>` and receive cached data from all 5 sources (gnomAD, UniProt, Ensembl, AlphaFold, MGI) in single request | ✓ VERIFIED | Aggregation endpoint at /api/external/gene/<symbol> (lines 460-545) calls all 7 source functions (includes gnomAD constraints + ClinVar separately), uses memoised versions for caching |
| 2. Backend respects external API rate limits and never triggers blocking (req_throttle prevents >10 queries/min to gnomAD) | ✓ VERIFIED | EXTERNAL_API_THROTTLE$gnomad = {capacity: 10, fill_time_s: 60} enforced via req_throttle in gnomAD proxy (lines 98-100, 238-240) |
| 3. When one external API fails, other sources still return data (error isolation works) | ✓ VERIFIED | Aggregation endpoint lines 506-527: each source wrapped in tryCatch, errors collected in results$errors, successful sources preserved in results$sources, returns 200 with partial data |
| 4. Second request for same gene returns cached data instantly (no external API call made) | ✓ VERIFIED | All proxy functions have memoised wrappers (_mem suffix) using cachem disk cache backends with TTL (30d static, 14d stable, 7d dynamic) |
| 5. Error responses follow RFC 9457 format with source identification so frontend can display meaningful messages | ✓ VERIFIED | create_external_error() returns RFC 9457 structure with source field, used by all endpoints for 400/404/503 responses |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | N/A | N/A | N/A | All proxy functions are substantive implementations with proper error handling |

### Code Quality Assessment

**Strengths:**
- All 7 proxy files are substantive (170-327 lines each, total 1631 lines)
- Consistent error handling pattern across all functions (validate → fetch → error check → return)
- Proper use of httr2 modern patterns (req_retry, req_throttle, req_timeout)
- Memoised wrappers correctly specify cache backend per data volatility
- Comprehensive roxygen2 documentation on all exported functions
- Test coverage includes infrastructure (validation, caching, throttling) and endpoint logic (error isolation, aggregation)
- Mock helpers avoid network calls in tests

**No blockers or concerns found.**

---

_Verified: 2026-01-27T21:30:00Z_
_Verifier: Claude (gsd-verifier)_
