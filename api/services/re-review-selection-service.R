# Re-Review Selection Service Layer for SysNDD API
# Provides the criteria/allowlist/matching logic that decides WHICH entities
# belong in a re-review batch.
#
# Split out of re-review-service.R (#346) so batch lifecycle (create, assign,
# reassign, archive, entity-assign, recalculate — see re-review-service.R)
# stays separate from selection (submit-field allowlist, WHERE/param
# builders, gene-atomic matching, preview, and manual-pick available-entity
# listing). Must be sourced BEFORE re-review-service.R: the lifecycle
# functions batch_create()/batch_recalculate() call select_matching_entities()
# defined here.
#
# Functions accept pool as parameter (dependency injection)

#' Columns the re-review submit endpoint is permitted to write.
#' The frontend submit action sends only `re_review_submitted`; the save-flags
#' and review/status IDs are written by review_update_re_review_status() /
#' status_update_re_review_status(), NOT here. Restricting to this single column
#' blocks SQL-identifier injection AND self-approval mass-assignment (#2, Codex).
re_review_submit_allowed_fields <- function() {
  c("re_review_submitted")
}

#' Validate + filter submitted field names to the allowlist. Fails loud.
#' setdiff() enforces membership explicitly, first: validate_query_column()
#' alone is not enough, since it special-cases "any"/"all" as always-valid
#' cross-column tokens (for generate_filter_expressions()/generate_sort_expressions())
#' which would otherwise let a field literally named "any"/"all" bypass the allowlist.
re_review_filter_submit_fields <- function(field_names) {
  allowed <- re_review_submit_allowed_fields()
  # An empty field set would build "UPDATE ... SET  WHERE ..." -> malformed SQL
  # (a 500 leaking a driver error). Reject it as a clean 400 (Codex LOW).
  if (length(field_names) == 0L) {
    stop_for_bad_request("Re-review submit requires at least one updatable field.")
  }
  bad <- setdiff(field_names, allowed)
  if (length(bad) > 0) {
    stop_for_bad_request(paste("Disallowed re-review submit field(s):", paste(bad, collapse = ", ")))
  }
  for (f in field_names) validate_query_column(f, allowed) # bare-identifier backstop
  field_names
}


#' Build dynamic WHERE clause from batch criteria
#'
#' Constructs a SQL WHERE clause from the provided criteria object.
#' Supports entity_ids, date_range, gene_list, status_filter, and disease_id filtering.
#'
#' @param criteria List with optional entity_ids (vector of entity IDs),
#'   date_range (list with start, end), gene_list (vector of hgnc_ids),
#'   status_filter (category_id), disease_id
#' @param pool Database connection pool for safe SQL interpolation
#' @return SQL string (without WHERE keyword). Returns "1=1" if no criteria.
#'
#' @examples
#' \dontrun{
#' where_clause <- build_batch_where_clause(
#'   list(date_range = list(start = "2020-01-01", end = "2023-12-31")),
#'   pool
#' )
#' }
#'
#' @export
build_batch_where_clause <- function(criteria, pool) {
  conditions <- character(0)

  # Direct entity ID filter (highest priority - specific entities)
  if (!is.null(criteria$entity_ids) && length(criteria$entity_ids) > 0) {
    placeholders <- paste(rep("?", length(criteria$entity_ids)), collapse = ", ")
    conditions <- c(conditions, paste0("e.entity_id IN (", placeholders, ")"))
  }

  # Date range filter
  if (!is.null(criteria$date_range)) {
    if (!is.null(criteria$date_range$start) && !is.null(criteria$date_range$end)) {
      conditions <- c(conditions, "r.review_date BETWEEN ? AND ?")
    } else if (!is.null(criteria$date_range$start)) {
      conditions <- c(conditions, "r.review_date >= ?")
    } else if (!is.null(criteria$date_range$end)) {
      conditions <- c(conditions, "r.review_date <= ?")
    }
  }

  # Gene list filter (array of HGNC IDs)
  if (!is.null(criteria$gene_list) && length(criteria$gene_list) > 0) {
    placeholders <- paste(rep("?", length(criteria$gene_list)), collapse = ", ")
    conditions <- c(conditions, paste0("e.hgnc_id IN (", placeholders, ")"))
  }

  # Status filter (category_id)
  if (!is.null(criteria$status_filter)) {
    conditions <- c(conditions, "s.category_id = ?")
  }

  # Disease filter
  if (!is.null(criteria$disease_id)) {
    conditions <- c(conditions, "e.disease_ontology_id_version LIKE ?")
  }

  # Combine with AND
  if (length(conditions) == 0) {
    return("1=1") # No filters, match all
  }

  paste(conditions, collapse = " AND ")
}


