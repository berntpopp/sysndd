# Syndromicity: one computed definition across SysNDD (#630)

Status: design
Issue: berntpopp/sysndd#630
Date: 2026-08-26

## Problem

`/api/analysis/phenotype_cluster_summary` returns a per-cluster `syndromicity`
string produced by a language model. Three defects, each verified against live
data rather than inferred.

**It is not reproducible on identical input.** `llm_cluster_summary_cache` rows
for `cluster_hash = f4a3dd1a27…` — identical cluster membership, identical model
(`gemini-3.5-flash`), 39 seconds apart — hold `predominantly_id`, then `mixed`,
then `predominantly_id`. Cluster 3 has been served as `predominantly_syndromic`
and as `predominantly_id` at different times, both under
`validation_status: "validated"`. Those are opposite clinical claims about the
same entities.

**The served value is not even the summarizer's.** Every `pending` (pre-judge)
row in the cache carries `syndromicity: "unknown"`. The generator abstains; the
value consumers read is the judge's `corrected_syndromicity` — a second model
inventing a value for a field the first one declined to fill.

**The label is wrong in the sense consumers read it.** The rule the prompt
encodes (`llm-types.R:558`) is stated over `quanti_sup_var` v.test scores, which
are *relative to the database average*. The served word is read as *absolute*.
Computing organ-system involvement directly from the curated HPO annotations of
the 1,931 entities in public-ready snapshot 70:

| cluster | n | none recorded | ≥1 extra-neuro system | % syndromic | median systems | served LLM label |
|---|---:|---:|---:|---:|---:|---|
| 1 | 343 | 45 | 298 | 86.9% | 2 | `predominantly_syndromic` / "progressive metabolic disorders" |
| 2 | 1053 | 360 | 693 | **65.8%** | 1 | `predominantly_id` / **"pure neurodevelopmental"** |
| 3 | 535 | 0 | 535 | 100% | 4 | `predominantly_syndromic` / "syndromic malformations" |

Cluster 2 is served as "pure neurodevelopmental" while two thirds of its
entities have documented extra-neurological organ involvement. Clusters 1 and 3
collapse to one label despite a 2x difference in extent of involvement.

Two corrections to the issue text, for the record. `syndromicity` **is**
enumerated (`llm-types.R:99`, `ellmer::type_enum`), so the drift the issue
predicts cannot occur for that field; it occurs for `clinical_pattern`, which is
free text and has already drifted between `"progressive metabolic disorders"`
and `"progressive metabolic/degenerative"` for the same cluster. The
reproducibility failure, which the issue does not name, is the more serious
defect.

### The same conflation one layer up

`phenotype_id_count` / `phenotype_non_id_count` are MCA quantitative
supplementary variables, computed from a hardcoded six-term ID list duplicated
in three places (`analysis-phenotype-functions.R:179`,
`job-phenotype-submission-service.R:51`, and consumed at
`async-job-handlers.R:193`). `phenotype_non_id_count` counts every non-ID term
as a syndromic feature — including the ontology root `HP:0000118`, the
clinical-course modifiers `HP:0003676` (Progressive) and `HP:0011420` (Age of
death), and six nervous-system terms that are the NDD phenotype itself. It is
served on `/PhenotypeCorrelations/PhenotypeClusters` under that name, so the
conflation is user-visible.

## The measure

### Unit and evidence

The **entity** (gene–disease association), because that is SysNDD's curation unit
and what phenotype clusters contain. Evidence is the entity's primary approved
review (`is_primary = 1 AND review_approved = 1`), active connect rows, modifier
`present` only — byte-identical to the filter
`generate_phenotype_cluster_input()` already applies, so the measure and the
partition can never disagree about what an annotation means. The 1,399
`uncertain` / `variable` / `rare` rows are surfaced as `equivocal_term_count`,
never silently counted. Explicit `absent` is unusable as evidence: 6 rows exist
in the entire database.

### Registry

`api/functions/syndromicity-registry.R` maps each of the 39 `phenotype_list`
terms to a `role` and, for organ terms, a **collapsed** `system`:

