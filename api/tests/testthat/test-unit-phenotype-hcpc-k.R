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
  # gen_mca_clust_obj uses unqualified tidyverse verbs; attach them so this test
  # (the first to actually execute it) does not depend on the harness's ambient
  # attachments. No-ops when already attached.
  suppressWarnings(suppressMessages({
    library(dplyr)
    library(tibble)
    library(tidyr)
    library(purrr)
    library(stringr)
  }))
  source_api_file("functions/analysis-phenotype-functions.R", local = FALSE, envir = globalenv())

  # Stub the identifier-hash helper: it is unrelated to this test (which asserts
  # clustering behavior — data-driven k, min_size enforcement, cluster_signature)
  # and pulling in its full runtime is unnecessary.
  had_hash <- exists("post_db_hash", envir = globalenv())
  old_hash <- if (had_hash) get("post_db_hash", envir = globalenv())
  assign("post_db_hash", function(...) list(links = list(hash = "test-stub")),
         envir = globalenv())
  withr::defer({
    if (had_hash) {
      assign("post_db_hash", old_hash, envir = globalenv())
    } else if (exists("post_db_hash", envir = globalenv())) {
      rm("post_db_hash", envir = globalenv())
    }
  })

  set.seed(1)
  # Production-shaped MCA input: entity_id lives in the ROWNAMES (never a
  # column), a categorical supplementary column (moi), three numeric
  # supplementary count columns, then the active HPO columns. Two clear
  # phenotype blocks (28 + 29) plus a 5-entity block that falls below min_size
  # and is dropped. The supplementary vars are correlated with the blocks so
  # HCPC yields a full per-cluster description (its desc tables must be
  # non-empty for the tibble assembly to succeed).
  mk <- function(n, cols_on) {
    m <- matrix(NA_character_, n, 6, dimnames = list(NULL, paste0("HP_", 1:6)))
    for (col in cols_on) m[, col] <- "yes"
    as.data.frame(m, stringsAsFactors = FALSE)
  }
  hpo <- rbind(mk(28, c(1, 2, 3)), mk(29, c(4, 5, 6)), mk(5, c(1, 6)))
  n <- nrow(hpo)
  grp <- c(rep("A", 28), rep("B", 29), rep("C", 5))
  df <- data.frame(
    moi    = ifelse(grp == "A", "AD", ifelse(grp == "B", "AR", "XL")),
    count1 = as.numeric(ifelse(grp == "A", 8, ifelse(grp == "B", 2, 5)) + rpois(n, 1)),
    count2 = as.numeric(ifelse(grp == "A", 3, ifelse(grp == "B", 9, 6)) + rpois(n, 1)),
    count3 = as.numeric(ifelse(grp == "A", 6, ifelse(grp == "B", 6, 1)) + rpois(n, 1)),
    hpo, stringsAsFactors = FALSE, check.names = FALSE
  )
  rownames(df) <- as.character(seq_len(n))
  res <- gen_mca_clust_obj(df, min_size = 10, quali_sup_var = 1:1, quanti_sup_var = 2:4, cutpoint = -1)
  expect_true(is.data.frame(res) && "cluster" %in% names(res))
  expect_true(all(res$cluster_size >= 10)) # tiny clusters dropped
  expect_true("cluster_signature" %in% names(res))
})