#' Build parameter list from batch criteria
#'
#' Creates a list of parameters matching the WHERE clause placeholders.
#'
#' @param criteria List with criteria (same structure as build_batch_where_clause)
#' @return List of parameters in order matching WHERE clause placeholders
#'
#' @keywords internal
build_batch_params <- function(criteria) {
  params <- list()

  # Entity IDs parameters (must match order in WHERE clause)
  if (!is.null(criteria$entity_ids) && length(criteria$entity_ids) > 0) {
    params <- c(params, as.list(criteria$entity_ids))
  }

  # Date range parameters
  if (!is.null(criteria$date_range)) {
    if (!is.null(criteria$date_range$start) && !is.null(criteria$date_range$end)) {
      params <- c(params, list(criteria$date_range$start, criteria$date_range$end))
    } else if (!is.null(criteria$date_range$start)) {
      params <- c(params, list(criteria$date_range$start))
    } else if (!is.null(criteria$date_range$end)) {
      params <- c(params, list(criteria$date_range$end))
    }
  }

  # Gene list parameters
  if (!is.null(criteria$gene_list) && length(criteria$gene_list) > 0) {
    params <- c(params, as.list(criteria$gene_list))
  }

  # Status filter parameter
  if (!is.null(criteria$status_filter)) {
    params <- c(params, list(criteria$status_filter))
  }

  # Disease filter parameter (with wildcard for LIKE)
  if (!is.null(criteria$disease_id)) {
    params <- c(params, list(paste0(criteria$disease_id, "%")))
  }

  params
}


