# ClinVar Card Rich Summary Design

## Goal

Make the `/Genes/:symbol` ClinVar Variants card more informative while keeping it as fast and compact as the current lightweight summary card.

The card should remain visually comparable in height and density to the Gene Constraint and Model Organisms cards. It should provide richer per-class detail through dense chips and accessible popovers, not by expanding the card vertically or loading the full ClinVar variant list into the above-the-fold card.

Performance and perceived speed are binding requirements.

## Current Findings

Current frontend path:

- `GeneView.vue` renders `GeneClinVarCard` inside the external evidence row.
- `useGeneClinVarCounts()` calls `/api/external/gnomad/variants/<symbol>?summary=true`.
- The current summary response is intentionally small and contains only total variants plus five ACMG class counts.
- `useGeneClinVar()` separately calls `/api/external/gnomad/variants/<symbol>` without `summary=true` for genomic visualization tabs.

Measured locally for `/Genes/ARID1B`:

- Summary payload: about `209` bytes.
- Full ClinVar payload: about `788 KB`.
- Total ClinVar variants: `2605`.
- Current visible ClinVar card height at `1440x900`: about `116px`.
- Current card content is compact but information-thin: five large labels, no consequence breakdown, no explanation of class composition.

Full gnomAD ClinVar variant objects already include the fields needed for richer summaries:

- `clinical_significance`
- `major_consequence`
- `hgvsp`
- `hgvsc`
- `gold_stars`
- `review_status`
- `in_gnomad`
- `clinvar_variation_id`
- `variant_id`

For ARID1B, useful consequence patterns are visible in the full payload. Examples:

- Global top consequences: `missense_variant`, `synonymous_variant`, `frameshift_variant`, `stop_gained`, `inframe_insertion`, `inframe_deletion`, `intron_variant`, and splice classes.
- Pathogenic variants are dominated by frameshift and stop-gained consequences.
- VUS variants are dominated by missense variants.
- Benign and likely benign variants are enriched for synonymous, missense, intronic, and in-frame consequences.

## Design Direction

Extend the existing lightweight summary endpoint so the card can render rich detail without consuming the full variant list.

The card should present a dense overview and defer detail into chip popovers:

- Header: `ClinVar Variants (2605)` with the existing ClinVar outbound link.
- Body: compact ACMG chips using short visible labels:
  - `P 601`
  - `LP 158`
  - `VUS 836`
  - `LB 890`
  - `B 117`
- Each chip has an accessible full name and a click/focus popover with consequence breakdown for that class.
- A small global consequence strip may be shown only if it fits without increasing the card height materially.

This should feel similar to Model Organisms:

- Dense chips.
- Click/focus popovers for more detail.
- Short visible labels with full context in accessible names and popover titles.
- No large descriptive copy in the loaded state.

## Data Contract

The existing endpoint remains:

`GET /api/external/gnomad/variants/<symbol>?summary=true`

It should continue returning the current fields:

```json
{
  "source": "gnomad_clinvar",
  "gene_symbol": "ARID1B",
  "gene_id": "ENSG00000049618",
  "counts": {
    "pathogenic": 601,
    "likely_pathogenic": 158,
    "vus": 836,
    "likely_benign": 890,
    "benign": 117
  },
  "variant_count": 2605,
  "summary": true
}
```

Add compact summary fields derived server-side from the already fetched memoised full result:

```json
{
  "consequence_counts": [
    { "key": "missense", "label": "Missense", "count": 1156 },
    { "key": "synonymous", "label": "Synonymous", "count": 510 },
    { "key": "lof", "label": "LoF", "count": 516 },
    { "key": "inframe_indel", "label": "In-frame indel", "count": 242 },
    { "key": "splice", "label": "Splice", "count": 78 },
    { "key": "intronic", "label": "Intronic", "count": 98 },
    { "key": "other", "label": "Other", "count": 5 }
  ],
  "class_breakdowns": {
    "pathogenic": {
      "label": "Pathogenic",
      "short_label": "P",
      "count": 601,
      "consequences": [
        { "key": "lof", "label": "LoF", "count": 387 },
        { "key": "splice", "label": "Splice", "count": 23 },
        { "key": "missense", "label": "Missense", "count": 3 },
        { "key": "other", "label": "Other", "count": 1 }
      ]
    }
  },
  "quality_counts": {
    "in_gnomad": 0,
    "review_stars": {
      "0": 0,
      "1": 0,
      "2": 0,
      "3": 0,
      "4": 0
    }
  }
}
```

