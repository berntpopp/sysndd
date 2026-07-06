# Public SEO payload assembly for static prerendering.

svc_seo_routes <- function(conn = NULL) {
  gene_rows <- db_execute_query(
    "
    SELECT symbol, hgnc_id, DATE_FORMAT(MAX(entry_date), '%Y-%m-%d') AS last_modified
    FROM ndd_entity_view
    GROUP BY hgnc_id, symbol
    ORDER BY symbol
    ",
    conn = conn
  )

  entity_rows <- db_execute_query(
    "
    SELECT entity_id, DATE_FORMAT(MAX(entry_date), '%Y-%m-%d') AS last_modified
    FROM ndd_entity_view
    GROUP BY entity_id
    ORDER BY entity_id
    ",
    conn = conn
  )

  list(
    static = list(list(path = "/", lastModified = Sys.Date())),
    genes = rows_to_lists(gene_rows, c(symbol = "symbol", hgncId = "hgnc_id", lastModified = "last_modified")),
    entities = rows_to_lists(entity_rows, c(entityId = "entity_id", lastModified = "last_modified"))
  )
}

svc_seo_static <- function() {
  list(
    list(path = "/", lastModified = Sys.Date()),
    list(path = "/Genes", lastModified = Sys.Date()),
    list(path = "/Entities", lastModified = Sys.Date())
  )
}

svc_seo_gene <- function(symbol, conn = NULL) {
  gene <- db_execute_query(
    "
    SELECT symbol, name, hgnc_id, ensembl_gene_id, entrez_id, omim_id
    FROM non_alt_loci_set
    WHERE symbol = ?
    LIMIT 1
    ",
    params = list(symbol),
    conn = conn
  )

  if (nrow(gene) == 0) {
    return(seo_not_found("gene", symbol))
  }

  hgnc_id <- as.character(gene$hgnc_id[[1]])
  entity_count <- db_execute_query(
    "SELECT COUNT(*) AS entity_count FROM ndd_entity_view WHERE hgnc_id = ?",
    params = list(hgnc_id),
    conn = conn
  )

  list(
    symbol = scalar_chr(gene$symbol),
    name = scalar_chr(gene$name),
    hgncId = scalar_chr(gene$hgnc_id),
    ensemblGeneId = scalar_chr(gene$ensembl_gene_id),
    entrezId = scalar_chr(gene$entrez_id),
    omimId = scalar_chr(gene$omim_id),
    entityCount = scalar_int(entity_count$entity_count, default = 0L),
    diseases = query_vector("disease", gene_disease_sql(), list(hgnc_id), conn),
    inheritanceModes = query_vector("inheritance", gene_inheritance_sql(), list(hgnc_id), conn),
    classifications = query_counts(gene_classification_sql(), list(hgnc_id), conn),
    nddStatuses = query_counts(gene_ndd_status_sql(), list(hgnc_id), conn),
    pmids = query_vector("pmid", gene_pmids_sql(), list(hgnc_id), conn),
    lastModified = scalar_chr(query_one(gene_last_modified_sql(), list(hgnc_id), conn)$last_modified)
  )
}

svc_seo_entity <- function(entity_id, conn = NULL) {
  entity <- db_execute_query(
    "
    SELECT entity_id, symbol, hgnc_id, disease_ontology_name, disease_ontology_id_version,
           hpo_mode_of_inheritance_term_name, category, ndd_phenotype_word
    FROM ndd_entity_view
    WHERE entity_id = ?
    LIMIT 1
    ",
    params = list(entity_id),
    conn = conn
  )

  if (nrow(entity) == 0) {
    return(seo_not_found("entity", entity_id))
  }

  review <- query_one(entity_review_sql(), list(entity_id), conn)

  list(
    entityId = as.character(entity$entity_id[[1]]),
    symbol = scalar_chr(entity$symbol),
    hgncId = scalar_chr(entity$hgnc_id),
    diseaseName = scalar_chr(entity$disease_ontology_name),
    diseaseOntologyId = scalar_chr(entity$disease_ontology_id_version),
    inheritanceName = scalar_chr(entity$hpo_mode_of_inheritance_term_name),
    classification = scalar_chr(entity$category),
    nddStatus = scalar_chr(entity$ndd_phenotype_word),
    synopsis = scalar_chr(review$synopsis),
    hpoTerms = rows_to_lists(
      db_execute_query(entity_hpo_sql(), list(entity_id), conn = conn),
      c(id = "id", label = "label")
    ),
    variationTerms = rows_to_lists(
      db_execute_query(entity_variation_sql(), list(entity_id), conn = conn),
      c(id = "id", label = "label")
    ),
    pmids = query_vector("pmid", entity_pmids_sql(), list(entity_id), conn),
    lastModified = scalar_chr(review$last_modified)
  )
}

seo_not_found <- function(resource, id) {
  list(status = 404L, error = "not_found", resource = resource, id = as.character(id))
}