#' Select entities for a re-review batch with gene-atomic grouping.
#'
#' Two-step query: first collect distinct hgnc_ids matching criteria
#' (ordered by oldest review_date), then expand to all matching entities
#' for those genes. Trim with a soft LIMIT — include all entities for a
#' partially-included gene; stop adding new genes once cumulative entity
#' count >= batch_size. Returns up to `batch_size` entities, with the
#' boundary gene fully included even if it pushes the count past the cap.
#'
#' @param criteria Named list with batch criteria.
#' @param batch_size Integer cap (default 20). The actual returned count
#'   may exceed this by at most (entities_in_boundary_gene - 1).
#' @param conn Database connection (pool or transaction connection).
#' @return Named list:
#'   - entities: data frame of selected entities with entity_id, hgnc_id,
#'     symbol, status_id, review_id, review_date, etc.
#'   - boundary_gene: hgnc_id where the soft-LIMIT engaged, or NA if the
#'     batch fits cleanly under batch_size.
#'   - gene_count: number of distinct hgnc_id values in the result.
#'   - entity_count: total number of entities (== nrow(entities)).
#'
#' @keywords internal
select_matching_entities <- function(criteria, batch_size = 20, conn) {
  where_clause <- build_batch_where_clause(criteria, conn)
  params <- build_batch_params(criteria)

  # Step 1: distinct hgnc_ids matching the criteria, ordered by oldest review_date per gene.
  # Cap at batch_size (worst case 1 entity per gene = batch_size genes).
  gene_query <- paste0(
    "SELECT e.hgnc_id, MIN(r.review_date) AS first_review_date
     FROM ndd_entity_view e
     LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id AND r.is_primary = 1
     LEFT JOIN ndd_entity_status s ON e.entity_id = s.entity_id AND s.is_active = 1
     WHERE ", where_clause, "
       AND e.entity_id NOT IN (
         SELECT rec.entity_id FROM re_review_entity_connect rec
         INNER JOIN re_review_assignment ra ON rec.re_review_batch = ra.re_review_batch
         WHERE rec.re_review_approved = 0
       )
     GROUP BY e.hgnc_id
     ORDER BY first_review_date ASC
     LIMIT ?"
  )
  gene_params <- c(params, list(as.integer(batch_size)))
  gene_rows <- db_execute_query(gene_query, gene_params, conn = conn)

  if (nrow(gene_rows) == 0) {
    return(list(
      entities     = data.frame(),
      boundary_gene = NA_character_,
      gene_count   = 0L,
      entity_count = 0L
    ))
  }

  # Step 2: pull all matching entities for those genes.
  hgnc_placeholders <- paste(rep("?", nrow(gene_rows)), collapse = ", ")
  ent_query <- paste0(
    "SELECT DISTINCT e.entity_id, e.hgnc_id, e.symbol, e.disease_ontology_name,
            e.disease_ontology_id_version, e.hpo_mode_of_inheritance_term_name,
            r.review_date, r.review_id, s.category_id, s.status_id
     FROM ndd_entity_view e
     LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id AND r.is_primary = 1
     LEFT JOIN ndd_entity_status s ON e.entity_id = s.entity_id AND s.is_active = 1
     WHERE ", where_clause, "
       AND e.hgnc_id IN (", hgnc_placeholders, ")
       AND e.entity_id NOT IN (
         SELECT rec.entity_id FROM re_review_entity_connect rec
         INNER JOIN re_review_assignment ra ON rec.re_review_batch = ra.re_review_batch
         WHERE rec.re_review_approved = 0
       )
     ORDER BY e.hgnc_id, r.review_date ASC"
  )
  ent_params <- c(params, as.list(gene_rows$hgnc_id))
  all_matching <- db_execute_query(ent_query, ent_params, conn = conn)

  if (nrow(all_matching) == 0) {
    return(list(
      entities     = data.frame(),
      boundary_gene = NA_character_,
      gene_count   = 0L,
      entity_count = 0L
    ))
  }

  # Step 3: soft LIMIT — accumulate by gene; stop adding new genes once entity count >= batch_size.
  # The boundary gene is fully included even if it pushes the cumulative count past the cap.
  selected <- list()
  per_gene <- split(all_matching, all_matching$hgnc_id)
  # Preserve gene order as discovered in step 1 (oldest first):
  per_gene <- per_gene[as.character(gene_rows$hgnc_id)]
  total <- 0L
  boundary <- NA_character_
  for (gid in names(per_gene)) {
    block <- per_gene[[gid]]
    if (total >= batch_size) break
    selected[[length(selected) + 1L]] <- block
    total <- total + nrow(block)
    if (total > batch_size && is.na(boundary)) {
      boundary <- gid
    }
  }

  out <- if (length(selected) > 0L) do.call(rbind, selected) else data.frame()
  list(
    entities     = out,
    boundary_gene = boundary,
    gene_count   = length(selected),
    entity_count = nrow(out)
  )
}


