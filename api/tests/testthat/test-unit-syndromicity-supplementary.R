# The MCA quantitative supplementary counts, unified onto the registry (#630).

source_api_file("functions/syndromicity-registry.R", local = FALSE)
source_api_file("functions/syndromicity-classify.R", local = FALSE)

test_that("supplementary counts are registry-derived and collapse systems", {
  out <- syndromicity_supplementary_counts(data.frame(
    entity_id = rep(1L, 5),
    phenotype_id = c("HP:0000077", "HP:0000119", "HP:0001249",
                     "HP:0001256", "HP:0003676"),
    modifier_name = "present", stringsAsFactors = FALSE
  ))
  expect_equal(out$extraneurological_system_count, 1L) # kidney + GU collapse
  expect_equal(out$phenotype_id_count, 2L)             # ID + ID mild
})

test_that("the retired flat non-ID count and the new system count differ as designed", {
  rows <- data.frame(
    entity_id = rep(1L, 5),
    phenotype_id = c("HP:0000077", "HP:0000119", "HP:0000707",
                     "HP:0003676", "HP:0000118"),
    modifier_name = "present", stringsAsFactors = FALSE
  )
  # The old rule counted every non-ID term: root + course modifier + neuro +
  # both renal terms = 5.
  expect_equal(sum(!rows$phenotype_id %in% syndromicity_id_severity_terms()), 5L)
  expect_equal(
    syndromicity_supplementary_counts(rows)$extraneurological_system_count, 1L
  )
})

test_that("an entity with only equivocal rows still gets a zero count, not a gap", {
  out <- syndromicity_supplementary_counts(data.frame(
    entity_id = c(1L, 2L),
    phenotype_id = c("HP:0000077", "HP:0000077"),
    modifier_name = c("present", "uncertain"), stringsAsFactors = FALSE
  ))
  expect_equal(nrow(out), 2L)
  expect_equal(out$extraneurological_system_count[out$entity_id == 2L], 0L)
  expect_equal(out$phenotype_id_count[out$entity_id == 2L], 0L)
})

test_that("an empty frame returns the empty shape", {
  out <- syndromicity_supplementary_counts(
    data.frame(entity_id = integer(), phenotype_id = character(),
               modifier_name = character(), stringsAsFactors = FALSE)
  )
  expect_equal(nrow(out), 0L)
  expect_setequal(names(out),
    c("entity_id", "extraneurological_system_count", "phenotype_id_count"))
})
