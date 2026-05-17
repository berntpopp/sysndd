# functions/mcp-repository.R
#
# Read-only repository helpers for the SysNDD MCP sidecar. These helpers only
# issue bounded SELECT statements and enforce the public-data gate:
# active approved entities from ndd_entity_view plus primary approved reviews.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

mcp_repo_resolve_gene <- function(normalized_gene) {
  if (identical(normalized_gene$kind, "hgnc_id")) {
    sql <- "
      SELECT hgnc_id, symbol, name, omim_id, ensembl_gene_id, uniprot_ids,
             STRING_id, mgd_id, rgd_id, mane_select
      FROM non_alt_loci_set
      WHERE hgnc_id = ?
      LIMIT 2"
    return(db_execute_query(sql, list(normalized_gene$value)))
  }

  sql <- "
    SELECT hgnc_id, symbol, name, omim_id, ensembl_gene_id, uniprot_ids,
           STRING_id, mgd_id, rgd_id, mane_select
    FROM non_alt_loci_set
    WHERE UPPER(symbol) = UPPER(?)
    LIMIT 2"
  db_execute_query(sql, list(normalized_gene$value))
}

mcp_repo_search <- function(query, types = c("gene", "entity", "disease"), limit = 10L) {
  like <- paste0("%", query, "%")
  prefix <- paste0(query, "%")
  results <- list()

  if ("gene" %in% types) {
    results$gene <- db_execute_query(
      "
        SELECT 'gene' AS type,
               symbol AS id,
               symbol AS label,
               name AS description,
               CASE
                 WHEN UPPER(symbol) = UPPER(?) OR hgnc_id = ? THEN 'exact_identifier'
                 WHEN UPPER(symbol) LIKE UPPER(?) THEN 'prefix'
                 ELSE 'contains'
               END AS match_tier
        FROM search_non_alt_loci_view
        WHERE UPPER(result) LIKE UPPER(?) OR hgnc_id = ?
        LIMIT ?",
      list(query, query, prefix, like, query, limit)
    )
  }

  if ("entity" %in% types) {
    results$entity <- db_execute_query(
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
        FROM ndd_entity_view
        WHERE CAST(entity_id AS CHAR) = ?
           OR UPPER(symbol) LIKE UPPER(?)
           OR UPPER(disease_ontology_name) LIKE UPPER(?)
        LIMIT ?",
      list(query, query, prefix, query, like, like, limit)
    )
  }

  if ("disease" %in% types) {
    results$disease <- db_execute_query(
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
        FROM search_disease_ontology_set
        WHERE UPPER(result) LIKE UPPER(?)
        LIMIT ?",
      list(query, query, prefix, like, limit)
    )
  }

  if ("phenotype" %in% types) {
    results$phenotype <- db_execute_query(
      "
        SELECT 'phenotype' AS type,
               phenotype_id AS id,
               HPO_term AS label,
               HPO_term_definition AS description,
               CASE
                 WHEN UPPER(phenotype_id) = UPPER(?) THEN 'exact_identifier'
                 WHEN UPPER(HPO_term) = UPPER(?) THEN 'exact_label'
                 WHEN UPPER(HPO_term) LIKE UPPER(?) THEN 'prefix'
                 ELSE 'contains'
               END AS match_tier
        FROM phenotype_list
        WHERE UPPER(phenotype_id) LIKE UPPER(?)
           OR UPPER(HPO_term) LIKE UPPER(?)
        LIMIT ?",
      list(query, query, prefix, like, like, limit)
    )
  }

  if ("variant" %in% types) {
    results$variant <- db_execute_query(
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
        FROM variation_ontology_list
        WHERE is_active <> 0
          AND (UPPER(vario_id) LIKE UPPER(?) OR UPPER(vario_name) LIKE UPPER(?))
        LIMIT ?",
      list(query, query, prefix, like, like, limit)
    )
  }

  dplyr::bind_rows(results)
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
      FROM ndd_entity_view ev
      JOIN ndd_entity_review er
        ON er.entity_id = ev.entity_id
       AND er.is_primary = 1
       AND er.review_approved = 1
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

  sql <- paste0("SELECT COUNT(*) AS total FROM ndd_entity_view WHERE ", paste(filters, collapse = " AND "))
  result <- db_execute_query(sql, params)
  as.integer(result$total[[1]] %||% 0L)
}

