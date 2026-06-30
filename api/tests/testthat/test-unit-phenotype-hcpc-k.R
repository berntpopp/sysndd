test_that("gen_mca_clust_obj selects k from data and enforces min_size", {
  src <- readLines(file.path(get_api_dir(), "functions", "analysis-phenotype-functions.R"))
  body <- paste(src, collapse = "\n")
  expect_match(body, "nb\\.clust\\s*=\\s*-1", fixed = FALSE)            # data-driven k path reachable
  expect_match(body, "cutpoint\\s*=\\s*-1", fixed = FALSE)             # default is data-driven
  expect_match(body, "filter\\(cluster_size\\s*>=\\s*min_size\\)")     # min_size now enforced
  expect_match(body, "cluster_signature")                              # stable identity present
})

test_that("gen_mca_clust_obj returns a data-driven k and drops tiny clusters", {
  testthat::skip_if_not_installed("FactoMineR")
  source_api_file("functions/analysis-phenotype-functions.R", local = FALSE, envir = globalenv())
  set.seed(1)
  # 60 entities: two clear phenotype blocks + 3 singletons
  mk <- function(n, cols_on) {
    m <- matrix(NA_character_, n, 6, dimnames = list(NULL, paste0("HP_", 1:6)))
    for (c in cols_on) m[, c] <- "yes"
    as.data.frame(m, stringsAsFactors = FALSE)
  }
  df <- rbind(mk(28, c(1, 2, 3)), mk(29, c(4, 5, 6)), mk(3, c(1, 6)))
  df$entity_id <- seq_len(nrow(df))
  df$moi <- "AD"; df$c1 <- 1; df$c2 <- 1; df$c3 <- 1
  df <- df[, c("entity_id", "moi", "c1", "c2", "c3", paste0("HP_", 1:6))]
  res <- gen_mca_clust_obj(df, min_size = 10, quali_sup_var = 1:1, quanti_sup_var = 2:4, cutpoint = -1)
  expect_true(is.data.frame(res) && "cluster" %in% names(res))
  expect_true(all(res$cluster_size >= 10)) # tiny clusters dropped
  expect_true("cluster_signature" %in% names(res))
})
