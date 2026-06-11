# functions/metadata-vocabulary-repository.R
#
# Repository layer for SysNDD-managed curation controlled vocabularies that the
# Admin "Manage Metadata" view (issue #32) administers.
#
# Scope (see AGENTS.md metadata-refresh notes):
#   - modifier_list                     (full CRUD)        SysNDD-managed
#   - ndd_entity_status_categories_list (full CRUD)        SysNDD-managed
#   - mode_of_inheritance_list          (edit + activate)  HPO-anchored
#   - variation_ontology_list           (edit + activate)  VariO-anchored
#
# Ontology-derived tables (phenotype_list, disease_ontology_set,
# non_alt_loci_set) are intentionally NOT writable here; they are refreshed
# from source via api/functions/metadata-refresh.R and the admin annotation
# jobs.
#
# Every statement uses parameterized `?` placeholders. db_execute_query /
# db_execute_statement already call DBI::dbBind(unname(params)), so caller
# param lists must be positional (unnamed-safe).

# ---------------------------------------------------------------------------
# Vocabulary descriptor table
# ---------------------------------------------------------------------------

#' Static descriptor of every admin-managed vocabulary.
#'
#' Centralises the table/column metadata so endpoints, services, and the
#' in-use delete guard share one source of truth. `usage` lists the tables
#' (and columns) that reference this vocabulary's primary key, used by the
#' in-use guard before a delete.
#'
#' @return Named list keyed by vocabulary slug.
#' @export
metadata_vocabulary_registry <- function() {
  list(
    modifier = list(
      slug = "modifier",
      label = "Modifiers",
      table = "modifier_list",
      pk = "modifier_id",
      pk_type = "integer",
      editable = TRUE,            # full CRUD (create/update/soft-delete)
      managed = "sysndd",
      fields = c("modifier_name", "allowed_phenotype", "allowed_variation"),
      has_is_active = TRUE,
      has_sort = TRUE,
      usage = list(
        list(table = "ndd_review_phenotype_connect", column = "modifier_id"),
        list(table = "ndd_review_variation_ontology_connect", column = "modifier_id")
      )
    ),
    status_category = list(
      slug = "status_category",
      label = "Status categories",
      table = "ndd_entity_status_categories_list",
      pk = "category_id",
      pk_type = "integer",
      editable = TRUE,
      managed = "sysndd",
      fields = c("category"),
      has_is_active = TRUE,
      has_sort = TRUE,
      usage = list(
        list(table = "ndd_entity_status", column = "category_id")
      )
    ),
    inheritance = list(
      slug = "inheritance",
      label = "Inheritance modes",
      table = "mode_of_inheritance_list",
      pk = "hpo_mode_of_inheritance_term",
      pk_type = "character",
      editable = "anchored",      # edit curated fields + activate only
      managed = "hpo",
      fields = c(
        "hpo_mode_of_inheritance_term_name",
        "hpo_mode_of_inheritance_term_definition",
        "inheritance_filter",
        "inheritance_short_text"
      ),
      has_is_active = TRUE,
      has_sort = TRUE,
      usage = list(
        list(table = "ndd_entity", column = "hpo_mode_of_inheritance_term")
      )
    ),
    variation_ontology = list(
      slug = "variation_ontology",
      label = "Variation ontology",
      table = "variation_ontology_list",
      pk = "vario_id",
      pk_type = "character",
      editable = "anchored",
      managed = "vario",
      fields = c("vario_name", "definition"),
      has_is_active = TRUE,
      has_sort = TRUE,
      usage = list(
        list(table = "ndd_review_variation_ontology_connect", column = "vario_id")
      )
    )
  )
}

#' Look up a vocabulary descriptor by slug, or NULL when unknown.
#'
#' @param slug Vocabulary slug.
#' @return Descriptor list or NULL.
#' @export
metadata_vocabulary_descriptor <- function(slug) {
  metadata_vocabulary_registry()[[slug]]
}

# ---------------------------------------------------------------------------
# Reads
# ---------------------------------------------------------------------------

#' List all rows of a managed vocabulary, ordered by sort then primary key.
#'
#' @param descriptor Vocabulary descriptor (from the registry).
#' @param conn Optional connection/pool. Defaults to global pool via helpers.
#' @return Tibble of all rows including inactive ones (admins see everything).
#' @export
metadata_vocabulary_list <- function(descriptor, conn = NULL) {
  order_col <- if (isTRUE(descriptor$has_sort)) "`sort`" else NULL
  order_clause <- paste(
    c(order_col, sprintf("`%s`", descriptor$pk)),
    collapse = ", "
  )
  sql <- sprintf(
    "SELECT * FROM `%s` ORDER BY %s",
    descriptor$table,
    order_clause
  )
  db_execute_query(sql, list(), conn = conn)
}

