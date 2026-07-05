source_api_file("functions/analysis-string-channels.R", local = FALSE, envir = globalenv())

test_that("string_recompute_score matches the STRING probabilistic-OR combine (exp+db)", {
  # escore = 500 (0.5), dscore = 400 (0.4), prior = 0.041:
  # strip -> probabilistic OR -> add prior back, on the 0..1 scale.
  p <- 0.041
  strip <- function(x) pmax(0, (x - p) / (1 - p))
  expected <- {
    c <- 1 - (1 - strip(0.5)) * (1 - strip(0.4))
    c + p * (1 - c)
  }
  expect_equal(string_recompute_score(500, 400) / 1000, expected, tolerance = 1e-6)
})

test_that("string_recompute_score is vectorized and stays in [0, 1000]", {
  out <- string_recompute_score(c(500L, 900L, 0L), c(400L, 0L, 0L))
  expect_length(out, 3L)
  expect_true(all(out >= 0 & out <= 1000))
  # exp = 0, db = 0 collapses to the prior (~41)
  expect_equal(out[3], 41, tolerance = 1e-6)
})

test_that("string_textmining_free_edges drops text-mining-only edges, keeps real evidence", {
  df <- tibble::tibble(
    protein1 = c("9606.P1", "9606.P2", "9606.P3"),
    protein2 = c("9606.PA", "9606.PB", "9606.PC"),
    neighborhood = c(0L, 0L, 0L),
    fusion = c(0L, 0L, 0L),
    cooccurence = c(0L, 0L, 0L),
    coexpression = c(0L, 0L, 0L),
    experimental = c(0L, 900L, 0L), # edge 2 = strong experimental
    database = c(0L, 0L, 500L), # edge 3 = database evidence
    textmining = c(950L, 0L, 0L), # edge 1 = text-mining ONLY
    combined_score = c(950L, 900L, 500L)
  )
  out <- string_textmining_free_edges(df, score_threshold = 400)
  expect_named(out, c("protein1", "protein2", "exp_db_score"))
  # edge 1 (exp = 0, db = 0) recombines to the prior (~41) < 400 -> dropped
  expect_false("9606.P1" %in% out$protein1)
  # edge 2 (strong experimental) survives
  expect_true("9606.P2" %in% out$protein1)
  # edge 3 (database evidence) survives
  expect_true("9606.P3" %in% out$protein1)
  expect_true(all(out$exp_db_score >= 400))
})

test_that("STRING_WEIGHT_CHANNELS env generalizes the OR over other named channels", {
  withr::local_envvar(STRING_WEIGHT_CHANNELS = "experimental,coexpression")
  df <- tibble::tibble(
    protein1 = c("A", "B"),
    protein2 = c("C", "D"),
    experimental = c(0L, 0L),
    coexpression = c(0L, 800L),
    database = c(900L, 0L) # excluded under this env, so row 1 must drop
  )
  out <- string_textmining_free_edges(df, score_threshold = 400)
  expect_false("A" %in% out$protein1) # high database ignored -> ~prior -> dropped
  expect_true("B" %in% out$protein1) # coexpression = 800 survives
})

test_that("string_textmining_free_edges fails fast on a missing channel column", {
  df <- tibble::tibble(protein1 = "A", protein2 = "B", experimental = 500L)
  expect_error(string_textmining_free_edges(df), "database")
})
