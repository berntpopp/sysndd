# Re-Review Service Layer for SysNDD API
# Provides business logic for dynamic batch management
#
# Functions accept pool as parameter (dependency injection)
# Handles batch creation, assignment, reassignment, and lifecycle

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


#' Create a new re-review batch
#'
#' Creates a new batch with entities matching the provided criteria.
#' Optionally assigns the batch to a user during creation.
#'
#' @param criteria List with batch criteria (at least one required)
#' @param assigned_user_id Optional user_id to assign batch to (can be NULL)
#' @param batch_name Optional custom batch name (auto-generated if NULL)
#' @param pool Database connection pool
#' @return List with status, message, and entry (batch_id, entity_count)
#'
#' @details
#' Uses db_with_transaction() for atomicity. If any step fails, the entire
#' operation is rolled back.
#'
#' Entity overlap prevention: Excludes entities already in active batches
#' (where re_review_approved = 0 and batch has an assignment).
#'
#' @examples
#' \dontrun{
#' result <- batch_create(
#'   list(date_range = list(start = "2020-01-01", end = "2022-12-31")),
#'   assigned_user_id = 5,
#'   batch_name = "Old entries batch",
#'   pool
#' )
#' }
#'
#' @export
batch_create <- function(criteria, assigned_user_id = NULL, batch_name = NULL, pool) {
  # Validate at least one criterion provided
  has_criteria <- (!is.null(criteria$entity_ids) && length(criteria$entity_ids) > 0) ||
    !is.null(criteria$date_range) ||
    (!is.null(criteria$gene_list) && length(criteria$gene_list) > 0) ||
    !is.null(criteria$status_filter) ||
    !is.null(criteria$disease_id)

  if (!has_criteria) {
    logger::log_warn("Batch creation failed: no criteria provided")
    return(list(
      status = 400,
      message = "At least one selection criterion is required"
    ))
  }

  # Get batch_size from criteria or use default
  batch_size <- if (!is.null(criteria$batch_size)) criteria$batch_size else 20

  # Use transaction for atomicity
  # Pass a function that receives the transaction connection
  result <- db_with_transaction(function(txn_conn) {
    # 1. Generate batch_name if NULL
    if (is.null(batch_name) || batch_name == "") {
      batch_name <- format(Sys.time(), "Batch %Y-%m-%d %H:%M")
    }

    # 2. Get next batch_id
    max_batch_result <- db_execute_query(
      "SELECT COALESCE(MAX(re_review_batch), 0) + 1 as next_batch FROM re_review_entity_connect",
      conn = txn_conn
    )
    batch_id <- max_batch_result$next_batch[1]

    # 3. Find matching entities using gene-atomic helper (fixes issue #29)
    selection <- select_matching_entities(criteria, batch_size = batch_size, conn = txn_conn)
    matching_entities <- selection$entities

    if (nrow(matching_entities) == 0) {
      stop("No entities match the specified criteria")
    }

    # 4. Insert re_review_entity_connect records for each entity
    for (i in seq_len(nrow(matching_entities))) {
      entity <- matching_entities[i, ]
      db_execute_statement(
        "INSERT INTO re_review_entity_connect
         (entity_id, re_review_batch, status_id, review_id,
          re_review_review_saved, re_review_status_saved, re_review_submitted, re_review_approved)
         VALUES (?, ?, ?, ?, 0, 0, 0, 0)",
        list(
          entity$entity_id,
          batch_id,
          entity$status_id,
          entity$review_id
        ),
        conn = txn_conn
      )
    }

    # 5. Create assignment if user specified
    if (!is.null(assigned_user_id)) {
      db_execute_statement(
        "INSERT INTO re_review_assignment (user_id, re_review_batch) VALUES (?, ?)",
        list(assigned_user_id, batch_id),
        conn = txn_conn
      )
    }

    # Return batch info
    list(batch_id = batch_id, entity_count = nrow(matching_entities))
  }, pool_obj = pool)

  logger::log_info("Batch created",
    batch_id = result$batch_id,
    entity_count = result$entity_count,
    assigned_to = assigned_user_id,
    batch_name = batch_name
  )

  list(
    status = 200,
    message = "Batch created successfully",
    entry = result
  )
}


