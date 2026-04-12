# functions/pubtator-parser.R
#### PubTator JSON parsing, data transformation, and gene symbol computation
#### Split from pubtator-functions.R (D3 refactor)

require(jsonlite)
require(logger)
require(digest) # for hashing
log_threshold(INFO)

#------------------------------------------------------------------------------
# generate_query_hash
#------------------------------------------------------------------------------
generate_query_hash <- function(query_string) {
  q_squish <- stringr::str_squish(query_string)
  q_hash <- digest::digest(q_squish, algo = "sha256", serialize = FALSE)
  return(q_hash)
}

#------------------------------------------------------------------------------
# pubtator_parse_biocjson
#------------------------------------------------------------------------------
#' Parse a PubTator3 BioCJSON API response into a data frame of documents
#'
#' The BioCJSON endpoint returns standard JSON: {"PubTator3": [doc1, doc2, ...]}.
#' Each doc has id, passages (with annotations), relations, etc.
#' jsonlite::fromJSON() simplifies the PubTator3 array into a data frame where
#' each row is one document. The passages column becomes a list of data frames.
#'
#' @param url The BioCJSON API URL to fetch
#' @return A data frame with one row per document, or NULL on failure.
#'         Columns include: id, passages (list column), pmid, etc.
#' @export
pubtator_parse_biocjson <- function(url) {
  tryCatch(
    {
      json_text <- paste(suppressWarnings(readLines(url)), collapse = "")
      if (is.null(json_text) || nchar(json_text) == 0) {
        log_warn("pubtator_parse_biocjson: empty response from {url}")
        return(NULL)
      }
      parsed <- fromJSON(json_text, simplifyVector = TRUE, simplifyDataFrame = TRUE)
      if (!"PubTator3" %in% names(parsed)) {
        log_warn("pubtator_parse_biocjson: no 'PubTator3' key in response")
        return(NULL)
      }
      docs_df <- parsed[["PubTator3"]]
      if (!is.data.frame(docs_df) || nrow(docs_df) == 0) {
        log_warn("pubtator_parse_biocjson: PubTator3 is empty or not a data frame")
        return(NULL)
      }
      # Ensure 'id' column exists (copy from '_id' if needed)
      if (!"id" %in% names(docs_df) && "_id" %in% names(docs_df)) {
        docs_df$id <- docs_df$`_id`
      }
      log_info("pubtator_parse_biocjson: parsed {nrow(docs_df)} documents")
      return(docs_df)
    },
    error = function(e) {
      log_warn(skip_formatter(paste("pubtator_parse_biocjson error:", e$message)))
      return(NULL)
    }
  )
}

#------------------------------------------------------------------------------
# flatten_pubtator_passages
#------------------------------------------------------------------------------
#' Flatten a PubTator object => row per annotation
#'
#' @param master_obj from pubtator_v3_data_from_pmids()
#' @return tibble with columns pmid, id, text, type, ...
#' @export
flatten_pubtator_passages <- function(master_obj) {
  base_tib <- build_pmid_annotations_table(master_obj)
  log_info("base_tib has {nrow(base_tib)} rows => flattening annotation DF...")

  if (nrow(base_tib) == 0) {
    log_warn("No rows => returning empty tibble.")
    return(base_tib)
  }

  base_tib2 <- base_tib %>%
    mutate(
      annotations = purrr::map2(annotations, dplyr::row_number(), function(ann_list, row_i) {
        if (!is.data.frame(ann_list) || nrow(ann_list) == 0) {
          log_info("Row {row_i}: annotation list is empty => empty tibble.")
          return(tibble())
        }
        log_info("Row {row_i}: annotation DF => {nrow(ann_list)} rows, {ncol(ann_list)} cols.")
        out_list <- vector("list", nrow(ann_list))
        for (i in seq_len(nrow(ann_list))) {
          single_row <- ann_list[i, , drop = FALSE]
          out_list[[i]] <- flatten_annotation_row(single_row)
        }
        ann_list_char <- dplyr::bind_rows(out_list)
        ann_list_char
      })
    )

  log_info("Done normalizing each row's annotation DF => unnesting annotations.")

  result <- base_tib2 %>%
    tidyr::unnest(annotations, keep_empty = TRUE) %>%
    dplyr::select(-dplyr::any_of(c("locations"))) %>%
    dplyr::rename_with(~ gsub("^infons\\.", "", .x), dplyr::starts_with("infons."))

  log_info("Flatten complete => {nrow(result)} rows, columns: {paste(names(result), collapse=', ')}")
  return(result)
}

