source_api_file("functions/analysis-string-channels.R", local = FALSE, envir = globalenv())

test_that("string_expdb_subgraph builds a weighted, text-mining-free subgraph (#510)", {
  f <- file.path(get_api_dir(), "data", "9606.protein.links.expdb.v11.5.min400.txt.gz")
  skip_if_not(file.exists(f), "exp+db edge file not present in this environment")

  # take a real connected pair from the compact file
  first <- data.table::fread(cmd = paste("zcat", shQuote(f)), nrows = 1,
                             col.names = c("protein1", "protein2", "exp_db_score"))
  ids <- c(as.character(first$protein1), as.character(first$protein2), "9606.ENSP99999999999")

  g <- string_expdb_subgraph(ids, score_threshold = 400, file = f)
  expect_s3_class(g, "igraph")
  expect_identical(attr(g, "weight_channel"), "experimental_database")
  expect_equal(igraph::vcount(g), 3L)                 # all ids kept (3rd is an isolate)
  expect_gte(igraph::ecount(g), 1L)                   # the real pair is connected
  expect_true(!is.null(igraph::E(g)$combined_score))  # exp+db carried in the plumbing attr
  expect_true(all(igraph::E(g)$combined_score >= 400))
})

test_that("string_expdb_subgraph returns NULL when the file is absent (graceful fallback)", {
  expect_null(string_expdb_subgraph(c("9606.ENSP1", "9606.ENSP2"),
                                    file = "/nonexistent/expdb.txt.gz"))
})

test_that("string_expdb_subgraph reads a synthetic file, de-dups both-direction edges, thresholds (#510)", {
  # Deterministic CI coverage of the read path (no gitignored runtime artifact
  # needed). STRING lists every pair in BOTH directions, so this includes A-B/B-A
  # and A-C/C-A duplicates plus a below-threshold edge that must be dropped.
  tmp <- tempfile(fileext = ".txt.gz")
  on.exit(unlink(tmp), add = TRUE)
  edges <- data.frame(
    protein1 = c("9606.A", "9606.B", "9606.A", "9606.C", "9606.A"),
    protein2 = c("9606.B", "9606.A", "9606.C", "9606.A", "9606.D"),
    exp_db_score = c(800, 800, 500, 500, 350),
    stringsAsFactors = FALSE
  )
  data.table::fwrite(edges, file = tmp, sep = " ", compress = "gzip") # header, like the builder

  ids <- c("9606.A", "9606.B", "9606.C", "9606.D", "9606.ISO")
  g <- string_expdb_subgraph(ids, score_threshold = 400, file = tmp)
  expect_s3_class(g, "igraph")
  expect_identical(attr(g, "weight_channel"), "experimental_database")
  expect_equal(igraph::vcount(g), 5L)                # all ids kept incl. the isolate
  # A-B and A-C survive (>= 400) and each both-direction pair collapses to ONE
  # undirected edge; A-D (350) is dropped. Without simplify() this would be 4.
  expect_equal(igraph::ecount(g), 2L)
  expect_true(all(igraph::E(g)$combined_score >= 400))
  expect_setequal(igraph::E(g)$combined_score, c(800, 500))
})

test_that("build_string_subgraph warns (not just messages) on the auto -> combined fallback (#514)", {
  source_api_file("functions/analyses-functions.R", local = FALSE, envir = globalenv())
  withr::local_envvar(STRING_EXPDB_EDGES_FILE = "/nonexistent/expdb.txt.gz")

  # Stub the STRINGdb singleton so the combined fallback needs no network/DB.
  old <- get0("get_string_db", envir = globalenv(), ifnotfound = NULL)
  assign("get_string_db", function(score_threshold = 400) {
    list(get_graph = function() {
      g <- igraph::make_empty_graph(directed = FALSE)
      igraph::add_vertices(g, 2, name = c("9606.A", "9606.B"))
    })
  }, envir = globalenv())
  on.exit(
    if (is.null(old)) rm("get_string_db", envir = globalenv()) else assign("get_string_db", old, envir = globalenv()),
    add = TRUE
  )

  id_tbl <- tibble::tibble(
    symbol = c("G1", "G2"), hgnc_id = c("HGNC:1", "HGNC:2"),
    STRING_id = c("9606.A", "9606.B")
  )
  expect_warning(
    g <- build_string_subgraph(c("HGNC:1", "HGNC:2"), score_threshold = 400, string_id_table = id_tbl),
    "combined_score", ignore.case = TRUE
  )
  expect_identical(attr(g, "weight_channel"), "combined_score")
})

test_that("build_string_subgraph prefers the exp+db channel when available", {
  source_api_file("functions/analyses-functions.R", local = FALSE, envir = globalenv())
  f <- file.path(get_api_dir(), "data", "9606.protein.links.expdb.v11.5.min400.txt.gz")
  skip_if_not(file.exists(f), "exp+db edge file not present")
  withr::local_envvar(STRING_EXPDB_EDGES_FILE = f)

  first <- data.table::fread(cmd = paste("zcat", shQuote(f)), nrows = 1,
                             col.names = c("protein1", "protein2", "exp_db_score"))
  id_tbl <- tibble::tibble(
    symbol = c("G1", "G2"),
    hgnc_id = c("HGNC:1", "HGNC:2"),
    STRING_id = c(as.character(first$protein1), as.character(first$protein2))
  )
  g <- build_string_subgraph(c("HGNC:1", "HGNC:2"), score_threshold = 400,
                             string_id_table = id_tbl)
  expect_identical(attr(g, "weight_channel"), "experimental_database")
})
