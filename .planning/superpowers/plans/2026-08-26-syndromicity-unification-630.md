# Syndromicity Unification (#630) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the model-generated, non-reproducible cluster `syndromicity` label with one computed, versioned, registry-backed definition used everywhere SysNDD talks about syndromicity.

**Architecture:** A single fail-closed registry classifies each of the 39 `phenotype_list` terms by role and collapsed organ system. One pure classifier turns an entity's `present` annotations into a syndromicity result; one pure aggregator turns a set of those into a cluster block. The snapshot builder attaches the block as a clusters-tibble column, which existing machinery carries to the API with no schema change. The same registry supplies the MCA quantitative supplementary counts and the ID-severity term list, retiring three hardcoded copies.

**Tech Stack:** R (plumber, dplyr, tibble, testthat), MySQL, Vue 3 + TypeScript (vitest).

**Spec:** `.planning/superpowers/specs/2026-08-26-syndromicity-unification-630-design.md`

## Global Constraints

- `SYNDROMICITY_RULE_VERSION <- "1.0"`. Emitted in every payload the measure produces.
- Thresholds, emitted inline in every cluster payload: `syndromic_system_count = 1L`, `predominantly_syndromic = 0.75`, `predominantly_isolated = 0.25`, `min_evaluable_fraction = 0.5`.
- Evidence filter is exactly `is_primary = 1 AND review_approved = 1`, `is_active = 1`, `modifier_name == "present"` — byte-identical to `generate_phenotype_cluster_input()`.
- `data_class` for every computed syndromicity payload is `"curated_derived_analysis"`. Never `llm_generated_summary`.
- `CLUSTER_LOGIC_VERSION` is **not** bumped (verified: membership is invariant under the supplementary-column change).
- `LLM_SUMMARY_PROMPT_VERSION` -> `"1.1"`.
- Namespace `dplyr::` explicitly; use `base::get(...)` never bare `get(..., mode=)`.
- Every new file is registered in `api/bootstrap/load_modules.R` in the task that creates it. Files are not autodiscovered.
- No file may exceed 600 lines, test files included.
- Never reference any manuscript, figure number, or external publication in any repository file.

---

### Task 1: Syndromicity registry

**Files:**
- Create: `api/functions/syndromicity-registry.R`
- Modify: `api/bootstrap/load_modules.R` (insert `"functions/syndromicity-registry.R"` immediately BEFORE `"functions/analysis-phenotype-mca-prep.R"`, line ~168)
- Test: `api/tests/testthat/test-unit-syndromicity-registry.R`

**Interfaces:**
- Consumes: nothing.
- Produces: `SYNDROMICITY_RULE_VERSION` (character scalar), `syndromicity_registry()` -> tibble with columns `phenotype_id`, `role`, `system`; `syndromicity_id_severity_terms()` -> character vector; `syndromicity_registry_assert_complete(vocabulary_ids)` -> invisible TRUE or `stop()`.

- [ ] **Step 1: Write the failing test**

```r
# api/tests/testthat/test-unit-syndromicity-registry.R
source_api_file("functions/syndromicity-registry.R", local = FALSE)

test_that("registry covers exactly the roles the rule defines", {
  reg <- syndromicity_registry()
  expect_setequal(
    unique(reg$role),
    c("ontology_root", "course_modifier", "ndd_core", "neuro", "organ")
  )
  expect_true(all(!is.na(reg$system[reg$role %in% c("organ", "neuro")])))
  expect_true(all(is.na(reg$system[reg$role %in%
    c("ontology_root", "course_modifier", "ndd_core")])))
})

test_that("the ontology root and clinical-course modifiers never carry a system", {
  reg <- syndromicity_registry()
  expect_equal(reg$role[reg$phenotype_id == "HP:0000118"], "ontology_root")
  expect_equal(reg$role[reg$phenotype_id == "HP:0003676"], "course_modifier")
  expect_equal(reg$role[reg$phenotype_id == "HP:0011420"], "course_modifier")
})

test_that("nested terms collapse into one system", {
  reg <- syndromicity_registry()
  sys_of <- function(id) reg$system[reg$phenotype_id == id]
  expect_equal(sys_of("HP:0000077"), sys_of("HP:0000119")) # kidney == genitourinary
  expect_equal(sys_of("HP:0000924"), sys_of("HP:0040064")) # skeletal == limbs
  expect_equal(sys_of("HP:0001939"), sys_of("HP:0012103")) # metabolism == mitochondrion
  expect_equal(sys_of("HP:0000202"), sys_of("HP:0001999")) # oral cleft == facial shape
  expect_equal(sys_of("HP:0000098"), sys_of("HP:0004322")) # tall == short stature
})

test_that("the six ID severity terms are the ndd_core role and nothing else", {
  expect_setequal(
    syndromicity_id_severity_terms(),
    c("HP:0001249", "HP:0001256", "HP:0002342", "HP:0010864",
      "HP:0002187", "HP:0006889")
  )
})

test_that("assert_complete is fail-closed in BOTH directions", {
  reg_ids <- syndromicity_registry()$phenotype_id
  expect_true(syndromicity_registry_assert_complete(reg_ids))
  expect_error(
    syndromicity_registry_assert_complete(c(reg_ids, "HP:9999999")),
    "not classified"
  )
  expect_error(
    syndromicity_registry_assert_complete(setdiff(reg_ids, "HP:0001250")),
    "no longer present"
  )
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-registry.R')"`
Expected: FAIL — `could not find function "syndromicity_registry"`.

- [ ] **Step 3: Write minimal implementation**

