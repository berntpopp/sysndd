# functions/mcp-repository.R
#
# Read-only repository helpers for the SysNDD MCP sidecar. These helpers only
# issue bounded SELECT statements against database-enforced approved-public
# projections only.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

mcp_repo_resolve_gene <- function(normalized_gene) {
  if (identical(normalized_gene$kind, "hgnc_id")) {
    sql <- "
      SELECT hgnc_id, symbol, name, omim_id, ensembl_gene_id, uniprot_ids,
             STRING_id, mgd_id, rgd_id, mane_select
      FROM mcp_public_gene
      WHERE hgnc_id = ?
      LIMIT 2"
    return(db_execute_query(sql, list(normalized_gene$value)))
  }

  sql <- "
    SELECT hgnc_id, symbol, name, omim_id, ensembl_gene_id, uniprot_ids,
           STRING_id, mgd_id, rgd_id, mane_select
    FROM mcp_public_gene
    WHERE UPPER(symbol) = UPPER(?)
    LIMIT 2"
  db_execute_query(sql, list(normalized_gene$value))
}

mcp_repo_search <- function(query, types = c("gene", "entity", "disease"), limit = 10L) {
  like <- paste0("%", query, "%")
  prefix <- paste0(query, "%")
  tokens <- mcp_search_tokens(query)
  token_like <- paste0("%", tokens, "%")
  candidate_limit <- min(max(as.integer(limit) * 5L, as.integer(limit)), 125L)
  results <- list()

  if ("gene" %in% types) {
    token_filter <- mcp_search_token_filter(c("nal.name", "hsl.lookup_symbol"), token_like)
    token_sql <- if (nzchar(token_filter$sql)) {
      paste0(" OR ", token_filter$sql)
    } else {
      ""
    }
    results$gene <- db_execute_query(
      paste0(
        "
        SELECT 'gene' AS type,
               nal.symbol AS id,
               nal.symbol AS label,
               nal.name AS description,
               CASE
                 WHEN hsl.symbol_type = 'alias' THEN 'alias'
                 WHEN hsl.symbol_type = 'previous' THEN 'previous'
                 WHEN hsl.symbol_type = 'current' THEN 'symbol'
                 WHEN UPPER(nal.name) LIKE UPPER(?) THEN 'name'
                 ELSE 'symbol_or_name'
               END AS matched_field,
               CASE
                 WHEN UPPER(nal.symbol) = UPPER(?) OR nal.hgnc_id = ? THEN 'exact_identifier'
                 WHEN UPPER(nal.symbol) = UPPER(?) THEN 'exact_label'
                 WHEN hsl.symbol_type IN ('alias', 'previous') AND hsl.lookup_symbol = UPPER(?) THEN hsl.symbol_type
                 WHEN UPPER(nal.name) = UPPER(?) THEN 'exact_label'
                 WHEN UPPER(nal.name) LIKE UPPER(?) THEN 'phrase'
                 WHEN UPPER(nal.symbol) LIKE UPPER(?) OR UPPER(hsl.lookup_symbol) LIKE UPPER(?) THEN 'prefix'
                 ELSE 'contains'
               END AS match_tier,
               0 AS token_matches
          FROM mcp_public_gene nal
          LEFT JOIN mcp_public_hgnc_symbol hsl
            ON hsl.hgnc_id = nal.hgnc_id
         WHERE UPPER(nal.symbol) LIKE UPPER(?)
            OR nal.hgnc_id = ?
            OR UPPER(nal.name) LIKE UPPER(?)
            OR UPPER(hsl.lookup_symbol) LIKE UPPER(?)",
        token_sql,
        "
         GROUP BY nal.hgnc_id, nal.symbol, nal.name, matched_field, match_tier
         LIMIT ?"
      ),
      c(
        list(like, query, query, query, query, query, like, prefix, prefix, like, query, like, like),
        token_filter$params,
        list(candidate_limit)
      )
    )
  }

  if ("entity" %in% types) {
    token_filter <- mcp_search_token_filter(
      c("CAST(entity_id AS CHAR)", "symbol", "disease_ontology_name", "category", "hpo_mode_of_inheritance_term_name"),
      token_like
    )
    token_sql <- if (nzchar(token_filter$sql)) paste0(" OR ", token_filter$sql) else ""
    results$entity <- db_execute_query(
      paste0(
        "
        SELECT 'entity' AS type,
               CAST(entity_id AS CHAR) AS id,
               CONCAT(symbol, ' / ', disease_ontology_name) AS label,
               CONCAT(category, '; ', hpo_mode_of_inheritance_term_name) AS description,
               CASE
                 WHEN CAST(entity_id AS CHAR) = ? THEN 'exact_identifier'
                 WHEN UPPER(symbol) = UPPER(?) THEN 'exact_label'
                 WHEN UPPER(symbol) LIKE UPPER(?) THEN 'prefix'
                 ELSE 'contains'
               END AS match_tier
        FROM mcp_public_entity
        WHERE CAST(entity_id AS CHAR) = ?
           OR UPPER(symbol) LIKE UPPER(?)
           OR UPPER(disease_ontology_name) LIKE UPPER(?)
           ", token_sql, "
        LIMIT ?"
      ),
      c(list(query, query, prefix, query, like, like), token_filter$params, list(candidate_limit))
    )
  }

  if ("disease" %in% types) {
    token_filter <- mcp_search_token_filter(
      c("disease_ontology_id_version", "disease_ontology_name"),
      token_like
    )
    token_sql <- if (nzchar(token_filter$sql)) paste0(" OR ", token_filter$sql) else ""
    results$disease <- db_execute_query(
      paste0(
        "
        SELECT 'disease' AS type,
               disease_ontology_id_version AS id,
               disease_ontology_name AS label,
               disease_ontology_id_version AS description,
               CASE
                 WHEN UPPER(disease_ontology_id_version) = UPPER(?) THEN 'exact_identifier'
                 WHEN UPPER(disease_ontology_name) = UPPER(?) THEN 'exact_label'
                 WHEN UPPER(disease_ontology_name) LIKE UPPER(?) THEN 'prefix'
                 ELSE 'contains'
               END AS match_tier
        FROM mcp_public_disease
        WHERE (UPPER(disease_ontology_id_version) LIKE UPPER(?)
           OR UPPER(disease_ontology_name) LIKE UPPER(?))
           ", token_sql, "
        LIMIT ?"
      ),
      c(list(query, query, prefix, like, like), token_filter$params, list(candidate_limit))
    )
  }

  if ("phenotype" %in% types) {
    synonym_select <- "WHEN UPPER(HPO_term_synonyms) LIKE UPPER(?) THEN 'synonym'"
    synonym_where <- "OR UPPER(HPO_term_synonyms) LIKE UPPER(?)"
    token_columns <- c("phenotype_id", "HPO_term", "HPO_term_synonyms")
    token_filter <- mcp_search_token_filter(token_columns, token_like)
    token_sql <- if (nzchar(token_filter$sql)) paste0(" OR ", token_filter$sql) else ""
    synonym_case_params <- list(like)
    synonym_where_params <- list(like)
    results$phenotype <- db_execute_query(
      paste0(
        "
        SELECT 'phenotype' AS type,
               phenotype_id AS id,
               HPO_term AS label,
               HPO_term_definition AS description,
               CASE
                 WHEN UPPER(phenotype_id) = UPPER(?) THEN 'phenotype_id'
                 WHEN UPPER(HPO_term) LIKE UPPER(?) THEN 'term'
                 ", synonym_select, "
                 ELSE 'term'
               END AS matched_field,
               CASE
                 WHEN UPPER(phenotype_id) = UPPER(?) THEN 'exact_identifier'
                 WHEN UPPER(HPO_term) = UPPER(?) THEN 'exact_label'
                 WHEN UPPER(HPO_term) LIKE UPPER(?) THEN 'prefix'
                 ", synonym_select, "
                 ELSE 'contains'
               END AS match_tier
        FROM mcp_public_phenotype
        WHERE UPPER(phenotype_id) LIKE UPPER(?)
           OR UPPER(HPO_term) LIKE UPPER(?)
           ", synonym_where, "
           ", token_sql, "
        LIMIT ?"
      ),
      c(
        list(query, prefix),
        synonym_case_params,
        list(query, query, prefix),
        synonym_case_params,
        list(like, like),
        synonym_where_params,
        token_filter$params,
        list(candidate_limit)
      )
    )
  }

  if ("variant" %in% types) {
    token_filter <- mcp_search_token_filter(c("vario_id", "vario_name", "definition"), token_like)
    token_sql <- if (nzchar(token_filter$sql)) paste0(" OR ", token_filter$sql) else ""
    results$variant <- db_execute_query(
      paste0(
        "
        SELECT 'variant' AS type,
               vario_id AS id,
               vario_name AS label,
               definition AS description,
               CASE
                 WHEN UPPER(vario_id) = UPPER(?) THEN 'exact_identifier'
                 WHEN UPPER(vario_name) = UPPER(?) THEN 'exact_label'
                 WHEN UPPER(vario_name) LIKE UPPER(?) THEN 'prefix'
                 ELSE 'contains'
               END AS match_tier
        FROM mcp_public_variation
        WHERE (UPPER(vario_id) LIKE UPPER(?) OR UPPER(vario_name) LIKE UPPER(?)
               ", token_sql, ")
        LIMIT ?"
      ),
      c(list(query, query, prefix, like, like), token_filter$params, list(candidate_limit))
    )
  }

  rows <- dplyr::bind_rows(results)
  ranked <- mcp_rank_search_candidates(rows, query_tokens = tokens, query = query)
  utils::head(ranked, limit)
}