| role | terms | counts toward syndromicity |
|---|---|---|
| `ontology_root` | `HP:0000118` | no — ancestor of everything |
| `course_modifier` | `HP:0003676`, `HP:0011420` | no — not organ involvement |
| `ndd_core` | `HP:0001249`, `HP:0001256`, `HP:0002342`, `HP:0010864`, `HP:0002187`, `HP:0006889` | no — the NDD phenotype itself |
| `neuro` | `HP:0000707`, `HP:0000708`, `HP:0001250`, `HP:0002011`, `HP:0002270`, `HP:0002376`, plus `HP:0000252`/`HP:0000256` (head size) | no — reported separately |
| `organ` | remaining 22 | yes, deduplicated by `system` |

Collapsing is what removes the double-counting. `HP:0000077` (kidney) and
`HP:0000119` (genitourinary) are one `renal_urogenital`; `HP:0000924` and
`HP:0040064` are one `skeletal`; `HP:0001939` and `HP:0012103` are one
`metabolic`; the four stature/weight terms are one `growth`; `HP:0000202` and
`HP:0001999` are one `craniofacial`. The remaining organ terms map one-to-one.

Abnormal head size (`HP:0000252` / `HP:0000256`) is classified **`neuro`, not
`organ`**: micro- and macrocephaly are cardinal neurodevelopmental findings, and
counting them as extra-systemic would call an entity syndromic on the strength
of a core NDD feature. Because that is the one genuinely contestable mapping
choice, every payload also carries `fraction_syndromic_with_head_size`, the same
statistic under the alternative operationalization.

The registry is the single definition of the ID-severity term set, retiring both
hardcoded copies.

**Fail-closed.** `syndromicity_registry_assert_complete()` compares the registry
against live `phenotype_list` in both directions and raises on either a term the
registry does not cover or a registry entry with no live term. A vocabulary
addition must be classified deliberately; it cannot be silently dropped into the
denominator or the numerator.

### Entity-level result

```
{ entity_id, rule_version: "1.0",
  extraneurological_systems: ["renal_urogenital","endocrine","metabolic"],
  system_count: 3,
  neurological_involvement: true,
  equivocal_term_count: 0,
  present_term_count: 8,
  call: "syndromic" }
```

`call` is `syndromic` when `system_count >= 1`;
`no_recorded_extraneurological_involvement` when the entity has >=1 `present`
annotation and `system_count == 0`; `insufficient_annotation` when it has none.

The middle value is deliberately **not** called `isolated_ndd`. SysNDD records
explicit phenotype absence on 6 rows in the entire database, so "no organ system
recorded" cannot be distinguished from "assessed and unaffected". Naming it
`isolated` would infer clinical absence from missing documentation — the defect
this repository already documents for the MCA input
(`analysis-phenotype-missingness.R:8`: unrecorded means UNKNOWN, not confirmed
absence) and the one the sibling kidney-genetics implementation ships via
`COALESCE(is_syndromic, FALSE)`. Keeping the third value distinct is required: 65 Definitive
entities have no annotations at all, and collapsing them into the no-involvement bucket
would report annotation absence as an established clinical finding.

Worked example, entity 4 (`ABCD1`): three extra-neurological systems
(`renal_urogenital`, `endocrine`, `metabolic`), nervous-system involvement
reported separately, `HP:0003676` excluded as a course modifier, ID excluded as
core. A flat non-ID count returns 7 for the same entity.

### Cluster-level aggregate

```
{ rule_version: "1.0",
  data_class: "curated_derived_analysis",
  measures: "recorded extra-neurological organ involvement",
  entities: 1053, evaluable: 1053, coverage: 1.0,
  insufficient_annotation: 0,
  no_recorded_extraneurological_involvement: 360, syndromic: 693,
  fraction_syndromic: 0.658,
  fraction_syndromic_ci95: { lower: 0.629, upper: 0.686 },
  fraction_syndromic_with_head_size: 0.746,
  median_systems: 1, mean_systems: 1.31, mean_present_terms: 5.6,
  system_frequencies: { craniofacial: 271, eye: 208, growth: 190, ... },
  neurological_system_frequencies: { nervous_system: 1012, head_size: 121 },
  cluster_call: "mixed",
  thresholds: { syndromic_system_count: 1,
                predominantly_syndromic: 0.75,
                predominantly_isolated: 0.25,
                min_evaluable_fraction: 0.5 } }
```

`fraction_syndromic` is over *evaluable* entities. `cluster_call` is
`predominantly_syndromic` at `>= 0.75`, `predominantly_isolated` at `<= 0.25`,
`mixed` between, and `insufficient_annotation` when evaluable entities are under
half of the cluster. The thresholds travel inside the payload so a frozen
downstream artifact self-identifies, and `fraction_syndromic` ships alongside the
word because a cluster can land near a boundary, which the word alone would
hide. A Wilson 95% interval ships with it for the same reason.

