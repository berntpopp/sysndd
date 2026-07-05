source_api_file("functions/analysis-phenotype-mca-prep.R", local = FALSE, envir = globalenv())

# Build a small in-memory presence matrix mirroring generate_phenotype_cluster_input:
#   - rownames = entities e1..e40
#   - leading supplementary columns: inh (factor), c1/c2/c3 (numeric counts)
#   - presence columns coded "yes"/NA:
#       "Phenotypic abnormality" -> 40/40 "yes" (HPO root)
#       "Ubiq term"              -> 39/40 "yes" (prevalence 0.975, near_universal)
#       "Common term"            -> 20/40 "yes" (prevalence 0.5, kept)
#       "Rare term"              ->  1/40 "yes" (prevalence 0.025, near_rare)
make_matrix <- function(n = 40L) {
  yes_first <- function(k) c(rep("yes", k), rep(NA_character_, n - k))
  mat <- data.frame(
    inh = factor(rep(c("Autosomal dominant inheritance",
                       "Autosomal recessive inheritance"), length.out = n)),
    c1 = as.numeric(seq_len(n)),
    c2 = as.numeric(rev(seq_len(n))),
    c3 = as.numeric(rep(1:4, length.out = n)),
    `Phenotypic abnormality` = yes_first(n),
    `Ubiq term` = yes_first(39L),
    `Common term` = yes_first(20L),
    `Rare term` = yes_first(1L),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  rownames(mat) <- paste0("e", seq_len(n))
  mat
}

test_that("phenotype_mca_active_filter drops root/near-rare/near-universal, keeps mid-band", {
  mat <- make_matrix()
  res <- phenotype_mca_active_filter(mat)

  # Kept terms: only the 50%-prevalence common term
  expect_true("Common term" %in% res$kept_terms)
  expect_false("Phenotypic abnormality" %in% res$kept_terms)
  expect_false("Rare term" %in% res$kept_terms)
  expect_false("Ubiq term" %in% res$kept_terms)
  expect_equal(res$kept_terms, "Common term")

  # excluded reasons are correct
  reason_for <- function(t) res$excluded$reason[res$excluded$term == t]
  expect_identical(reason_for("Phenotypic abnormality"), "root")
  expect_identical(reason_for("Rare term"), "near_rare")
  expect_identical(reason_for("Ubiq term"), "near_universal")
  expect_setequal(colnames(res$excluded), c("term", "prevalence", "reason"))

  # prevalence recorded correctly (root is 1.0 but reason takes precedence)
  expect_equal(res$excluded$prevalence[res$excluded$term == "Ubiq term"], 39 / 40)
  expect_equal(res$excluded$prevalence[res$excluded$term == "Rare term"], 1 / 40)
})

test_that("phenotype_mca_active_filter preserves supplementary columns as leading columns", {
  mat <- make_matrix()
  res <- phenotype_mca_active_filter(mat)
  am <- res$active_matrix

  # Leading 4 columns unchanged in identity/order
  expect_identical(colnames(am)[1:4], c("inh", "c1", "c2", "c3"))
  expect_identical(am$inh, mat$inh)
  expect_identical(am$c1, mat$c1)
  expect_identical(am$c2, mat$c2)
  expect_identical(am$c3, mat$c3)
  # Presence columns are the leading supplementary ones + kept terms only
  expect_identical(colnames(am), c("inh", "c1", "c2", "c3", "Common term"))
  expect_identical(rownames(am), rownames(mat))
})

test_that("phenotype_mca_active_filter honors hpo_lookup root mapping", {
  mat <- make_matrix()
  # Rename the root so it is no longer caught by name; map via hpo_lookup id instead.
  colnames(mat)[colnames(mat) == "Phenotypic abnormality"] <- "Root alias"
  lookup <- tibble::tibble(
    HPO_term = c("Root alias", "Common term"),
    phenotype_id = c("HP:0000118", "HP:0001234")
  )
  res <- phenotype_mca_active_filter(mat, drop_terms = character(0), hpo_lookup = lookup)
  expect_false("Root alias" %in% res$kept_terms)
  expect_identical(res$excluded$reason[res$excluded$term == "Root alias"], "root")
})

test_that("phenotype_mca_encode_presence yields {absent,present} factors with correct counts", {
  mat <- make_matrix()
  presence <- c("Common term", "Rare term")
  enc <- phenotype_mca_encode_presence(mat, presence)

  expect_s3_class(enc$`Common term`, "factor")
  expect_identical(levels(enc$`Common term`), c("absent", "present"))
  expect_identical(levels(enc$`Rare term`), c("absent", "present"))

  expect_equal(sum(enc$`Common term` == "present"), 20L)
  expect_equal(sum(enc$`Common term` == "absent"), 20L)
  expect_equal(sum(enc$`Rare term` == "present"), 1L)
  expect_equal(sum(enc$`Rare term` == "absent"), 39L)

  # Supplementary columns untouched
  expect_identical(enc$inh, mat$inh)
  expect_identical(enc$c1, mat$c1)
})

test_that("phenotype_mca_ncp applies the 1/Q rule and returns adjusted inertia", {
  res <- phenotype_mca_ncp(c(0.30, 0.10, 0.04, 0.02), q_active = 20)
  # 1/Q = 0.05 -> lambda > 0.05 for {0.30, 0.10} -> 2 retained
  expect_equal(res$ncp, 2L)
  expect_length(res$adjusted_inertia, 2L)
  expect_true(all(res$adjusted_inertia > 0))
})

test_that("phenotype_mca_ncp floors ncp and accepts n_categories override", {
  # Only one axis exceeds 1/Q (0.20 > 0.05), floor lifts ncp to 2
  res <- phenotype_mca_ncp(c(0.20, 0.02, 0.01), q_active = 20, floor = 2L)
  expect_equal(res$ncp, 2L)
  expect_length(res$adjusted_inertia, 1L)

  # n_categories override changes the Greenacre denominator (still positive here)
  res2 <- phenotype_mca_ncp(c(0.30, 0.10), q_active = 20, n_categories = 45)
  expect_true(all(is.finite(res2$adjusted_inertia)))
})
