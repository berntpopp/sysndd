# Deterministic, synthetic fixtures for the disposable MCP principal verifier.
# No production data or credential is read by this file.

mcp_verify_exec <- function(conn, sql, params = list()) {
  if (length(params)) {
    DBI::dbExecute(conn, sql, params = unname(params))
  } else {
    DBI::dbExecute(conn, sql)
  }
}

mcp_verify_query <- function(conn, sql, params = list()) {
  if (length(params)) {
    DBI::dbGetQuery(conn, sql, params = unname(params))
  } else {
    DBI::dbGetQuery(conn, sql)
  }
}

mcp_verify_seed_core <- function(conn) {
  mcp_verify_exec(conn, "SET FOREIGN_KEY_CHECKS = 0")
  on.exit(mcp_verify_exec(conn, "SET FOREIGN_KEY_CHECKS = 1"), add = TRUE)

  statements <- c(
    "INSERT INTO non_alt_loci_set
       (hgnc_id, symbol, name, status, ensembl_gene_id, uniprot_ids, STRING_id)
     VALUES ('HGNC:7001','LIVEGENE','Live verification gene','Approved',
             'ENSGLIVE7001','PLIVE7001','9606.ENSP7001'),
            ('HGNC:7002','WITHDRAWN_LIVE','withdrawn sentinel','Withdrawn',NULL,NULL,NULL)",
    "INSERT INTO hgnc_symbol_lookup (lookup_symbol,hgnc_id,symbol_type)
     VALUES ('LIVEGENE','HGNC:7001','current'),('LIVEALIAS','HGNC:7001','alias')",
    "INSERT INTO disease_ontology_set
       (disease_ontology_id_version,disease_ontology_id,disease_ontology_name,
        disease_ontology_source,disease_ontology_is_specific,MONDO,is_active)
     VALUES ('MONDO:7000001','MONDO:7000001','Live verification syndrome',
             'MONDO',1,'MONDO:7000001',1),
            ('MONDO:7000002','MONDO:7000002','inactive disease sentinel',
             'MONDO',1,'MONDO:7000002',0)",
    "INSERT INTO mode_of_inheritance_list
       (hpo_mode_of_inheritance_term,hpo_mode_of_inheritance_term_name,
        inheritance_filter,is_active)
     VALUES ('HP:0000006','Autosomal dominant inheritance','AD',1)",
    "INSERT INTO phenotype_list
       (phenotype_id,HPO_term,HPO_term_definition,HPO_term_synonyms)
     VALUES ('HP:7000001','Live verification phenotype','synthetic definition','live feature')",
    "INSERT INTO variation_ontology_list
       (vario_id,vario_name,definition,obsolete,is_active)
     VALUES ('VariO:7001','Live loss of function','synthetic variation',0,1)",
    "INSERT INTO ndd_entity
       (entity_id,hgnc_id,hpo_mode_of_inheritance_term,disease_ontology_id_version,
        ndd_phenotype,entry_user_id,is_active)
     VALUES (7001,'HGNC:7001','HP:0000006','MONDO:7000001',1,1,1),
            (7002,'HGNC:7001','HP:0000006','MONDO:7000002',1,1,0),
            (7003,'HGNC:7001','HP:0000006','MONDO:7000001',0,1,1)", # non_ndd
    "INSERT INTO ndd_entity_status
       (status_id,entity_id,category_id,is_active,status_user_id,status_approved)
     VALUES (7001,7001,1,1,1,1),(7002,7002,1,1,1,1),(7003,7003,2,1,1,1)",
    "INSERT INTO ndd_entity_review
       (review_id,entity_id,synopsis,is_primary,review_user_id,review_approved)
     VALUES (7001,7001,'approved synopsis sentinel',1,1,1),
            (7002,7001,'draft confidentiality sentinel',1,1,0),
            (7003,7001,'secondary confidentiality sentinel',0,1,1),
            (7004,7002,'inactive entity confidentiality sentinel',1,1,1)",
    "INSERT INTO ndd_review_phenotype_connect
       (review_phenotype_id,review_id,phenotype_id,modifier_id,entity_id,is_active)
     VALUES (7001,7001,'HP:7000001',1,7001,1),
            (7002,7002,'HP:7000001',1,7001,1),
            (7003,7001,'HP:7000001',1,7003,1),
            (7004,7001,'HP:7000001',1,7001,0)",
    "INSERT INTO ndd_review_variation_ontology_connect
       (review_vario_id,review_id,vario_id,modifier_id,entity_id,is_active)
     VALUES (7001,7001,'VariO:7001',1,7001,1),
            (7002,7002,'VariO:7001',1,7001,1)",
    "INSERT INTO publication
       (publication_id,publication_type,Title,Abstract,Publication_date,
        publication_date_source,Journal,Keywords,Lastname,Firstname)
     VALUES ('PMID:7000001','case report','Live verification publication',
             'approved publication abstract','2026-01-01','publisher','Live Journal',
             'live verification','Verifier','Vera')",
    "INSERT INTO ndd_review_publication_join
       (review_publication_id,review_id,entity_id,publication_id,publication_type,is_reviewed)
     VALUES (7001,7001,7001,'PMID:7000001','case report',1),
            (7002,7002,7001,'PMID:7000001','draft link sentinel',1),
            (7003,7001,7003,'PMID:7000001','cross_entity sentinel',1)",
    "INSERT INTO ndd_database_comparison
       (symbol,hgnc_id,disease_ontology_id,inheritance,category,pathogenicity_mode,list,version)
     VALUES ('LIVEGENE','HGNC:7001','MONDO:7000001','AD','Definitive','LoF','LiveSource','v1'),
            ('WITHDRAWN_LIVE','HGNC:7002','MONDO:7000002','AD','Draft','sentinel','HiddenSource','v0')",
    "UPDATE comparisons_metadata
        SET last_full_refresh=UTC_TIMESTAMP(),last_refresh_status='success',
            sources_count=1,rows_imported=1
      WHERE id=(SELECT id FROM (SELECT MAX(id) id FROM comparisons_metadata) latest)",
    "INSERT INTO nddscore_release
       (release_id,score_schema_version,version,n_genes,n_hpo_predictions,n_hpo_terms,
        n_features,hpo_threshold,is_active,import_status,import_completed_at,activated_at)
     VALUES ('live-active','1.0','live-v1',1,1,1,1,0.5,1,'active',UTC_TIMESTAMP(),UTC_TIMESTAMP()),
            ('live-inactive','1.0','hidden-v0',1,0,0,1,0.5,0,'validated',UTC_TIMESTAMP(),NULL)",
    "INSERT INTO nddscore_gene_prediction
       (release_id,hgnc_id,gene_symbol,ndd_score,`rank`,percentile,risk_tier,
        confidence_tier,known_sysndd_gene,n_predicted_hpo,prediction_note)
     VALUES ('live-active','HGNC:7001','LIVEGENE',0.91,1,99.9,'high','high',1,1,
             'live prediction sentinel'),
            ('live-inactive','HGNC:7002','WITHDRAWN_LIVE',0.99,1,100,'high','high',0,0,
             'inactive NDDScore sentinel')",
    "INSERT INTO nddscore_hpo_prediction
       (release_id,hgnc_id,gene_symbol,phenotype_id,phenotype_name,probability,rank_for_gene)
     VALUES ('live-active','HGNC:7001','LIVEGENE','HP:7000001',
             'Live verification phenotype',0.88,1)"
  )
  for (statement in statements) mcp_verify_exec(conn, statement)
}

