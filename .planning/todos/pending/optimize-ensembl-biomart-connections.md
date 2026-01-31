# Optimize Ensembl BioMart Connections

**Priority:** High
**Category:** Performance / Reliability
**Created:** 2026-01-28
**Status:** Backlog
**Source:** Code audit of HGNC update pipeline (C3)

## Problem

Both `gene_coordinates_from_symbol()` and `gene_coordinates_from_ensembl()` in `api/functions/ensembl-functions.R` create **both** hg19 and hg38 BioMart objects at the top of each function, regardless of which reference is actually needed. Each `useMart()` + `useDataset()` pair is a network round trip.

### Current behavior (per function call):

```
Line 24-25:  mart_hg19 <- useMart(...)   # Network call 1
             mart_hg19 <- useDataset(...) # Network call 2
Line 27-28:  mart_hg38 <- useMart(...)   # Network call 3
             mart_hg38 <- useDataset(...) # Network call 4
Line 31-32:  mart <- useMart(...)         # Network call 5 (duplicate!)
             mart <- useDataset(...)      # Network call 6 (duplicate!)
```

Since `update_process_hgnc_data()` calls these functions **4 times** (hg19 by ensembl, hg19 by symbol, hg38 by ensembl, hg38 by symbol), this results in **24 useMart/useDataset calls** when only **4** are needed (2 marts × 2 datasets).

### Additional bug

Lines 32 and 84 call `useDataset("hsapiens_gene_ensembl", mart_hg19)` using the pre-created variable instead of the newly created `mart`. The code accidentally works because the datasets match, but the flow reveals the pre-created marts are vestigial.

## Impact

- **Performance**: 20 unnecessary network calls (~2-5 seconds each) add 40-100 seconds to the pipeline
- **Reliability**: When Ensembl is intermittent, more connection attempts mean more failure opportunities. The current Ensembl outage failures are multiplied by this redundancy.
- **Error surface**: Each unnecessary `useMart()` can trigger the "redirected to status.ensembl.org" error

## Suggested Fix

### Option A: Refactor functions to accept mart objects

```r
update_process_hgnc_data <- function(...) {
  # Create marts once
  mart_hg19 <- useEnsembl("ensembl", dataset = "hsapiens_gene_ensembl",
                           host = "grch37.ensembl.org", mirror = "useast")
  mart_hg38 <- useEnsembl("ensembl", dataset = "hsapiens_gene_ensembl",
                           mirror = "useast")

  # Pass to coordinate functions
  gene_coordinates_from_ensembl(ensembl_gene_id, mart = mart_hg19)
  gene_coordinates_from_symbol(symbol, mart = mart_hg19)
  # etc.
}
```

### Option B: Also use `useEnsembl()` with mirror fallback

The `biomaRt::useEnsembl()` function supports `mirror` parameter for automatic failover:

```r
useEnsembl("ensembl", dataset = "hsapiens_gene_ensembl",
           mirror = "useast")  # Falls back to US East mirror
```

This would improve reliability when the main Ensembl server is down.

## Files Affected

- `api/functions/ensembl-functions.R` — refactor both coordinate functions
- `api/functions/hgnc-functions.R` — pass marts from `update_process_hgnc_data()`

## Scope

This requires changing function signatures (adding `mart` parameter), which affects callers. The functions may be called from other places beyond `hgnc-functions.R`, so a careful grep is needed.

---
*Discovered during HGNC bulk gnomAD enrichment code audit (2026-01-28).*