#' Assign a batch to a user
#'
#' Assigns an unassigned batch to a specified user.
#'
#' @param batch_id Integer batch ID to assign
#' @param user_id Integer user ID to assign batch to
#' @param pool Database connection pool
#' @return List with status and message
#'
#' @examples
#' \dontrun{
#' result <- batch_assign(batch_id = 15, user_id = 5, pool)
#' }
#'
#' @export
batch_assign <- function(batch_id, user_id, pool) {
  # Verify batch exists
  batch_exists <- db_execute_query(
    "SELECT COUNT(*) as count FROM re_review_entity_connect WHERE re_review_batch = ?",
    list(batch_id),
    conn = pool
  )

  if (batch_exists$count[1] == 0) {
    logger::log_warn("Batch assignment failed: batch not found", batch_id = batch_id)
    return(list(
      status = 404,
      message = "Batch not found"
    ))
  }

  # Verify batch is not already assigned
  existing_assignment <- db_execute_query(
    "SELECT COUNT(*) as count FROM re_review_assignment WHERE re_review_batch = ?",
    list(batch_id),
    conn = pool
  )

  if (existing_assignment$count[1] > 0) {
    logger::log_warn("Batch assignment failed: already assigned", batch_id = batch_id)
    return(list(
      status = 409,
      message = "Batch is already assigned. Use reassign to change assignment."
    ))
  }

  # Insert assignment
  db_execute_statement(
    "INSERT INTO re_review_assignment (user_id, re_review_batch) VALUES (?, ?)",
    list(user_id, batch_id),
    conn = pool
  )

  logger::log_info("Batch assigned",
    batch_id = batch_id,
    user_id = user_id
  )

  list(
    status = 200,
    message = "Batch assigned successfully"
  )
}


#' Reassign a batch to a different user
#'
#' Changes the user assignment for an existing batch.
#'
#' @param batch_id Integer batch ID to reassign
#' @param new_user_id Integer new user ID to assign batch to
#' @param pool Database connection pool
#' @return List with status and message
#'
#' @examples
#' \dontrun{
#' result <- batch_reassign(batch_id = 15, new_user_id = 8, pool)
#' }
#'
#' @export
batch_reassign <- function(batch_id, new_user_id, pool) {
  # Verify batch exists
  batch_exists <- db_execute_query(
    "SELECT COUNT(*) as count FROM re_review_entity_connect WHERE re_review_batch = ?",
    list(batch_id),
    conn = pool
  )

  if (batch_exists$count[1] == 0) {
    logger::log_warn("Batch reassignment failed: batch not found", batch_id = batch_id)
    return(list(
      status = 404,
      message = "Batch not found"
    ))
  }

  # Check if assignment exists
  existing_assignment <- db_execute_query(
    "SELECT assignment_id, user_id FROM re_review_assignment WHERE re_review_batch = ?",
    list(batch_id),
    conn = pool
  )

  if (nrow(existing_assignment) == 0) {
    # No existing assignment, create one
    db_execute_statement(
      "INSERT INTO re_review_assignment (user_id, re_review_batch) VALUES (?, ?)",
      list(new_user_id, batch_id),
      conn = pool
    )
    logger::log_info("Batch assigned (was unassigned)",
      batch_id = batch_id,
      new_user_id = new_user_id
    )
  } else {
    # Update existing assignment
    old_user_id <- existing_assignment$user_id[1]
    db_execute_statement(
      "UPDATE re_review_assignment SET user_id = ? WHERE re_review_batch = ?",
      list(new_user_id, batch_id),
      conn = pool
    )
    logger::log_info("Batch reassigned",
      batch_id = batch_id,
      old_user_id = old_user_id,
      new_user_id = new_user_id
    )
  }

  list(
    status = 200,
    message = "Batch reassigned successfully"
  )
}


#' Archive a batch (soft delete)
#'
#' Archives a batch by removing its assignment. The re_review_entity_connect
#' records are preserved for audit trail.
#'
#' @param batch_id Integer batch ID to archive
#' @param pool Database connection pool
#' @return List with status and message
#'
#' @examples
#' \dontrun{
#' result <- batch_archive(batch_id = 15, pool)
#' }
#'
#' @export
batch_archive <- function(batch_id, pool) {
  # Verify batch exists
  batch_exists <- db_execute_query(
    "SELECT COUNT(*) as count FROM re_review_entity_connect WHERE re_review_batch = ?",
    list(batch_id),
    conn = pool
  )

  if (batch_exists$count[1] == 0) {
    logger::log_warn("Batch archive failed: batch not found", batch_id = batch_id)
    return(list(
      status = 404,
      message = "Batch not found"
    ))
  }

  # Remove assignment (soft delete - preserves entity_connect records for audit)
  affected_rows <- db_execute_statement(
    "DELETE FROM re_review_assignment WHERE re_review_batch = ?",
    list(batch_id),
    conn = pool
  )

  logger::log_info("Batch archived",
    batch_id = batch_id,
    assignment_removed = affected_rows > 0
  )

  list(
    status = 200,
    message = "Batch archived successfully"
  )
}