Run through the shipped functions against the live database (3,612 entities,
20,119 annotation rows), snapshot 70 yields:

| cluster | n | syndromic | none recorded | fraction [95% CI] | median systems | with head size | call |
|---|---:|---:|---:|---|---:|---:|---|
| 1 | 343 | 298 | 45 | 0.869 [0.829-0.900] | 2 | 0.892 | `predominantly_syndromic` |
| 2 | 1053 | 693 | 360 | 0.658 [0.629-0.686] | 1 | 0.746 | **`mixed`** |
| 3 | 535 | 535 | 0 | 1.000 [0.993-1.000] | 4 | 1.000 | `predominantly_syndromic` |

Cluster 2's interval excludes 0.75, so `mixed` is a supported call rather than a
coin flip at a cutoff. Its head-size sensitivity (0.746) lands almost exactly on
the boundary, which is why that statistic ships rather than being decided
silently in the registry.

### What was deliberately not copied from the sibling implementation

`../kidney-genetics-db` supplies the right shape — a named ancestor set,
descendant expansion, an explicit threshold — and four defects that are not
imported:

- Its `gene_hpo_classifications` view uses `LEFT JOIN` + `COALESCE(..., FALSE)`,
  so an unannotated gene is reported as `Isolated`. This design keeps
  `insufficient_annotation` a distinct terminal value at every layer.
- It has two divergent implementations of the same method name (one sums
  category scores, one averages them) behind the same 0.3 threshold. This design
  has one function, called from one place.
- Its threshold is hardcoded twice. Here it is a named constant emitted in the
  payload.
- Its tests mock the descendant sets, so the indicator term IDs are not actually
  pinned. Here the registry is asserted against live `phenotype_list` in both
  directions.

Its category set itself is not portable: its four indicators include
`neurologic` (`HP:0000707`), which for NDD is the primary phenotype, not an
extra-systemic marker. Its unit is the gene; ours is the entity.

Descendant expansion is not needed here. SysNDD annotates against a fixed
39-term controlled vocabulary rather than free HPO, so the mapping is a static,
auditable table and the annotation-depth confounder is far weaker — though not
absent, which is why `present_term_count` ships with every result.

## Where it is computed

Once, in the snapshot builder's `phenotype_clusters` branch, which already
reloads the entity matrix. Attached as a clusters-tibble list-column.

Two structural facts, verified in code, make this additive:

- `cluster_hash` is a hash of the cluster's **sorted `entity_id` set**
  (`analysis-phenotype-functions.R:93` -> `data-helpers.R:219`), copied into the
  snapshot at `analysis-snapshot-builder.R:176`. (`cluster_signature_hash` is a
  separate, currently unused top-5-term hash — do not confuse them.) Since
  membership is verified identical, the hash is identical, so **existing LLM
  summaries survive and no regeneration is required**.
- `analysis_snapshot_build_cluster_rows()` folds any column outside its excluded
  set into `metadata_json` (`analysis-snapshot-builder.R:194`), and
  `service_analysis_snapshot_shape_clusters()` merges those keys back onto the
  served row (`analysis-snapshot-service.R:330`). The block reaches
  `/api/analysis/phenotype_clustering` with no schema change and no
  serving-path change.

`payload_hash` does change — the payload gained a result, which is honest. The
correlation snapshot's dependency gate pins the phenotype `snapshot_id`, so a
forced correlation refresh must follow the cluster refresh.

## MCA supplementary variables

The three quantitative supplementary columns are redefined onto the registry.
The count stays at three so the positional `quanti_sup_var = 2:4` index
arithmetic in the builder and `phenotype_mca_prep_matrix()` is untouched:

| before | after | meaning |
|---|---|---|
| `phenotype_non_id_count` | `extraneurological_system_count` | collapsed extra-neurological systems |
| `phenotype_id_count` | `phenotype_id_count` (unchanged) | ID-core/severity terms, list now from the registry |
| `gene_entity_count` | `gene_entity_count` (unchanged) | — |

Supplementary variables are projected onto axes built from active variables
only, so **cluster membership is unchanged**; only `desc.var$quanti` v.test
values change.