```r
# api/functions/syndromicity-registry.R
#
# Single source of truth for how SysNDD defines syndromicity (#630).
#
# SysNDD annotates entities against a FIXED 39-term controlled vocabulary
# (phenotype_list), not free HPO, so classification is a static auditable table
# rather than a descendant expansion. Each term carries a role and, for terms
# that represent organ involvement, a COLLAPSED system: HP:0000077 (kidney) and
# HP:0000119 (genitourinary) are one system, not two, which is what stops a
# single clinical finding being counted twice.
#
# Roles and what they mean for the measure:
#   ontology_root   HP:0000118 - ancestor of every other term; never counted.
#   course_modifier Progressive / Age of death - clinical course, not organ
#                   involvement; never counted.
#   ndd_core        Intellectual disability + its five severity grades - the NDD
#                   phenotype itself, so never an "additional" feature.
#   neuro           Nervous-system findings. In NDD the nervous system IS the
#                   primary phenotype, so these are reported separately and are
#                   NOT part of the syndromicity numerator. This is also why the
#                   sibling kidney-genetics category set is not portable: its
#                   `neurologic` indicator is our core.
#   organ           Extra-neurological organ involvement - the numerator.

SYNDROMICITY_RULE_VERSION <- "1.0"

syndromicity_registry <- function() {
  tibble::tribble(
    ~phenotype_id, ~role,             ~system,
    "HP:0000118",  "ontology_root",   NA_character_,
    "HP:0003676",  "course_modifier", NA_character_,
    "HP:0011420",  "course_modifier", NA_character_,
    "HP:0001249",  "ndd_core",        NA_character_,
    "HP:0001256",  "ndd_core",        NA_character_,
    "HP:0002342",  "ndd_core",        NA_character_,
    "HP:0010864",  "ndd_core",        NA_character_,
    "HP:0002187",  "ndd_core",        NA_character_,
    "HP:0006889",  "ndd_core",        NA_character_,
    "HP:0000707",  "neuro",           "nervous_system",
    "HP:0000708",  "neuro",           "nervous_system",
    "HP:0001250",  "neuro",           "nervous_system",
    "HP:0002011",  "neuro",           "nervous_system",
    "HP:0002270",  "neuro",           "nervous_system",
    "HP:0002376",  "neuro",           "nervous_system",
    "HP:0000077",  "organ",           "renal_urogenital",
    "HP:0000119",  "organ",           "renal_urogenital",
    "HP:0000924",  "organ",           "skeletal",
    "HP:0040064",  "organ",           "skeletal",
    "HP:0001939",  "organ",           "metabolic",
    "HP:0012103",  "organ",           "metabolic",
    "HP:0000098",  "organ",           "growth",
    "HP:0004322",  "organ",           "growth",
    "HP:0001548",  "organ",           "growth",
    "HP:0001513",  "organ",           "growth",
    "HP:0000202",  "organ",           "craniofacial",
    "HP:0001999",  "organ",           "craniofacial",
    "HP:0000252",  "organ",           "head_size",
    "HP:0000256",  "organ",           "head_size",
    "HP:0000365",  "organ",           "ear_hearing",
    "HP:0000478",  "organ",           "eye",
    "HP:0000818",  "organ",           "endocrine",
    "HP:0001574",  "organ",           "integument",
    "HP:0001627",  "organ",           "cardiovascular",
    "HP:0001871",  "organ",           "hematologic",
    "HP:0002664",  "organ",           "neoplasm",
    "HP:0002715",  "organ",           "immune",
    "HP:0003011",  "organ",           "musculature",
    "HP:0011024",  "organ",           "gastrointestinal"
  )
}

#' The ID / ID-severity terms. Single definition; callers must not re-list these.
syndromicity_id_severity_terms <- function() {
  reg <- syndromicity_registry()
  reg$phenotype_id[reg$role == "ndd_core"]
}

#' Fail closed against the live vocabulary, in BOTH directions.
#'
#' A new phenotype_list term with no registry entry would silently vanish from
#' the measure; a registry entry whose term was removed would silently rot. Both
#' raise. Callers on a request path must NOT wrap this in tryCatch.
syndromicity_registry_assert_complete <- function(vocabulary_ids) {
  reg_ids <- syndromicity_registry()$phenotype_id
  missing <- setdiff(vocabulary_ids, reg_ids)
  if (length(missing) > 0L) {
    stop(sprintf(
      "syndromicity registry: phenotype_list term(s) not classified: %s",
      paste(sort(missing), collapse = ", ")
    ), call. = FALSE)
  }
  stale <- setdiff(reg_ids, vocabulary_ids)
  if (length(stale) > 0L) {
    stop(sprintf(
      "syndromicity registry: classified term(s) no longer present in phenotype_list: %s",
      paste(sort(stale), collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-registry.R')"`
Expected: PASS, 5 tests.

- [ ] **Step 5: Register the module and commit**

Insert into `api/bootstrap/load_modules.R` immediately before `"functions/analysis-phenotype-mca-prep.R"`:

```r
    # #630: single definition of syndromicity (roles + collapsed organ systems)
    # and of the ID-severity term list. Registered BEFORE the phenotype MCA prep
    # and the phenotype functions, which consume it for the supplementary counts.
    "functions/syndromicity-registry.R",
```

```bash
git add api/functions/syndromicity-registry.R api/tests/testthat/test-unit-syndromicity-registry.R api/bootstrap/load_modules.R
git commit -m "feat(630): syndromicity registry with fail-closed vocabulary assertion"
```

---

### Task 2: Entity classifier and cluster aggregator

**Files:**
- Create: `api/functions/syndromicity-classify.R`
- Modify: `api/bootstrap/load_modules.R` (insert immediately AFTER `"functions/syndromicity-registry.R"`)
- Test: `api/tests/testthat/test-unit-syndromicity-classify.R`

**Interfaces:**
- Consumes: `syndromicity_registry()`, `SYNDROMICITY_RULE_VERSION` from Task 1.
- Produces:
  - `syndromicity_classify_entities(annotations)` — `annotations` is a data.frame with columns `entity_id` (integer), `phenotype_id` (character), `modifier_name` (character). Returns a tibble with one row per **distinct `entity_id` present in `annotations`** and columns `entity_id`, `system_count` (int), `systems` (list of character), `neurological_involvement` (lgl), `present_term_count` (int), `equivocal_term_count` (int), `call` (chr).
  - `syndromicity_entity_result(row)` — one classifier row -> the named list the API serialises.
  - `syndromicity_aggregate_cluster(entity_rows)` — classifier tibble -> the named list the cluster payload carries.
  - `SYNDROMICITY_THRESHOLDS` — named list.

- [ ] **Step 1: Write the failing test**