#' Preview matching entities without creating batch
#'
#' Returns entities that match the provided criteria without creating a batch.
#' Useful for previewing batch contents before creation.
#'
#' @param criteria List with batch criteria (see build_batch_where_clause)
#' @param batch_size Integer maximum number of entities to return (default: 20)
#' @param pool Database connection pool
#' @return List with status=200 and data=tibble of matching entities
#'
#' @examples
#' \dontrun{
#' result <- batch_preview(
#'   list(date_range = list(start = "2020-01-01", end = "2022-12-31")),
#'   batch_size = 20,
#'   pool
#' )
#' }
#'
#' @export
batch_preview <- function(criteria, batch_size = 20, pool) {
  # Use gene-atomic helper to avoid splitting entities across gene boundaries
  # (fixes issue #29 where DISTINCT + ORDER BY review_date + LIMIT split genes)
  selection <- select_matching_entities(criteria, batch_size = batch_size, conn = pool)
  matching_entities <- selection$entities

  logger::log_info("Batch preview",
    criteria_count = length(criteria),
    matching_count = selection$entity_count,
    gene_count     = selection$gene_count,
    boundary_gene  = selection$boundary_gene
  )

  list(
    status        = 200,
    data          = matching_entities,
    boundary_gene = selection$boundary_gene,
    gene_count    = selection$gene_count,
    entity_count  = selection$entity_count
  )
}


#' List entities available for manual re-review assignment
#'
#' Returns entities not currently connected to an active re-review batch. This
#' is intentionally separate from batch_preview(): manual picking needs a
#' searchable, paginated entity list, while preview is gene-atomic and
#' batch-size limited.
#'
#' @param query Optional search string matching entity_id, symbol, disease,
#'   status category, or review date.
#' @param page Integer page number, one-based.
#' @param page_size Integer page size.
#' @param pool Database connection pool.
#' @return List with status, data, and meta.
#'
#' @export
available_entities <- function(query = NULL, page = 1L, page_size = 25L, pool) {
  page <- max(1L, as.integer(page %||% 1L))
  page_size <- min(100L, max(1L, as.integer(page_size %||% 25L)))
  offset <- (page - 1L) * page_size

  where_clause <- paste(
    "e.entity_id NOT IN (
       SELECT rec.entity_id FROM re_review_entity_connect rec
       INNER JOIN re_review_assignment ra ON rec.re_review_batch = ra.re_review_batch
       WHERE rec.re_review_approved = 0
     )"
  )
  params <- list()

  query <- trimws(query %||% "")
  if (nzchar(query)) {
    where_clause <- paste0(
      where_clause,
      " AND (
        CAST(e.entity_id AS CHAR) LIKE ?
        OR e.symbol LIKE ?
        OR e.disease_ontology_name LIKE ?
        OR COALESCE(c.category, '') LIKE ?
        OR DATE_FORMAT(r.review_date, '%Y-%m-%d') LIKE ?
      )"
    )
    like_query <- paste0("%", query, "%")
    params <- rep(list(like_query), 5L)
  }

  count_sql <- paste0(
    "SELECT COUNT(*) AS total
     FROM ndd_entity_view e
     LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id AND r.is_primary = 1
     LEFT JOIN ndd_entity_status s ON e.entity_id = s.entity_id AND s.is_active = 1
     LEFT JOIN ndd_entity_status_categories_list c ON s.category_id = c.category_id
     WHERE ", where_clause
  )
  total_rows <- db_execute_query(count_sql, params, conn = pool)
  total <- as.integer(total_rows$total[1] %||% 0L)

  data_sql <- paste0(
    "SELECT DISTINCT e.entity_id, e.hgnc_id, e.symbol AS gene_symbol,
            e.disease_ontology_name, r.review_date, c.category AS status_name
     FROM ndd_entity_view e
     LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id AND r.is_primary = 1
     LEFT JOIN ndd_entity_status s ON e.entity_id = s.entity_id AND s.is_active = 1
     LEFT JOIN ndd_entity_status_categories_list c ON s.category_id = c.category_id
     WHERE ", where_clause, "
     ORDER BY r.review_date ASC, e.entity_id ASC
     LIMIT ? OFFSET ?"
  )
  rows <- db_execute_query(data_sql, c(params, list(page_size, offset)), conn = pool)

  list(
    status = 200,
    data = rows,
    meta = list(
      page = page,
      page_size = page_size,
      total = total,
      total_pages = ceiling(total / page_size)
    )
  )
}
