# Unit tests for the snapshot partition-coherence gate (#514).
#
# The gate refuses to publish a clustering snapshot whose SERVED membership and
# VALIDATION describe different partitions — the exact incoherence that reached
# production in #514 (stale memoise membership vs freshly-recomputed validation).
source_api_file("functions/analysis-snapshot-coherence.R", local = FALSE, envir = globalenv())

# minimal membership tibble (mirrors gen_string_clust_obj: integer `cluster`, size >= min)
mk_membership <- function(ids, channel = "experimental_database") {
  t <- tibble::tibble(cluster = as.integer(ids), cluster_size = rep(11L, length(ids)))
  attr(t, "weight_channel") <- channel
  t
}
# minimal validation list (mirrors validate_functional_clusters return shape)
mk_val <- function(ids, channel = "experimental_database") {
  list(
    per_cluster = tibble::tibble(
      cluster_id = as.character(ids),
      jaccard_mean = rep(0.8, length(ids)),
      jaccard_n_resamples = rep(50L, length(ids))
    ),
    partition = list(weight_channel = channel)
  )
}

test_that("coherent membership + validation passes and returns a coherent summary", {
  m <- mk_membership(c(1, 2, 10))
  v <- mk_val(c(1, 2, 10))
  res <- analysis_snapshot_assert_partition_coherent(
    m, v$per_cluster, kind = "functional",
    membership_channel = attr(m, "weight_channel"),
    validation_channel = v$partition$weight_channel
  )
  expect_true(res$coherent)
})

test_that("a visible membership cluster without a validation score is refused (missing score)", {
  m <- mk_membership(c(1, 2, 10))
  v <- mk_val(c(1, 2)) # cluster 10 has no stability row -> incoherent
  expect_error(
    analysis_snapshot_assert_partition_coherent(m, v$per_cluster, kind = "functional"),
    "coheren", ignore.case = TRUE
  )
})

test_that("a validation cluster with no served membership is refused (orphan)", {
  m <- mk_membership(c(1, 2))
  v <- mk_val(c(1, 2, 10))
  expect_error(
    analysis_snapshot_assert_partition_coherent(m, v$per_cluster, kind = "functional"),
    "coheren", ignore.case = TRUE
  )
})

test_that("membership/validation channel disagreement is refused", {
  m <- mk_membership(c(1, 2, 10), channel = "combined_score")
  v <- mk_val(c(1, 2, 10), channel = "experimental_database")
  expect_error(
    analysis_snapshot_assert_partition_coherent(
      m, v$per_cluster, kind = "functional",
      membership_channel = "combined_score", validation_channel = "experimental_database"
    ),
    "channel", ignore.case = TRUE
  )
})

test_that("the escape hatch downgrades a hard failure to a warning", {
  m <- mk_membership(c(1, 2, 10))
  v <- mk_val(c(1, 2))
  withr::local_envvar(ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE = "false")
  expect_warning(
    res <- analysis_snapshot_assert_partition_coherent(m, v$per_cluster, kind = "functional"),
    "coheren", ignore.case = TRUE
  )
  expect_false(res$coherent)
})

test_that("empty membership + empty validation is trivially coherent", {
  m <- mk_membership(integer(0))
  v <- mk_val(integer(0))
  res <- analysis_snapshot_assert_partition_coherent(m, v$per_cluster, kind = "functional")
  expect_true(res$coherent)
})

test_that("join helper gates then left-joins the validation scores and carries channel provenance", {
  m <- mk_membership(c(1, 2, 10))
  v <- mk_val(c(1, 2, 10))
  joined <- analysis_snapshot_join_validated_clusters(m, v, kind = "functional")
  expect_true(all(c("cluster", "jaccard_mean", "jaccard_n_resamples") %in% names(joined)))
  expect_false("cluster_id" %in% names(joined))
  expect_equal(nrow(joined), 3L)
  expect_identical(attr(joined, "membership_weight_channel"), "experimental_database")
})

test_that("join helper raises on an incoherent partition (does not silently mis-join)", {
  m <- mk_membership(c(1, 2, 10))
  v <- mk_val(c(1, 2)) # divergent partitions
  expect_error(analysis_snapshot_join_validated_clusters(m, v, kind = "functional"),
               "coheren", ignore.case = TRUE)
})

# --- content-level (same-partition proof, Codex finding #1) ---

# membership with a per-cluster `identifiers` list-column carrying member ids
mk_membership_with_members <- function(members, channel = "experimental_database", id_col = "STRING_id") {
  ids <- as.integer(names(members))
  ident <- lapply(members, function(v) {
    df <- tibble::tibble(x = as.character(v))
    names(df) <- id_col
    df
  })
  t <- tibble::tibble(cluster = ids, cluster_size = vapply(members, length, integer(1)), identifiers = ident)
  attr(t, "weight_channel") <- channel
  t
}
mk_val_with_members <- function(members, channel = "experimental_database") {
  ids <- names(members)
  list(
    per_cluster = tibble::tibble(
      cluster_id = ids, jaccard_mean = rep(0.8, length(ids)), jaccard_n_resamples = rep(50L, length(ids))
    ),
    reference_members = lapply(members, as.character),
    partition = list(weight_channel = channel)
  )
}

