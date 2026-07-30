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

**Aggregate values are resolved by parsing ClinVar's documented grammar, then exact-matching each
token.** None appear in the six-gene sample, but ClinVar genuinely aggregates across submissions —
`Pathogenic/Likely pathogenic/Pathogenic, low penetrance/Established risk allele; risk factor` is a
live record ([VCV000013310](https://www.ncbi.nlm.nih.gov/clinvar/variation/13310/)). Whole-string
matching alone would send every such value to `unknown` and **undercount real pathogenic variants**.
The resolution ladder is:

1. Exact-match the whole normalized string against `CLINVAR_SIGNIFICANCE_TABLE`. Hit → done. This is
   the path every one of the nine observed values takes, including
   `conflicting classifications of pathogenicity`.
2. Miss → split on `;` and `|`, ClinVar's separators between the pathogenicity assertion and
   secondary assertions. Keep the **first** segment; discard the rest.
3. Split that segment on `/`, ClinVar's separator between aggregated classification terms, and
   exact-match **each** token against `CLINVAR_SIGNIFICANCE_TOKENS` (the atomic terms only).
4. **Every** token must resolve, or the whole value is `unknown`. If any token is `conflicting` the
   result is `conflicting`; otherwise the result is the most severe ACMG tier present; if no token is
   an ACMG tier, the result is `other`.

This is tokenizing a documented delimiter grammar and then exact-matching, not substring guessing:
`conflicting classifications of pathogenicity` never reaches step 3, and if it did, its tokens would
not include a bare `pathogenic`. `pathogenic, low penetrance` survives step 3 intact because it
contains a comma, not a slash.

Anything still unresolved is `unknown` — never guessed. The count is **user-visible**, not just
logged: `unknown` renders in the plots' `Other` chip with its count, and the card's
`ClinVar Variants (N)` header exposes the gap between `variant_count` and the chip sum.

**Unknown terms are logged, once per distinct term per session.** A module-level `Set` guard keeps a
500-variant page from emitting 500 identical warnings.

### 3.2 The other three implementations become adapters

- **`protein.ts::normalizeClassification()`** delegates. `PathogenicityClass` gains `'Conflicting'`;
  `PATHOGENICITY_COLORS['Conflicting'] = '#6f42c1'`. These D3 palettes are TypeScript literals and
  cannot consume Sass, so this is a hex literal like its five neighbours — but it is the **value of
  the existing `$purple` token** (`app/src/assets/scss/_variables.scss:22`) rather than a newly
  invented colour, which is what the visual guide's "existing token colors rather than new one-off
  palette values" asks for. `other` and `unknown` both map to the existing `'other'` class.
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

| Surface | existing default | Conflicting chip | default | Other chip |
|---|---|---|---|---|
| Protein lollipop (`ProteinDomainLollipopPlot.vue:109-114`) | **P/LP only** | yes | **off** | yes, rendered only when count > 0, default **off** |
| Gene-structure plot (`GeneStructurePlotWithVariants.vue:99-104`) | **P/LP only** | yes | **off** | yes, rendered only when count > 0, default **off** |
| 3D VariantPanel (`VariantPanel.vue:175-182`) | **all on** | yes (`Conf`) | **on** | no — `AcmgClassification` has no `other` member; `null` stays gray + raw-string label |

Every new chip follows its own surface's existing posture rather than a new one. Both plots already
hide VUS/LB/B by default for clinical focus, so Conflicting and Other are hidden there too; the 3D
panel already shows everything, so Conflicting shows. Each chip carries its count, so a default-off
category is "explicit exclusion with the count surfaced" rather than a silent drop — and this is a
strict improvement on today, where Conflicting variants are drawn Pathogenic-red *and* bypass the
P/LP-only default entirely.

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
  `lollipop-render.ts:250` keeps a **second**, independent `Record<PathogenicityClass, number>`
  stacking order for individual mode, which already ranks `other: -1` (lowest) and therefore already
  disagrees with the aggregate order. It is deleted and derived from `PATHOGENICITY_SEVERITY` via
  `pathogenicitySeverityRank()`, so the two modes agree by construction and a future class cannot be
  added to one and forgotten in the other. Reordering the aggregate list therefore changes the
  dominant colour of every aggregated position that mixes `other` with a recognised class — an
  intended correction, aligning aggregate mode with what individual mode already did.

### 3.3.1 Consumers that must widen with the unions

These are exhaustive or count-bound and fail (or silently truncate) the moment a union grows:

| File:line | What breaks | Fix |
|---|---|---|
| `composables/d3-lollipop/lollipop-render.ts:250` | exhaustive `Record<PathogenicityClass, number>` — TS error | derive from `PATHOGENICITY_SEVERITY` |
| `components/gene/proteinLollipopControls.ts:18` | `PathogenicityFilterKey` union | add `conflicting`, `other` |
| `components/gene/GeneStructurePlotControls.vue:171` | a **second** `PathogenicityFilterKey` union, exported to its parent | add `conflicting`, `other` |
| `components/gene/GeneStructurePlotWithVariants.vue:252,263` | local `selectOnly`/`selectAll` set five keys | add both |
| `components/gene/VariantPanel.vue:284-295` | the `filter-change` watcher enumerates five keys, so a `Conf` toggle would never reach `ProteinStructure3D` | add `conflicting` |
| `components/gene/gene-structure-plot/gene-structure-tooltip.ts:133` | `.slice(0, 5)` over what is now seven possible classes | render every non-zero class |
| `composables/__tests__/useGeneClinVarCounts.spec.ts:35` and `GeneClinVarCard.spec.ts:5` | five-count mocks | see §3.5 — `conflicting` is optional at the wire boundary |

`composables/d3-lollipop/lollipop-tooltip.ts:199` already filters to non-zero and does not truncate;
no change needed.

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
gain **`conflicting?: number`** — deliberately *optional* at the wire boundary, so a stale deployed
API, a cached response, and the existing five-count test mocks all keep type-checking. The card's
`counts` computed spreads over a zero-filled base (`{ ...empty, ...props.counts }`), which is what
turns a missing `conflicting` into `0`; the existing `count > 0` chip filter then omits the chip
entirely. `chipMeta` gains a `conflicting` entry between `likely_pathogenic` and `vus`, styled
`.clinvar-chip--conf` (`#6f42c1` background, white text — contrast ratio 5.94:1, AA-compliant).
Genes without conflicting submissions render exactly as before.

After this, PCDH12 reconciles: card `P 18 | LP 13 | CONF 28 | VUS 261 | LB 145 | B 37` = 502, plus
the one `not provided` in `other_classifications` = 503 = `variant_count`. The lollipop legend reads
the same numbers for the subset it can position.

## 4. Testing

**Cross-language parity is enforced by a shared fixture**, not by two hand-maintained lists:
`api/tests/testthat/fixtures/clinvar-significance-vocabulary.json` maps every raw term to its
expected canonical class, and **both** suites drive their implementation from that one file. It
lives under `api/tests/` because that directory is copied into the API container, while the host-run
vitest can reach it from a full checkout.

The fixture is a *test* artifact, not a runtime one — two production tables still exist, one per
language, and a fixture that only asserts one direction could not catch a key added to one table and
not the other. Both suites therefore assert **bidirectional completeness**: the set of production
table keys must equal the set of normalized fixture keys, exactly, with no extras on either side.
The same holds for the token table. Adding a term means editing the fixture first; both suites then
fail until both tables follow.

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
- Generating both production tables from one machine-readable source at build time. The bidirectional
  completeness tests in §4 make drift a test failure, which is sufficient for a 26-term vocabulary
  that changes on ClinVar's release cadence; a codegen step is not worth its maintenance cost here.
- Surfacing `other_classifications` on the ClinVar card beyond the new `conflicting` chip.
- Any change to curated SysNDD data — this path is read-only external-provider display.

## 6. Adversarial review

One round, Codex `gpt-5.6-terra` at high effort, verdict **BLOCK** — full text in
`.planning/reviews/2026-07-30-607-spec-codex-review.md`. Every code claim was verified against the
files before acceptance. Resolutions:

| # | Finding | Resolution |
|---|---|---|
| P0 1 | Exact-match-only undercounts real aggregate labels such as `Pathogenic/Likely pathogenic/Pathogenic, low penetrance/Established risk allele; risk factor` | **Accepted.** §3.1 now parses ClinVar's documented `;`/`|`/`/` grammar and exact-matches each token; unresolved values surface in the `Other` chip, not only a console warning |
| P1 2 | `lollipop-render.ts:250` second exhaustive severity map | **Accepted.** §3.3 derives it from `PATHOGENICITY_SEVERITY` |
| P1 3 | Spec wrongly claimed the lollipop defaults to all-on; it is P/LP-only | **Accepted — factual error.** §3.3 corrected; Conflicting and Other default **off** on both plots |
| P1 4 | Both `PathogenicityFilterKey` unions and the only/all helpers were omitted | **Accepted.** §3.3.1 |
| P1 5 | The `VariantPanel.vue` filter-change watcher was omitted, so the Conf chip would not sync 3D markers | **Accepted.** §3.3.1 |
| P1 6 | The fixture is a test artifact, not a runtime single source of truth | **Accepted in part.** §4 adds bidirectional completeness tests; build-time codegen declined as disproportionate (§5) |
| P2 7 | Severity reordering has wider effects than acknowledged | **Accepted.** §3.3 states it, and unifies the two orderings |
| P2 8 | `gene-structure-tooltip.ts:133` truncates to five of seven classes | **Accepted.** §3.3.1 |
| P2 9 | Required `conflicting` breaks existing five-count mocks; the `?? 0` claim was wrong | **Accepted.** §3.5 makes it optional at the wire and zero-fills centrally |
| P2 10 | The `$purple` "token" is a hex literal in TS, not token-based styling | **Accepted.** §3.2 wording corrected |
