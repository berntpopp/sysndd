# functions/syndromicity-registry.R
#
# Single source of truth for how SysNDD defines syndromicity (#630).
#
# SysNDD annotates entities against a FIXED 39-term controlled vocabulary
# (`phenotype_list`), not free HPO, so classification is a static auditable
# table rather than a runtime descendant expansion. Each term carries a role
# and, for terms that represent organ involvement, a COLLAPSED system:
# HP:0000077 (kidney) and HP:0000119 (genitourinary) are ONE system, not two,
# which is what stops a single clinical finding being counted twice.
#
# Roles and what they mean for the measure:
#   ontology_root   HP:0000118 -- the ancestor of every other term in the
#                   vocabulary; counting it would count "has any phenotype".
#   course_modifier Progressive / Age of death -- clinical course and outcome,
#                   not organ involvement.
#   ndd_core        Intellectual disability plus its five severity grades --
#                   the NDD phenotype itself, so never an "additional" feature.
#   neuro           Nervous-system findings. In NDD the nervous system IS the
#                   primary phenotype, so these are reported SEPARATELY and are
#                   not part of the syndromicity numerator. This is also why the
#                   sibling kidney-genetics indicator set is not portable: its
#                   `neurologic` category is our core phenotype.
#   organ           Extra-neurological organ involvement -- the numerator.
#
# This module is also the single definition of the ID / ID-severity term list.
# It previously existed as three hardcoded copies; a guard test fails if one
# reappears.

SYNDROMICITY_RULE_VERSION <- "1.0"

#' The term -> (role, collapsed system) classification.
#'
#' @return tibble with columns `phenotype_id`, `role`, `system`.
#' @export
syndromicity_registry <- function() {
  tibble::tribble(
    ~phenotype_id, ~role,             ~system,
    # --- excluded by role -------------------------------------------------
    "HP:0000118",  "ontology_root",   NA_character_, # Phenotypic abnormality
    "HP:0003676",  "course_modifier", NA_character_, # Progressive
    "HP:0011420",  "course_modifier", NA_character_, # Age of death
    # --- the NDD phenotype itself -----------------------------------------
    "HP:0001249",  "ndd_core",        NA_character_, # Intellectual disability
    "HP:0001256",  "ndd_core",        NA_character_, # ID, mild
    "HP:0002342",  "ndd_core",        NA_character_, # ID, moderate
    "HP:0010864",  "ndd_core",        NA_character_, # ID, severe
    "HP:0002187",  "ndd_core",        NA_character_, # ID, profound
    "HP:0006889",  "ndd_core",        NA_character_, # ID, borderline
    # --- nervous system: reported separately, never the numerator ---------
    "HP:0000707",  "neuro",           "nervous_system", # Abn. nervous system
    "HP:0000708",  "neuro",           "nervous_system", # Behavioral abnormality
    "HP:0001250",  "neuro",           "nervous_system", # Seizures
    "HP:0002011",  "neuro",           "nervous_system", # Abn. brain morphology
    "HP:0002270",  "neuro",           "nervous_system", # Abn. autonomic n. s.
    "HP:0002376",  "neuro",           "nervous_system", # Developmental regression
    # --- extra-neurological organ systems, collapsed ----------------------
    "HP:0000077",  "organ",           "renal_urogenital", # Abn. kidney
    "HP:0000119",  "organ",           "renal_urogenital", # Abn. genitourinary
    "HP:0000924",  "organ",           "skeletal",         # Abn. skeletal system
    "HP:0040064",  "organ",           "skeletal",         # Abn. limbs
    "HP:0001939",  "organ",           "metabolic",        # Abn. metabolism
    "HP:0012103",  "organ",           "metabolic",        # Abn. mitochondrion
    "HP:0000098",  "organ",           "growth",           # Tall stature
    "HP:0004322",  "organ",           "growth",           # Short stature
    "HP:0001548",  "organ",           "growth",           # Overgrowth
    "HP:0001513",  "organ",           "growth",           # Obesity
    "HP:0000202",  "organ",           "craniofacial",     # Oral cleft
    "HP:0001999",  "organ",           "craniofacial",     # Abnormal facial shape
    # Head size is EXTRA-NEUROLOGICAL, not part of the NDD core phenotype.
    # Micro-/macrocephaly are measured on physical examination (occipitofrontal
    # circumference), exactly like stature and weight -- they are growth /
    # dysmorphology findings, not nervous-system FUNCTION findings. HPO agrees:
    # HP:0000252 sits under Abnormality of skull size -> Abnormal skull
    # morphology -> Abnormality of head or neck, NOT under HP:0000707. And
    # clinically they are among the features that make an intellectual
    # disability syndromic: "non-syndromic ID" means ID without microcephaly,
    # dysmorphism or malformation. Kept as its OWN system rather than merged
    # into craniofacial, because head size is a distinct measurement axis from
    # facial morphology; the raw per-system counts let a consumer merge them.
    "HP:0000252",  "organ",           "head_size",        # Microcephaly
    "HP:0000256",  "organ",           "head_size",        # Macrocephaly
    "HP:0000365",  "organ",           "ear_hearing",      # Hearing impairment
    "HP:0000478",  "organ",           "eye",              # Abn. eye
    "HP:0000818",  "organ",           "endocrine",        # Abn. endocrine system
    "HP:0001574",  "organ",           "integument",       # Abn. integument
    "HP:0001627",  "organ",           "cardiovascular",   # Abnormal heart morph.
    "HP:0001871",  "organ",           "hematologic",      # Abn. blood
    "HP:0002664",  "organ",           "neoplasm",         # Neoplasm
    "HP:0002715",  "organ",           "immune",           # Abn. immune system
    "HP:0003011",  "organ",           "musculature",      # Abn. musculature
    "HP:0011024",  "organ",           "gastrointestinal"  # Abn. GI tract
  )
}

#' The ID / ID-severity terms.
#'
#' Single definition. Callers must not re-list these; a guard test
#' (test-unit-id-term-hardcode-guard.R) fails if they do.
#'
#' @export
syndromicity_id_severity_terms <- function() {
  reg <- syndromicity_registry()
  reg$phenotype_id[reg$role == "ndd_core"]
}

#' Assert the registry matches the live vocabulary, in BOTH directions.
#'
#' A new `phenotype_list` term with no registry entry would silently vanish from
#' the measure; a registry entry whose term was removed would silently rot. Both
#' raise. Callers on a request path must NOT wrap this in `tryCatch` -- a
#' swallowed failure would serve a syndromicity value computed over an
#' incomplete vocabulary, which is the class of defect this module exists to
#' prevent.
#'
#' @param vocabulary_ids Character vector of live `phenotype_list.phenotype_id`.
#' @return invisible(TRUE), or stops.
#' @export
syndromicity_registry_assert_complete <- function(vocabulary_ids) {
  reg_ids <- syndromicity_registry()$phenotype_id
  ids <- unique(as.character(vocabulary_ids))
  ids <- ids[!is.na(ids)]

  missing <- setdiff(ids, reg_ids)
  if (length(missing) > 0L) {
    stop(sprintf(
      "syndromicity registry: phenotype_list term(s) not classified: %s",
      paste(sort(missing), collapse = ", ")
    ), call. = FALSE)
  }

  stale <- setdiff(reg_ids, ids)
  if (length(stale) > 0L) {
    stop(sprintf(
      "syndromicity registry: classified term(s) no longer present in phenotype_list: %s",
      paste(sort(stale), collapse = ", ")
    ), call. = FALSE)
  }

  invisible(TRUE)
}