mcp_repo_get_gene_entities <- function(hgnc_id,
                                       category = NULL,
                                       ndd_phenotype = "any",
                                       limit = 25L,
                                       offset = 0L) {
  filters <- c("ev.hgnc_id = ?")
  params <- list(hgnc_id)

  if (!is.null(category) && nzchar(category)) {
    filters <- c(filters, "ev.category = ?")
    params <- c(params, list(category))
  }
  if (identical(ndd_phenotype, "yes")) {
    filters <- c(filters, "ev.ndd_phenotype = 1")
  } else if (identical(ndd_phenotype, "no")) {
    filters <- c(filters, "ev.ndd_phenotype = 0")
  }

  sql <- paste0(
    "
      SELECT ev.entity_id, ev.symbol, ev.hgnc_id, ev.disease_ontology_id_version,
             ev.disease_ontology_name, ev.hpo_mode_of_inheritance_term_name,
             ev.category, ev.ndd_phenotype_word, er.synopsis, er.review_date
      FROM mcp_public_entity ev
      JOIN mcp_public_review er ON er.entity_id = ev.entity_id
      WHERE ", paste(filters, collapse = " AND "), "
      ORDER BY ev.symbol, ev.entity_id
      LIMIT ? OFFSET ?"
  )
  db_execute_query(sql, c(params, list(limit, offset)))
}

