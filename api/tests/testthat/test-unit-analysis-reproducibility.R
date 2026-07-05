# tests/testthat/test-unit-analysis-reproducibility.R
#
# #512 round-trip guarantee: the reproducibility bundle must carry enough to
# INDEPENDENTLY recompute the served separation metric. These tests exercise the
# representation-agnostic serializer (`analysis_reproducibility_bundle`) with
# small synthetic payloads (no DB, no STRING, no MCA) so they are fast and
# deterministic.

source_api_file("functions/analysis-reproducibility.R", local = FALSE, envir = globalenv())

# A connected 2-clique graph (4 + 4 nodes + one bridge) with weighted edges, a
# planted two-community membership, and the served modularity computed on it.
build_synthetic_functional_payload <- function() {
  g <- igraph::disjoint_union(igraph::make_full_graph(4), igraph::make_full_graph(4))
  g <- igraph::add_edges(g, c(1, 5)) # bridge so the whole graph is one component
  igraph::V(g)$name <- as.character(seq_len(igraph::vcount(g)))
  set.seed(1)
  igraph::E(g)$combined_score <- round(stats::runif(igraph::ecount(g), 0.4, 0.99), 4)
  memb <- c(rep(1L, 4), rep(2L, 4))
  served <- igraph::modularity(g, memb, weights = igraph::E(g)$combined_score)

  el <- igraph::as_data_frame(g, what = "edges")
  edges <- data.frame(
    source = as.character(el$from),
    target = as.character(el$to),
    combined_score = as.numeric(el$combined_score),
    exp_db_score = as.numeric(el$combined_score),
    stringsAsFactors = FALSE
  )
  membership <- data.frame(
    node = as.character(seq_len(8)),
    cluster = memb,
    stringsAsFactors = FALSE
  )
  list(
    edges = edges,
    membership = membership,
    served_modularity = served,
    params = list(seed = 42L, weight_channel = "combined_score", resolution = 1.0)
  )
}

build_synthetic_phenotype_payload <- function() {
  set.seed(3)
  coords_mat <- rbind(
    matrix(stats::rnorm(60, 0), ncol = 3),
    matrix(stats::rnorm(60, 6), ncol = 3)
  )
  colnames(coords_mat) <- paste0("Dim.", seq_len(ncol(coords_mat)))
  eids <- as.character(seq_len(nrow(coords_mat)))
  memb <- c(rep(1L, 20), rep(2L, 20))
  served_sil <- mean(cluster::silhouette(memb, stats::dist(coords_mat))[, "sil_width"])
  coords <- cbind(
    data.frame(entity_id = eids, stringsAsFactors = FALSE),
    as.data.frame(coords_mat)
  )
  membership <- data.frame(entity_id = eids, cluster = memb, stringsAsFactors = FALSE)
  list(
    coords = coords,
    membership = membership,
    served_silhouette = served_sil,
    params = list(ncp = 3L, kk = "Inf", consolidation = TRUE, seed = 42L)
  )
}

test_that("functional bundle round-trips: recomputed modularity == served", {
  payload <- build_synthetic_functional_payload()
  b <- analysis_reproducibility_bundle("functional", payload)

  expect_true(is.raw(b$bundle_gzip_json))
  expect_equal(b$byte_size, length(b$bundle_gzip_json))
  expect_identical(b$kind, "functional")

  parsed <- analysis_reproducibility_decode(b$bundle_gzip_json)

  # Rebuild the graph purely from the published bundle and recompute modularity.
  g <- igraph::graph_from_data_frame(
    parsed$edges[, c("source", "target")],
    directed = FALSE
  )
  igraph::E(g)$weight <- parsed$edges$combined_score
  g <- igraph::largest_component(g)
  memb <- parsed$membership$cluster[match(
    igraph::V(g)$name,
    as.character(parsed$membership$node)
  )]
  q <- igraph::modularity(g, as.integer(factor(memb)), weights = igraph::E(g)$weight)

  expect_equal(round(q, 3), round(parsed$served_modularity, 3))
  expect_equal(round(parsed$served_modularity, 3), round(payload$served_modularity, 3))
})

test_that("reproducibility_hash is a stable 64-char sha256 over the canonical JSON", {
  payload <- build_synthetic_functional_payload()
  b1 <- analysis_reproducibility_bundle("functional", payload)
  b2 <- analysis_reproducibility_bundle("functional", payload)

  expect_true(grepl("^[0-9a-f]{64}$", b1$reproducibility_hash))
  expect_identical(b1$reproducibility_hash, b2$reproducibility_hash) # deterministic

  # The hash is over the pre-gzip canonical JSON, so it is independent of gzip.
  bundle_obj <- list(
    schema_version = ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION,
    kind = "functional",
    params = payload$params,
    edges = as.data.frame(payload$edges, stringsAsFactors = FALSE),
    membership = as.data.frame(payload$membership, stringsAsFactors = FALSE),
    served_modularity = as.numeric(payload$served_modularity)
  )
  expected_json <- analysis_reproducibility_canonical_json(bundle_obj)
  expect_identical(
    b1$reproducibility_hash,
    digest::digest(expected_json, algo = "sha256", serialize = FALSE)
  )

  # A changed input changes the hash.
  payload2 <- payload
  payload2$served_modularity <- payload$served_modularity + 0.01
  b3 <- analysis_reproducibility_bundle("functional", payload2)
  expect_false(identical(b1$reproducibility_hash, b3$reproducibility_hash))
})

test_that("gzip blob round-trips back to the identical parsed structure", {
  payload <- build_synthetic_functional_payload()
  b <- analysis_reproducibility_bundle("functional", payload)

  parsed <- analysis_reproducibility_decode(b$bundle_gzip_json)
  expect_identical(nrow(parsed$edges), nrow(payload$edges))
  expect_identical(nrow(parsed$membership), nrow(payload$membership))
  expect_setequal(names(parsed$edges), names(payload$edges))
  expect_equal(sort(parsed$membership$cluster), sort(payload$membership$cluster))

  # DBI blob columns come back as a list-of-raw; decode must accept that too.
  parsed_from_list <- analysis_reproducibility_decode(list(b$bundle_gzip_json))
  expect_equal(round(parsed_from_list$served_modularity, 6), round(payload$served_modularity, 6))
})

test_that("phenotype bundle round-trips: recomputed silhouette == served", {
  payload <- build_synthetic_phenotype_payload()
  b <- analysis_reproducibility_bundle("phenotype", payload)

  expect_identical(b$kind, "phenotype")
  parsed <- analysis_reproducibility_decode(b$bundle_gzip_json)

  dim_cols <- grep("^Dim", names(parsed$coords), value = TRUE)
  coord_mat <- as.matrix(parsed$coords[, dim_cols, drop = FALSE])
  memb <- parsed$membership$cluster[match(
    parsed$coords$entity_id,
    as.character(parsed$membership$entity_id)
  )]
  sil <- mean(cluster::silhouette(as.integer(memb), stats::dist(coord_mat))[, "sil_width"])

  expect_equal(round(sil, 3), round(parsed$served_silhouette, 3))
})

test_that("an unsupported bundle kind is rejected", {
  expect_error(
    analysis_reproducibility_bundle("banana", list()),
    "Unsupported reproducibility bundle kind"
  )
})

test_that("decode rejects a non-raw blob", {
  expect_error(
    analysis_reproducibility_decode("not-a-blob"),
    "not a raw gzip blob"
  )
})