This claim was **verified empirically**, not asserted (the #514 lesson: a
membership-affecting claim must be checked live). Running the real 1,931-entity
Definitive matrix through `phenotype_mca_prep_matrix()` and then
`FactoMineR::MCA(ncp = 8, quali.sup = 1:1, quanti.sup = 2:4)` +
`HCPC(nb.clust = -1, kk = Inf, consol = TRUE)` twice — once with
`phenotype_non_id_count` (column mean 5.184) and once with
`extraneurological_system_count` (column mean 2.593), a 2x shift in the
supplementary column:

```
identical MCA active coordinates : TRUE
identical cluster membership     : TRUE
n clusters OLD/NEW               : 3 / 3
```

Membership, and therefore `cluster_signature`, `cluster_hash` and every cached
LLM summary, are unaffected. `CLUSTER_LOGIC_VERSION` is deliberately **not**
bumped: the memoise key already includes the matrix content
(`gen_mca_clust_obj_mem(input$matrix)`), so the changed column invalidates the
entry on its own and the recomputed partition is identical. The single computation helper is shared by all three matrix paths
(`generate_phenotype_cluster_input()`, `job-phenotype-submission-service.R`,
`async-job-handlers.R`) so the served snapshot and the interactive job cannot
diverge. The frontend renders `variable` verbatim, so
`/PhenotypeCorrelations/PhenotypeClusters` picks the new name up with no change;
a display-label map gives it a readable title.

## API surface

- `GET /api/analysis/phenotype_clustering` — gains the per-cluster block.
- `GET /api/analysis/phenotype_cluster_summary` — gains a `syndromicity` sibling
  of `summary_json`, resolved by one DB-only lookup on `cluster_hash` against
  the current public-ready phenotype snapshot (`null` when the hash is not in
  it), plus a `validation_scope` sibling of `validation_status` naming exactly
  what the judge checked. Any stale `syndromicity` key inside a cached
  `summary_json` is **stripped on read**, which is what lets this ship without
  forcing regeneration.
- `GET /api/entity/<id>/syndromicity` — new, Curator-free, DB-only, one query,
  entity resolved through `ndd_entity_view` so a non-public entity returns
  `status: "missing"`. This is what makes every cluster aggregate auditable; the
  aggregate is an unverifiable claim without it.

All three carry `data_class: "curated_derived_analysis"`.

## LLM contract

- `syndromicity` removed from `phenotype_cluster_summary_type`, from generator
  prompt step 8, from judge step 7, and from `corrected_syndromicity` and its
  application in `llm-judge.R:275`.
- `clinical_pattern` becomes `ellmer::type_enum` over the five values the prompt
  already names (`syndromic malformation`, `pure neurodevelopmental`,
  `progressive metabolic/degenerative`, `overgrowth syndrome`, `other`) and is
  validated server-side on read; an out-of-vocabulary value degrades to `other`
  with one logged warning rather than being served verbatim.
- `syndromicity` removed from `mcp_readonly_llm_summary_json_keys()` and from
  the inline fallback in `mcp-analysis-llm-cache-service.R`.
- `LLM_SUMMARY_PROMPT_VERSION` -> `1.1` (the generator contract changed).
- `db/migrations/008` holds a copy of the prompt text; a new migration updates
  the stored template so the DB copy does not contradict the code.

## Frontend and MCP

`LlmSummaryCard` renders the computed block as its own section, outside the
robot-provenance footer, showing `cluster_call`, `fraction_syndromic` and
`median_systems`. The LLM `Pattern` badge stays but under the AI provenance
line. `useLlmSummaryCard.ts` drops its `syndromicity` union type and its
`syndromicityVariant` / `syndromicityLabel` computeds in favour of the computed
block's own presenter.

MCP exposes the computed block in the phenotype analysis context labelled
`curated_derived_analysis`, never inside the LLM summary payload. Reads stay
DB-only and validated-only.

## Testing

- Registry completeness against live `phenotype_list` in **both** directions,
  and a static guard that no file outside the registry hardcodes an ID-severity
  HPO list.
- Entity-level: zero annotations -> `insufficient_annotation`; annotated with no
  organ term -> `no_recorded_extraneurological_involvement`; nested terms in one system counted once
  (`HP:0000077` + `HP:0000119` -> 1); course modifiers and the root excluded;
  the `ABCD1` worked example pinned at 3 systems.
- Cluster-level: threshold boundaries at exactly 0.25 / 0.75; an all-unannotated
  cluster -> `insufficient_annotation`; `fraction_syndromic` denominator excludes
  unannotated entities.
