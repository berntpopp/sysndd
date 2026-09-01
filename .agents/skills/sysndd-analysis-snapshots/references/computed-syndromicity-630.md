# Computed syndromicity (#630)

> Extracted verbatim from `AGENTS.md` (2026-09-01) to keep the root instruction file lean.
> This is the authoritative detail for this subsystem.

Syndromicity has ONE definition in SysNDD, and it is computed, not generated.
`/api/analysis/phenotype_cluster_summary` used to return a per-cluster
`syndromicity` string produced by Gemini. It was **not reproducible on identical
input**: cache rows for `cluster_hash = f4a3dd1a27…` — same membership, same
model, 39 seconds apart — hold `predominantly_id`, `mixed`, `predominantly_id`,
and cluster 3 was served as both `predominantly_syndromic` and
`predominantly_id` under `validation_status: "validated"`. Worse, every
`pending` (pre-judge) row carried `syndromicity: "unknown"`: the generator
abstained and the value consumers read was the **judge's**
`corrected_syndromicity`, invented for a field the generator declined to fill.

- **`api/functions/syndromicity-registry.R` is the single source of truth.** It
  maps each of the 39 `phenotype_list` terms to a `role`
  (`ontology_root` | `course_modifier` | `ndd_core` | `neuro` | `organ`) and,
  for organ terms, a **collapsed** `system`. Collapsing is what removes
  double-counting: kidney + genitourinary are ONE `renal_urogenital`, skeletal +
  limbs one `skeletal`, metabolism + mitochondrion one `metabolic`, the four
  stature/weight terms one `growth`, oral cleft + facial shape one
  `craniofacial`. It is also the ONLY definition of the ID-severity term list,
  which previously existed as three hardcoded copies;
  `test-unit-id-term-hardcode-guard.R` fails if one reappears.
  `syndromicity_registry_assert_complete()` is **fail-closed in both
  directions** — a new vocabulary term with no registry entry, or a registry
  entry whose term was removed, raises rather than silently shifting the
  numerator or the denominator. Never wrap it in `tryCatch` on a request path.
- **Abnormal head size is `organ`, in its own `head_size` system.** OFC is a
  physical measurement -- a growth / dysmorphology finding like stature -- not a
  nervous-system function finding; HPO places `HP:0000252` under Abnormality of
  skull size -> head and neck, NOT under `HP:0000707`; and clinically
  micro-/macrocephaly is one of the features that makes an intellectual
  disability syndromic. Do not reclassify it as `neuro` on the argument that it
  "co-occurs with NDD" -- frequent co-occurrence is not the same as being the
  primary phenotype. Because it is the one genuinely contestable mapping choice,
  every payload carries `fraction_syndromic_excl_head_size` for the alternative
  reading.
- **No value is called `isolated`, at EITHER level.** The entity call is
  `no_recorded_extraneurological_involvement` and the cluster call is
  `predominantly_no_recorded_involvement`. SysNDD records explicit phenotype
  absence on **6 rows database-wide**, so "no organ system recorded" cannot be
  distinguished from "assessed and unaffected"; naming it `isolated` would infer
  clinical absence from missing documentation — the same defect this repo
  already documents for the MCA input (`analysis-phenotype-missingness.R`) and
  the one `kidney-genetics-db` ships via `COALESCE(is_syndromic, FALSE)`.
  `insufficient_annotation` stays a distinct third value for the same reason.
- **Only `present` counts as evidence** — the same rows
  `generate_phenotype_cluster_input()` admits to the MCA, so the measure and the
  partition can never disagree about what an annotation means. The
  `uncertain`/`variable`/`rare` rows are surfaced as `equivocal_term_count`, so
  the repository read must return ALL active modifiers, never a pre-filtered
  present-only set.
- **Scope: the cluster fraction describes an annotation-selected subset.** The
  clustering input admits only entities with >=1 `present` annotation, so for a
  cluster block `evaluable == entities` and `coverage == 1` by construction, and
  cluster-level `insufficient_annotation` is unreachable in production. Those
  fields still ship because the same aggregator serves entity sets that are not
  annotation-selected. `fraction_syndromic` is reported WITH `coverage` and a
  Wilson 95% interval; `cluster_call` is a convenience label over stated,
  versioned thresholds emitted inline in the payload, not the primary quantity.