mcp_repo_count_gene_entities <- function(hgnc_id, category = NULL, ndd_phenotype = "any") {
  filters <- c("hgnc_id = ?")
  params <- list(hgnc_id)
  if (!is.null(category) && nzchar(category)) {
    filters <- c(filters, "category = ?")
    params <- c(params, list(category))
  }
  if (identical(ndd_phenotype, "yes")) {
    filters <- c(filters, "ndd_phenotype = 1")
  } else if (identical(ndd_phenotype, "no")) {
    filters <- c(filters, "ndd_phenotype = 0")
  }

  sql <- paste0("SELECT COUNT(*) AS total FROM mcp_public_entity WHERE ", paste(filters, collapse = " AND "))
  result <- db_execute_query(sql, params)
  as.integer(result$total[[1]] %||% 0L)
}

mcp_repo_get_gene_comparisons <- function(hgnc_id, limit = 25L) {
  db_execute_query(
    "
      SELECT hgnc_id, disease_ontology_id, inheritance, category,
             pathogenicity_mode, `list`, version
      FROM mcp_public_comparison
      WHERE hgnc_id = ?
      ORDER BY `list`, category
      LIMIT ?",
    list(hgnc_id, limit)
  )
}

mcp_repo_get_entity_context <- function(entity_id) {
  db_execute_query(
    "
      SELECT ev.entity_id, ev.hgnc_id, ev.symbol, ev.disease_ontology_id_version,
             ev.disease_ontology_name, ev.hpo_mode_of_inheritance_term,
             ev.hpo_mode_of_inheritance_term_name, ev.category, ev.category_id,
             ev.ndd_phenotype, ev.ndd_phenotype_word, er.synopsis, er.review_date
      FROM mcp_public_entity ev
      JOIN mcp_public_review er ON er.entity_id = ev.entity_id
      WHERE ev.entity_id = ?
      LIMIT 1",
    list(entity_id)
  )
}

mcp_repo_get_entity_phenotypes <- function(entity_id) {
  db_execute_query(
    "
      SELECT entity_id, phenotype_id, HPO_term, modifier_name
      FROM mcp_public_review_phenotype
      WHERE entity_id = ?
      ORDER BY HPO_term
      LIMIT 100",
    list(entity_id)
  )
}

mcp_repo_get_entity_variation <- function(entity_id) {
  db_execute_query(
    "
      SELECT entity_id, vario_id, vario_name, modifier_name
      FROM mcp_public_review_variation
      WHERE entity_id = ?
      ORDER BY vario_name
      LIMIT 100",
    list(entity_id)
  )
}

mcp_repo_get_entity_publications <- function(entity_id, limit = 10L) {
  db_execute_query(
    "
      SELECT entity_id, publication_id, Title, Journal,
             Publication_date, publication_date_source, Lastname,
             Firstname, Abstract, publication_type, curation_review_date
      FROM mcp_public_review_publication
      WHERE entity_id = ?
      ORDER BY Publication_date DESC, publication_id
      LIMIT ?",
    list(entity_id, limit)
  )
}