#' Assign specific entities to a user
#'
#' Creates a new batch containing only the specified entities and assigns
#' it to a user. This enables gene-specific assignment workflows.
#'
#' @param entity_ids Vector of entity_id integers to include in batch
#' @param user_id Integer user ID to assign batch to (required)
#' @param batch_name Optional custom batch name (auto-generated if NULL)
#' @param pool Database connection pool
#' @return List with status, message, and entry (batch_id, entity_count)
#'
#' @details
#' Uses db_with_transaction() for atomicity. Validates that:
#' - entity_ids is not empty
#' - All entity_ids exist in the database
#' - None of the entities are already in active batches
#'
#' @examples
#' \dontrun{
#' result <- entity_assign(
#'   entity_ids = c(100, 105, 110),
#'   user_id = 5,
#'   batch_name = "Priority genes batch",
#'   pool
#' )
#' }
#'
#' @export
entity_assign <- function(entity_ids, user_id, batch_name = NULL, pool) {
  # Validate entity_ids not empty
  if (is.null(entity_ids) || length(entity_ids) == 0) {
    logger::log_warn("Entity assignment failed: no entities provided")
    return(list(
      status = 400,
      message = "At least one entity_id is required"
    ))
  }

  # Validate user_id provided
  if (is.null(user_id)) {
    logger::log_warn("Entity assignment failed: no user_id provided")
    return(list(
      status = 400,
      message = "user_id is required"
    ))
  }

  # Use transaction for atomicity
  result <- db_with_transaction(function(txn_conn) {
    # 1. Generate batch_name if NULL
    if (is.null(batch_name) || batch_name == "") {
      batch_name <- format(Sys.time(), "Batch %Y-%m-%d %H:%M")
    }

    # 2. Validate all entity_ids exist
    placeholders <- paste(rep("?", length(entity_ids)), collapse = ", ")
    existing_entities <- db_execute_query(
      paste0(
        "SELECT e.entity_id, s.status_id, r.review_id
         FROM ndd_entity_view e
         LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id AND r.is_primary = 1
         LEFT JOIN ndd_entity_status s ON e.entity_id = s.entity_id AND s.is_active = 1
         WHERE e.entity_id IN (", placeholders, ")"
      ),
      as.list(entity_ids),
      conn = txn_conn
    )

    if (nrow(existing_entities) != length(entity_ids)) {
      missing_count <- length(entity_ids) - nrow(existing_entities)
      stop(paste("Some entity_ids do not exist or are inactive:", missing_count, "missing"))
    }

    # 3. Check for entities already in active batches
    entities_in_active <- db_execute_query(
      paste0(
        "SELECT rec.entity_id FROM re_review_entity_connect rec
         INNER JOIN re_review_assignment ra ON rec.re_review_batch = ra.re_review_batch
         WHERE rec.entity_id IN (", placeholders, ")
           AND rec.re_review_approved = 0"
      ),
      as.list(entity_ids),
      conn = txn_conn
    )

    if (nrow(entities_in_active) > 0) {
      stop(paste("Some entities are already in active batches:",
                 paste(entities_in_active$entity_id, collapse = ", ")))
    }

    # 4. Get next batch_id
    max_batch_result <- db_execute_query(
      "SELECT COALESCE(MAX(re_review_batch), 0) + 1 as next_batch FROM re_review_entity_connect",
      conn = txn_conn
    )
    batch_id <- max_batch_result$next_batch[1]

    # 5. Insert re_review_entity_connect records for each entity
    for (i in seq_len(nrow(existing_entities))) {
      entity <- existing_entities[i, ]
      db_execute_statement(
        "INSERT INTO re_review_entity_connect
         (entity_id, re_review_batch, status_id, review_id,
          re_review_review_saved, re_review_status_saved, re_review_submitted, re_review_approved)
         VALUES (?, ?, ?, ?, 0, 0, 0, 0)",
        list(
          entity$entity_id,
          batch_id,
          entity$status_id,
          entity$review_id
        ),
        conn = txn_conn
      )
    }

    # 6. Create assignment for user
    db_execute_statement(
      "INSERT INTO re_review_assignment (user_id, re_review_batch) VALUES (?, ?)",
      list(user_id, batch_id),
      conn = txn_conn
    )

    # Return batch info
    list(batch_id = batch_id, entity_count = nrow(existing_entities))
  }, pool_obj = pool)

  logger::log_info("Entities assigned to user",
    batch_id = result$batch_id,
    entity_count = result$entity_count,
    user_id = user_id,
    batch_name = batch_name
  )

  list(
    status = 200,
    message = "Entities assigned successfully",
    entry = result
  )
}


