# Tests for the computed syndromicity classifier and cluster aggregator (#630).
#
# These drive the real functions over hand-built annotation frames. The rule is
# deterministic and DB-free, so every clinical decision it encodes is pinned
# here rather than left to a model.

source_api_file("functions/syndromicity-registry.R", local = FALSE)
source_api_file("functions/syndromicity-classify.R", local = FALSE)

ann <- function(...) {
  rows <- list(...)
  do.call(rbind, lapply(rows, function(r) {
    data.frame(
      entity_id = as.integer(r[[1]]),
      phenotype_id = r[[2]],
      modifier_name = r[[3]],
      stringsAsFactors = FALSE
    )
  }))
}

test_that("nested terms in one system count once", {
  out <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000077", "present"), # kidney
    list(1L, "HP:0000119", "present")  # genitourinary -> same collapsed system
  ))
  expect_equal(out$system_count, 1L)
  expect_equal(out$systems[[1]], "renal_urogenital")
  expect_equal(out$call, "syndromic")
})

test_that("root, course modifiers, ID core and neuro never enter the numerator", {
  out <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000118", "present"), # ontology root
    list(1L, "HP:0003676", "present"), # Progressive
    list(1L, "HP:0011420", "present"), # Age of death
    list(1L, "HP:0001249", "present"), # Intellectual disability
    list(1L, "HP:0001250", "present")  # Seizures -> neuro
  ))
  expect_equal(out$system_count, 0L)
  expect_true(out$neurological_involvement)
  expect_equal(out$call, "no_recorded_extraneurological_involvement")
})

test_that("no present annotation is insufficient_annotation, never isolated", {
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
  # A flat non-ID count over the same rows returns 7; that gap is the defect.
  expect_equal(sum(!c(
    "HP:0000077", "HP:0000707", "HP:0000708", "HP:0000818",
    "HP:0001249", "HP:0001939", "HP:0002011", "HP:0003676"
  ) %in% syndromicity_id_severity_terms()), 7L)
})

test_that("an unclassified term raises rather than being silently dropped", {
  expect_error(
    syndromicity_classify_entities(ann(list(1L, "HP:9999999", "present"))),
    "not classified"
  )
})

test_that("an empty annotation frame returns the empty shape, not an error", {
  out <- syndromicity_classify_entities(
    data.frame(entity_id = integer(), phenotype_id = character(),
               modifier_name = character(), stringsAsFactors = FALSE)
  )
  expect_equal(nrow(out), 0L)
  expect_true(all(c("entity_id", "system_count", "systems", "call") %in% names(out)))
})

test_that("multiple entities are classified independently", {
  out <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000077", "present"),
    list(2L, "HP:0001249", "present"),
    list(3L, "HP:0001249", "uncertain")
  ))
  expect_equal(nrow(out), 3L)
  expect_equal(out$call[out$entity_id == 1L], "syndromic")
  expect_equal(out$call[out$entity_id == 2L], "no_recorded_extraneurological_involvement")
  expect_equal(out$call[out$entity_id == 3L], "insufficient_annotation")
})

test_that("cluster aggregate excludes unannotated entities from the denominator", {
  rows <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000077", "present"),  # syndromic
    list(2L, "HP:0001249", "present"),  # no recorded extra-neuro involvement
    list(3L, "HP:0001249", "uncertain") # insufficient
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
      lapply(seq_len(n_syn), function(i) {
        data.frame(entity_id = i, phenotype_id = "HP:0000077",
                   modifier_name = "present", stringsAsFactors = FALSE)
      }),
      lapply(seq_len(n_iso), function(i) {
        data.frame(entity_id = 1000L + i, phenotype_id = "HP:0001249",
                   modifier_name = "present", stringsAsFactors = FALSE)
      })
    ))
    syndromicity_aggregate_cluster(syndromicity_classify_entities(rows))
  }
  expect_equal(mk(3, 1)$cluster_call, "predominantly_syndromic") # exactly 0.75
  expect_equal(mk(1, 3)$cluster_call, "predominantly_isolated")  # exactly 0.25
  expect_equal(mk(2, 1)$cluster_call, "mixed")                   # 0.667
})

test_that("a mostly-unannotated cluster reports insufficient_annotation", {
  rows <- syndromicity_classify_entities(do.call(rbind, c(
    list(data.frame(entity_id = 1L, phenotype_id = "HP:0000077",
                    modifier_name = "present", stringsAsFactors = FALSE)),
    lapply(2:5, function(i) {
      data.frame(entity_id = i, phenotype_id = "HP:0001249",
                 modifier_name = "uncertain", stringsAsFactors = FALSE)
    })
  )))
  expect_equal(syndromicity_aggregate_cluster(rows)$cluster_call,
               "insufficient_annotation")
})

test_that("system_frequencies counts systems, not terms", {
  rows <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000077", "present"), # renal_urogenital
    list(1L, "HP:0000119", "present"), # renal_urogenital again -> still 1 entity
    list(2L, "HP:0000119", "present")  # renal_urogenital
  ))
  agg <- syndromicity_aggregate_cluster(rows)
  expect_equal(agg$system_frequencies$renal_urogenital, 2L)
})