The example counts are illustrative of shape, not fixed fixtures. Tests should use small deterministic fixtures.

### Normalization Rules

Use stable categories suitable for a compact clinical summary:

- `missense`: `missense_variant`
- `synonymous`: `synonymous_variant`
- `lof`: `frameshift_variant`, `stop_gained`, `start_lost`, and close equivalents already present in gnomAD ClinVar major consequences
- `splice`: `splice_donor_variant`, `splice_acceptor_variant`, `splice_region_variant`
- `inframe_indel`: `inframe_insertion`, `inframe_deletion`
- `intronic`: `intron_variant`
- `utr`: UTR consequences if present
- `other`: anything not mapped above

The API may also expose raw top `major_consequence` counts if useful for debugging, but the UI should use normalized categories by default. Normalized categories keep the card readable and reduce popover noise.

Classification normalization should preserve the existing five primary buckets so current displayed counts do not regress:

- `pathogenic`
- `likely_pathogenic`
- `vus`
- `likely_benign`
- `benign`

Compound ClinVar labels need an explicit policy:

- `Pathogenic/Likely pathogenic` contributes to `pathogenic`.
- `Benign/Likely benign` contributes to `likely_benign`.
- `Conflicting classifications of pathogenicity`, `not provided`, and unmapped labels should not disappear. Include them under an optional `other_classifications` object and in `variant_count`, but do not force additional top-level chips unless the design is revised.

This policy fixes a current ambiguity: the existing substring classifier folds `Pathogenic/Likely pathogenic` into `pathogenic` and `Benign/Likely benign` into `benign` or `likely_benign` depending on string order. The new summary should make the behavior intentional and covered by tests.

## API Design

Update only the `summary=true` branch of `api/endpoints/external_endpoints.R`.

Do not add database tables, migrations, or new external requests. The endpoint should compute the summary from `result$variants`, which already comes from `fetch_gnomad_clinvar_variants_mem(symbol)`.

Keep the full endpoint response unchanged when `summary` is absent or false. The genomic visualization tabs depend on the full variant list and should not see a shape change.

Expected performance:

- No additional gnomAD request.
- Summary response should remain small; target under `5 KB` for high-variant genes.
- Server computation should be linear in variant count and use simple aggregation, not nested scans over the variant list for each chip.
- The memoised full-result fetch remains the only upstream cost.

## Frontend Design

Update `useGeneClinVarCounts.ts` types to reflect the richer summary payload. Do not rename the composable in this change unless the implementation plan calls for a narrow alias; stability matters more than perfect naming.

`GeneClinVarCard.vue` should:

- Accept the richer `counts`, `consequence_counts`, `class_breakdowns`, and optional `quality_counts`.
- Preserve backward compatibility with the existing count-only shape for tests and cached responses during local iteration.
- Render short dense chips in a flex row.
- Use accessible names that include the visible label text and full label, e.g. visible `P 601`, accessible `P 601 Pathogenic variants`.
- Use click/focus popovers, not hover-only content, for breakdown detail. Hover-only can remain as supplemental tooltip behavior for short labels, but the detail must be keyboard reachable.
- Keep empty state inside the card: `No ClinVar variants returned for this gene.`
- Keep error/retry behavior unchanged.
- Keep the ClinVar outbound link in loaded and empty states.

Popover content should be compact:

- Title: full class name and count, e.g. `Pathogenic (601)`.
- Consequence rows: label, count, percentage of class.
- Optional footer: `Observed in gnomAD: N` and review-star distribution if present.

Avoid showing long variant examples in this above-the-fold card. Specific variant inspection belongs in the existing protein/gene visualization views and ClinVar external link.

### Visual Density

The loaded card target is the current card height class, not a larger explanatory panel.

Acceptance targets for `/Genes/ARID1B` at `1440x900`:

- ClinVar card height should remain within `+25px` of current height unless browser verification shows the neighboring cards still align cleanly.
- No chip wraps into a third row at `lg` or wider.
- At mobile width, wrapping is allowed but the chip row should remain readable and should not introduce horizontal overflow.

Recommended chip copy:

- `P 601`
- `LP 158`
- `VUS 836`
- `LB 890`
- `B 117`

