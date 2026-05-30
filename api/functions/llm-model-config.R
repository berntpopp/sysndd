# functions/llm-model-config.R
#
# Central Gemini model catalog and operator configuration validation.

LLM_DEFAULT_GEMINI_MODEL <- "gemini-3.5-flash"

.llm_model_scalar <- function(value) {
  if (is.null(value) || length(value) == 0L || is.na(value[[1]])) {
    return(NA_character_)
  }

  value <- trimws(as.character(value[[1]]))
  if (!nzchar(value)) {
    return(NA_character_)
  }

  value
}

.llm_model_config_value <- function(config) {
  if (is.null(config)) {
    return(NA_character_)
  }

  if (is.environment(config)) {
    if (exists("gemini_model", envir = config, inherits = FALSE)) {
      return(.llm_model_scalar(get("gemini_model", envir = config, inherits = FALSE)))
    }
    return(NA_character_)
  }

  if (is.list(config) && "gemini_model" %in% names(config)) {
    return(.llm_model_scalar(config$gemini_model))
  }

  NA_character_
}

.llm_model_runtime_config <- function(config = NULL) {
  if (!is.null(config)) {
    return(config)
  }
  if (exists("dw", envir = .GlobalEnv, inherits = FALSE)) {
    return(get("dw", envir = .GlobalEnv, inherits = FALSE))
  }
  NULL
}

.llm_model_log_info <- function(message) {
  if (requireNamespace("logger", quietly = TRUE)) {
    logger::log_info(message)
  }
  invisible(NULL)
}

#' Built-in Gemini model catalog
#'
#' @return Data frame of model metadata and SysNDD allow/availability status.
#' @export
llm_model_catalog <- function() {
  data.frame(
    model_id = c(
      "gemini-3.5-flash",
      "gemini-3.1-pro-preview",
      "gemini-3.1-flash-lite",
      "gemini-2.5-flash",
      "gemini-2.5-pro",
      "gemini-2.5-flash-lite",
      "gemini-3-pro-preview"
    ),
    display_name = c(
      "Gemini 3.5 Flash",
      "Gemini 3.1 Pro Preview",
      "Gemini 3.1 Flash-Lite",
      "Gemini 2.5 Flash",
      "Gemini 2.5 Pro",
      "Gemini 2.5 Flash Lite",
      "Gemini 3 Pro Preview"
    ),
    description = c(
      "Current fast text model with strong reasoning and grounding support",
      "Highest-reasoning Gemini 3.1 preview model",
      "Cost-efficient Gemini 3 text model for high-volume summary generation",
      "Stable Gemini 2.5 balanced model",
      "Complex reasoning, stable release",
      "Stable low-cost Gemini 2.5 model",
      "Shut-down preview model; retained only for historical cache metadata"
    ),
    rpm_limit = c(1000L, 1000L, 2000L, 2000L, 1000L, 4000L, 0L),
    rpd_limit = c(NA_integer_, NA_integer_, NA_integer_, NA_integer_, 5000L, NA_integer_, 0L),
    recommended_for = c(
      "Default summaries",
      "Complex analysis",
      "High-volume summaries",
      "Stable balanced",
      "Stable production",
      "Budget processing",
      "Historical metadata only"
    ),
    status = c("stable", "preview", "stable", "stable", "stable", "stable", "shutdown"),
    allowed = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE),
    default = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    shutdown_date = c(
      NA_character_, NA_character_, NA_character_, NA_character_, NA_character_,
      NA_character_, "2026-03-09"
    ),
    stringsAsFactors = FALSE
  )
}

#' Return catalog metadata for one Gemini model
#'
#' @param model Character Gemini model id.
#' @return List of catalog metadata. Unknown models return `status = "unknown"`
#'   and `allowed = FALSE`.
#' @export
llm_model_metadata <- function(model) {
  model <- .llm_model_scalar(model)
  if (is.na(model)) {
    model <- NA_character_
  }
  catalog <- llm_model_catalog()
  row <- if (is.na(model)) {
    catalog[FALSE, , drop = FALSE]
  } else {
    catalog[catalog$model_id == model, , drop = FALSE]
  }

  if (nrow(row) == 1L) {
    return(as.list(row[1, , drop = FALSE]))
  }

  list(
    model_id = model,
    display_name = model,
    description = "Unknown Gemini model outside the built-in SysNDD catalog",
    rpm_limit = 1000L,
    rpd_limit = NA_integer_,
    recommended_for = "Operator-managed use",
    status = "unknown",
    allowed = FALSE,
    default = FALSE,
    shutdown_date = NA_character_
  )
}