test_that("an empty cluster aggregates without dividing by zero", {
  agg <- syndromicity_aggregate_cluster(syndromicity_classify_entities(
    data.frame(entity_id = integer(), phenotype_id = character(),
               modifier_name = character(), stringsAsFactors = FALSE)
  ))
  expect_equal(agg$entities, 0L)
  expect_true(is.na(agg$fraction_syndromic))
  expect_equal(agg$cluster_call, "insufficient_annotation")
})

test_that("abnormal head size counts as extra-neurological involvement", {
  # OFC is a physical measurement, like stature -- a growth/dysmorphology
  # finding, not a nervous-system function finding. HPO places HP:0000252 under
  # head and neck, not under HP:0000707, and clinically micro-/macrocephaly is
  # one of the features that makes an intellectual disability syndromic.
  out <- syndromicity_classify_entities(ann(
    list(1L, "HP:0001249", "present"), # Intellectual disability
    list(1L, "HP:0000252", "present")  # Microcephaly -> organ/head_size
  ))
  expect_equal(out$system_count, 1L)
  expect_setequal(out$systems[[1]], "head_size")
  expect_equal(out$call, "syndromic")
  # The alternative reading stays inspectable without re-running anything.
  expect_equal(out$system_count_excl_head_size, 0L)
})

test_that("the aggregate reports coverage and a Wilson interval", {
  rows <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000077", "present"),
    list(2L, "HP:0000119", "present"),
    list(3L, "HP:0001249", "present"),
    list(4L, "HP:0001249", "uncertain")
  ))
  agg <- syndromicity_aggregate_cluster(rows)
  expect_equal(agg$entities, 4L)
  expect_equal(agg$evaluable, 3L)
  expect_equal(agg$coverage, 0.75)
  expect_true(agg$fraction_syndromic_ci95$lower < agg$fraction_syndromic)
  expect_true(agg$fraction_syndromic_ci95$upper > agg$fraction_syndromic)
  expect_true(agg$fraction_syndromic_ci95$lower >= 0)
  expect_true(agg$fraction_syndromic_ci95$upper <= 1)
})

test_that("the Wilson interval stays inside [0,1] at the boundaries", {
  all_syn <- syndromicity_classify_entities(do.call(rbind, lapply(1:5, function(i) {
    data.frame(entity_id = i, phenotype_id = "HP:0000077",
               modifier_name = "present", stringsAsFactors = FALSE)
  })))
  agg <- syndromicity_aggregate_cluster(all_syn)
  expect_equal(agg$fraction_syndromic, 1)
  expect_lte(agg$fraction_syndromic_ci95$upper, 1)
  expect_lt(agg$fraction_syndromic_ci95$lower, 1)
})

test_that("raw per-system frequencies let a consumer re-collapse the mapping", {
  rows <- syndromicity_classify_entities(ann(
    list(1L, "HP:0000478", "present"), # eye
    list(2L, "HP:0000365", "present"), # ear_hearing
    list(3L, "HP:0000252", "present"), list(3L, "HP:0001249", "present")
  ))
  agg <- syndromicity_aggregate_cluster(rows)
  expect_equal(agg$system_frequencies$eye, 1L)
  expect_equal(agg$system_frequencies$ear_hearing, 1L)
  expect_equal(agg$system_frequencies$head_size, 1L)
  # eye + ear are kept separate on purpose; the raw counts make a merged
  # "sensory" recomputation possible without regenerating the snapshot.
  expect_equal(agg$fraction_syndromic, 1)
  # Without head size, entity 3 has no recorded involvement -> 2/3.
  expect_equal(agg$fraction_syndromic_excl_head_size, round(2 / 3, 4))
})

test_that("a call whose interval straddles its threshold is flagged borderline", {
  # A categorical label at a fixed cutoff is a cliff; when the interval contains
  # the cutoff, the word implies a precision the data does not carry.
  mk <- function(n_syn, n_none) {
    rows <- do.call(rbind, c(
      lapply(seq_len(n_syn), function(i) {
        data.frame(entity_id = i, phenotype_id = "HP:0000077",
                   modifier_name = "present", stringsAsFactors = FALSE)
      }),
      lapply(seq_len(n_none), function(i) {
        data.frame(entity_id = 100000L + i, phenotype_id = "HP:0001249",
                   modifier_name = "present", stringsAsFactors = FALSE)
      })
    ))
    syndromicity_aggregate_cluster(syndromicity_classify_entities(rows))
  }
  # 785 / 1053 = 0.746, CI [0.718, 0.771] -> straddles 0.75
  near <- mk(785, 268)
  expect_equal(near$cluster_call, "mixed")
  expect_true(near$cluster_call_borderline)
  expect_lt(near$fraction_syndromic_ci95$lower, 0.75)
  expect_gt(near$fraction_syndromic_ci95$upper, 0.75)

  # 535 / 535 = 1.0, CI nowhere near a cutoff
  clear <- mk(535, 0)
  expect_equal(clear$cluster_call, "predominantly_syndromic")
  expect_false(clear$cluster_call_borderline)
})