Recommended colors should retain ACMG semantics but must pass contrast:

- Pathogenic: high-contrast red with white text.
- Likely pathogenic: orange or red-orange with dark text only if contrast passes.
- VUS: amber with dark text.
- Likely benign: teal/green with dark text only if contrast passes.
- Benign: green with white or dark text based on contrast.

## Data Flow And Architecture

Keep the v11.3 data-loading model:

- `GeneView.vue` still calls `useGeneClinVarCounts(symbolForExternal)` for the above-the-fold ClinVar card.
- `GeneView.vue` still calls `useGeneClinVar(symbolForExternal)` for genomic visualizations.
- Do not change request timing for `TablesEntities`.
- Do not change SWR composables, `cacheStore`, or unrelated hooks.
- Do not change the route shape or external source orchestration.

The key architectural constraint is that the compact card must not subscribe to the full ClinVar variant array just to render summary popovers.

## Accessibility

Interactive chips must be reachable and understandable without a mouse:

- Chips should be buttons or button-like elements with `role="button"`, `tabindex="0"`, Enter/Space handling, and visible focus.
- Prefer Bootstrap Vue Next `BPopover` with manual or click triggers following the Model Organisms card pattern.
- Ensure the accessible name contains the visible chip text to avoid label-content-name mismatches.
- Popover titles should identify the class, not only repeat abbreviations.
- Color must not be the only signal; labels and counts carry the information.

## Testing Strategy

Use test-first implementation.

API tests:

- Summary endpoint preserves existing count fields and `summary=true`.
- Summary endpoint includes normalized `consequence_counts`.
- Summary endpoint includes per-class `class_breakdowns`.
- Compound classifications are handled intentionally:
  - `Pathogenic/Likely pathogenic`
  - `Benign/Likely benign`
  - `Conflicting classifications of pathogenicity`
- Summary mode does not change the full endpoint shape.
- The aggregation helper should be testable without hitting gnomAD.

Frontend unit tests:

- `useGeneClinVarCounts` accepts the richer summary shape and keeps its cache key distinct from `useGeneClinVar`.
- `GeneClinVarCard` renders dense short chips from summary data.
- A class chip opens a popover containing consequence labels and counts.
- The card remains compatible with count-only props.
- Empty and error states remain unchanged.
- Accessible names include visible chip text.

Browser checks:

- `/Genes/ARID1B` at `390x844`, `1024x768`, and `1440x900`.
- Assert no horizontal overflow in the ClinVar card.
- Assert card height stays close to the current card at desktop.
- Assert the popover is keyboard reachable.
- Run a focused axe check on the card area.

Performance checks:

- Compare `summary=true` payload size before and after; target `<5 KB`.
- Confirm the card still requests only `summary=true`, not the full ClinVar payload.
- Confirm the full ClinVar endpoint is still requested only by genomic visualizations, preserving existing behavior.
- Run frontend lint/type-check and relevant unit tests before handoff.

## Acceptance Criteria

- The ClinVar card gives class-by-consequence detail without loading the full variant list into the card.
- `summary=true` remains the above-the-fold card source and stays under `5 KB` for ARID1B.
- `/Genes/ARID1B` ClinVar card remains visually dense and comparable in height to Model Organisms and Gene Constraint at desktop.
- Dense chips are readable, high-contrast, and keyboard accessible.
- Chip popovers show normalized consequence breakdowns by ACMG class.
- The current full ClinVar endpoint remains backward compatible for protein/gene visualization tabs.
- No API, DB, SWR, cacheStore, or `TablesEntities` request-timing changes are introduced.
- Relevant API tests, frontend unit tests, lint, and type-check pass.

## Out Of Scope

- Direct ClinVar API integration.
- New database storage or migrations.
- Rendering individual variant lists inside the compact card.
- Changing the protein lollipop plot or gene structure plot behavior.
- Changing the full `/api/external/gnomad/variants/<symbol>` response shape.
- Broad redesign of the external evidence row beyond the ClinVar card internals.

## Spec Self-Review

- Placeholder scan: no unfinished placeholders remain.
- Internal consistency: the compact card uses the enriched summary endpoint; the full ClinVar list remains reserved for visualization tabs.
- Scope check: one endpoint summary branch, one composable type, one card component, focused tests.
- Ambiguity check: performance thresholds, normalization policy, interaction behavior, and non-goals are explicit.