rows_to_lists <- function(rows, columns) {
  if (nrow(rows) == 0) {
    return(list())
  }

  lapply(seq_len(nrow(rows)), function(index) {
    row <- rows[index, , drop = FALSE]
    stats::setNames(
      lapply(columns, function(column) scalar_chr(row[[column]])),
      names(columns)
    )
  })
}

query_one <- function(sql, params, conn) {
  rows <- db_execute_query(sql, params = params, conn = conn)
  if (nrow(rows) == 0) tibble::tibble() else rows[1, , drop = FALSE]
}

query_vector <- function(column, sql, params, conn) {
  rows <- db_execute_query(sql, params = params, conn = conn)
  if (nrow(rows) == 0 || !(column %in% names(rows))) {
    return(list())
  }
  as.list(as.character(stats::na.omit(rows[[column]])))
}

query_counts <- function(sql, params, conn) {
  rows_to_lists(db_execute_query(sql, params = params, conn = conn), c(label = "label", count = "count"))
}

scalar_chr <- function(value, default = NULL) {
  if (is.null(value) || length(value) == 0 || is.na(value[[1]])) default else as.character(value[[1]])
}

scalar_int <- function(value, default = 0L) {
  if (is.null(value) || length(value) == 0 || is.na(value[[1]])) default else as.integer(value[[1]])
}

gene_disease_sql <- function() "
  SELECT DISTINCT disease_ontology_name AS disease
  FROM ndd_entity_view
  WHERE hgnc_id = ?
  ORDER BY disease_ontology_name
"

gene_inheritance_sql <- function() "
  SELECT DISTINCT hpo_mode_of_inheritance_term_name AS inheritance
  FROM ndd_entity_view
  WHERE hgnc_id = ?
  ORDER BY hpo_mode_of_inheritance_term_name
"

gene_classification_sql <- function() "
  SELECT category AS label, COUNT(*) AS count
  FROM ndd_entity_view
  WHERE hgnc_id = ?
  GROUP BY category
  ORDER BY count DESC, category
"

gene_ndd_status_sql <- function() "
  SELECT ndd_phenotype_word AS label, COUNT(*) AS count
  FROM ndd_entity_view
  WHERE hgnc_id = ?
  GROUP BY ndd_phenotype_word
  ORDER BY count DESC, ndd_phenotype_word
"

gene_pmids_sql <- function() "
  SELECT DISTINCT REPLACE(rpj.publication_id, 'PMID:', '') AS pmid
  FROM ndd_review_publication_join rpj
  JOIN ndd_entity_review er
    ON rpj.review_id = er.review_id
    AND er.is_primary = 1 AND er.review_approved = 1
  WHERE rpj.entity_id IN (SELECT entity_id FROM ndd_entity_view WHERE hgnc_id = ?)
    AND rpj.is_reviewed = 1
  ORDER BY pmid
"

gene_last_modified_sql <- function() "
  SELECT DATE_FORMAT(MAX(entry_date), '%Y-%m-%d') AS last_modified
  FROM ndd_entity_view
  WHERE hgnc_id = ?
"

entity_review_sql <- function() "
  SELECT synopsis, DATE_FORMAT(MAX(review_date), '%Y-%m-%d') AS last_modified
  FROM ndd_entity_review
  WHERE entity_id = ? AND review_approved = 1
  GROUP BY synopsis
  ORDER BY MAX(is_primary) DESC, MAX(review_date) DESC
  LIMIT 1
"

entity_hpo_sql <- function() "
  SELECT DISTINCT pc.phenotype_id AS id, pl.HPO_term AS label
  FROM ndd_review_phenotype_connect pc
  JOIN ndd_entity_review er
    ON pc.review_id = er.review_id
    AND er.is_primary = 1 AND er.review_approved = 1
  JOIN phenotype_list pl ON pc.phenotype_id = pl.phenotype_id
  WHERE pc.entity_id = ? AND pc.is_active = 1
  ORDER BY pl.HPO_term
"

entity_variation_sql <- function() "
  SELECT DISTINCT vc.vario_id AS id, vl.vario_name AS label
  FROM ndd_review_variation_ontology_connect vc
  JOIN ndd_entity_review er
    ON vc.review_id = er.review_id
    AND er.is_primary = 1 AND er.review_approved = 1
  JOIN variation_ontology_list vl ON vc.vario_id = vl.vario_id
  WHERE vc.entity_id = ? AND vc.is_active = 1
  ORDER BY vl.vario_name
"

entity_pmids_sql <- function() "
  SELECT DISTINCT REPLACE(rpj.publication_id, 'PMID:', '') AS pmid
  FROM ndd_review_publication_join rpj
  JOIN ndd_entity_review er
    ON rpj.review_id = er.review_id
    AND er.is_primary = 1 AND er.review_approved = 1
  WHERE rpj.entity_id = ? AND rpj.is_reviewed = 1
  ORDER BY pmid
"
