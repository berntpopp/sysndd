# functions/syndromicity-classify.R
#
# Pure classification and aggregation for the computed syndromicity measure
# (#630). No DB access, no side effects, deterministic -- the repository layer
# supplies annotation rows, this file decides what they mean.
#
# The measure this replaces was produced by a language model and was not
# reproducible on identical input: the same cluster hash, the same model and a
# 39-second gap yielded `predominantly_id`, `mixed`, `predominantly_id`. Every
# decision below is therefore a stated rule, versioned by
# SYNDROMICITY_RULE_VERSION, with its thresholds emitted inline in the payload
# so a frozen downstream artifact self-identifies.
#
# WHAT THIS MEASURES, PRECISELY: recorded extra-neurological organ involvement.
# It is an evidence-based measure, not a clinical adjudication. SysNDD records
# explicit phenotype ABSENCE on 6 rows in the entire database, so an entity with
# no recorded organ involvement cannot be distinguished from one that was
# assessed and found unaffected. That is why no value in the vocabulary is
# called "isolated": `no_recorded_extraneurological_involvement` says exactly
# what the data support and nothing more. Treating unrecorded as absent is the
# defect this repository already documents for the MCA input
# (analysis-phenotype-missingness.R) and the one the sibling kidney-genetics
# implementation ships via `COALESCE(is_syndromic, FALSE)`.

SYNDROMICITY_THRESHOLDS <- list(
  syndromic_system_count  = 1L,
  predominantly_syndromic = 0.75,
  predominantly_isolated  = 0.25,
  min_evaluable_fraction  = 0.5
)

#' Wilson score interval for a binomial proportion.
#'
#' Reported alongside `fraction_syndromic` so a cluster sitting near a cutoff
#' reads as the uncertainty it is rather than as a hard categorical claim.
#' Wilson rather than Wald: it behaves at proportions near 0 and 1 and at small
#' n, both of which occur (cluster sizes span an order of magnitude).
#'
#' @keywords internal
.syndromicity_wilson_interval <- function(successes, n, z = 1.959964) {
  if (is.na(n) || n <= 0L) {
    return(list(lower = NA_real_, upper = NA_real_))
  }
  p <- successes / n
  denom <- 1 + (z^2) / n
  centre <- (p + (z^2) / (2 * n)) / denom
  half <- (z * sqrt(p * (1 - p) / n + (z^2) / (4 * n^2))) / denom
  list(
    lower = round(max(0, centre - half), 4),
    upper = round(min(1, centre + half), 4)
  )
}