#' Recalculate batch entities based on updated criteria
#'
#' Re-calculates which entities belong in a batch based on new criteria.
#' Only allowed for batches that are NOT yet assigned.
#'
#' @param batch_id Integer batch ID to recalculate
#' @param criteria List with new batch criteria
#' @param pool Database connection pool
#' @return List with status, message, and entry (batch_id, entity_count)
#'
#' @details
#' Uses db_with_transaction() for atomicity. This operation:
#' 1. Verifies the batch exists and is NOT assigned
#' 2. Deletes existing re_review_entity_connect records for the batch
#' 3. Re-queries entities using the new criteria
#' 4. Inserts new re_review_entity_connect records
#'
#' @examples
#' \dontrun{
#' result <- batch_recalculate(
#'   batch_id = 15,
#'   criteria = list(date_range = list(start = "2019-01-01", end = "2021-12-31")),
#'   pool
#' )
#' }
#'
#' @export
batch_recalculate <- function(batch_id, criteria, pool) {
  # Validate at least one criterion provided
  has_criteria <- !is.null(criteria$date_range) ||
    (!is.null(criteria$gene_list) && length(criteria$gene_list) > 0) ||
    !is.null(criteria$status_filter) ||
    !is.null(criteria$disease_id)

  if (!has_criteria) {
    logger::log_warn("Batch recalculation failed: no criteria provided")
    return(list(
      status = 400,
      message = "At least one selection criterion is required"
    ))
  }

  # Verify batch exists
  batch_exists <- db_execute_query(
    "SELECT COUNT(*) as count FROM re_review_entity_connect WHERE re_review_batch = ?",
    list(batch_id),
    conn = pool
  )

  if (batch_exists$count[1] == 0) {
    logger::log_warn("Batch recalculation failed: batch not found", batch_id = batch_id)
    return(list(
      status = 404,
      message = "Batch not found"
    ))
  }

  # Verify batch is NOT assigned (recalculation only allowed before assignment)
  is_assigned <- db_execute_query(
    "SELECT COUNT(*) as count FROM re_review_assignment WHERE re_review_batch = ?",
    list(batch_id),
    conn = pool
  )

  if (is_assigned$count[1] > 0) {
    logger::log_warn("Batch recalculation failed: batch is assigned", batch_id = batch_id)
    return(list(
      status = 409,
      message = "Cannot recalculate assigned batch. Only unassigned batches can be recalculated."
    ))
  }

  # Get batch_size from criteria or use default
  batch_size <- if (!is.null(criteria$batch_size)) criteria$batch_size else 20

  # Use transaction for atomicity
  result <- db_with_transaction(function(txn_conn) {
    # 1. Delete existing re_review_entity_connect records for this batch
    deleted_count <- db_execute_statement(
      "DELETE FROM re_review_entity_connect WHERE re_review_batch = ?",
      list(batch_id),
      conn = txn_conn
    )

    # 2. Find matching entities using gene-atomic helper (fixes issue #29)
    selection <- select_matching_entities(criteria, batch_size = batch_size, conn = txn_conn)
    matching_entities <- selection$entities

    if (nrow(matching_entities) == 0) {
      stop("No entities match the specified criteria")
    }

    # 3. Insert new re_review_entity_connect records
    for (i in seq_len(nrow(matching_entities))) {
      entity <- matching_entities[i, ]
      db_execute_statement(
        "INSERT INTO re_review_entity_connect
         (entity_id, re_review_batch, status_id, review_id,
          re_review_review_saved, re_review_status_saved, re_review_submitted, re_review_approved)
         VALUES (?, ?, ?, ?, 0, 0, 0, 0)",
        list(
          entity$entity_id,
          batch_id,
          entity$status_id,
          entity$review_id
        ),
        conn = txn_conn
      )
    }

    # Return batch info
    list(
      batch_id = batch_id,
      entity_count = nrow(matching_entities),
      old_count = deleted_count
    )
  }, pool_obj = pool)

  logger::log_info("Batch recalculated",
    batch_id = result$batch_id,
    old_entity_count = result$old_count,
    new_entity_count = result$entity_count
  )

  list(
    status = 200,
    message = "Batch recalculated successfully",
    entry = list(batch_id = result$batch_id, entity_count = result$entity_count)
  )
}