```r
# api/tests/testthat/test-unit-syndromicity-classify.R
source_api_file("functions/syndromicity-registry.R", local = FALSE)
source_api_file("functions/syndromicity-classify.R", local = FALSE)

ann <- function(...) {
  rows <- list(...)
  do.call(rbind, lapply(rows, function(r) {
    data.frame(entity_id = r[[1]], phenotype_id = r[[2]],
               modifier_name = r[[3]], stringsAsFactors = FALSE)
  }))
}

test_that("nested terms in one system count once", {
  out <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000077", "present"),   # kidney
    list(1L, "HP:0000119", "present")    # genitourinary -> same system
  ))
  expect_equal(out$system_count, 1L)
  expect_equal(out$systems[[1]], "renal_urogenital")
  expect_equal(out$call, "syndromic")
})

test_that("root, course modifiers, ID core and neuro never enter the numerator", {
  out <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000118", "present"),   # ontology root
    list(1L, "HP:0003676", "present"),   # Progressive
    list(1L, "HP:0011420", "present"),   # Age of death
    list(1L, "HP:0001249", "present"),   # ID
    list(1L, "HP:0001250", "present")    # Seizures -> neuro
  ))
  expect_equal(out$system_count, 0L)
  expect_true(out$neurological_involvement)
  expect_equal(out$call, "isolated_ndd")
})

test_that("no present annotation is insufficient_annotation, not isolated", {
  out <- syndromicity_classify_entities(ann(
    list(1L, "HP:0001250", "uncertain")
  ))
  expect_equal(out$call, "insufficient_annotation")
  expect_equal(out$present_term_count, 0L)
  expect_equal(out$equivocal_term_count, 1L)
})

test_that("the ABCD1 worked example yields three extra-neurological systems", {
  out <- syndromicity_classify_entities(ann(
    list(4L, "HP:0000077", "present"), list(4L, "HP:0000707", "present"),
    list(4L, "HP:0000708", "present"), list(4L, "HP:0000818", "present"),
    list(4L, "HP:0001249", "present"), list(4L, "HP:0001939", "present"),
    list(4L, "HP:0002011", "present"), list(4L, "HP:0003676", "present")
  ))
  expect_equal(out$system_count, 3L)
  expect_setequal(out$systems[[1]], c("renal_urogenital", "endocrine", "metabolic"))
  expect_true(out$neurological_involvement)
  expect_equal(out$call, "syndromic")
})

test_that("an unclassified term raises rather than being dropped", {
  expect_error(
    syndromicity_classify_entities(ann(list(1L, "HP:9999999", "present"))),
    "not classified"
  )
})

test_that("cluster aggregate excludes unannotated entities from the denominator", {
  rows <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000077", "present"),   # syndromic
    list(2L, "HP:0001249", "present"),   # isolated
    list(3L, "HP:0001249", "uncertain")  # insufficient
  ))
  agg <- syndromicity_aggregate_cluster(rows)
  expect_equal(agg$entities, 3L)
  expect_equal(agg$evaluable, 2L)
  expect_equal(agg$insufficient_annotation, 1L)
  expect_equal(agg$fraction_syndromic, 0.5)
  expect_equal(agg$cluster_call, "mixed")
  expect_equal(agg$data_class, "curated_derived_analysis")
  expect_equal(agg$rule_version, SYNDROMICITY_RULE_VERSION)
})

test_that("cluster_call thresholds are inclusive at exactly 0.75 and 0.25", {
  mk <- function(n_syn, n_iso) {
    rows <- do.call(rbind, c(
      lapply(seq_len(n_syn), function(i)
        data.frame(entity_id = i, phenotype_id = "HP:0000077",
                   modifier_name = "present", stringsAsFactors = FALSE)),
      lapply(seq_len(n_iso), function(i)
        data.frame(entity_id = 1000L + i, phenotype_id = "HP:0001249",
                   modifier_name = "present", stringsAsFactors = FALSE))
    ))
    syndromicity_aggregate_cluster(syndromicity_classify_entities(rows))
  }
  expect_equal(mk(3, 1)$cluster_call, "predominantly_syndromic") # 0.75
  expect_equal(mk(1, 3)$cluster_call, "predominantly_isolated")  # 0.25
  expect_equal(mk(2, 1)$cluster_call, "mixed")                   # 0.667
})

test_that("a cluster that is mostly unannotated reports insufficient_annotation", {
  rows <- syndromicity_classify_entities(do.call(rbind, c(
    list(data.frame(entity_id = 1L, phenotype_id = "HP:0000077",
                    modifier_name = "present", stringsAsFactors = FALSE)),
    lapply(2:5, function(i)
      data.frame(entity_id = i, phenotype_id = "HP:0001249",
                 modifier_name = "uncertain", stringsAsFactors = FALSE))
  )))
  expect_equal(syndromicity_aggregate_cluster(rows)$cluster_call,
               "insufficient_annotation")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-classify.R')"`
Expected: FAIL — `could not find function "syndromicity_classify_entities"`.

- [ ] **Step 3: Write minimal implementation**

```r
# api/functions/syndromicity-classify.R
#
# Pure classification and aggregation for the computed syndromicity measure
# (#630). No DB access, no side effects, deterministic — the repository layer
# supplies rows, this file decides what they mean.

SYNDROMICITY_THRESHOLDS <- list(
  syndromic_system_count  = 1L,
  predominantly_syndromic = 0.75,
  predominantly_isolated  = 0.25,
  min_evaluable_fraction  = 0.5
)

#' Classify entities from their annotation rows.
#'
#' `annotations` needs `entity_id`, `phenotype_id`, `modifier_name`. Only
#' `present` rows are evidence — matching generate_phenotype_cluster_input()
#' exactly, so the measure and the clustering partition can never disagree about
#' what an annotation means. Non-present rows are counted as `equivocal` so the
#' ambiguity is visible rather than hidden.
syndromicity_classify_entities <- function(annotations) {
  ann <- tibble::as_tibble(annotations)
  if (nrow(ann) == 0L) {
    return(tibble::tibble(
      entity_id = integer(), system_count = integer(), systems = list(),
      neurological_involvement = logical(), present_term_count = integer(),
      equivocal_term_count = integer(), call = character()
    ))
  }

  reg <- syndromicity_registry()
  observed <- unique(ann$phenotype_id[!is.na(ann$phenotype_id)])
  unknown <- setdiff(observed, reg$phenotype_id)
  if (length(unknown) > 0L) {
    stop(sprintf(
      "syndromicity: annotation term(s) not classified in the registry: %s",
      paste(sort(unknown), collapse = ", ")
    ), call. = FALSE)
  }

  ann <- dplyr::left_join(ann, reg, by = "phenotype_id")
  present <- ann[!is.na(ann$modifier_name) & ann$modifier_name == "present", , drop = FALSE]
  equivocal <- ann[is.na(ann$modifier_name) | ann$modifier_name != "present", , drop = FALSE]

  entity_ids <- sort(unique(ann$entity_id))
  rows <- lapply(entity_ids, function(id) {
    p <- present[present$entity_id == id, , drop = FALSE]
    e <- equivocal[equivocal$entity_id == id, , drop = FALSE]
    systems <- sort(unique(p$system[!is.na(p$system) & p$role == "organ"]))
    neuro <- any(p$role == "neuro", na.rm = TRUE)
    n_present <- nrow(p)
    call <- if (n_present == 0L) {
      "insufficient_annotation"
    } else if (length(systems) >= SYNDROMICITY_THRESHOLDS$syndromic_system_count) {
      "syndromic"
    } else {
      "isolated_ndd"
    }
    tibble::tibble(
      entity_id = as.integer(id),
      system_count = length(systems),
      systems = list(as.character(systems)),
      neurological_involvement = isTRUE(neuro),
      present_term_count = as.integer(n_present),
      equivocal_term_count = as.integer(nrow(e)),
      call = call
    )
  })
  dplyr::bind_rows(rows)
}

#' One classifier row -> the named list the API serialises.
syndromicity_entity_result <- function(row) {
  list(
    entity_id = as.integer(row$entity_id[[1]]),
    rule_version = SYNDROMICITY_RULE_VERSION,
    data_class = "curated_derived_analysis",
    extraneurological_systems = as.character(row$systems[[1]]),
    system_count = as.integer(row$system_count[[1]]),
    neurological_involvement = isTRUE(row$neurological_involvement[[1]]),
    present_term_count = as.integer(row$present_term_count[[1]]),
    equivocal_term_count = as.integer(row$equivocal_term_count[[1]]),
    call = as.character(row$call[[1]])
  )
}

#' Aggregate classifier rows into the per-cluster payload block.
#'
#' `fraction_syndromic` is over EVALUABLE entities (those with >=1 present
#' annotation). Folding unannotated entities into the denominator would report
#' annotation absence as evidence of isolated NDD.
syndromicity_aggregate_cluster <- function(entity_rows) {
  rows <- tibble::as_tibble(entity_rows)
  n <- nrow(rows)
  insufficient <- sum(rows$call == "insufficient_annotation")
  isolated <- sum(rows$call == "isolated_ndd")
  syndromic <- sum(rows$call == "syndromic")
  evaluable <- n - insufficient

  fraction <- if (evaluable > 0L) round(syndromic / evaluable, 4) else NA_real_
  evaluable_ok <- n > 0L &&
    (evaluable / n) >= SYNDROMICITY_THRESHOLDS$min_evaluable_fraction

  cluster_call <- if (!evaluable_ok || is.na(fraction)) {
    "insufficient_annotation"
  } else if (fraction >= SYNDROMICITY_THRESHOLDS$predominantly_syndromic) {
    "predominantly_syndromic"
  } else if (fraction <= SYNDROMICITY_THRESHOLDS$predominantly_isolated) {
    "predominantly_isolated"
  } else {
    "mixed"
  }

  evaluable_rows <- rows[rows$call != "insufficient_annotation", , drop = FALSE]
  freq <- table(unlist(evaluable_rows$systems))
  system_frequencies <- if (length(freq) == 0L) {
    stats::setNames(list(), character())
  } else {
    as.list(stats::setNames(as.integer(freq), names(freq)))
  }

  list(
    rule_version = SYNDROMICITY_RULE_VERSION,
    data_class = "curated_derived_analysis",
    entities = as.integer(n),
    evaluable = as.integer(evaluable),
    insufficient_annotation = as.integer(insufficient),
    isolated_ndd = as.integer(isolated),
    syndromic = as.integer(syndromic),
    fraction_syndromic = fraction,
    median_systems = if (nrow(evaluable_rows) > 0L)
      stats::median(evaluable_rows$system_count) else NA_real_,
    mean_systems = if (nrow(evaluable_rows) > 0L)
      round(mean(evaluable_rows$system_count), 3) else NA_real_,
    system_frequencies = system_frequencies,
    cluster_call = cluster_call,
    thresholds = SYNDROMICITY_THRESHOLDS
  )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-classify.R')"`