- **The MCA supplementary variables are unified onto the registry.**
  `phenotype_non_id_count` (which counted the ontology root, both course
  modifiers and every nervous-system term as a syndromic feature, and
  double-counted nested terms) is now `extraneurological_system_count`. There
  are still exactly THREE quantitative supplementary columns because
  `gen_mca_clust_obj()` and `validate_phenotype_clusters()` address them
  POSITIONALLY (`quali.sup = 1:1`, `quanti.sup = 2:4`) — and an unchanged column
  COUNT does not prove an unchanged column ORDER, so every matrix path calls
  `phenotype_mca_assert_supplementary_layout()`. Supplementary variables are
  projected onto axes built from ACTIVE variables only, so **membership is
  unchanged**; verified live, not asserted (identical MCA coordinates, identical
  partition, identical member sets vs published snapshot 70).
- **`cluster_hash` is a hash of the cluster's sorted `entity_id` set**
  (`analysis-phenotype-functions.R` -> `data-helpers.R:219`), NOT
  `cluster_signature_hash` (a separate, currently unused top-5-term hash). Since
  membership is unchanged, the hashes are unchanged and **every cached LLM
  summary survives**. `payload_hash` does change (the payload gained a result),
  so the correlation snapshot must be force-refreshed after the cluster one and
  the next analysis release gets a new `release_id`.
- **`LLM_SUMMARY_PROMPT_VERSION` is deliberately NOT bumped, and this is
  load-bearing.** `get_cached_summary()` binds the version into every lookup, so
  a bump 404s every cached summary until an administrator regenerates; and
  `mcp_public_llm_cluster_summary` pins the version in SQL while
  `mcp-analysis-repository.R` independently filters the view by the R constant,
  so a one-sided bump makes the MCP intersection EMPTY. The retired field is
  stripped on READ instead (`llm_summary_strip_llm_syndromicity()`), and
  migration `054` rebuilds the view without the key.
  `test-unit-llm-prompt-version-pin.R` fails if the R constant and the SQL
  literal ever diverge, so the next legitimate bump is a loud failure rather
  than a silent outage of two surfaces.
- **`clinical_pattern` is now an `ellmer::type_enum`** over the five values the
  prompt already named, validated server-side on read, with the observed
  production drift (`"progressive metabolic disorders"`,
  `"syndromic malformations"`, `"overgrowth syndromes"`) aliased rather than
  degraded to `other`. It still contains two syndromicity-bearing values, so it
  can contradict the computed measure; the response carries
  `pattern_conflicts_with_computed` rather than hiding that.
  `validation_status` now travels with a `validation_scope` string naming what
  the judge does and does not cover.
- **The summary endpoint serves the FROZEN block the snapshot stored**
  (`syndromicity_stored_block_for_cluster()`), never a live recomputation:
  `cluster_hash` hashes membership only, so recomputing would drift from the
  published `/phenotype_clustering` payload as curation continued, and would add
  two DB round trips to every cache hit.
- **The computed block is rendered by `SyndromicityCard.vue`, NOT inside
  `LlmSummaryCard`**, which only mounts when a non-rejected LLM summary exists —
  deterministic, curation-derived data must not disappear because a model output
  did. It is driven by the cluster row, which carries the block via
  `metadata_json`.
- Register new modules in BOTH `bootstrap/load_modules.R` and
  `bootstrap/setup_workers.R`. Current order: `syndromicity-registry.R` ->
  `syndromicity-classify.R` -> `syndromicity-repository.R` ->
  `syndromicity-snapshot.R`, all before `analysis-phenotype-mca-prep.R`.
- **Deploy:** restart `worker` and `worker-maintenance`, force-refresh
  `phenotype_clusters`, then force-refresh `phenotype_functional_correlations`
  (its dependency gate pins the phenotype `snapshot_id`). No LLM regeneration is
  required.

