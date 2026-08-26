# Tests for the syndromicity registry (#630).
#
# The registry is the single definition of how SysNDD classifies its 39-term
# phenotype vocabulary for the computed syndromicity measure. These tests pin
# the classification itself, not a mock of it.

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

test_that("abnormal head size is neurodevelopmental, not extra-systemic", {
  reg <- syndromicity_registry()
  # Micro/macrocephaly are cardinal NDD features. Counting them as an
  # extra-neurological "system" would call an entity with ID + microcephaly
  # syndromic on the strength of a core neurodevelopmental finding.
  expect_equal(reg$role[reg$phenotype_id == "HP:0000252"], "neuro")
  expect_equal(reg$role[reg$phenotype_id == "HP:0000256"], "neuro")
  expect_equal(reg$system[reg$phenotype_id == "HP:0000252"], "head_size")
})

test_that("the six ID severity terms are the ndd_core role and nothing else", {
  expect_setequal(
    syndromicity_id_severity_terms(),
    c("HP:0001249", "HP:0001256", "HP:0002342", "HP:0010864",
      "HP:0002187", "HP:0006889")
  )
})

test_that("every nervous-system term is excluded from the organ numerator", {
  reg <- syndromicity_registry()
  neuro <- reg$phenotype_id[reg$role == "neuro"]
  expect_setequal(
    neuro,
    c("HP:0000707", "HP:0000708", "HP:0001250",
      "HP:0002011", "HP:0002270", "HP:0002376",
      "HP:0000252", "HP:0000256")
  )
  expect_false(any(reg$role[reg$phenotype_id %in% neuro] == "organ"))
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