mcp_repo_get_publication_context <- function(publication_id) {
  db_execute_query(
    "
      SELECT rp.publication_id, rp.Title, rp.Abstract, rp.Journal, rp.Publication_date,
             rp.publication_date_source, rp.Lastname, rp.Firstname, rp.Keywords,
             ev.entity_id, ev.symbol, ev.hgnc_id, ev.disease_ontology_name,
             ev.category, rp.publication_type, rp.curation_review_date
      FROM mcp_public_review_publication rp
      JOIN mcp_public_entity ev ON ev.entity_id = rp.entity_id
      WHERE rp.publication_id = ?
      LIMIT 50",
    list(publication_id)
  )
}

mcp_repo_find_entities_by_phenotype <- function(phenotype,
                                                modifier = "present",
                                                category = "Definitive",
                                                limit = 25L,
                                                offset = 0L) {
  like <- paste0("%", phenotype, "%")
  db_execute_query(
    "
      SELECT ev.entity_id, ev.symbol, ev.hgnc_id, ev.disease_ontology_id_version,
             ev.disease_ontology_name, ev.hpo_mode_of_inheritance_term_name,
             ev.category, ev.ndd_phenotype_word, rp.phenotype_id, rp.HPO_term,
             rp.modifier_name
      FROM mcp_public_entity ev
      JOIN mcp_public_review_phenotype rp ON rp.entity_id = ev.entity_id
      WHERE (UPPER(rp.phenotype_id) = UPPER(?) OR UPPER(rp.HPO_term) LIKE UPPER(?))
        AND (? IS NULL OR ev.category = ?)
        AND (? IS NULL OR UPPER(rp.modifier_name) = UPPER(?))
      ORDER BY ev.symbol, ev.entity_id
      LIMIT ? OFFSET ?",
    list(phenotype, like, category, category, modifier, modifier, limit, offset)
  )
}

mcp_repo_count_entities_by_phenotype <- function(phenotype,
                                                 modifier = "present",
                                                 category = "Definitive") {
  like <- paste0("%", phenotype, "%")
  result <- db_execute_query(
    "
      SELECT COUNT(*) AS total
      FROM mcp_public_entity ev
      JOIN mcp_public_review_phenotype rp ON rp.entity_id = ev.entity_id
      WHERE (UPPER(rp.phenotype_id) = UPPER(?) OR UPPER(rp.HPO_term) LIKE UPPER(?))
        AND (? IS NULL OR ev.category = ?)
        AND (? IS NULL OR UPPER(rp.modifier_name) = UPPER(?))",
    list(phenotype, like, category, category, modifier, modifier)
  )
  if (!"total" %in% names(result) || nrow(result) == 0L) {
    return(0L)
  }
  as.integer(result$total[[1]] %||% 0L)
}

mcp_repo_find_entities_by_disease <- function(disease, limit = 25L, offset = 0L) {
  like <- paste0("%", disease, "%")
  db_execute_query(
    "
      SELECT ev.entity_id, ev.symbol, ev.hgnc_id, ev.disease_ontology_id_version,
             ev.disease_ontology_name, ev.hpo_mode_of_inheritance_term_name,
             ev.category, ev.ndd_phenotype_word
      FROM mcp_public_entity ev
      WHERE UPPER(ev.disease_ontology_id_version) = UPPER(?)
         OR UPPER(ev.disease_ontology_name) LIKE UPPER(?)
      ORDER BY ev.symbol, ev.entity_id
      LIMIT ? OFFSET ?",
    list(disease, like, limit, offset)
  )
}

mcp_repo_count_entities_by_disease <- function(disease) {
  like <- paste0("%", disease, "%")
  result <- db_execute_query(
    "
      SELECT COUNT(*) AS total
      FROM mcp_public_entity ev
      WHERE UPPER(ev.disease_ontology_id_version) = UPPER(?)
         OR UPPER(ev.disease_ontology_name) LIKE UPPER(?)",
    list(disease, like)
  )
  if (!"total" %in% names(result) || nrow(result) == 0L) {
    return(0L)
  }
  as.integer(result$total[[1]] %||% 0L)
}

mcp_repo_get_stats <- function() {
  db_execute_query(
    "
      SELECT 'entities' AS metric, COUNT(*) AS value FROM mcp_public_entity
      UNION ALL
      SELECT 'genes' AS metric, COUNT(DISTINCT hgnc_id) AS value FROM mcp_public_entity
      UNION ALL
      SELECT CONCAT('category:', category) AS metric, COUNT(*) AS value FROM mcp_public_entity GROUP BY category
      UNION ALL
      SELECT CONCAT('ndd_phenotype:', ndd_phenotype_word) AS metric, COUNT(*) AS value
      FROM mcp_public_entity
      GROUP BY ndd_phenotype_word
      UNION ALL
      SELECT 'publications' AS metric, COUNT(DISTINCT publication_id) AS value
      FROM mcp_public_review_publication
      LIMIT 100"
  )
}