mcp_repo_get_gene_comparisons <- function(hgnc_id, limit = 25L) {
  db_execute_query(
    "
      SELECT hgnc_id, disease_ontology_id, inheritance, category,
             pathogenicity_mode, `list`, version
      FROM ndd_database_comparison_view
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
      FROM ndd_entity_view ev
      JOIN ndd_entity_review er
        ON er.entity_id = ev.entity_id
       AND er.is_primary = 1
       AND er.review_approved = 1
      WHERE ev.entity_id = ?
      LIMIT 1",
    list(entity_id)
  )
}

mcp_repo_get_entity_phenotypes <- function(entity_id) {
  db_execute_query(
    "
      SELECT pc.entity_id, pc.phenotype_id, pl.HPO_term, ml.modifier_name
      FROM ndd_entity_view ev
      JOIN ndd_entity_review er
        ON er.entity_id = ev.entity_id
       AND er.is_primary = 1
       AND er.review_approved = 1
      JOIN ndd_review_phenotype_connect pc
        ON pc.review_id = er.review_id
       AND pc.entity_id = ev.entity_id
       AND pc.is_active = 1
      JOIN phenotype_list pl ON pl.phenotype_id = pc.phenotype_id
      LEFT JOIN modifier_list ml ON ml.modifier_id = pc.modifier_id
      WHERE ev.entity_id = ?
      ORDER BY pl.HPO_term
      LIMIT 100",
    list(entity_id)
  )
}

mcp_repo_get_entity_variation <- function(entity_id) {
  db_execute_query(
    "
      SELECT vc.entity_id, vc.vario_id, vol.vario_name, ml.modifier_name
      FROM ndd_entity_view ev
      JOIN ndd_entity_review er
        ON er.entity_id = ev.entity_id
       AND er.is_primary = 1
       AND er.review_approved = 1
      JOIN ndd_review_variation_ontology_connect vc
        ON vc.review_id = er.review_id
       AND vc.entity_id = ev.entity_id
       AND vc.is_active = 1
      JOIN variation_ontology_list vol ON vol.vario_id = vc.vario_id
      LEFT JOIN modifier_list ml ON ml.modifier_id = vc.modifier_id
      WHERE ev.entity_id = ?
      ORDER BY vol.vario_name
      LIMIT 100",
    list(entity_id)
  )
}

mcp_repo_get_entity_publications <- function(entity_id, limit = 10L) {
  db_execute_query(
    "
      SELECT rpj.entity_id, p.publication_id, p.Title, p.Journal,
             p.Publication_date, p.publication_date_source, p.Lastname,
             p.Firstname, p.Abstract,
             rpj.publication_type, er.review_date AS curation_review_date
      FROM ndd_entity_view ev
      JOIN ndd_entity_review er
        ON er.entity_id = ev.entity_id
       AND er.is_primary = 1
       AND er.review_approved = 1
      JOIN ndd_review_publication_join rpj
        ON rpj.review_id = er.review_id
       AND rpj.entity_id = ev.entity_id
       AND rpj.is_reviewed = 1
      JOIN publication p ON p.publication_id = rpj.publication_id
      WHERE ev.entity_id = ?
      ORDER BY p.Publication_date DESC, p.publication_id
      LIMIT ?",
    list(entity_id, limit)
  )
}