Expected: PASS, 8 tests.

- [ ] **Step 5: Register the module and commit**

Insert into `api/bootstrap/load_modules.R` immediately after `"functions/syndromicity-registry.R"`:

```r
    "functions/syndromicity-classify.R",
```

```bash
git add api/functions/syndromicity-classify.R api/tests/testthat/test-unit-syndromicity-classify.R api/bootstrap/load_modules.R
git commit -m "feat(630): entity classifier and cluster aggregator for computed syndromicity"
```

---

### Task 3: Unify the MCA supplementary counts onto the registry

Retires the three hardcoded ID-term copies and replaces `phenotype_non_id_count` with the registry-derived `extraneurological_system_count`. Column ORDER and COUNT must not change: `gen_mca_clust_obj()` and `validate_phenotype_clusters()` address supplementary columns positionally (`quali_sup_var = 1:1`, `quanti_sup_var = 2:4`).

**Files:**
- Modify: `api/functions/syndromicity-classify.R` (add `syndromicity_supplementary_counts()`)
- Modify: `api/functions/analysis-phenotype-functions.R:179-249`
- Modify: `api/services/job-phenotype-submission-service.R:51,116-129`
- Modify: `api/functions/async-job-handlers.R:193-206`
- Test: `api/tests/testthat/test-unit-syndromicity-supplementary.R`
- Test: `api/tests/testthat/test-unit-id-term-hardcode-guard.R`

**Interfaces:**
- Consumes: `syndromicity_registry()`, `syndromicity_classify_entities()`.
- Produces: `syndromicity_supplementary_counts(annotations)` -> tibble `entity_id`, `extraneurological_system_count` (int), `phenotype_id_count` (int).

- [ ] **Step 1: Write the failing tests**

```r
# api/tests/testthat/test-unit-syndromicity-supplementary.R
source_api_file("functions/syndromicity-registry.R", local = FALSE)
source_api_file("functions/syndromicity-classify.R", local = FALSE)

test_that("supplementary counts are registry-derived and collapse systems", {
  out <- syndromicity_supplementary_counts(data.frame(
    entity_id = c(1L, 1L, 1L, 1L, 1L),
    phenotype_id = c("HP:0000077", "HP:0000119", "HP:0001249",
                     "HP:0001256", "HP:0003676"),
    modifier_name = "present", stringsAsFactors = FALSE
  ))
  expect_equal(out$extraneurological_system_count, 1L) # kidney+GU collapse
  expect_equal(out$phenotype_id_count, 2L)             # ID + ID mild
})

test_that("the old flat non-ID count and the new system count differ as designed", {
  rows <- data.frame(
    entity_id = 1L,
    phenotype_id = c("HP:0000077", "HP:0000119", "HP:0000707",
                     "HP:0003676", "HP:0000118"),
    modifier_name = "present", stringsAsFactors = FALSE
  )
  old_flat <- sum(!rows$phenotype_id %in% syndromicity_id_severity_terms())
  expect_equal(old_flat, 5L)
  expect_equal(syndromicity_supplementary_counts(rows)$extraneurological_system_count, 1L)
})
```

```r
# api/tests/testthat/test-unit-id-term-hardcode-guard.R
test_that("no file outside the registry hardcodes the ID severity term list", {
  root <- get_api_dir()
  files <- list.files(
    file.path(root, c("functions", "services", "endpoints")),
    pattern = "[.]R$", full.names = TRUE, recursive = TRUE
  )
  files <- files[basename(files) != "syndromicity-registry.R"]
  offenders <- Filter(function(f) {
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    grepl("HP:0001249", txt, fixed = TRUE) &&
      grepl("HP:0010864", txt, fixed = TRUE)
  }, files)
  expect_equal(
    basename(offenders), character(0),
    info = paste("ID severity terms must come from syndromicity_id_severity_terms():",
                 paste(basename(offenders), collapse = ", "))
  )
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-supplementary.R'); testthat::test_file('tests/testthat/test-unit-id-term-hardcode-guard.R')"`
Expected: first FAILs with `could not find function "syndromicity_supplementary_counts"`; second FAILs listing `analysis-phenotype-functions.R` and `job-phenotype-submission-service.R`.

- [ ] **Step 3: Add the helper**

Append to `api/functions/syndromicity-classify.R`:

```r
#' Registry-derived MCA quantitative supplementary counts.
#'
#' Returns exactly TWO count columns; the caller adds gene_entity_count, keeping
#' the supplementary block at three columns so the positional quanti_sup_var =
#' 2:4 addressing in gen_mca_clust_obj() and validate_phenotype_clusters() is
#' preserved.
#'
#' `extraneurological_system_count` replaces the former `phenotype_non_id_count`,
#' which counted the ontology root, the clinical-course modifiers and the
#' nervous-system terms as syndromic features. Supplementary variables are
#' projected onto axes built from ACTIVE variables only, so this changes no
#' cluster membership (verified end to end on the live 1931-entity matrix:
#' identical MCA coordinates, identical partition).
syndromicity_supplementary_counts <- function(annotations) {
  classified <- syndromicity_classify_entities(annotations)
  ann <- tibble::as_tibble(annotations)
  id_terms <- syndromicity_id_severity_terms()
  id_counts <- ann |>
    dplyr::filter(.data$modifier_name == "present",
                  .data$phenotype_id %in% id_terms) |>
    dplyr::distinct(.data$entity_id, .data$phenotype_id) |>
    dplyr::count(.data$entity_id, name = "phenotype_id_count")

  classified |>
    dplyr::select(entity_id, extraneurological_system_count = "system_count") |>
    dplyr::left_join(id_counts, by = "entity_id") |>
    dplyr::mutate(
      extraneurological_system_count = as.integer(.data$extraneurological_system_count),
      phenotype_id_count = as.integer(dplyr::coalesce(.data$phenotype_id_count, 0L))
    )
}
```