test_that("same cluster-id labels but DIFFERENT member content is refused (same-partition proof)", {
  # ids match, channels match, but cluster 1 holds different members on each side.
  mm <- list("1" = c("A", "B", "C"), "2" = c("D", "E"))
  vm <- list("1" = c("A", "B", "X"), "2" = c("D", "E")) # cluster 1 content differs
  expect_error(
    analysis_snapshot_assert_partition_coherent(
      mk_membership(c(1, 2)), mk_val(c(1, 2))$per_cluster, kind = "functional",
      membership_members = mm, validation_members = vm
    ),
    "content", ignore.case = TRUE
  )
})

test_that("identical member content passes the same-partition proof", {
  same <- list("1" = c("A", "B", "C"), "2" = c("D", "E"))
  res <- analysis_snapshot_assert_partition_coherent(
    mk_membership(c(1, 2)), mk_val(c(1, 2))$per_cluster, kind = "functional",
    membership_members = same, validation_members = same
  )
  expect_true(res$coherent)
})

test_that("join helper enforces member content coherence end to end (functional STRING_id)", {
  members <- list("1" = c("9606.A", "9606.B"), "2" = c("9606.C", "9606.D"))
  m <- mk_membership_with_members(members, id_col = "STRING_id")
  v <- mk_val_with_members(members)
  joined <- analysis_snapshot_join_validated_clusters(m, v, kind = "functional")
  expect_equal(nrow(joined), 2L)

  # now corrupt one cluster's membership content -> must be refused
  bad <- members
  bad[["1"]] <- c("9606.A", "9606.Z")
  mbad <- mk_membership_with_members(bad, id_col = "STRING_id")
  expect_error(analysis_snapshot_join_validated_clusters(mbad, v, kind = "functional"),
               "content", ignore.case = TRUE)
})

# --- #573 H4: reference member sets expressed in the STORED id space ---

test_that("reference_members_store_space maps functional STRING_id -> hgnc_id via served identifiers", {
  membership <- tibble::tibble(
    cluster = c(1L, 2L),
    identifiers = list(
      tibble::tibble(STRING_id = c("9606.A", "9606.B"), hgnc_id = c("HGNC:1", "HGNC:2")),
      tibble::tibble(STRING_id = c("9606.C"), hgnc_id = c("HGNC:3"))
    )
  )
  ref <- list("1" = c("9606.A", "9606.B"), "2" = c("9606.C"))
  out <- analysis_snapshot_reference_members_store_space(ref, membership, "functional")
  expect_setequal(out[["1"]], c("HGNC:1", "HGNC:2"))
  expect_setequal(out[["2"]], "HGNC:3")

  # an UNMAPPED STRING_id is kept verbatim (fail-closed: cannot equal a stored hgnc_id)
  ref2 <- list("1" = c("9606.A", "9606.UNKNOWN"))
  out2 <- analysis_snapshot_reference_members_store_space(ref2, membership, "functional")
  expect_setequal(out2[["1"]], c("HGNC:1", "9606.UNKNOWN"))
})

test_that("reference_members_store_space passes phenotype entity ids through unchanged", {
  ref <- list("1" = c("10", "11"), "2" = c("12"))
  out <- analysis_snapshot_reference_members_store_space(ref, NULL, "phenotype")
  expect_setequal(out[["1"]], c("10", "11"))
  expect_setequal(out[["2"]], "12")
  expect_equal(length(analysis_snapshot_reference_members_store_space(list(), NULL, "phenotype")), 0L)
})

test_that("join attaches the store-space reference attestation for the builder to persist", {
  members <- list("1" = c("9606.A", "9606.B"), "2" = c("9606.C", "9606.D"))
  m <- mk_membership_with_members(members, id_col = "STRING_id")
  v <- mk_val_with_members(members)
  joined <- analysis_snapshot_join_validated_clusters(m, v, kind = "functional")
  attest <- attr(joined, "reference_members_store_space")
  expect_false(is.null(attest))
  expect_setequal(names(attest), c("1", "2"))
})

test_that("reference_members_store_space expands a one-to-many STRING_id to ALL its hgnc_ids (MC1)", {
  # A STRING protein that joins two hgnc records: the served cluster_members hold
  # BOTH, so the mapped reference must hold BOTH (a first-wins dict false-rejects).
  membership <- tibble::tibble(
    cluster = 1L,
    identifiers = list(tibble::tibble(
      STRING_id = c("9606.A", "9606.A", "9606.B"),
      hgnc_id = c("HGNC:1", "HGNC:1b", "HGNC:2")
    ))
  )
  ref <- list("1" = c("9606.A", "9606.B"))
  out <- analysis_snapshot_reference_members_store_space(ref, membership, "functional")
  expect_setequal(out[["1"]], c("HGNC:1", "HGNC:1b", "HGNC:2"))
})
