# Optimize Ensembl BioMart Connections

**Priority:** Low
**Category:** Performance
**Created:** 2026-01-28
**Revised:** 2026-04-11 — rewritten to match post-v4.0 code
**Status:** Backlog

## Background

The original version of this todo (2026-01-28) described severe redundancy in `api/functions/ensembl-functions.R`: both coordinate functions created a full hg19 + hg38 mart pair at the top, then re-created a third mart for the actual query. That was ~24 unnecessary `useMart()`/`useDataset()` round trips per HGNC update, plus a subtle variable-shadowing bug.

**All of that is fixed.** Phase 74 (v10.3) rewrote the file with:

- A single `create_ensembl_mart(reference = "hg38" | "hg19")` helper with per-reference mirror lists (`ENSEMBL_HG38_MIRRORS`, `ENSEMBL_HG19_MIRRORS`)
- Mirror failover across useast → uswest → asia → www.ensembl.org for hg38
- Exponential backoff retry with jitter (`sleep_with_backoff()`)
- Graceful degradation — returns `NA` for `bed_format` instead of crashing when all mirrors fail
- `safe_getBM()` wrapper with its own retry loop
- A `check_ensembl_connectivity()` pre-flight helper
- Comprehensive test coverage in `api/tests/testthat/test-external-ensembl.R`

No more variable shadowing, no more double mart construction. Reliability concerns from the original todo are **resolved**.

## Remaining inefficiency

Each of the three exported functions (`gene_coordinates_from_symbol`, `gene_coordinates_from_ensembl`, `gene_id_version_from_ensembl`) calls `create_ensembl_mart()` internally:

```r
# api/functions/ensembl-functions.R
gene_coordinates_from_symbol <- function(...) {
  ...
  mart <- create_ensembl_mart(reference = reference)   # line 226
  ...
}

gene_coordinates_from_ensembl <- function(...) {
  ...
  mart <- create_ensembl_mart(reference = reference)   # line 296
  ...
}

gene_id_version_from_ensembl <- function(...) {
  ...
  mart <- create_ensembl_mart(reference = reference)   # line 365
  ...
}
```

And `update_process_hgnc_data()` in `api/functions/hgnc-functions.R` calls the coordinate functions **four times in sequence**:

```r
# hgnc-functions.R:316, 324, 332, 340
gene_coordinates_from_ensembl(ensembl_gene_id)                   # creates hg19 mart
gene_coordinates_from_symbol(symbol)                             # creates hg19 mart AGAIN
gene_coordinates_from_ensembl(ensembl_gene_id, reference = "hg38")  # creates hg38 mart
gene_coordinates_from_symbol(symbol, reference = "hg38")            # creates hg38 mart AGAIN
```

**Cost:** 4 `create_ensembl_mart()` calls per HGNC update when only 2 marts are actually needed (one per reference genome). On a cold run with mirror retries, each call is 2–5 seconds, so ~4–10 seconds of redundant network time per HGNC update. Not a hot path — HGNC update is a manual admin action, not a per-request concern.

## Suggested fix (small)

Add an optional `mart = NULL` parameter to the three exported functions so callers can pass a pre-built mart and avoid re-creating it:

```r
gene_coordinates_from_symbol <- function(gene_symbols, reference = "hg19", mart = NULL) {
  ...
  if (is.null(mart)) {
    mart <- create_ensembl_mart(reference = reference)
  }
  ...
}
```

Then refactor `update_process_hgnc_data()` to build one mart per reference and thread it through:

```r
mart_hg19 <- create_ensembl_mart(reference = "hg19")
mart_hg38 <- create_ensembl_mart(reference = "hg38")

gene_coordinates_from_ensembl(ensembl_gene_id, reference = "hg19", mart = mart_hg19)
gene_coordinates_from_symbol(symbol,           reference = "hg19", mart = mart_hg19)
gene_coordinates_from_ensembl(ensembl_gene_id, reference = "hg38", mart = mart_hg38)
gene_coordinates_from_symbol(symbol,           reference = "hg38", mart = mart_hg38)
```

Backward compatible — existing callers that don't pass `mart` still get the old behavior.

## Nice-to-have (optional)

Consider migrating `create_ensembl_mart()` from `biomaRt::useMart(biomart = "ensembl", host = mirror)` to `biomaRt::useEnsembl(biomart = "ensembl", mirror = "useast")`. `useEnsembl()` has a built-in mirror fallback mechanism, which would let us drop some of our hand-rolled failover logic. Low priority — current implementation works fine.

## Files affected

- `api/functions/ensembl-functions.R` — add `mart =` parameter to 3 exported functions
- `api/functions/hgnc-functions.R` — build marts once in `update_process_hgnc_data()`, pass through to coordinate calls
- `api/tests/testthat/test-external-ensembl.R` — add 1–2 tests for the new `mart` parameter path

## Scope

Small, self-contained change. One plan, maybe half a day including tests. Not blocking anything.

## Why keep this open

The original reliability issues are resolved, but the redundant mart-creation pattern is still measurably wasteful on HGNC updates and is a small, pleasant cleanup task worth doing when touching this area for other reasons. Don't schedule a dedicated phase for it — bundle with the next HGNC/Ensembl-area work.