#' Classify entities from their annotation rows.
#'
#' Only `present` rows are evidence for involvement -- the same rows
#' `generate_phenotype_cluster_input()` admits to the MCA, so the measure and
#' the clustering partition can never disagree about what counts as an
#' annotation. Non-present rows (`uncertain` / `variable` / `rare`) are NOT
#' evidence and are counted separately as `equivocal_term_count`, so the
#' ambiguity is inspectable instead of silently discarded.
#'
#' @param annotations data.frame with `entity_id`, `phenotype_id`,
#'   `modifier_name`. Must carry ALL active modifiers, not a pre-filtered
#'   present-only set, or `equivocal_term_count` is unobservable.
#' @return tibble, one row per distinct `entity_id` present in `annotations`.
#' @export
syndromicity_classify_entities <- function(annotations) {
  ann <- tibble::as_tibble(annotations)
  if (nrow(ann) == 0L) {
    return(tibble::tibble(
      entity_id = integer(),
      system_count = integer(),
      systems = list(),
      neuro_systems = list(),
      neurological_involvement = logical(),
      system_count_with_head_size = integer(),
      present_term_count = integer(),
      equivocal_term_count = integer(),
      call = character()
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
  is_present <- !is.na(ann$modifier_name) & ann$modifier_name == "present"

  entity_ids <- sort(unique(as.integer(ann$entity_id)))
  rows <- lapply(entity_ids, function(id) {
    mine <- ann$entity_id == id
    p <- ann[mine & is_present, , drop = FALSE]
    n_equivocal <- sum(mine & !is_present)

    systems <- sort(unique(p$system[!is.na(p$system) & p$role == "organ"]))
    neuro_systems <- sort(unique(p$system[!is.na(p$system) & p$role == "neuro"]))
    n_present <- nrow(p)

    # Sensitivity: the same count under the alternative operationalization that
    # treats abnormal head size as extra-systemic rather than neurodevelopmental.
    #
    # Both counts are resolved HERE, not inside the tibble() call below:
    # tibble() evaluates its arguments sequentially with earlier columns in
    # scope, so a `length(systems)` written inline after the `systems` list-column
    # is defined would measure the LIST (always 1), not the character vector.
    n_systems <- length(systems)
    n_neuro_systems <- length(neuro_systems)
    n_systems_with_head_size <- n_systems +
      as.integer("head_size" %in% neuro_systems)

    call <- if (n_present == 0L) {
      "insufficient_annotation"
    } else if (n_systems >= SYNDROMICITY_THRESHOLDS$syndromic_system_count) {
      "syndromic"
    } else {
      "no_recorded_extraneurological_involvement"
    }

    tibble::tibble(
      entity_id = as.integer(id),
      system_count = n_systems,
      systems = list(as.character(systems)),
      neuro_systems = list(as.character(neuro_systems)),
      neurological_involvement = n_neuro_systems > 0L,
      system_count_with_head_size = n_systems_with_head_size,
      present_term_count = as.integer(n_present),
      equivocal_term_count = as.integer(n_equivocal),
      call = call
    )
  })

  dplyr::bind_rows(rows)
}

#' One classifier row -> the named list the API serialises.
#'
#' @export
syndromicity_entity_result <- function(row) {
  list(
    entity_id = as.integer(row$entity_id[[1]]),
    rule_version = SYNDROMICITY_RULE_VERSION,
    data_class = "curated_derived_analysis",
    measures = "recorded extra-neurological organ involvement",
    extraneurological_systems = as.character(row$systems[[1]]),
    system_count = as.integer(row$system_count[[1]]),
    neurological_systems = as.character(row$neuro_systems[[1]]),
    neurological_involvement = isTRUE(row$neurological_involvement[[1]]),
    system_count_with_head_size = as.integer(row$system_count_with_head_size[[1]]),
    present_term_count = as.integer(row$present_term_count[[1]]),
    equivocal_term_count = as.integer(row$equivocal_term_count[[1]]),
    call = as.character(row$call[[1]])
  )
}

#' Aggregate classifier rows into the per-cluster payload block.
#'
#' `fraction_syndromic` is over EVALUABLE entities (those with >=1 `present`
#' annotation) and is reported WITH `coverage` and a Wilson 95% interval,
#' because the fraction alone would hide two things: that the denominator is an
#' annotation-selected subset, and that a handful of entities can move a cluster
#' across a cutoff.
#'
#' SCOPE NOTE: the phenotype clustering input admits only entities with at least
#' one `present` annotation, so for a cluster block `evaluable == entities` by
#' construction and `coverage == 1`. The fields still ship because this same
#' aggregator serves entity sets that are NOT annotation-selected (e.g. an
#' arbitrary gene's entities), where they are load-bearing.
#'
#' @export
syndromicity_aggregate_cluster <- function(entity_rows) {
  rows <- tibble::as_tibble(entity_rows)
  n <- nrow(rows)
  insufficient <- sum(rows$call == "insufficient_annotation")
  no_involvement <- sum(rows$call == "no_recorded_extraneurological_involvement")
  syndromic <- sum(rows$call == "syndromic")
  evaluable <- n - insufficient

  fraction <- if (evaluable > 0L) round(syndromic / evaluable, 4) else NA_real_
  interval <- .syndromicity_wilson_interval(syndromic, evaluable)
  coverage <- if (n > 0L) round(evaluable / n, 4) else NA_real_
  coverage_ok <- n > 0L &&
    coverage >= SYNDROMICITY_THRESHOLDS$min_evaluable_fraction

  cluster_call <- if (!coverage_ok || is.na(fraction)) {
    "insufficient_annotation"
  } else if (fraction >= SYNDROMICITY_THRESHOLDS$predominantly_syndromic) {
    "predominantly_syndromic"
  } else if (fraction <= SYNDROMICITY_THRESHOLDS$predominantly_isolated) {
    "predominantly_isolated"
  } else {
    "mixed"
  }

  evaluable_rows <- rows[rows$call != "insufficient_annotation", , drop = FALSE]

  tally <- function(values) {
    freq <- table(unlist(values))
    if (length(freq) == 0L) {
      return(stats::setNames(list(), character()))
    }
    as.list(stats::setNames(as.integer(freq), names(freq)))
  }

  list(
    rule_version = SYNDROMICITY_RULE_VERSION,
    data_class = "curated_derived_analysis",
    measures = "recorded extra-neurological organ involvement",
    entities = as.integer(n),
    evaluable = as.integer(evaluable),
    coverage = coverage,
    insufficient_annotation = as.integer(insufficient),
    no_recorded_extraneurological_involvement = as.integer(no_involvement),
    syndromic = as.integer(syndromic),
    fraction_syndromic = fraction,
    fraction_syndromic_ci95 = interval,
    median_systems = if (nrow(evaluable_rows) > 0L) {
      as.numeric(stats::median(evaluable_rows$system_count))
    } else {
      NA_real_
    },
    mean_systems = if (nrow(evaluable_rows) > 0L) {
      round(mean(evaluable_rows$system_count), 3)
    } else {
      NA_real_
    },
    mean_present_terms = if (nrow(evaluable_rows) > 0L) {
      round(mean(evaluable_rows$present_term_count), 3)
    } else {
      NA_real_
    },
    # Raw per-system entity counts, so a consumer who disagrees with the
    # collapse can recompute under their own mapping instead of taking ours.
    system_frequencies = tally(evaluable_rows$systems),
    neurological_system_frequencies = tally(evaluable_rows$neuro_systems),
    # Sensitivity to the one genuinely contestable mapping choice.
    fraction_syndromic_with_head_size = if (evaluable > 0L) {
      round(sum(evaluable_rows$system_count_with_head_size >= 1L) / evaluable, 4)
    } else {
      NA_real_
    },
    cluster_call = cluster_call,
    thresholds = SYNDROMICITY_THRESHOLDS
  )
}
