# ClinVar significance normalization — one table-driven vocabulary (#607)

- **Issue:** [#607](https://github.com/berntpopp/sysndd/issues/607)
- **Date:** 2026-07-30
- **Scope:** `app/src/types/`, `app/src/components/gene/`, `app/src/composables/d3-lollipop/`, `api/functions/external-proxy-gnomad.R`
- **Status:** design approved (options A = first-class Conflicting category, B = ClinVar card gains a Conflicting chip)

## 1. Problem

ClinVar variants classified `Conflicting classifications of pathogenicity` are counted and rendered as
**Pathogenic** in every client-side gene-page visualization, because
`"conflicting classifications of pathogenicity".includes('pathogenic')` is `true` (`pathogenic` is a
substring of *pathogenic*ity) and the string contains no `likely`.

Verified against the live production API (2026-07-30, 6 genes, 10 718 variants). PCDH12 alone:

| `clinical_significance` | n |
|---|---|
| Uncertain significance | 261 |
| Likely benign | 140 |
| Benign | 37 |
| **Conflicting classifications of pathogenicity** | **28** |
| Pathogenic | 13 |
| Likely pathogenic | 13 |
| Pathogenic/Likely pathogenic | 5 |
| Benign/Likely benign | 5 |
| not provided | 1 |
| **total** | **503** |

The lollipop legend reports `Pathogenic 46` = 13 + 5 + 28. The server-computed ClinVar card on the
same screen reports `P 18`. Two contradicting numbers, same gene, same page.

The **complete distinct-value set observed across all six genes is those nine strings** — no
pipe-joined or comma-joined compound assertions appear in the gnomAD projection. This is the
evidence the lookup table is built from.

## 2. Root causes

Four independent implementations of the same normalization; three are wrong, and the fourth is
right only by accident of ordering.

| Location | Consumers | Defect |
|---|---|---|
| `app/src/types/protein.ts:283` `normalizeClassification()` | lollipop, gene-structure plot, genomic tabs | Conflicting → `Pathogenic` |
| `app/src/types/alphafold.ts:227` `classifyClinicalSignificance()` | 3D viewer, VariantPanel | Conflicting → `pathogenic`; *and* `Pathogenic/Likely pathogenic` → `likely_pathogenic`, disagreeing with the other three |
| `app/src/components/gene/GeneClinVarCard.vue:173` | card fallback when `?summary=true` is absent | Conflicting → `pathogenic` (masked in prod) |
| `api/functions/external-proxy-gnomad.R:332` `normalize_clinvar_classification()` | `/api/external/gnomad/variants/<symbol>?summary=true` | correct output, fragile method — `grepl("conflicting")` special-case ahead of substring tests; one new vocabulary term from the same bug |

Both TypeScript functions carry doc comments claiming conflicting values return `null` / `other`.
They do not.

### 2.1 Three coupled defects the issue does not name

1. **`geneStructureVariantPlotUtils.ts:93`** — `filterState.pathogenicity[variant.classification] ?? true`.
   Any class outside the five-key map is **unconditionally visible**. The gene-structure plot
   defaults to P/LP only, so Conflicting variants today render Pathogenic-red *and* ignore the
   default filter. Fixing only the normalizer leaves them gray-but-always-on.
2. **`protein.ts:176` `PATHOGENICITY_SEVERITY`** — `'other'` sits at the **highest** severity index,
   so in aggregated mode a single unrecognised variant hijacks the dominant colour of an entire
   position. Same "unknown term lands in a severe bucket" failure, one layer down.
3. **`variantPanelData.ts:120`** — the `else` branch for `classification === null` is a no-op with a
   comment, so unclassified variants silently bypass ACMG filtering in the 3D panel.

## 3. Design

### 3.1 One shared vocabulary — `app/src/types/clinvarSignificance.ts` (new)

The single source of truth for the client. Exact string equality against an explicit lookup table
after one normalization step. **No `includes()`, no regex, no substring fallback.**

```ts
export type ClinVarSignificanceClass =
  | 'pathogenic'
  | 'likely_pathogenic'
  | 'vus'
  | 'likely_benign'
  | 'benign'
  | 'conflicting'
  | 'other'      // recognised, but not an ACMG pathogenicity tier
  | 'unknown';   // NOT in the table — never guessed

export function normalizeClinVarSignificanceKey(raw: unknown): string;
export function normalizeClinVarSignificance(raw: unknown): ClinVarSignificanceClass;
export const CLINVAR_SIGNIFICANCE_TABLE: Readonly<Record<string, ClinVarSignificanceClass>>;
```

**Normalization step** (`normalizeClinVarSignificanceKey`), applied once to both table keys and
input: non-string or empty → `''`; otherwise `replace(/_/g, ' ')` → `trim()` → `toLowerCase()` →
`replace(/\s+/g, ' ')`. An empty key resolves to `'unknown'`.

**Table** — ClinVar's published germline-classification vocabulary plus the one legacy synonym
(`Conflicting interpretations of pathogenicity`, renamed by ClinVar in 2023):

| class | normalized keys |
|---|---|
| `pathogenic` | `pathogenic`, `pathogenic/likely pathogenic`, `pathogenic, low penetrance` |
| `likely_pathogenic` | `likely pathogenic`, `likely pathogenic, low penetrance` |
| `vus` | `uncertain significance` |
| `likely_benign` | `likely benign`, `benign/likely benign` |
| `benign` | `benign` |
| `conflicting` | `conflicting classifications of pathogenicity`, `conflicting interpretations of pathogenicity` |
| `other` | `not provided`, `no classification provided`, `no classifications from unflagged records`, `no classification for the single variant`, `drug response`, `risk factor`, `association`, `association not found`, `protective`, `affects`, `confers sensitivity`, `established risk allele`, `likely risk allele`, `uncertain risk allele`, `other` |

Two combined-pair rules are settled explicitly and identically on both sides — **most severe of the
pair wins**: `Pathogenic/Likely pathogenic` → `pathogenic` (matches the server today, corrects
`alphafold.ts`), and `Benign/Likely benign` → `likely_benign` (matches all four implementations
today).

The three risk-allele terms map to `other`, not to an ACMG tier: they are a different kind of claim,
and `other` is the honest, fail-safe destination.

**Compound multi-assertion strings are deliberately not parsed.** None appear in the gnomAD
projection. A hypothetical `Pathogenic|risk factor` resolves to `unknown` rather than being split by
a delimiter heuristic — an undercount is visible and recoverable, a misfiled Pathogenic is neither.

**Unknown terms are logged, once per distinct term per session.** A module-level `Set` guard keeps a
500-variant page from emitting 500 identical warnings.

### 3.2 The other three implementations become adapters

- **`protein.ts::normalizeClassification()`** delegates. `PathogenicityClass` gains `'Conflicting'`;
  `PATHOGENICITY_COLORS['Conflicting'] = '#6f42c1'` (the existing `$purple` token in
  `app/src/assets/scss/_variables.scss` — the visual guide requires token colours, not one-off
  palette values). `other` and `unknown` both map to the existing `'other'` class.
- **`alphafold.ts::classifyClinicalSignificance()`** delegates. `ACMG_COLORS`/`ACMG_LABELS` gain
  `conflicting: '#6f42c1'` / `'Conflicting'`, so `AcmgClassification` gains the member. `other` and
  `unknown` continue to return `null` (existing "unclassified" behaviour: gray `#999999`, labelled
  with the raw significance string, which is genuinely informative for `not provided`).
- **`GeneClinVarCard.vue`** deletes its inline `includes()` chain and derives fallback counts through
  the shared normalizer.

Adapters, not a type migration: the two palettes are intentionally different (the lollipop uses a
red→green diverging ramp, the 3D panel uses Bootstrap variants matching the card badges), so
collapsing `PathogenicityClass` and `AcmgClassification` into one union would not unify colours and
would churn ~10 files for no correctness gain.

### 3.3 Where Conflicting variants go — first-class legend category

| Surface | Conflicting chip | default | Other chip |
|---|---|---|---|
| Protein lollipop (`ProteinDomainLollipopPlot.vue`) | yes | **on** (surface is all-on today) | yes, rendered only when count > 0 |
| Gene-structure plot (`GeneStructurePlotWithVariants.vue`) | yes | **off** (surface is P/LP-only today) | yes, rendered only when count > 0 |
| 3D VariantPanel (`VariantPanel.vue`) | yes (`Conf`) | **on** | no — `AcmgClassification` has no `other` member; `null` stays gray + raw-string label |

Each chip carries its count, so a default-off category is "explicit exclusion with the count
surfaced" rather than a silent drop.

Supporting changes:

- `LollipopFilterState` gains `conflicting: boolean` and `other: boolean`;
  `isClassificationVisible()` maps `'Conflicting'` → `filterState.conflicting` and the `default`
  branch → `filterState.other ?? true` (the `?? true` keeps older callers that omit the key working).
- `GeneStructurePlotWithVariants` filter state gains `conflicting` and `other`; its
  `isVariantVisible()` pathogenicity map gains `Conflicting` and `other` entries.
  `isGeneStructureVariantVisible()` keeps its `?? true` fallback — now unreachable for every class the
  normalizer can emit, and still a safe default for a caller that passes a partial map.
- `VariantFilterKey` gains `'conflicting'`; `classificationToFilterKey`, `getHiddenClassifications`,
  `selectOnly`, `selectAll`, and `countByClassification` all extend.
  `filterMappableVariants`'s no-op `else` becomes an explicit early-`return true` with a comment
  stating that unclassified variants are intentionally always visible.
- `PATHOGENICITY_SEVERITY` is reordered to
  `['other', 'Benign', 'Likely benign', 'Conflicting', 'Uncertain significance', 'Likely pathogenic', 'Pathogenic']`.
  This demotes `'other'` from most-severe to least-severe (defect 2.1.2) and places `Conflicting`
  just below VUS — a position holding a Pathogenic and a Conflicting still renders Pathogenic; a
  position holding only Conflicting renders purple.

### 3.4 Server: table-driven, and `conflicting` becomes a primary class

`normalize_clinvar_classification()` is rewritten as an exact-match lookup over the identical
vocabulary. Return contract is unchanged in shape: one of the primary class keys, or
`other:<sanitized>` for everything else. Every `grepl()` fallback is removed, so a new upstream term
lands in `other:<sanitized>` instead of being routed into `pathogenic` by substring luck.

`clinvar_primary_classes` gains a sixth entry:

```r
conflicting = list(label = "Conflicting classifications", short_label = "CONF")
```

so `Conflicting classifications of pathogenicity` now resolves to `"conflicting"` — a first-class
count with its own `class_breakdowns` consequence rollup — instead of
`other:conflicting_classifications_of_pathogenicity`.

**This intentionally changes one existing assertion.** `api/tests/testthat/test-unit-gnomad-clinvar-summary.R`
currently asserts `summary$other_classifications$conflicting_classifications_of_pathogenicity == 1`;
it moves to `summary$counts$conflicting == 1`. The issue text expects that file to keep passing
unchanged — decision B supersedes it, and the change is recorded here for the reviewer.

No cache invalidation and no `CACHE_VERSION` bump: `summarise_gnomad_clinvar_variants()` is called at
request time in `external_endpoints.R:134` from the already-cached raw variant list, so the memoised
return shape (`fetch_gnomad_clinvar_variants_mem`) is untouched.

### 3.5 ClinVar card gains a Conflicting chip

`ClinVarClassificationCounts` (`useGeneClinVarCounts.ts`) and `ClinVarCounts` (`GeneClinVarCard.vue`)
gain `conflicting: number`; `chipMeta` gains a `conflicting` entry between `likely_pathogenic` and
`vus`, styled `.clinvar-chip--conf` (`#6f42c1` background, white text — contrast ratio 5.9:1,
AA-compliant). The card already filters chips to `count > 0`, so genes without conflicting
submissions render exactly as before, and a stale API response lacking `counts.conflicting` yields
`undefined`, is coerced with `?? 0`, and is filtered out.

After this, PCDH12 reconciles: card `P 18 | LP 13 | CONF 28 | VUS 261 | LB 145 | B 37` = 502, plus
the one `not provided` in `other_classifications` = 503 = `variant_count`. The lollipop legend reads
the same numbers for the subset it can position.

## 4. Testing

**Cross-language parity is enforced by a shared fixture**, not by two hand-maintained lists:
`api/tests/testthat/fixtures/clinvar-significance-vocabulary.json` maps every raw term to its
expected canonical class, and **both** suites drive their implementation from that one file. It
lives under `api/tests/` because that directory is copied into the API container, while the host-run
vitest can reach it from a full checkout.

| Suite | Coverage |
|---|---|
| `app/src/types/clinvarSignificance.spec.ts` (new) | table-driven over the shared fixture; `Conflicting…` is **not** pathogenic; unknown string → `'unknown'` and never an ACMG tier; underscore / case / whitespace / `null` / `undefined` / `''` normalization; unknown-term warning fires once per distinct term |
| `app/src/types/protein.spec.ts` (new) | `normalizeClassification` per fixture; `PATHOGENICITY_SEVERITY` ordering; `aggregateVariantsByPosition` dominant-class selection with Conflicting and `other` present |
| `app/src/types/alphafold.spec.ts` (new) | `classifyClinicalSignificance` per fixture; `Pathogenic/Likely pathogenic` → `pathogenic` (regression for the cross-module disagreement) |
| `variantPanelData.spec.ts`, `genomicVisualizationData.spec.ts`, `geneStructureVariantPlotUtils.spec.ts`, `proteinLollipopControls.spec.ts`, `GeneClinVarCard.spec.ts` | extended for the `conflicting` class: counting, filtering, visibility, chip rendering |
| `api/tests/testthat/test-unit-gnomad-clinvar-summary.R` | `conflicting` as a primary count; unknown term → `other:<sanitized>` and **not** `pathogenic`; table-driven pass over the shared fixture |

An end-to-end visual check on PCDH12 in the restarted dev stack closes the loop: the lollipop legend
must read `Pathogenic 13`, `Likely pathogenic 13`, `Conflicting 28`, and the card must read `P 18`,
`CONF 28`.

## 5. Out of scope

- Unifying `PathogenicityClass` and `AcmgClassification` into one type/palette (§3.2).
- Parsing compound multi-assertion significance strings (§3.1).
- Surfacing `other_classifications` on the ClinVar card beyond the new `conflicting` chip.
- Any change to curated SysNDD data — this path is read-only external-provider display.
