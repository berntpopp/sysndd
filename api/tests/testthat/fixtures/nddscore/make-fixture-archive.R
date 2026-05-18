# Regenerates the NDDScore test fixture archives.
# Run from repo root: Rscript api/tests/testthat/fixtures/nddscore/make-fixture-archive.R
# Produces, in this directory:
#   nddscore_fixture_release.tar.gz  - valid trimmed release (3 genes, 4 HPO predictions, 2 terms)
#   nddscore_fixture_corrupt_sha256.tar.gz - same files but inner checksums.sha256 is wrong
# Generated archives are intentionally gitignored; commit this generator, not the tarballs.
# The fixture mirrors the real archive layout:
#   sysndd_zenodo_dataset/sysndd_prediction_release/{*.tsv, nddscore_release.json,
#     nddscore_schema.sql, checksums.sha256}

fixture_dir <- "api/tests/testthat/fixtures/nddscore"
rel <- "sysndd_zenodo_dataset/sysndd_prediction_release"

build_one <- function(out_name, corrupt_sha = FALSE) {
  stage <- file.path(tempdir(), paste0("ndd_fix_", as.integer(runif(1, 1, 1e9))))
  rel_dir <- file.path(stage, rel)
  dir.create(rel_dir, recursive = TRUE, showWarnings = FALSE)

  gene_tsv <- paste(
    "release_id\thgnc_id\tgene_symbol\tensembl_gene_id\tndd_score\tndd_score_std\tndd_score_iqr\tbag_agreement\trank\tpercentile\trisk_tier\tconfidence_tier\tknown_sysndd_gene\tmodel_split\tinheritance_ad_probability\tinheritance_ar_probability\tinheritance_xld_probability\tinheritance_xlr_probability\ttop_inheritance_mode\tcalled_inheritance_modes\tn_predicted_hpo\ttop_hpo_predictions_json\tshap_clinical\tshap_constraint\tshap_expression\tshap_network\tshap_conservation\tshap_other\tdominant_shap_group\ttop_features_json\tprediction_note",
    "ndd_fixture_release\tHGNC:2022\tCLCN4\tENSG00000073464\t0.9938804\t0.0035516\t0.0040947\t1.0\t1\t100.0\tVery High\tHigh\t1\ttrain\t0.0244\t0.0\t0.7373\t0.0233\tXLD\t\"[\"\"XLD\"\"]\"\t2\t\"[]\"\t1.06\t1.90\t2.18\t0.36\t0.07\t0.04\texpression\t\"[]\"\tFixture gene CLCN4.",
    "ndd_fixture_release\tHGNC:11110\tSTXBP1\tENSG00000136854\t0.9512000\t0.0100000\t0.0120000\t0.9\t2\t99.5\tHigh\tHigh\t1\ttest\t0.8100\t0.0200\t0.0100\t0.0050\tAD\t\"[\"\"AD\"\"]\"\t2\t\"[]\"\t0.50\t0.40\t0.30\t0.20\t0.10\t0.05\tclinical\t\"[]\"\tFixture gene STXBP1.",
    "ndd_fixture_release\tHGNC:99999\tFIXNOVEL\tENSG00000000001\t0.4200000\t0.0500000\t0.0600000\t0.5\t3\t42.0\tLow\tLow\t0\ttrain\t0.3000\t0.3000\t0.0100\t0.0100\tAR\t\"[]\"\t0\t\"[]\"\t0.10\t0.10\t0.10\t0.10\t0.10\t0.10\tother\t\"[]\"\tFixture novel gene.",
    sep = "\n"
  )
  hpo_pred_tsv <- paste(
    "release_id\thgnc_id\tgene_symbol\tphenotype_id\tphenotype_name\tprobability\trank_for_gene\tpasses_default_threshold\tterm_auc_roc\tterm_auc_pr\tterm_training_support",
    "ndd_fixture_release\tHGNC:2022\tCLCN4\tHP:0001249\tIntellectual disability\t0.9981000\t1\t1\t0.8200000\t0.7100000\t450",
    "ndd_fixture_release\tHGNC:2022\tCLCN4\tHP:0001250\tSeizure\t0.8317000\t2\t1\t0.7900000\t0.6800000\t300",
    "ndd_fixture_release\tHGNC:11110\tSTXBP1\tHP:0001249\tIntellectual disability\t0.9700000\t1\t1\t0.8200000\t0.7100000\t450",
    "ndd_fixture_release\tHGNC:11110\tSTXBP1\tHP:0001250\tSeizure\t0.9100000\t2\t1\t0.7900000\t0.6800000\t300",
    sep = "\n"
  )
  hpo_term_tsv <- paste(
    "release_id\tphenotype_id\tphenotype_name\tterm_auc_roc\tterm_auc_pr\tterm_training_support",
    "ndd_fixture_release\tHP:0001249\tIntellectual disability\t0.8200000\t0.7100000\t450",
    "ndd_fixture_release\tHP:0001250\tSeizure\t0.7900000\t0.6800000\t300",
    sep = "\n"
  )
  release_json <- paste0(
    '{\n',
    '  "release_id": "ndd_fixture_release",\n',
    '  "score_schema_version": "1.0.0",\n',
    '  "created_at": "2026-05-17T13:53:16",\n',
    '  "n_genes": 3,\n',
    '  "n_hpo_predictions": 4,\n',
    '  "n_hpo_terms": 2,\n',
    '  "n_features": 48,\n',
    '  "hpo_threshold": 0.5,\n',
    '  "calibration_method": "platt_oob",\n',
    '  "ndd_model_created_at": "2026-05-17T13:49:24",\n',
    '  "phenotype_model_created_at": "2026-05-17T13:51:16",\n',
    '  "inheritance_model_created_at": "2026-05-17T13:51:20",\n',
    '  "is_active": true,\n',
    '  "ndd_performance_json": {"test": {"auc_roc": 0.8877, "auc_pr": 0.8965, ',
    '"brier": 0.1388, "bss": 0.4438}},\n',
    '  "phenotype_performance_json": {"pre_tpr": {"macro_auc_roc": 0.749}},\n',
    '  "inheritance_performance_json": {"macro_f1": 0.728},\n',
    '  "data_versions_json": {"hgnc": {"version": "2026-04"}},\n',
    '  "artifact_hashes_json": {"nddscore_schema.sql": "fixture"}\n',
    '}\n'
  )
  schema_sql <- "-- fixture schema placeholder; real DDL ships in db/migrations/023\n"

  writeLines(gene_tsv, file.path(rel_dir, "nddscore_gene_predictions.tsv"))
  writeLines(hpo_pred_tsv, file.path(rel_dir, "nddscore_hpo_predictions.tsv"))
  writeLines(hpo_term_tsv, file.path(rel_dir, "nddscore_hpo_terms.tsv"))
  writeLines(release_json, file.path(rel_dir, "nddscore_release.json"))
  writeLines(schema_sql, file.path(rel_dir, "nddscore_schema.sql"))

  checksum_files <- c(
    "nddscore_gene_predictions.tsv", "nddscore_hpo_predictions.tsv",
    "nddscore_hpo_terms.tsv", "nddscore_release.json", "nddscore_schema.sql"
  )
  sha_lines <- vapply(checksum_files, function(f) {
    digest_val <- if (corrupt_sha && f == "nddscore_release.json") {
      paste(rep("0", 64), collapse = "")
    } else {
      digest::digest(file = file.path(rel_dir, f), algo = "sha256")
    }
    paste0(digest_val, "  ", f)
  }, character(1))
  writeLines(sha_lines, file.path(rel_dir, "checksums.sha256"))

  fixed_time <- as.POSIXct("2026-05-17 13:53:16", tz = "UTC")
  staged_paths <- list.files(
    stage,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    include.dirs = TRUE
  )
  Sys.setFileTime(staged_paths, fixed_time)

  old_wd <- getwd()
  setwd(stage)
  on.exit(setwd(old_wd), add = TRUE)
  utils::tar(
    file.path(old_wd, fixture_dir, out_name),
    files = "sysndd_zenodo_dataset",
    compression = "gzip"
  )
  setwd(old_wd)
  archive <- file.path(fixture_dir, out_name)
  message(sprintf(
    "%s: %d bytes, md5=%s", out_name,
    file.size(archive), digest::digest(file = archive, algo = "md5")
  ))
}

build_one("nddscore_fixture_release.tar.gz", corrupt_sha = FALSE)
build_one("nddscore_fixture_corrupt_sha256.tar.gz", corrupt_sha = TRUE)
