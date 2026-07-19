source_api_file("functions/analysis-cluster-validation.R", local = FALSE, envir = globalenv())

test_that("cluster_max_jaccard recovers identical partitions at 1.0", {
  ref  <- list(A = c("g1", "g2", "g3"), B = c("g4", "g5"))
  boot <- list(X = c("g1", "g2", "g3"), Y = c("g4", "g5"))
  present <- c("g1", "g2", "g3", "g4", "g5")
  res <- cluster_max_jaccard(ref, boot, present)
  expect_equal(unname(res[["A"]]), 1.0)
  expect_equal(unname(res[["B"]]), 1.0)
})

test_that("cluster_max_jaccard penalizes a split cluster", {
  ref  <- list(A = c("g1", "g2", "g3", "g4"))
  boot <- list(X = c("g1", "g2"), Y = c("g3", "g4"))   # ref A split in two
  res <- cluster_max_jaccard(ref, boot, c("g1", "g2", "g3", "g4"))
  expect_equal(unname(res[["A"]]), 0.5)              # max(2/4, 2/4)
})

test_that("cluster_max_jaccard returns NA (not -Inf) when a reference cluster is absent from the subsample", {
  # Cluster B has no members in `present`, so every recovery is NA. The result
  # must be NA_real_, never max(numeric(0)) == -Inf (which would poison the mean).
  ref  <- list(A = c("g1", "g2"), B = c("g8", "g9"))
  boot <- list(X = c("g1", "g2"))
  present <- c("g1", "g2", "g3")                     # B's members not sampled
  res <- cluster_max_jaccard(ref, boot, present)
  expect_equal(unname(res[["A"]]), 1.0)
  expect_true(is.na(res[["B"]]))
  expect_false(is.infinite(res[["B"]]))
})

test_that("cluster_max_jaccard returns NA for every cluster when no bootstrap clusters exist", {
  ref <- list(A = c("g1", "g2"), B = c("g3"))
  res <- cluster_max_jaccard(ref, list(), c("g1", "g2", "g3"))
  expect_true(all(is.na(res)))
})

test_that("gen_string_clust_obj clusters the shared build_string_subgraph helper", {
  # Contract: the validator's reference graph must be the SAME object production
  # clusters. Refactoring (not reconstructing) the construction guarantees that.
  src <- readLines(file.path(get_api_dir(), "functions", "analyses-functions.R"))
  body <- paste(src, collapse = "\n")
  expect_match(body, "build_string_subgraph\\s*<-\\s*function")            # helper exists
  expect_match(body, "subgraph\\s*<-\\s*build_string_subgraph\\(")        # production calls it
})

source_api_file("functions/analysis-snapshot-builder.R", local = FALSE, envir = globalenv())

test_that("missingness_sensitivity is EXCLUDED from payload_hash (additive, no cluster_hash churn)", {
  base_payload <- list(
    kind = "clusters",
    clusters = tibble::tibble(cluster = 1:2, hash_filter = c("h1", "h2")),
    members = tibble::tibble(entity_id = c("e1", "e2")),
    row_counts = list(clusters = 2L),
    partition_validation = list(
      algorithm = "mca_hcpc",
      missingness_sensitivity = list(status = "ok", adjusted_rand_index = 0.90)
    )
  )
  variant <- base_payload
  variant$partition_validation$missingness_sensitivity <-
    list(status = "ok", adjusted_rand_index = 0.10)

  hash_of <- function(p) analysis_snapshot_payload_hash(
    p[setdiff(names(p), c("raw", "partition_validation", "reproducibility"))]
  )
  expect_identical(hash_of(base_payload), hash_of(variant))
})

test_that("validate_phenotype_clusters attaches missingness_sensitivity additively", {
  testthat::skip_if_not_installed("FactoMineR")
  testthat::skip_if_not_installed("cluster")
  source_api_file("functions/analysis-phenotype-mca-prep.R", local = FALSE, envir = globalenv())
  source_api_file("functions/analysis-phenotype-functions.R", local = FALSE, envir = globalenv())
  source_api_file("functions/analysis-null-models.R", local = FALSE, envir = globalenv())
  source_api_file("functions/analysis-phenotype-missingness.R", local = FALSE, envir = globalenv())

  # Small synthetic encoded matrix with a 2-cluster positive structure and the real
  # 4 leading supplementary columns, so gen_mca_clust_obj/HCPC produce >= 2 clusters.
  lv <- c("absent", "present"); f <- function(x) factor(x, lv)
  n <- 40
  grp <- rep(1:2, each = n / 2)
  m <- data.frame(
    inh = rep("AD", n),
    phenotype_non_id_count = 1, phenotype_id_count = 1, gene_entity_count = 1,
    Seizures     = f(ifelse(grp == 1, "present", "absent")),
    ID           = f(ifelse(grp == 1, "present", "absent")),
    Microcephaly = f(ifelse(grp == 2, "present", "absent")),
    Ataxia       = f(ifelse(grp == 2, "present", "absent"))
  )
  rownames(m) <- paste0("e", seq_len(n))
  attr(m, "mca_provenance") <- list(kept_terms = c("Seizures", "ID", "Microcephaly", "Ataxia"))

  val <- tryCatch(
    validate_phenotype_clusters(m, quali_sup_var = 1:1, quanti_sup_var = 2:4,
                                min_size = 5, n_resamples = 2),
    error = function(e) NULL
  )
  testthat::skip_if(is.null(val), "phenotype validator unavailable on host")
  ms <- val$partition$missingness_sensitivity
  expect_false(is.null(ms))
  expect_true(all(c("adjusted_rand_index", "per_cluster_max_jaccard",
                    "silhouette_served_partition") %in% names(ms)))
})