- Builder: the block is present on the phenotype payload and `cluster_hash` is
  byte-identical to the pre-change value for the same membership.
- Endpoint: `syndromicity` stripped from a cached `summary_json` that still
  contains it; `null` for an unknown `cluster_hash`; `clinical_pattern` outside
  the enum degrades to `other`.
- Frontend: card renders the computed block and does not badge it as AI-generated.

## Deploy

Restart `worker` and `worker-maintenance` (worker-executed code changed), then
`POST /api/admin/analysis/snapshots/refresh?analysis_type=phenotype_clusters&force=true`,
then the same for `phenotype_functional_correlations` (its dependency gate pins
the phenotype `snapshot_id`). No LLM regeneration is required; existing
summaries keep serving because `cluster_hash` is unchanged.

## Out of scope

Backfilling a syndromicity value onto historical superseded snapshots. Changing
which entities are clustered. Any entity-level curation UI for recording
syndromicity directly.


## Adversarial review outcomes

The draft of this spec was reviewed adversarially (Codex, gpt-5.6-sol, high
effort) against the actual code. Fourteen findings; the ones that changed the
design:

- **`isolated_ndd` inferred clinical absence from missing documentation.**
  Renamed to `no_recorded_extraneurological_involvement`. See the entity-level
  section.
- **Bumping `LLM_SUMMARY_PROMPT_VERSION` would have emptied two surfaces at
  once.** `get_cached_summary()` binds the version into every lookup
  (`llm-cache-repository.R:134`), so every cached `1.0` row would 404; and
  `mcp_public_llm_cluster_summary` pins `prompt_version = '1.0'` in SQL
  (`044_mcp_public_read_projections.sql:253`) while `mcp-analysis-repository.R:199`
  independently filters by the R constant, making the intersection empty. The
  version is therefore **not** bumped; the view is rebuilt only to drop the
  retired `syndromicity` key, and a guard test pins the R constant to the value
  the view hardcodes so the next legitimate bump fails loudly instead of
  silently.
- **The hash mechanism in the draft was wrong.** Corrected above; the conclusion
  survives because membership was verified identical.
- **`CLUSTER_LOGIC_VERSION` must still be bumped**, even though membership is
  invariant: it is persisted as generator provenance (#585), so leaving it stale
  would falsely identify the new output.
- **"Still three columns" does not prove `quanti.sup = 2:4` is still valid.**
  Every input-path test asserts the exact leading column NAMES.
- **Cluster-level `insufficient_annotation` is unreachable**, because the
  clustering input admits only entities with >=1 `present` annotation. Confirmed
  live: `coverage == 1.00` for all three clusters. The scope is stated in the
  aggregator's own documentation and `coverage` ships so the selection is
  visible.
- **Head size is a core NDD feature**, not extra-systemic. Reclassified, with
  `fraction_syndromic_with_head_size` shipping the alternative. This materially
  improved the result: cluster 2 moved from 0.745 (exactly on the cutoff) to
  0.658 with a CI that excludes it.
- **The retained `clinical_pattern` enum still carries syndromicity claims**
  (`pure neurodevelopmental`, `syndromic malformation`), so the LLM can
  contradict the computed measure under another name. The response carries a
  `conflicts_with_computed` flag rather than hiding the disagreement.
- **The builder read the entity data three times.** Annotation evidence is
  loaded once and passed to clustering, validation and aggregation.
- **The computed block must not live inside `LlmSummaryCard`**, which renders
  only when a non-rejected LLM summary exists — deterministic data would
  disappear whenever the model output did. It is a sibling card driven by the
  cluster row. (Also established: the existing "Pattern" badge is
  `summary.syndromicity`, and `clinical_pattern` was never typed or displayed.)
- **Missed surfaces**: `bootstrap/setup_workers.R` as well as
  `bootstrap/load_modules.R`; `documentation/02-web-tool.qmd:256`;
  `app/tests/docs-screenshots/helpers.ts:97`; the OpenAPI sample;
  `test-unit-phenotype-missingness.R:193`; the MCP canonical view hash and
  projection tests.

Findings not adopted as stated: renaming the whole measure away from
"syndromicity" (the field name is what consumers read, so the honesty belongs in
the value vocabulary and the `measures` string, not in hiding the term), and
removing the categorical `cluster_call` entirely (consumers need a label; it is
retained but demoted below `fraction_syndromic`, `coverage` and the interval).