#------------------------------------------------------------------------------
# build_pmid_annotations_table
#------------------------------------------------------------------------------
build_pmid_annotations_table <- function(master_obj) {
  if (!is.list(master_obj)) {
    log_warn("master_obj not a list => returning empty tibble.")
    return(tibble(pmid = character(), annotations = list()))
  }
  if (!all(c("id", "passages") %in% names(master_obj))) {
    log_warn("master_obj missing 'id' or 'passages' => empty tibble.")
    return(tibble(pmid = character(), annotations = list()))
  }

  pmids_vec <- master_obj$id
  pass_list <- master_obj$passages
  if (!is.vector(pmids_vec) || !is.list(pass_list) || length(pmids_vec) != length(pass_list)) {
    log_warn("mismatch lengths => empty tibble.")
    return(tibble(pmid = character(), annotations = list()))
  }

  all_rows <- list()
  for (i in seq_along(pmids_vec)) {
    pmid_str <- as.character(pmids_vec[i])
    pass_df <- pass_list[[i]]
    if (!is.data.frame(pass_df)) {
      log_warn("passages[[{i}]] is not a data frame => skip.")
      next
    }
    for (row_i in seq_len(nrow(pass_df))) {
      ann_list <- NULL
      if ("annotations" %in% names(pass_df)) {
        ann_list <- pass_df$annotations[[row_i]]
      }
      row_obj <- list(
        pmid = pmid_str,
        annotations = list(ann_list %||% list())
      )
      all_rows <- append(all_rows, list(row_obj))
    }
  }

  if (length(all_rows) == 0) {
    return(tibble(pmid = character(), annotations = list()))
  }
  tib_out <- dplyr::bind_rows(all_rows)
  return(tib_out)
}

#------------------------------------------------------------------------------
# flatten_annotation_row
#------------------------------------------------------------------------------
flatten_annotation_row <- function(one_annot) {
  stopifnot(nrow(one_annot) == 1)

  log_info("flatten_annotation_row => columns: {paste(names(one_annot), collapse=', ')}")

  if ("infons" %in% names(one_annot)) {
    infons_val <- one_annot[["infons"]]
    if (is.data.frame(infons_val) && nrow(infons_val) == 1) {
      # expand columns => infons.xyz
      for (cn in names(infons_val)) {
        infons_val[[cn]] <- as.character(infons_val[[cn]])
      }
      names(infons_val) <- paste0("infons.", names(infons_val))
      one_annot[["infons"]] <- NULL
      one_annot <- cbind(one_annot, infons_val)
    } else {
      # fallback => JSON
      one_annot[["infons"]] <- safe_as_json(infons_val)
    }
  }

  for (colname in names(one_annot)) {
    colval <- one_annot[[colname]][[1]]
    if (is.null(colval)) {
      one_annot[[colname]] <- ""
    } else if (is.atomic(colval)) {
      one_annot[[colname]] <- as.character(colval)
    } else if (is.data.frame(colval)) {
      one_annot[[colname]] <- safe_as_json(colval)
    } else if (is.list(colval)) {
      one_annot[[colname]] <- safe_as_json(colval)
    } else {
      one_annot[[colname]] <- as.character(colval)
    }
  }

  for (cn in names(one_annot)) {
    one_annot[[cn]] <- as.character(one_annot[[cn]])
  }
  out <- tibble::as_tibble(one_annot)
  return(out)
}

#------------------------------------------------------------------------------
# safe_as_json
#------------------------------------------------------------------------------
safe_as_json <- function(x) {
  if (is.null(x)) {
    return("")
  }
  if (is.atomic(x) && length(x) == 1) {
    return(as.character(x))
  }
  out <- tryCatch(
    {
      jsonlite::toJSON(x, auto_unbox = TRUE)
    },
    error = function(e) {
      as.character(x)
    }
  )
  return(out)
}