#' Operator-managed extra Gemini model allowlist
#'
#' @return Character vector from comma-separated `GEMINI_ALLOWED_MODELS_EXTRA`.
#' @export
llm_model_extra_allowlist <- function() {
  raw <- Sys.getenv("GEMINI_ALLOWED_MODELS_EXTRA", unset = NA_character_)
  raw <- .llm_model_scalar(raw)
  if (is.na(raw)) {
    return(character())
  }

  values <- trimws(unlist(strsplit(raw, ",", fixed = TRUE), use.names = FALSE))
  unique(values[nzchar(values)])
}

#' Validate whether a Gemini model is usable by SysNDD
#'
#' @param model Character Gemini model id.
#' @param config Optional config list; currently reserved for future policy.
#' @return List with validity, warning, and error metadata.
#' @export
llm_model_config_validate <- function(model, config = NULL) {
  model <- .llm_model_scalar(model)
  if (is.na(model)) {
    return(list(
      valid = FALSE,
      operator_allowed = FALSE,
      warning = "Gemini model is empty.",
      error_code = "llm_model_invalid",
      message = "Gemini model is empty."
    ))
  }

  meta <- llm_model_metadata(model)
  if (isTRUE(meta$allowed)) {
    return(list(
      valid = TRUE,
      operator_allowed = FALSE,
      warning = NA_character_,
      error_code = NA_character_,
      message = NA_character_
    ))
  }

  if (identical(meta$status, "unknown") && model %in% llm_model_extra_allowlist()) {
    warning <- paste(
      "Gemini model", model,
      "is outside the built-in SysNDD catalog and is allowed by operator override."
    )
    return(list(
      valid = TRUE,
      operator_allowed = TRUE,
      warning = warning,
      error_code = NA_character_,
      message = warning
    ))
  }

  reason <- if (identical(meta$status, "shutdown")) {
    paste0("Gemini model ", model, " is shut down and is not allowed.")
  } else {
    paste0("Gemini model ", model, " is not in the allowed SysNDD model catalog.")
  }

  list(
    valid = FALSE,
    operator_allowed = FALSE,
    warning = reason,
    error_code = "llm_model_invalid",
    message = reason
  )
}

#' Resolve effective Gemini model configuration
#'
#' Resolution order is `GEMINI_MODEL`, config `gemini_model`, then the SysNDD
#' default `LLM_DEFAULT_GEMINI_MODEL`.
#'
#' @param config Optional config list with `gemini_model`.
#' @return List with model, source, default, validity, and warning metadata.
#' @export
llm_model_config_resolve <- function(config = NULL) {
  runtime_config <- .llm_model_runtime_config(config)
  env_model <- .llm_model_scalar(Sys.getenv("GEMINI_MODEL", unset = NA_character_))
  config_model <- .llm_model_config_value(runtime_config)

  if (!is.na(env_model)) {
    model <- env_model
    source <- "env"
  } else if (!is.na(config_model)) {
    model <- config_model
    source <- "config"
  } else {
    model <- LLM_DEFAULT_GEMINI_MODEL
    source <- "default"
  }

  validation <- llm_model_config_validate(model, config = runtime_config)
  c(
    list(
      model = model,
      source = source,
      default_model = LLM_DEFAULT_GEMINI_MODEL
    ),
    validation
  )
}

#' Resolve the default Gemini model name
#'
#' @param config Optional config list with `gemini_model`.
#' @return Character model id.
#' @export
get_default_gemini_model <- function(config = NULL) {
  resolved <- llm_model_config_resolve(config = config)
  .llm_model_log_info(sprintf("Using Gemini model: %s", resolved$model))
  resolved$model
}

#' List Gemini models allowed for selection
#'
#' @param include_preview Logical, include preview models from the catalog.
#' @param include_operator_allowed Logical, append unknown operator-allowlisted
#'   models from `GEMINI_ALLOWED_MODELS_EXTRA`.
#' @return Character vector of model ids.
#' @export
list_gemini_models <- function(include_preview = TRUE, include_operator_allowed = TRUE) {
  catalog <- llm_model_catalog()
  rows <- catalog$allowed
  if (!include_preview) {
    rows <- rows & catalog$status != "preview"
  }

  models <- catalog$model_id[rows]
  if (include_operator_allowed) {
    extra <- setdiff(llm_model_extra_allowlist(), catalog$model_id)
    models <- c(models, extra)
  }

  unique(models)
}

#' Get display metadata for Gemini text generation models
#'
#' @param model_id Character Gemini model id.
#' @return List with display and policy metadata.
#' @export
get_gemini_model_metadata <- function(model_id) {
  info <- llm_model_metadata(model_id)
  if (identical(info$status, "unknown") && model_id %in% llm_model_extra_allowlist()) {
    info$description <- "Operator-allowlisted Gemini model outside the built-in SysNDD catalog"
    info$recommended_for <- "Operator allowlist"
    info$status <- "operator_allowed"
    info$allowed <- TRUE
  }
  info
}
