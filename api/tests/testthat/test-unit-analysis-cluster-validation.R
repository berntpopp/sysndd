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

test_that("gen_string_clust_obj clusters the shared build_string_subgraph helper", {
  # Contract: the validator's reference graph must be the SAME object production
  # clusters. Refactoring (not reconstructing) the construction guarantees that.
  src <- readLines(file.path(get_api_dir(), "functions", "analyses-functions.R"))
  body <- paste(src, collapse = "\n")
  expect_match(body, "build_string_subgraph\\s*<-\\s*function")            # helper exists
  expect_match(body, "subgraph\\s*<-\\s*build_string_subgraph\\(")        # production calls it
})