#------------------------------------------------------------------------------
# compute_pubtator_gene_symbols
#   Extracts human gene symbols for publications in a given query.
#   Used by both pubtator_db_update (sync) and pubtator_db_update_async.
#------------------------------------------------------------------------------
#' Compute and store human gene symbols per search_id
#'
#' Joins annotation cache with HGNC gene list using three strategies:
#' 1. Direct entrez_id match against non_alt_loci_set
#' 2. Case-insensitive name match against HGNC symbols
#' 3. Parse @GENE_ tags from text_hl and match display texts against HGNC
#'
#' @param query_id Integer query_id from pubtator_query_cache
#' @param conn Database connection (transaction connection or direct DBI connection)
#' @return Invisible NULL (side-effect: updates gene_symbols in pubtator_search_cache)
#' @keywords internal
compute_pubtator_gene_symbols <- function(query_id, conn) {
  log_info("Computing human gene symbols for query_id={query_id}...")

  # Source 1: Annotation cache (direct entrez_id + name fallback)
  gene_symbols_df <- db_execute_query(
    "SELECT search_id,
            GROUP_CONCAT(DISTINCT symbol ORDER BY symbol SEPARATOR ',') AS gene_symbols
     FROM (
       SELECT s.search_id, nal.symbol
       FROM pubtator_search_cache s
       JOIN pubtator_annotation_cache a ON s.search_id = a.search_id
       JOIN non_alt_loci_set nal ON nal.entrez_id = a.normalized_id
       WHERE s.query_id = ?
         AND a.type = 'Gene'
         AND a.normalized_id IS NOT NULL
         AND a.normalized_id != ''
       UNION
       SELECT s.search_id, nal.symbol
       FROM pubtator_search_cache s
       JOIN pubtator_annotation_cache a ON s.search_id = a.search_id
       JOIN non_alt_loci_set nal ON UPPER(nal.symbol) = UPPER(a.name)
       WHERE s.query_id = ?
         AND a.type = 'Gene'
         AND a.name IS NOT NULL
         AND a.name != ''
     ) gene_matches
     GROUP BY search_id",
    list(query_id, query_id),
    conn = conn
  )

  # Source 2: Parse @GENE_ tags from text_hl (search API annotations)
  text_hl_rows <- db_execute_query(
    "SELECT search_id, text_hl FROM pubtator_search_cache
     WHERE query_id = ? AND text_hl LIKE '%@GENE_%'",
    list(query_id),
    conn = conn
  )

  if (nrow(text_hl_rows) > 0) {
    # Extract gene names and display texts from text_hl
    hl_genes <- do.call(rbind, lapply(seq_len(nrow(text_hl_rows)), function(i) {
      row <- text_hl_rows[i, ]
      # Extract @GENE_<symbol> tags (non-numeric = gene symbols)
      symbols <- stringr::str_match_all(
        row$text_hl,
        "@GENE_([A-Za-z][A-Za-z0-9_-]+)\\s"
      )[[1]][, 2]
      # Extract display texts from @@@<text>@@@ after @GENE_ tags
      displays <- stringr::str_match_all(
        row$text_hl,
        "@GENE_[^ ]+ @GENE_[0-9]+ @@@<?m?>?([^@<]+)(?:</m>)?@@@"
      )[[1]][, 2]
      all_names <- unique(c(symbols, displays))
      if (length(all_names) > 0) {
        data.frame(
          search_id = row$search_id,
          gene_name = all_names,
          stringsAsFactors = FALSE
        )
      } else {
        NULL
      }
    }))

    if (!is.null(hl_genes) && nrow(hl_genes) > 0) {
      # Match against HGNC symbols (case-insensitive)
      unique_names <- unique(toupper(hl_genes$gene_name))
      placeholders <- paste(rep("?", length(unique_names)), collapse = ",")
      hgnc_matches <- db_execute_query(
        sprintf(
          "SELECT UPPER(symbol) AS upper_symbol, symbol
           FROM non_alt_loci_set WHERE UPPER(symbol) IN (%s)",
          placeholders
        ),
        as.list(unique_names),
        conn = conn
      )

      if (nrow(hgnc_matches) > 0) {
        hl_genes$upper_name <- toupper(hl_genes$gene_name)
        hl_matched <- dplyr::inner_join(
          hl_genes, hgnc_matches,
          by = c("upper_name" = "upper_symbol")
        )
        if (nrow(hl_matched) > 0) {
          hl_summary <- hl_matched %>%
            dplyr::group_by(search_id) %>%
            dplyr::summarise(
              hl_gene_symbols = paste(
                sort(unique(symbol)), collapse = ","
              ),
              .groups = "drop"
            )

          # Merge text_hl genes with annotation cache genes
          if (nrow(gene_symbols_df) > 0) {
            gene_symbols_df <- dplyr::full_join(
              gene_symbols_df, hl_summary,
              by = "search_id"
            )
            gene_symbols_df$gene_symbols <- mapply(
              function(a, b) {
                syms <- unique(sort(unlist(strsplit(
                  paste(na.omit(c(a, b)), collapse = ","), ","
                ))))
                paste(syms, collapse = ",")
              },
              gene_symbols_df$gene_symbols,
              gene_symbols_df$hl_gene_symbols
            )
            gene_symbols_df$hl_gene_symbols <- NULL
          } else {
            gene_symbols_df <- data.frame(
              search_id = hl_summary$search_id,
              gene_symbols = hl_summary$hl_gene_symbols,
              stringsAsFactors = FALSE
            )
          }
        }
      }
    }
  }

  if (nrow(gene_symbols_df) > 0) {
    log_info("Updating gene_symbols for {nrow(gene_symbols_df)} publications")
    for (r in seq_len(nrow(gene_symbols_df))) {
      db_execute_statement(
        "UPDATE pubtator_search_cache
         SET gene_symbols = ?
         WHERE search_id = ?",
        list(gene_symbols_df$gene_symbols[r], gene_symbols_df$search_id[r]),
        conn = conn
      )
    }
  }

  invisible(NULL)
}