mcp_repo_get_publication_context <- function(publication_id) {
  db_execute_query(
    "
      SELECT p.publication_id, p.Title, p.Abstract, p.Journal, p.Publication_date,
             p.publication_date_source, p.Lastname, p.Firstname, p.Keywords,
             ev.entity_id, ev.symbol, ev.hgnc_id, ev.disease_ontology_name,
             ev.category, er.review_date AS curation_review_date
      FROM publication p
      JOIN ndd_review_publication_join rpj
        ON rpj.publication_id = p.publication_id
       AND rpj.is_reviewed = 1
      JOIN ndd_entity_review er
        ON er.review_id = rpj.review_id
       AND er.is_primary = 1
       AND er.review_approved = 1
      JOIN ndd_entity_view ev
        ON ev.entity_id = rpj.entity_id
       AND ev.entity_id = er.entity_id
      WHERE p.publication_id = ?
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
             ev.category, ev.ndd_phenotype_word, pc.phenotype_id, pl.HPO_term,
             ml.modifier_name
      FROM ndd_entity_view ev
      JOIN ndd_entity_review er
        ON er.entity_id = ev.entity_id
       AND er.is_primary = 1
       AND er.review_approved = 1
      JOIN ndd_review_phenotype_connect pc
        ON pc.review_id = er.review_id
       AND pc.entity_id = ev.entity_id
       AND pc.is_active = 1
      JOIN phenotype_list pl ON pl.phenotype_id = pc.phenotype_id
      LEFT JOIN modifier_list ml ON ml.modifier_id = pc.modifier_id
      WHERE (UPPER(pc.phenotype_id) = UPPER(?) OR UPPER(pl.HPO_term) LIKE UPPER(?))
        AND (? IS NULL OR ev.category = ?)
        AND (? IS NULL OR UPPER(ml.modifier_name) = UPPER(?))
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
      FROM ndd_entity_view ev
      JOIN ndd_entity_review er
        ON er.entity_id = ev.entity_id
       AND er.is_primary = 1
       AND er.review_approved = 1
      JOIN ndd_review_phenotype_connect pc
        ON pc.review_id = er.review_id
       AND pc.entity_id = ev.entity_id
       AND pc.is_active = 1
      JOIN phenotype_list pl ON pl.phenotype_id = pc.phenotype_id
      LEFT JOIN modifier_list ml ON ml.modifier_id = pc.modifier_id
      WHERE (UPPER(pc.phenotype_id) = UPPER(?) OR UPPER(pl.HPO_term) LIKE UPPER(?))
        AND (? IS NULL OR ev.category = ?)
        AND (? IS NULL OR UPPER(ml.modifier_name) = UPPER(?))",
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
      FROM ndd_entity_view ev
      JOIN ndd_entity_review er
        ON er.entity_id = ev.entity_id
       AND er.is_primary = 1
       AND er.review_approved = 1
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
      FROM ndd_entity_view ev
      JOIN ndd_entity_review er
        ON er.entity_id = ev.entity_id
       AND er.is_primary = 1
       AND er.review_approved = 1
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
      SELECT 'entities' AS metric, COUNT(*) AS value FROM ndd_entity_view
      UNION ALL
      SELECT 'genes' AS metric, COUNT(DISTINCT hgnc_id) AS value FROM ndd_entity_view
      UNION ALL
      SELECT CONCAT('category:', category) AS metric, COUNT(*) AS value FROM ndd_entity_view GROUP BY category
      UNION ALL
      SELECT CONCAT('ndd_phenotype:', ndd_phenotype_word) AS metric, COUNT(*) AS value
      FROM ndd_entity_view
      GROUP BY ndd_phenotype_word
      UNION ALL
      SELECT 'publications' AS metric, COUNT(DISTINCT p.publication_id) AS value
      FROM publication p
      JOIN ndd_review_publication_join rpj ON rpj.publication_id = p.publication_id AND rpj.is_reviewed = 1
      JOIN ndd_entity_review er ON er.review_id = rpj.review_id AND er.is_primary = 1 AND er.review_approved = 1
      JOIN ndd_entity_view ev ON ev.entity_id = rpj.entity_id AND ev.entity_id = er.entity_id
      LIMIT 100"
  )
}