- [ ] **Step 4: Replace the three hardcoded call sites**

In `api/functions/analysis-phenotype-functions.R`, delete the `id_phenotype_ids <- c(...)` literal at line 179 and replace the `dplyr::group_by(entity_id) %>% dplyr::mutate(phenotype_non_id_count = ..., phenotype_id_count = ...)` block (lines ~226-231) with a join on the helper:

```r
  supp <- syndromicity_supplementary_counts(
    dplyr::select(joined_raw, entity_id, phenotype_id, modifier_name)
  )
  joined <- joined %>%
    dplyr::left_join(supp, by = "entity_id")
```

where `joined_raw` is the pre-`dplyr::select()` frame that still carries `modifier_name`. Keep `dplyr::relocate(extraneurological_system_count, .before = phenotype_id_count)` and the existing `dplyr::relocate(gene_entity_count, .after = phenotype_id_count)` so column order stays `inheritance, extraneurological_system_count, phenotype_id_count, gene_entity_count`.

Apply the identical replacement in `api/services/job-phenotype-submission-service.R` (delete the literal at line 51; rewrite lines 116-129) and in `api/functions/async-job-handlers.R` (lines 193-206 consume `payload$id_phenotype_ids`; change the payload to carry the annotation rows' `modifier_name` and call the same helper, so the interactive job and the served snapshot cannot diverge).

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-supplementary.R'); testthat::test_file('tests/testthat/test-unit-id-term-hardcode-guard.R')"`
Expected: PASS.

- [ ] **Step 6: Verify membership invariance against the live matrix**

Run the invariance check inside the running API container (it needs the real 1931-entity matrix, RMariaDB and FactoMineR):

```bash
docker exec sysndd-api-1 Rscript /tmp/exp3.R
```
Expected output must contain:
```
identical MCA active coordinates : TRUE
identical cluster membership     : TRUE
```
If either is FALSE, STOP — the change is not supplementary-only and the plan's core assumption is broken.

- [ ] **Step 7: Commit**

```bash
git add api/functions/syndromicity-classify.R api/functions/analysis-phenotype-functions.R api/services/job-phenotype-submission-service.R api/functions/async-job-handlers.R api/tests/testthat/test-unit-syndromicity-supplementary.R api/tests/testthat/test-unit-id-term-hardcode-guard.R
git commit -m "refactor(630): derive MCA supplementary counts from the syndromicity registry"
```

---

### Task 4: Repository reads

**Files:**
- Create: `api/functions/syndromicity-repository.R`
- Modify: `api/bootstrap/load_modules.R` (after `"functions/syndromicity-classify.R"`)
- Test: `api/tests/testthat/test-integration-syndromicity-repository.R`

**Interfaces:**
- Consumes: Task 2's classifier.
- Produces:
  - `syndromicity_annotations_for_entities(entity_ids, conn = NULL)` -> data.frame `entity_id`, `phenotype_id`, `modifier_name`.
  - `syndromicity_cluster_member_ids(cluster_hash, conn = NULL)` -> integer vector, pinned to the current public-ready `phenotype_clusters` snapshot; `integer(0)` when the hash is not in it.

- [ ] **Step 1: Write the failing test**

```r
# api/tests/testthat/test-integration-syndromicity-repository.R
skip_if_missing_sysndd_schema()
source_api_file("functions/syndromicity-registry.R", local = FALSE)
source_api_file("functions/syndromicity-classify.R", local = FALSE)
source_api_file("functions/syndromicity-repository.R", local = FALSE)

test_that("annotations come only from primary approved reviews", {
  with_test_db_transaction({
    rows <- syndromicity_annotations_for_entities(c(1L, 2L))
    expect_true(all(c("entity_id", "phenotype_id", "modifier_name") %in% names(rows)))
    expect_true(all(rows$entity_id %in% c(1L, 2L)))
  })
})

test_that("an unknown cluster hash yields no members rather than an error", {
  with_test_db_transaction({
    expect_equal(syndromicity_cluster_member_ids("not-a-real-hash"), integer(0))
  })
})

test_that("the live vocabulary satisfies the registry in both directions", {
  with_test_db_transaction({
    ids <- db_execute_query("SELECT phenotype_id FROM phenotype_list")$phenotype_id
    expect_true(syndromicity_registry_assert_complete(ids))
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-syndromicity-repository.R')"`
Expected: FAIL — `could not find function "syndromicity_annotations_for_entities"`. (If it SKIPs, load the schema first with `make test-db-schema` — a wall of skips is not a pass.)

- [ ] **Step 3: Write the implementation**

```r
# api/functions/syndromicity-repository.R
#
# DB reads for the computed syndromicity measure (#630). One query per call,
# never one per entity. Parameters are BOUND, never interpolated. Entity
# visibility is enforced inside the same statement via ndd_entity_view, so a
# non-public entity cannot leak annotations.

syndromicity_annotations_for_entities <- function(entity_ids, conn = NULL) {
  ids <- unique(as.integer(entity_ids))
  ids <- ids[!is.na(ids)]
  if (length(ids) == 0L) {
    return(data.frame(entity_id = integer(), phenotype_id = character(),
                      modifier_name = character(), stringsAsFactors = FALSE))
  }
  placeholders <- paste(rep("?", length(ids)), collapse = ", ")
  sql <- sprintf("
    SELECT c.entity_id, c.phenotype_id, m.modifier_name
    FROM ndd_review_phenotype_connect c
    JOIN ndd_entity_review r
      ON r.review_id = c.review_id
     AND r.entity_id = c.entity_id
     AND r.is_primary = 1
     AND r.review_approved = 1
    JOIN ndd_entity_view v ON v.entity_id = c.entity_id
    JOIN modifier_list m ON m.modifier_id = c.modifier_id
    WHERE c.is_active = 1 AND c.entity_id IN (%s)", placeholders)
  db_execute_query(sql, params = unname(as.list(ids)), conn = conn)
}

syndromicity_cluster_member_ids <- function(cluster_hash, conn = NULL) {
  hash <- as.character(cluster_hash)[1]
  if (is.na(hash) || !nzchar(hash)) return(integer())
  rows <- db_execute_query("
    SELECT mem.entity_id
    FROM analysis_snapshot_manifest man
    JOIN analysis_snapshot_cluster cl
      ON cl.snapshot_id = man.snapshot_id AND cl.cluster_kind = 'phenotype'
    JOIN analysis_snapshot_cluster_member mem
      ON mem.snapshot_id = cl.snapshot_id
     AND mem.cluster_kind = cl.cluster_kind
     AND mem.cluster_id = cl.cluster_id
    WHERE man.analysis_type = 'phenotype_clusters'
      AND man.public_ready = 1
      AND man.status = 'public_ready'
      AND cl.cluster_hash = ?",
    params = list(hash), conn = conn)
  if (is.null(rows) || nrow(rows) == 0L) return(integer())
  as.integer(rows$entity_id)
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-syndromicity-repository.R')"`
Expected: PASS, 3 tests, 0 skips.

- [ ] **Step 5: Register and commit**

```bash
git add api/functions/syndromicity-repository.R api/tests/testthat/test-integration-syndromicity-repository.R api/bootstrap/load_modules.R
git commit -m "feat(630): DB reads for computed syndromicity, pinned to public-ready snapshots"
```

---

### Task 5: Attach the block in the snapshot builder

**Files:**
- Modify: `api/functions/analysis-snapshot-builder.R` (the `phenotype_clusters` branch, ~line 419-444)
- Test: `api/tests/testthat/test-unit-syndromicity-snapshot-attach.R`

**Interfaces:**
- Consumes: `syndromicity_annotations_for_entities()`, `syndromicity_classify_entities()`, `syndromicity_aggregate_cluster()`.
- Produces: a `syndromicity` list-column on the phenotype clusters tibble, which `analysis_snapshot_build_cluster_rows()` folds into `metadata_json` and `service_analysis_snapshot_shape_clusters()` merges back onto the served row.

- [ ] **Step 1: Write the failing test**

```r
# api/tests/testthat/test-unit-syndromicity-snapshot-attach.R
source_api_file("functions/syndromicity-registry.R", local = FALSE)
source_api_file("functions/syndromicity-classify.R", local = FALSE)
source_api_file("functions/analysis-snapshot-builder.R", local = FALSE)

test_that("attaching syndromicity does not change cluster_hash", {
  clusters <- tibble::tibble(
    cluster = "1", hash_filter = "abc123", cluster_size = 2L,
    identifiers = list(tibble::tibble(entity_id = c(1L, 2L),
                                      hgnc_id = c("HGNC:1", "HGNC:2"),
                                      symbol = c("A", "B")))
  )
  before <- analysis_snapshot_build_cluster_rows(clusters, "phenotype")$clusters$cluster_hash
  clusters$syndromicity <- list(list(cluster_call = "mixed", rule_version = "1.0"))
  after <- analysis_snapshot_build_cluster_rows(clusters, "phenotype")$clusters$cluster_hash
  expect_identical(before, after)
})

test_that("the block reaches metadata_json", {
  clusters <- tibble::tibble(
    cluster = "1", hash_filter = "abc123", cluster_size = 1L,
    identifiers = list(tibble::tibble(entity_id = 1L, hgnc_id = "HGNC:1", symbol = "A")),
    syndromicity = list(list(cluster_call = "mixed", fraction_syndromic = 0.5))
  )
  md <- analysis_snapshot_build_cluster_rows(clusters, "phenotype")$clusters$metadata_json[[1]]
  parsed <- jsonlite::fromJSON(md, simplifyVector = FALSE)
  expect_equal(parsed$syndromicity$cluster_call, "mixed")
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-snapshot-attach.R')"`
Expected: the second test FAILs (no `syndromicity` key survives) if `analysis_snapshot_metadata_json()` drops list values; the first should already PASS and is a regression guard.

- [ ] **Step 3: Add the attachment in the phenotype branch**

In `api/functions/analysis-snapshot-builder.R`, inside `phenotype_clusters`, immediately after `clusters <- analysis_snapshot_join_validated_clusters(clusters, val, kind = "phenotype")`:

```r
      # #630: computed, registry-backed syndromicity per cluster. Attached as a
      # clusters-tibble column, which build_cluster_rows() folds into
      # metadata_json and shape_clusters() merges back onto the served row --
      # no schema change. cluster_hash comes from cluster_signature (the top-5
      # enriched quali_inp_var terms), so this cannot churn it and every cached
      # LLM summary survives. Not exists()-guarded: a missing module must fail
      # loudly rather than silently publish a snapshot with no syndromicity.
      clusters$syndromicity <- lapply(clusters$identifiers, function(ids) {
        entity_ids <- if (is.null(ids) || nrow(ids) == 0L) integer() else as.integer(ids$entity_id)
        ann <- syndromicity_annotations_for_entities(entity_ids)
        syndromicity_aggregate_cluster(syndromicity_classify_entities(ann))
      })
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-snapshot-attach.R')"`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add api/functions/analysis-snapshot-builder.R api/tests/testthat/test-unit-syndromicity-snapshot-attach.R
git commit -m "feat(630): attach computed syndromicity to phenotype cluster snapshots"
```

---

### Task 6: Entity endpoint and cluster-summary endpoint

**Files:**
- Create: `api/services/entity-syndromicity-service.R`
- Modify: `api/bootstrap/load_modules.R` (immediately BEFORE `"services/entity-read-endpoint-service.R"`)
- Modify: `api/endpoints/entity_endpoints.R` (new `@get <sysndd_id>/syndromicity` route, declared BEFORE any dynamic sibling that could capture `syndromicity` as a parameter)
- Modify: `api/functions/llm-endpoint-helpers.R:222-240` (`format_summary_response`)
- Test: `api/tests/testthat/test-unit-syndromicity-endpoint.R`

**Interfaces:**
- Consumes: Tasks 2 and 4.
- Produces: `svc_entity_syndromicity(entity_id, res)`; `llm_summary_strip_llm_syndromicity(summary_json)`; `llm_summary_normalize_clinical_pattern(value)`; `LLM_CLINICAL_PATTERN_VOCABULARY`.

- [ ] **Step 1: Write the failing test**

```r
# api/tests/testthat/test-unit-syndromicity-endpoint.R
source_api_file("functions/llm-endpoint-helpers.R", local = FALSE)

test_that("a stale LLM syndromicity key is stripped from a cached summary", {
  out <- llm_summary_strip_llm_syndromicity(list(
    summary = "text", syndromicity = "predominantly_id", clinical_pattern = "other"
  ))
  expect_null(out$syndromicity)
  expect_equal(out$summary, "text")
  expect_equal(out$clinical_pattern, "other")
})

test_that("clinical_pattern outside the vocabulary degrades to other", {
  expect_equal(llm_summary_normalize_clinical_pattern("pure neurodevelopmental"),
               "pure neurodevelopmental")
  expect_equal(llm_summary_normalize_clinical_pattern("progressive metabolic disorders"),
               "other")
  expect_equal(llm_summary_normalize_clinical_pattern(NULL), NULL)
})

test_that("the vocabulary is exactly the five values the prompt names", {
  expect_setequal(LLM_CLINICAL_PATTERN_VOCABULARY, c(
    "syndromic malformation", "pure neurodevelopmental",
    "progressive metabolic/degenerative", "overgrowth syndrome", "other"))
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-endpoint.R')"`
Expected: FAIL — `could not find function "llm_summary_strip_llm_syndromicity"`.

- [ ] **Step 3: Implement**

Append to `api/functions/llm-endpoint-helpers.R`:

```r
LLM_CLINICAL_PATTERN_VOCABULARY <- c(
  "syndromic malformation", "pure neurodevelopmental",
  "progressive metabolic/degenerative", "overgrowth syndrome", "other"
)

#' Drop the retired model-generated syndromicity key (#630).
#'
#' Historical cache rows still carry it. Serving it would present a
#' non-reproducible model label as a clinical finding, so it is removed on READ
#' -- which is what lets this ship without forcing a regeneration of every
#' cached summary.
llm_summary_strip_llm_syndromicity <- function(summary_json) {
  if (!is.list(summary_json)) return(summary_json)
  summary_json[["syndromicity"]] <- NULL
  summary_json
}

#' Constrain clinical_pattern to the enumerated vocabulary.
llm_summary_normalize_clinical_pattern <- function(value) {
  if (is.null(value) || length(value) == 0L) return(NULL)
  v <- as.character(value)[1]
  if (is.na(v) || !nzchar(v)) return(NULL)
  if (v %in% LLM_CLINICAL_PATTERN_VOCABULARY) return(v)
  log_warn("clinical_pattern outside vocabulary, degrading to 'other': {v}")
  "other"
}
```

Then in `format_summary_response()` replace the `summary_json` assignment and the returned list with:

```r
  summary_json <- llm_summary_strip_llm_syndromicity(summary_json)
  summary_json$clinical_pattern <-
    llm_summary_normalize_clinical_pattern(summary_json$clinical_pattern)

  computed <- tryCatch(
    svc_cluster_syndromicity(cached$cluster_hash[1]),
    error = function(e) NULL
  )

  list(
    cache_id = cached$cache_id[1],
    cluster_type = cached$cluster_type[1],
    cluster_number = as.integer(cluster_number),
    model_name = cached$model_name[1],
    created_at = as.character(cached$created_at[1]),
    validation_status = cached$validation_status[1],
    validation_scope = paste(
      "LLM judge verdict on the generated prose, its phenotype grounding and",
      "its inheritance claims. Does NOT cover syndromicity, which is computed",
      "from curated HPO annotations and served separately."
    ),
    summary_json = summary_json,
    syndromicity = computed,
    generated = FALSE
  )
```

Note the `@serializer` on `phenotype_cluster_summary` must become `json list(na="string", null="null")` so a `NULL` `syndromicity` serialises as JSON `null` rather than `{}`.

Create `api/services/entity-syndromicity-service.R` with `svc_entity_syndromicity()` (resolves the entity through `ndd_entity_view`, returns `status: "missing"` when absent) and `svc_cluster_syndromicity()` (resolves members via `syndromicity_cluster_member_ids()`, returns `NULL` for an unknown hash).

- [ ] **Step 4: Run to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-syndromicity-endpoint.R')"`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add api/services/entity-syndromicity-service.R api/functions/llm-endpoint-helpers.R api/endpoints/entity_endpoints.R api/bootstrap/load_modules.R api/tests/testthat/test-unit-syndromicity-endpoint.R
git commit -m "feat(630): serve computed syndromicity; strip retired LLM field on read"
```

---

### Task 7: Remove syndromicity from the LLM contract

**Files:**
- Modify: `api/functions/llm-types.R:99-107` (delete the `syndromicity` field), `:558-562` (delete prompt step 8, renumber)
- Modify: `api/functions/llm-judge.R:98` (delete `corrected_syndromicity`), `:275-280` (delete its application)
- Modify: `api/functions/llm-judge-prompts.R:307-330,398,485,525-529,577,588` (delete the syndromicity grounding block and Step 7)
- Modify: `api/functions/llm-summary-config.R` (`LLM_SUMMARY_PROMPT_VERSION` -> `"1.1"`)
- Modify: `api/functions/mcp-readonly-contract.R:178-179`, `api/services/mcp-analysis-llm-cache-service.R:27-28` (drop `"syndromicity"`)
- Modify: `api/tests/testthat/test-mcp-select-principal-projections.R:172-173`
- Create: `db/migrations/054_update_phenotype_cluster_prompt_template.sql`
- Modify: `api/functions/migration-manifest.R` (`EXPECTED_LATEST_MIGRATION`, `EXPECTED_MIGRATION_COUNT`)
- Test: `api/tests/testthat/test-unit-llm-syndromicity-removal.R`

- [ ] **Step 1: Write the failing test**

```r
# api/tests/testthat/test-unit-llm-syndromicity-removal.R
test_that("the LLM contract no longer mentions syndromicity", {
  root <- get_api_dir()
  for (f in c("functions/llm-types.R", "functions/llm-judge.R",
              "functions/llm-judge-prompts.R")) {
    txt <- paste(readLines(file.path(root, f), warn = FALSE), collapse = "\n")
    expect_false(grepl("syndromicity", txt, ignore.case = TRUE),
                 info = paste(f, "still references syndromicity"))
  }
})

test_that("clinical_pattern is an enum in the type spec", {
  txt <- paste(readLines(file.path(get_api_dir(), "functions/llm-types.R"),
                         warn = FALSE), collapse = "\n")
  expect_match(txt, "clinical_pattern\\s*=\\s*ellmer::type_enum")
})

test_that("the prompt version was bumped", {
  source_api_file("functions/llm-summary-config.R", local = FALSE)
  expect_equal(LLM_SUMMARY_PROMPT_VERSION, "1.1")
})

test_that("MCP no longer allowlists syndromicity", {
  source_api_file("functions/mcp-readonly-contract.R", local = FALSE)
  expect_false("syndromicity" %in% mcp_readonly_llm_summary_json_keys())
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-llm-syndromicity-removal.R')"`
Expected: FAIL on all four.

- [ ] **Step 3: Apply the removals**

Replace the `clinical_pattern` field in `phenotype_cluster_summary_type` with:

```r
  clinical_pattern = ellmer::type_enum(
    c("syndromic malformation", "pure neurodevelopmental",
      "progressive metabolic/degenerative", "overgrowth syndrome", "other"),
    "Syndrome category suggested by the phenotype pattern. Choose exactly one of
     the listed values."
  ),
```

Delete the `syndromicity` field entirely. In the prompt, delete instruction 8 and the `#### Syndromicity Metrics` section, and change instruction 4 to say the value must be exactly one of the five enum strings. Delete Step 7 and `corrected_syndromicity` from the judge.

Write `db/migrations/054_update_phenotype_cluster_prompt_template.sql` as an idempotent `UPDATE llm_prompt_templates SET ... WHERE ...` that removes the syndromicity instruction from the stored template, then bump both constants in `api/functions/migration-manifest.R`.

- [ ] **Step 4: Run to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-llm-syndromicity-removal.R')"`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor(630): drop model-generated syndromicity, enumerate clinical_pattern"
```

---

### Task 8: Frontend

**Files:**
- Create: `app/src/components/llm/syndromicityPresenter.ts`
- Create: `app/src/components/llm/SyndromicityBlock.vue`
- Modify: `app/src/components/llm/useLlmSummaryCard.ts:31,64-65,162-200,341-342`
- Modify: `app/src/components/llm/LlmSummaryCard.vue:107-112`
- Modify: `app/src/components/analyses/phenotypeClusterTable.ts` (add `phenotypeClusterVariableLabel()` and use it for both display and export headers)
- Modify: `app/src/components/analyses/PhenotypeClusterVariableTable.vue`
- Test: `app/src/components/llm/syndromicityPresenter.spec.ts`, `app/src/components/analyses/phenotypeClusterTable.spec.ts`

- [ ] **Step 1: Write the failing tests**

```ts
// app/src/components/analyses/phenotypeClusterTable.spec.ts (append)
import { phenotypeClusterVariableLabel } from './phenotypeClusterTable';

describe('phenotypeClusterVariableLabel', () => {
  it('renders the registry-derived supplementary variables readably', () => {
    expect(phenotypeClusterVariableLabel('extraneurological_system_count')).toBe(
      'Extra-neurological organ systems'
    );
    expect(phenotypeClusterVariableLabel('phenotype_id_count')).toBe(
      'Intellectual disability terms'
    );
    expect(phenotypeClusterVariableLabel('gene_entity_count')).toBe(
      'Disease entities per gene'
    );
  });

  it('leaves an unmapped variable untouched', () => {
    expect(phenotypeClusterVariableLabel('Progressive_present')).toBe('Progressive_present');
  });
});
```

```ts
// app/src/components/llm/syndromicityPresenter.spec.ts
import { describe, it, expect } from 'vitest';
import { syndromicityLabel, syndromicityVariant, hasSyndromicity } from './syndromicityPresenter';

describe('syndromicityPresenter', () => {
  it('labels the computed cluster call', () => {
    expect(syndromicityLabel({ cluster_call: 'predominantly_syndromic' })).toBe(
      'Predominantly syndromic'
    );
    expect(syndromicityLabel({ cluster_call: 'mixed' })).toBe('Mixed');
    expect(syndromicityLabel({ cluster_call: 'insufficient_annotation' })).toBe(
      'Insufficient annotation'
    );
  });

  it('treats a null block as absent', () => {
    expect(hasSyndromicity(null)).toBe(false);
    expect(hasSyndromicity({ cluster_call: 'mixed' })).toBe(true);
  });

  it('does not use the AI badge variant', () => {
    expect(syndromicityVariant({ cluster_call: 'predominantly_syndromic' })).not.toBe('light');
  });
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd app && npx vitest run src/components/llm/syndromicityPresenter.spec.ts src/components/analyses/phenotypeClusterTable.spec.ts`
Expected: FAIL — module not found / export missing.

- [ ] **Step 3: Implement**

Add to `phenotypeClusterTable.ts`:

```ts
/**
 * Display labels for the MCA supplementary variables (#630).
 *
 * The API serves registry-derived variable names; this is the single map used
 * for BOTH the on-screen table and the Excel export headers so the two cannot
 * drift. An unmapped variable (every qualitative HPO term) renders verbatim.
 */
export const PHENOTYPE_CLUSTER_VARIABLE_LABELS: Record<string, string> = {
  extraneurological_system_count: 'Extra-neurological organ systems',
  phenotype_id_count: 'Intellectual disability terms',
  gene_entity_count: 'Disease entities per gene',
};

export function phenotypeClusterVariableLabel(variable: string): string {
  return PHENOTYPE_CLUSTER_VARIABLE_LABELS[variable] ?? variable;
}
```

Create `syndromicityPresenter.ts` exporting `SyndromicityBlock` type, `hasSyndromicity`, `syndromicityLabel`, `syndromicityVariant`, `syndromicitySubtitle` (renders `"74.5% of 1053 entities, median 1 system"`). Create `SyndromicityBlock.vue` rendering it as its own section with a `bi-clipboard-data` icon and the text "Computed from curated HPO annotations". Delete the `syndromicity` union member, `syndromicityVariant` and `syndromicityLabel` from `useLlmSummaryCard.ts` and mount `<SyndromicityBlock>` in `LlmSummaryCard.vue` OUTSIDE the robot-provenance footer.

- [ ] **Step 4: Run to verify they pass**

Run: `cd app && npx vitest run src/components/llm src/components/analyses && npm run type-check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/src && git commit -m "feat(630): render computed syndromicity distinctly; label MCA supplementary variables"
```

---

### Task 9: Documentation and handoff

**Files:**
- Modify: `AGENTS.md` (new subsection under Architecture Invariants)
- Modify: `documentation/02-web-tool.qmd:257` (the MCA sentence still says the quantitative supplementary variables are "phenotype counts divided into ID-related and non-ID-related phenotypes (indicator of 'syndromicity')")
- Modify: `documentation/09-deployment.qmd` (refresh runbook)
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Write the AGENTS.md section**

Cover: the registry is the single definition and is fail-closed; `present` only; the three-way `call` and why `insufficient_annotation` must stay distinct; `neuro` is excluded because it is the NDD core; supplementary variables are projected so membership is invariant (with the verified evidence); `cluster_hash` is signature-derived so LLM summaries survive; the strip-on-read; and the refresh order.

- [ ] **Step 2: Update the MCA description**

Replace the `documentation/02-web-tool.qmd:257` clause with the registry-derived description: extra-neurological organ systems (collapsed), ID terms, and entities per gene.

- [ ] **Step 3: Run the full local gate**

```bash
make code-quality-audit && make lint-api && cd app && npm run lint && npm run type-check && npm run test:unit && cd .. && make test-api-fast
```
Expected: all green. Fix any file that crossed 600 lines by extracting, and ratchet `scripts/code-quality-file-size-baseline.tsv` in this PR if a touched file legitimately grew.

- [ ] **Step 4: Commit and open the PR**

```bash
git add -A && git commit -m "docs(630): document the computed syndromicity definition and refresh order"
git push -u origin feat/syndromicity-unification-630
gh pr create --title "feat(630): one computed definition of syndromicity across SysNDD" --body "..."
```

---

## Self-Review

**Spec coverage.** Registry -> Task 1. Entity + cluster rule -> Task 2. MCA supplementary unification -> Task 3. DB reads -> Task 4. Snapshot attachment -> Task 5. Both endpoints, strip-on-read, `validation_scope` -> Task 6. LLM contract, prompt version, migration, MCP allowlist -> Task 7. Frontend card + variable labels -> Task 8. Docs + deploy -> Task 9. No spec section is unassigned.

**Type consistency.** `system_count` is the classifier's column name and is aliased to `extraneurological_system_count` in the supplementary helper (Task 3) and in the entity result (Task 2); `systems` is the classifier column, `extraneurological_systems` the serialised name. `cluster_call` is used identically in Tasks 2, 6 and 8.

**Known risk.** Task 3 rewrites three call sites that must stay byte-identical in column ORDER; Step 6 is the gate that catches a mistake there, and it must not be skipped.