#' Fetch a single vocabulary row by primary key.
#'
#' @param descriptor Vocabulary descriptor.
#' @param pk_value Primary-key value.
#' @param conn Optional connection/pool.
#' @return Single-row tibble (0 rows when not found).
#' @export
metadata_vocabulary_get <- function(descriptor, pk_value, conn = NULL) {
  sql <- sprintf(
    "SELECT * FROM `%s` WHERE `%s` = ?",
    descriptor$table,
    descriptor$pk
  )
  db_execute_query(sql, list(pk_value), conn = conn)
}

#' Count references to a vocabulary value across its usage tables.
#'
#' Drives the in-use delete guard. Returns the total reference count so a
#' caller can block deletion (or refuse hard-delete) when the value is used.
#'
#' @param descriptor Vocabulary descriptor.
#' @param pk_value Primary-key value to check.
#' @param conn Optional connection/pool.
#' @return Integer total reference count across all usage tables.
#' @export
metadata_vocabulary_usage_count <- function(descriptor, pk_value, conn = NULL) {
  usage <- descriptor$usage %||% list()
  if (length(usage) == 0) {
    return(0L)
  }
  total <- 0L
  for (ref in usage) {
    sql <- sprintf(
      "SELECT COUNT(*) AS n FROM `%s` WHERE `%s` = ?",
      ref$table,
      ref$column
    )
    res <- db_execute_query(sql, list(pk_value), conn = conn)
    total <- total + as.integer(res$n[[1]] %||% 0L)
  }
  total
}

# ---------------------------------------------------------------------------
# Writes (parameterized, positional placeholders)
# ---------------------------------------------------------------------------

#' Insert a vocabulary row.
#'
#' @param descriptor Vocabulary descriptor.
#' @param columns Named list of column -> value (must include the pk).
#' @param conn Optional connection/pool.
#' @return Integer rows affected.
#' @export
metadata_vocabulary_insert <- function(descriptor, columns, conn = NULL) {
  cols <- names(columns)
  placeholders <- paste(rep("?", length(cols)), collapse = ", ")
  col_sql <- paste(sprintf("`%s`", cols), collapse = ", ")
  sql <- sprintf(
    "INSERT INTO `%s` (%s) VALUES (%s)",
    descriptor$table,
    col_sql,
    placeholders
  )
  db_execute_statement(sql, unname(as.list(columns)), conn = conn)
}

#' Update a vocabulary row by primary key.
#'
#' @param descriptor Vocabulary descriptor.
#' @param pk_value Primary-key value identifying the row.
#' @param columns Named list of column -> value to set (pk excluded).
#' @param conn Optional connection/pool.
#' @return Integer rows affected.
#' @export
metadata_vocabulary_update <- function(descriptor, pk_value, columns, conn = NULL) {
  cols <- names(columns)
  set_sql <- paste(sprintf("`%s` = ?", cols), collapse = ", ")
  sql <- sprintf(
    "UPDATE `%s` SET %s WHERE `%s` = ?",
    descriptor$table,
    set_sql,
    descriptor$pk
  )
  params <- c(unname(as.list(columns)), list(pk_value))
  db_execute_statement(sql, params, conn = conn)
}

#' Soft-delete (deactivate) a vocabulary row by setting is_active = 0.
#'
#' @param descriptor Vocabulary descriptor.
#' @param pk_value Primary-key value.
#' @param conn Optional connection/pool.
#' @return Integer rows affected.
#' @export
metadata_vocabulary_soft_delete <- function(descriptor, pk_value, conn = NULL) {
  sql <- sprintf(
    "UPDATE `%s` SET `is_active` = 0 WHERE `%s` = ?",
    descriptor$table,
    descriptor$pk
  )
  db_execute_statement(sql, list(pk_value), conn = conn)
}

#' Compute the next primary-key value for integer-keyed vocabularies.
#'
#' modifier_list / ndd_entity_status_categories_list do not auto-increment,
#' so new rows pick MAX(pk)+1.
#'
#' @param descriptor Vocabulary descriptor.
#' @param conn Optional connection/pool.
#' @return Integer next pk value.
#' @export
metadata_vocabulary_next_id <- function(descriptor, conn = NULL) {
  sql <- sprintf(
    "SELECT COALESCE(MAX(`%s`), 0) + 1 AS next_id FROM `%s`",
    descriptor$pk,
    descriptor$table
  )
  res <- db_execute_query(sql, list(), conn = conn)
  as.integer(res$next_id[[1]])
}