mcp_verify_insert_manifest <- function(conn, normalized, source_version) {
  mcp_verify_exec(
    conn,
    paste(
      "INSERT INTO analysis_snapshot_manifest",
      "(analysis_type,parameter_hash,schema_version,data_class,status,public_ready,",
      "generated_at,activated_at,stale_after,source_data_version,parameters_json,",
      "input_hash,payload_hash,algorithm_name,algorithm_version,row_counts_json)",
      "VALUES (?,?, '1.2',?,'public_ready',1,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),",
      "DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 1 DAY),?,?,",
      "REPEAT('a',64),REPEAT('b',64),'live-fixture','1',JSON_OBJECT('rows',1))"
    ),
    list(
      normalized$analysis_type, normalized$parameter_hash,
      normalized$data_class, source_version, normalized$parameters_json
    )
  )
  as.numeric(mcp_verify_query(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1]])
}

mcp_verify_seed_analysis <- function(conn) {
  source_version <- mcp_verify_query(
    conn,
    "SELECT source_data_version FROM mcp_public_analysis_source_version"
  )$source_data_version[[1]]
  presets <- analysis_snapshot_supported_presets()
  ids <- list()
  for (preset in presets) {
    normalized <- analysis_snapshot_normalize_params(
      preset$analysis_type,
      preset$params
    )
    ids[[preset$analysis_type]] <- mcp_verify_insert_manifest(
      conn,
      normalized,
      source_version
    )
  }

  for (kind in c("functional", "phenotype")) {
    type <- paste0(kind, "_clusters")
    snapshot_id <- ids[[type]]
    mcp_verify_exec(
      conn,
      paste(
        "INSERT INTO analysis_snapshot_cluster",
        "(snapshot_id,cluster_kind,cluster_id,cluster_hash,cluster_size,label,metadata_json)",
        "VALUES (?,?,'1',REPEAT(?,64),1,?,JSON_OBJECT('live',true))"
      ),
      list(snapshot_id, kind, substr(kind, 1, 1), paste("live", kind, "cluster"))
    )
    mcp_verify_exec(
      conn,
      paste(
        "INSERT INTO analysis_snapshot_cluster_member",
        "(snapshot_id,cluster_kind,cluster_id,member_rank,entity_id,hgnc_id,symbol)",
        "VALUES (?,?,'1',1,7001,'HGNC:7001','LIVEGENE')"
      ),
      list(snapshot_id, kind)
    )
  }

  correlations <- list(
    phenotype_correlations = c("HP:7000001", "HP:7000002", "phenotype"),
    phenotype_functional_correlations = c("pc_1", "fc_1", "cross_axis")
  )
  for (type in names(correlations)) {
    values <- correlations[[type]]
    mcp_verify_exec(
      conn,
      paste(
        "INSERT INTO analysis_snapshot_correlation",
        "(snapshot_id,row_rank,correlation_kind,x_key,y_key,value,abs_value,metadata_json)",
        "VALUES (?,1,?,?,?,0.8,0.8,JSON_OBJECT('live',true))"
      ),
      list(ids[[type]], values[[3]], values[[1]], values[[2]])
    )
  }

  network_id <- ids$gene_network_edges
  mcp_verify_exec(
    conn,
    paste(
      "INSERT INTO analysis_snapshot_network_node",
      "(snapshot_id,hgnc_id,symbol,cluster_id,category,degree,display_order)",
      "VALUES (?,'HGNC:7001','LIVEGENE','1','Definitive',1,1),",
      "(?,'HGNC:7009','LIVEPARTNER','1','Definitive',1,2)"
    ),
    list(network_id, network_id)
  )
  mcp_verify_exec(
    conn,
    paste(
      "INSERT INTO analysis_snapshot_network_edge",
      "(snapshot_id,edge_rank,source_hgnc_id,target_hgnc_id,confidence)",
      "VALUES (?,1,'HGNC:7001','HGNC:7009',0.95)"
    ),
    list(network_id)
  )

  functional_id <- ids$functional_clusters
  summary <- jsonlite::toJSON(
    list(
      summary = "allowed LLM summary sentinel",
      key_themes = list("live theme"),
      confidence = "high",
      forbidden_top_level = "confidential judge sentinel",
      nested = list(forbidden_nested = "confidential reasoning sentinel")
    ),
    auto_unbox = TRUE
  )
  mcp_verify_exec(
    conn,
    paste(
      "INSERT INTO llm_cluster_summary_cache",
      "(cluster_type,cluster_number,cluster_hash,model_name,prompt_version,summary_json,",
      "tags,is_current,validation_status,validated_at)",
      "VALUES ('functional',1,REPEAT('f',64),'fixture-model','1.0',?,",
      "JSON_ARRAY('live'),1,'validated',UTC_TIMESTAMP())"
    ),
    list(summary)
  )
  invisible(list(ids = ids, source_version = source_version, functional = functional_id))
}
