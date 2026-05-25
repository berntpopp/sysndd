# api/functions/metadata-refresh.R
#
# Transaction-safe helpers for metadata table refreshes. MySQL TRUNCATE is DDL
# and auto-commits, so refresh paths must use DELETE plus insert inside a real
# transaction when rollback semantics matter.

metadata_with_foreign_key_checks_disabled <- function(conn, work) {
  if (!is.function(work)) {
    stop("work must be a function", call. = FALSE)
  }

  fk_restored <- FALSE
  work_completed <- FALSE

  DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")
  on.exit({
    if (!isTRUE(fk_restored)) {
      metadata_restore_foreign_key_checks(
        conn,
        "metadata refresh cleanup",
        fail_on_error = isTRUE(work_completed)
      )
    }
  }, add = TRUE)

  result <- work()
  work_completed <- TRUE

  metadata_restore_foreign_key_checks(conn, "metadata refresh", fail_on_error = TRUE)
  fk_restored <- TRUE

  result
}

metadata_log_foreign_key_restore_failure <- function(message) {
  if (exists("log_warn", mode = "function")) {
    tryCatch(
      get("log_warn", mode = "function")(message),
      error = function(e) warning(message, call. = FALSE)
    )
  } else {
    warning(message, call. = FALSE)
  }

  invisible(NULL)
}

metadata_restore_foreign_key_checks <- function(conn,
                                                context,
                                                fail_on_error = TRUE) {
  tryCatch(
    {
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1")
      invisible(TRUE)
    },
    error = function(e) {
      message <- sprintf(
        "Failed to restore FOREIGN_KEY_CHECKS after %s: %s",
        context,
        conditionMessage(e)
      )
      metadata_log_foreign_key_restore_failure(message)
      if (isTRUE(fail_on_error)) {
        stop(message, call. = FALSE)
      }
      invisible(FALSE)
    }
  )
}

metadata_apply_ontology_auto_fixes <- function(conn, auto_fixes) {
  if (is.null(auto_fixes) || nrow(auto_fixes) == 0) {
    return(0L)
  }

  auto_fixes_applied <- 0L
  for (i in seq_len(nrow(auto_fixes))) {
    fix <- auto_fixes[i, ]
    DBI::dbExecute(
      conn,
      "UPDATE ndd_entity SET disease_ontology_id_version = ? WHERE disease_ontology_id_version = ?",
      params = unname(list(fix$new_version, fix$old_version))
    )
    auto_fixes_applied <- auto_fixes_applied + 1L
  }

  auto_fixes_applied
}

refresh_disease_ontology_set <- function(conn,
                                         disease_ontology_set_update,
                                         auto_fixes = tibble::tibble(
                                           old_version = character(0),
                                           new_version = character(0)
                                         ),
                                         compatibility_rows = tibble::tibble()) {
  metadata_with_foreign_key_checks_disabled(conn, function() {
    DBI::dbWithTransaction(conn, {
      DBI::dbExecute(conn, "DELETE FROM disease_ontology_set")

      if (nrow(disease_ontology_set_update) > 0) {
        DBI::dbAppendTable(conn, "disease_ontology_set", disease_ontology_set_update)
      }

      compat_count <- 0L
      if (nrow(compatibility_rows) > 0) {
        DBI::dbAppendTable(conn, "disease_ontology_set", compatibility_rows)
        compat_count <- nrow(compatibility_rows)
      }

      auto_fixes_applied <- metadata_apply_ontology_auto_fixes(conn, auto_fixes)

      list(
        auto_fixes_applied = auto_fixes_applied,
        compatibility_rows = compat_count
      )
    })
  })
}
