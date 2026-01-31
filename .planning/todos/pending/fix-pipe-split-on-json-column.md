# Fix str_split("\\|") Applied to JSON Column

**Priority:** Medium (latent — works currently but fragile)
**Category:** Data Integrity / API
**Created:** 2026-01-28
**Status:** Backlog
**Source:** Code audit of HGNC update pipeline (C1)

## Problem

In `api/endpoints/gene_endpoints.R` (~line 239), the gene endpoint applies `str_split(., pattern = "\\|")` to **every column** via `across(everything(), ...)`. This includes the `gnomad_constraints` column which contains a JSON string.

Currently this works because the JSON only contains numeric fields (no pipe characters). However:

1. Any future addition of a text field containing `|` to the gnomAD JSON would silently corrupt the output.
2. The JSON string arrives at the frontend wrapped in an array (`["{\\"pLI\\":0.99,...}"]` instead of `"{\\"pLI\\":0.99,...}"`), requiring the frontend to dereference `[0]`.
3. The TypeScript type at `app/src/types/gene.ts` declares `gnomad_constraints: string[]` (array) which is a consequence of this split, not the desired type.

## Impact

- **Current**: No visible breakage. Frontend handles the array wrapping.
- **Future risk**: Adding any text-based field to gnomAD constraints JSON would silently corrupt data.
- **Type pollution**: TypeScript types reflect the split artifact rather than the actual data shape.

## Suggested Fix

Exclude `gnomad_constraints` (and potentially `alphafold_id`) from the pipe-split transformation:

```r
# Instead of across(everything(), ...)
across(-c(gnomad_constraints), ~ str_split(., pattern = "\\|"))
```

Or better, apply the split only to columns known to contain pipe-separated values.

## Files Affected

- `api/endpoints/gene_endpoints.R` — pipe-split transformation
- `app/src/types/gene.ts` — `gnomad_constraints` type should be `string` not `string[]`
- `app/src/components/gene/GeneConstraintCard.vue` — may need to remove `[0]` dereference

---
*Discovered during HGNC bulk gnomAD enrichment code audit (2026-01-28).*
