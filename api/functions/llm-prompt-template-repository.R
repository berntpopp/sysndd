# functions/llm-prompt-template-repository.R
#
# Database persistence for admin-editable LLM prompt templates
# (`llm_prompt_templates` table, migration 008_add_llm_prompt_templates.sql).
#
# This file provides:
# - get_prompt_template(): Active-template lookup with hardcoded-default fallback
# - get_default_prompt_template(): Hardcoded prompt fallback (matches migration 008 seeds)
# - save_prompt_template(): Transactional insert + previous-version retirement
# - get_all_prompt_templates(): Active template for every prompt_type (admin display)
#
# Dependencies (sourced before this file):
# - db-helpers.R: db_execute_query(), db_execute_statement(), db_with_transaction()
#
# Extracted from the original monolithic llm-service.R as part of the #346
# refactor (Wave 4, Task 7). Generation/fetch orchestration stays in
# llm-service.R; this file is DB-persistence-only.

require(logger)

log_threshold(INFO)

# Load database helper functions for repository layer access (if not already loaded)
if (!exists("db_execute_query", mode = "function")) {
  .funcs_dir <- tryCatch(file.path(get_api_dir(), "functions"), error = function(e) "functions")
  .p <- file.path(.funcs_dir, "db-helpers.R")
  if (file.exists(.p)) source(.p, local = FALSE)
  rm(list = intersect(c(".funcs_dir", ".p"), ls()), envir = environment())
}


#' Get active prompt template from database
#'
#' Returns the active prompt template for the specified type.
#' Falls back to hardcoded default if no database entry exists.
#'
#' @param prompt_type Character, one of "functional_generation", "functional_judge",
#'   "phenotype_generation", "phenotype_judge"
#'
#' @return List with template_id, prompt_type, version, template_text, description
#'
#' @export
get_prompt_template <- function(prompt_type) {
  valid_types <- c(
    "functional_generation", "functional_judge",
    "phenotype_generation", "phenotype_judge"
  )
  if (!prompt_type %in% valid_types) {
    log_error("Invalid prompt_type: {prompt_type}")
    rlang::abort(paste("Invalid prompt_type:", prompt_type))
  }

  # Try database first
  result <- tryCatch(
    {
      db_execute_query(
        "SELECT template_id, prompt_type, version, template_text, description
       FROM llm_prompt_templates
       WHERE prompt_type = ? AND is_active = TRUE
       ORDER BY created_at DESC
       LIMIT 1",
        list(prompt_type)
      )
    },
    error = function(e) {
      log_warn("Failed to query prompt templates: {e$message}")
      tibble::tibble()
    }
  )

  if (nrow(result) > 0) {
    return(list(
      template_id = result$template_id[1],
      prompt_type = result$prompt_type[1],
      version = result$version[1],
      template_text = result$template_text[1],
      description = result$description[1]
    ))
  }

  # Fallback to hardcoded defaults
  log_debug("Using hardcoded default for prompt_type: {prompt_type}")
  get_default_prompt_template(prompt_type)
}


#' Get hardcoded default prompt template
#'
#' Returns the original hardcoded prompt for backward compatibility.
#' Used when database table doesn't exist or has no entry for type.
#'
#' @param prompt_type Character, one of "functional_generation", "functional_judge",
#'   "phenotype_generation", "phenotype_judge"
#'
#' @return List with template_id, prompt_type, version, template_text, description
#'
#' @export
get_default_prompt_template <- function(prompt_type) {
  # Hardcoded fallbacks matching the original prompts in build_*_prompt functions
  templates <- list(
    functional_generation = paste0(
      "You are a genomics expert analyzing gene clusters associated with ",
      "neurodevelopmental disorders. Analyze this functional gene cluster and ",
      "summarize its biological significance based STRICTLY on the enrichment ",
      "data provided."
    ),
    functional_judge = paste0(
      "You are a STRICT scientific accuracy validator. Review the following ",
      "AI-generated summary and evaluate whether it accurately represents the ",
      "gene cluster data."
    ),
    phenotype_generation = paste0(
      "You are a clinical geneticist analyzing phenotype clusters from a ",
      "neurodevelopmental disorder database. Analyze this phenotype cluster ",
      "and describe its clinical pattern using ONLY the data listed."
    ),
    phenotype_judge = paste0(
      "You are a STRICT validator for AI-generated phenotype cluster summaries. ",
      "Review the following summary and evaluate scientific accuracy."
    )
  )

  list(
    template_id = NA_integer_,
    prompt_type = prompt_type,
    version = "1.0",
    template_text = templates[[prompt_type]],
    description = "Default hardcoded template"
  )
}


#' Save prompt template to database
#'
#' Creates a new version of a prompt template. Optionally deactivates
#' previous versions of the same type.
#'
#' @param prompt_type Character, one of "functional_generation", "functional_judge",
#'   "phenotype_generation", "phenotype_judge"
#' @param template_text Character, the prompt text
#' @param version Character, version string (e.g., "1.1")
#' @param description Character or NULL, description of changes
#' @param created_by Integer or NULL, user_id of creator
#' @param deactivate_previous Logical, if TRUE marks previous versions as inactive
#'
#' @return Integer, the template_id of the new entry
#'
#' @export
save_prompt_template <- function(prompt_type,
                                 template_text,
                                 version,
                                 description = NULL,
                                 created_by = NULL,
                                 deactivate_previous = TRUE) {
  valid_types <- c(
    "functional_generation", "functional_judge",
    "phenotype_generation", "phenotype_judge"
  )
  if (!prompt_type %in% valid_types) {
    rlang::abort(paste("Invalid prompt_type:", prompt_type))
  }

  # Convert NULLs to NA for DBI binding (DBI requires length 1)
  description_val <- if (is.null(description)) NA_character_ else description
  created_by_val <- if (is.null(created_by)) NA_integer_ else as.integer(created_by)

  result <- db_with_transaction(function(txn_conn) {
    if (deactivate_previous) {
      db_execute_statement(
        "UPDATE llm_prompt_templates SET is_active = FALSE WHERE prompt_type = ?",
        list(prompt_type),
        conn = txn_conn
      )
    }

    db_execute_statement(
      "INSERT INTO llm_prompt_templates
       (prompt_type, version, template_text, description, is_active, created_by)
       VALUES (?, ?, ?, ?, TRUE, ?)",
      list(prompt_type, version, template_text, description_val, created_by_val),
      conn = txn_conn
    )

    id_result <- db_execute_query("SELECT LAST_INSERT_ID() AS id", conn = txn_conn)
    id_result$id[1]
  })

  log_info("Saved prompt template: type={prompt_type}, version={version}, id={result}")
  result
}


#' Get all prompt templates for admin display
#'
#' Returns the active template for each prompt type.
#'
#' @return Named list with template data for each type
#'
#' @export
get_all_prompt_templates <- function() {
  types <- c(
    "functional_generation", "functional_judge",
    "phenotype_generation", "phenotype_judge"
  )

  templates <- lapply(types, get_prompt_template)
  names(templates) <- types
  templates
}
