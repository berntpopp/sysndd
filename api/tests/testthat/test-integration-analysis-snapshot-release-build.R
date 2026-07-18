# tests/testthat/test-integration-analysis-snapshot-release-build.R
#
# Tests for the analysis-snapshot RELEASE build orchestrator (#573 Slice A /
# Task A4): analysis_snapshot_release_build().
#
# ARCHITECTURE: the orchestrator has three dependency-injection seams so the
# correctness-critical GATES are deterministically unit-testable WITHOUT seeding
# the (very complex) analysis_snapshot_* source tables:
#   - loader(analysis_type, parameter_hash, conn)  (default analysis_snapshot_get_public)
#   - reproducibility_loader(snapshot_id, conn)    (default analysis_snapshot_get_reproducibility)
#   - coherence_assert(snapshot, kind)             (default analysis_snapshot_release_assert_coherent)
# Every gate branch is driven by injecting fakes. PERSISTENCE (analysis_release_*)
# runs against the REAL release tables (ensure_test_release_schema), so
# idempotency/persistence is genuinely exercised even while the snapshot SOURCE is
# faked. The real seam DEFAULTS are exercised by the post-slice dev-stack e2e.
#
# DDL / transaction traps (verified live against RMariaDB, mirrored from the A3
# repository test): analysis_release_insert() opens ONE DBI::dbWithTransaction()
# on its conn, which cannot be nested inside with_test_db_transaction(); and
# ensure_test_release_schema() applies DDL (auto-commits) on its OWN short-lived
# connection first. So the build tests use a single plain connection and clean up
# via DELETE (children cascade), never with_test_db_transaction().

release_build_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(release_build_test_wd), testthat::teardown_env())

source(file.path("core", "errors.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-dependencies.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-coherence.R"), local = TRUE)
source(file.path("functions", "analysis-reproducibility.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-release-repository.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-release-materialize.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-release.R"), local = TRUE)

# --------------------------------------------------------------------------- #
# Fixtures: fake loaded snapshots mirroring analysis_snapshot_get_public()'s
# return shape (status_code + manifest [1-row df] + payload tibbles).
# --------------------------------------------------------------------------- #

SRC_V <- "srcv-2026-07-18"
FUNC_ID <- 101L
PHEN_ID <- 202L
CORR_ID <- 303L
FUNC_HASH <- analysis_release_sha256("functional-payload")
PHEN_HASH <- analysis_release_sha256("phenotype-payload")
CORR_HASH <- analysis_release_sha256("correlation-payload")

DB_RELEASE_VERSION <- "1.0.0"
DB_RELEASE_COMMIT <- "abc1234"

make_manifest <- function(analysis_type, snapshot_id, payload_hash,
                          source_data_version = SRC_V,
                          input_hash = analysis_release_sha256(paste0(analysis_type, "-input")),
                          schema_version = "1.2",
                          source_versions_json = NA_character_,
                          db_release_version = DB_RELEASE_VERSION,
                          db_release_commit = DB_RELEASE_COMMIT) {
  data.frame(
    analysis_type = analysis_type,
    snapshot_id = as.integer(snapshot_id),
    payload_hash = payload_hash,
    input_hash = input_hash,
    source_data_version = source_data_version,
    schema_version = schema_version,
    source_versions_json = source_versions_json,
    db_release_version = db_release_version,
    db_release_commit = db_release_commit,
    stringsAsFactors = FALSE
  )
}

make_cluster_snap <- function(analysis_type, kind, snapshot_id, payload_hash,
                              source_data_version = SRC_V, status_code = "available",
                              stability_ok = TRUE) {
  meta <- if (stability_ok) {
    c('{"jaccard_mean":0.82,"jaccard_n_resamples":50}', '{"jaccard_mean":0.61,"jaccard_n_resamples":50}')
  } else {
    c('{"jaccard_mean":0.82,"jaccard_n_resamples":50}', '{"jaccard_n_resamples":0}')
  }
  clusters <- data.frame(
    cluster_kind = c(kind, kind),
    cluster_id = c("1", "2"),
    cluster_hash = c(analysis_release_sha256(paste0(kind, "-c1")), analysis_release_sha256(paste0(kind, "-c2"))),
    cluster_size = c(3L, 2L),
    label = c("Cluster A", "Cluster B"),
    metadata_json = meta,
    stringsAsFactors = FALSE
  )
  members <- data.frame(
    cluster_kind = kind,
    cluster_id = c("1", "1", "1", "2", "2"),
    member_rank = c(1L, 2L, 3L, 1L, 2L),
    entity_id = c(10L, 11L, 12L, 13L, 14L),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3", "HGNC:4", "HGNC:5"),
    symbol = c("G1", "G2", "G3", "G4", "G5"),
    stringsAsFactors = FALSE
  )
  list(
    status_code = status_code,
    manifest = make_manifest(analysis_type, snapshot_id, payload_hash, source_data_version),
    clusters = clusters,
    cluster_members = members
  )
}

make_corr_snap <- function(func_id = FUNC_ID, func_hash = FUNC_HASH,
                           phen_id = PHEN_ID, phen_hash = PHEN_HASH,
                           source_data_version = SRC_V, status_code = "available") {
  deps_json <- analysis_snapshot_canonical_json(list(dependencies = list(
    functional_clusters = list(snapshot_id = func_id, payload_hash = func_hash),
    phenotype_clusters = list(snapshot_id = phen_id, payload_hash = phen_hash)
  )))
  correlations <- data.frame(
    row_rank = 1:3,
    correlation_kind = c("pc_fc", "pc_fc", "pc_fc"),
    x_key = c("fc_1", "fc_1", "pc_1"),
    y_key = c("fc_1", "pc_1", "pc_1"),
    value = c(1.0, 0.21, 1.0),
    abs_value = c(1.0, 0.21, 1.0),
    metadata_json = NA_character_,
    stringsAsFactors = FALSE
  )
  list(
    status_code = status_code,
    manifest = make_manifest("phenotype_functional_correlations", CORR_ID, CORR_HASH,
      source_data_version,
      source_versions_json = deps_json
    ),
    correlations = correlations
  )
}

make_repro_bundle <- function(kind) {
  payload <- if (identical(kind, "functional")) {
    list(
      edges = data.frame(
        source = c("1", "2"), target = c("2", "3"),
        combined_score = c(0.987654321098765, 0.6543210987654321),
        stringsAsFactors = FALSE
      ),
      membership = data.frame(node = c("1", "2", "3"), cluster = c(1L, 1L, 2L), stringsAsFactors = FALSE),
      served_modularity = 0.123456789012345,
      params = list(seed = 42L, weight_channel = "experimental_database")
    )
  } else {
    list(
      coords = data.frame(
        entity_id = c("10", "11"), Dim.1 = c(0.111111111, 0.222222222),
        Dim.2 = c(0.333333333, 0.444444444), stringsAsFactors = FALSE
      ),
      membership = data.frame(entity_id = c("10", "11"), cluster = c(1L, 2L), stringsAsFactors = FALSE),
      served_silhouette = 0.234567890123,
      params = list(seed = 42L)
    )
  }
  analysis_reproducibility_bundle(kind, payload)
}

FUNC_BUNDLE <- make_repro_bundle("functional")
PHEN_BUNDLE <- make_repro_bundle("phenotype")

# reproducibility_loader fake returning the real bundle row-shape for cluster ids.
present_repro_loader <- function(snapshot_id, conn = NULL) {
  sid <- as.integer(snapshot_id)
  b <- if (identical(sid, FUNC_ID)) FUNC_BUNDLE else if (identical(sid, PHEN_ID)) PHEN_BUNDLE else NULL
  if (is.null(b)) {
    return(NULL)
  }
  row <- data.frame(
    kind = b$kind, reproducibility_hash = b$reproducibility_hash,
    byte_size = b$byte_size, stringsAsFactors = FALSE
  )
  row$bundle_gzip_json <- list(b$bundle_gzip_json) # DBI blob column shape: list-of-raw
  row
}

pass_coherence <- function(snapshot, kind) invisible(TRUE)

# Base loader returning a coherent, available snapshot for every default layer.
make_loader <- function(overrides = list()) {
  base <- list(
    functional_clusters = make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH),
    phenotype_clusters = make_cluster_snap("phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH),
    phenotype_functional_correlations = make_corr_snap()
  )
  snaps <- utils::modifyList(base, overrides)
  function(analysis_type, parameter_hash, conn = NULL) snaps[[analysis_type]]
}

# A functional cluster snapshot whose manifest validation_json carries the served
# membership channel + the validation channel (the exp+db-vs-text-mining #514 case).
make_functional_snap_with_channels <- function(membership_channel, validation_channel) {
  snap <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
  snap$manifest$validation_json <- analysis_snapshot_canonical_json(list(
    weight_channel = validation_channel,
    membership_weight_channel = membership_channel
  ))
  snap
}

# A functional cluster snapshot whose validation_json carries the H4 reference
# member-set attestation (in the stored hgnc_id space) + matching channels.
make_functional_snap_with_reference <- function(reference_members) {
  snap <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
  snap$manifest$validation_json <- analysis_snapshot_canonical_json(list(
    weight_channel = "experimental_database",
    membership_weight_channel = "experimental_database",
    reference_members = reference_members
  ))
  snap
}

# A STATEFUL loader: returns the original snapshot on the first read of each
# preset, then a DIFFERENT {snapshot_id, payload_hash} for `changed_type` on the
# pre-insert re-read — simulating a concurrent axis refresh mid-build. Proves the
# pre-insert re-read is a FRESH DB read, not a tautological re-check of `loaded`.
make_stateful_loader <- function(changed_type = "functional_clusters") {
  counts <- new.env(parent = emptyenv())
  base <- make_loader()
  function(analysis_type, parameter_hash, conn = NULL) {
    n <- (counts[[analysis_type]] %||% 0L) + 1L
    counts[[analysis_type]] <- n
    snap <- base(analysis_type, parameter_hash, conn)
    if (identical(analysis_type, changed_type) && n >= 2L) {
      snap$manifest <- make_manifest(analysis_type, 999L, analysis_release_sha256("refreshed-payload"))
    }
    snap
  }
}

# --------------------------------------------------------------------------- #
# Gate tests (no DB: they fail before any persistence; conn = NULL).
# --------------------------------------------------------------------------- #

test_that("build refuses when any layer snapshot is not available", {
  loader <- make_loader(list(
    phenotype_clusters = make_cluster_snap(
      "phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH,
      status_code = "snapshot_stale"
    )
  ))
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE,
      loader = loader, reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence
    ),
    class = "release_snapshot_not_available"
  )
})

test_that("build refuses an available-but-incoherent snapshot (hard coherence re-check)", {
  throwing_coherence <- function(snapshot, kind) stop("planted incoherence")
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE,
      loader = make_loader(), reproducibility_loader = present_repro_loader,
      coherence_assert = throwing_coherence
    ),
    class = "release_source_incoherent"
  )
})

test_that("build refuses when a cluster layer's reproducibility bundle is missing", {
  missing_repro_loader <- function(snapshot_id, conn = NULL) {
    if (identical(as.integer(snapshot_id), FUNC_ID)) {
      return(NULL)
    }
    present_repro_loader(snapshot_id, conn)
  }
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE,
      loader = make_loader(), reproducibility_loader = missing_repro_loader,
      coherence_assert = pass_coherence
    ),
    class = "release_reproducibility_missing"
  )
})

test_that("build refuses layers that do not share one source_data_version", {
  loader <- make_loader(list(
    phenotype_clusters = make_cluster_snap(
      "phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH,
      source_data_version = "srcv-DIFFERENT"
    )
  ))
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE,
      loader = loader, reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence
    ),
    class = "release_source_version_mismatch"
  )
})

test_that("build refuses a correlation snapshot whose dependency lineage is stale", {
  # Correlation manifest pins a functional snapshot_id that no longer matches.
  loader <- make_loader(list(
    phenotype_functional_correlations = make_corr_snap(func_id = 999L)
  ))
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE,
      loader = loader, reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence
    ),
    class = "release_dependency_lineage_mismatch"
  )
})

test_that("build rejects an unknown requested layer (selection, not redefinition) with 400", {
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE, layers = list(list(analysis_type = "not_a_layer")),
      loader = make_loader(), reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence
    ),
    class = "error_400"
  )
})

test_that("build rejects a reproducibility bundle whose bytes do not hash to reproducibility_hash (H2)", {
  # The stored reproducibility_hash is present but LIES about the bytes (corrupt/restored bundle).
  corrupt_repro_loader <- function(snapshot_id, conn = NULL) {
    row <- present_repro_loader(snapshot_id, conn)
    if (is.null(row)) {
      return(NULL)
    }
    row$reproducibility_hash <- analysis_release_sha256("this-hash-does-not-match-the-bytes")
    row
  }
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE,
      loader = make_loader(), reproducibility_loader = corrupt_repro_loader,
      coherence_assert = pass_coherence
    ),
    class = "release_reproducibility_missing"
  )
})

test_that("build refuses to proceed unlocked when the advisory lock cannot be acquired (H3a)", {
  # Inject a lock seam that reports acquisition FAILED (a source preset is mid-refresh).
  failing_lock <- function(conn, lock_names) list(ok = FALSE, acquired = character(0), skipped = FALSE)
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE,
      loader = make_loader(), reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence, lock_acquire = failing_lock
    ),
    class = "release_lock_unavailable"
  )
})

test_that("build refuses a functional snapshot whose served channel != validation channel", {
  # Real coherence default reads validation_json; membership (combined_score) was
  # clustered on a different STRING channel than the validation scored (exp+db).
  loader <- make_loader(list(
    functional_clusters = make_functional_snap_with_channels(
      membership_channel = "combined_score", validation_channel = "experimental_database"
    )
  ))
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE,
      loader = loader, reproducibility_loader = present_repro_loader,
      coherence_assert = analysis_snapshot_release_assert_coherent # the REAL default
    ),
    class = "release_source_incoherent"
  )
})

# --------------------------------------------------------------------------- #
# Real default coherence seam: pass when internally consistent, throw
# release_source_incoherent when a visible cluster lacks a stability score.
# --------------------------------------------------------------------------- #

test_that("analysis_snapshot_release_assert_coherent gates stored-snapshot integrity", {
  ok <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
  expect_invisible(analysis_snapshot_release_assert_coherent(ok, "functional"))

  incoherent <- make_cluster_snap(
    "functional_clusters", "functional", FUNC_ID, FUNC_HASH,
    stability_ok = FALSE
  )
  expect_error(
    analysis_snapshot_release_assert_coherent(incoherent, "functional"),
    class = "release_source_incoherent"
  )
})

test_that("analysis_snapshot_release_assert_coherent runs the H4 member-set proof when attested", {
  # served functional cluster_members: cluster 1 = {HGNC:1,2,3}, cluster 2 = {HGNC:4,5}.
  coherent_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:3"), "2" = c("HGNC:4", "HGNC:5"))
  incoherent_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:99"), "2" = c("HGNC:4", "HGNC:5"))

  # (b) coherent attestation -> passes, no member-set warning.
  expect_invisible(
    analysis_snapshot_release_assert_coherent(make_functional_snap_with_reference(coherent_ref), "functional")
  )

  # (a) attested snapshot whose served members differ in CONTENT (same cluster-ids)
  #     -> refuse, EVEN with the build-time coherence env downgraded to false.
  withr::with_envvar(list(ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE = "false"), {
    expect_error(
      analysis_snapshot_release_assert_coherent(make_functional_snap_with_reference(incoherent_ref), "functional"),
      class = "release_source_incoherent"
    )
  })

  # (c) legacy snapshot WITHOUT the attestation -> degrades + warns (never refuses).
  legacy <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
  expect_warning(
    expect_invisible(analysis_snapshot_release_assert_coherent(legacy, "functional")),
    "member-set verification is unavailable"
  )
})

test_that("a PARTIAL/incomplete reference attestation is treated as incoherent, not degraded (MC2)", {
  # served cluster_members have clusters 1 AND 2; the attestation omits cluster 2.
  # It must NOT slip through the intersection-only proof as "legacy-absent" — a
  # present-but-partial attestation is INCOHERENT (release_source_incoherent).
  partial_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:3")) # missing served cluster "2"
  snap <- make_functional_snap_with_reference(partial_ref)
  # If it were mis-treated as legacy-absent it would degrade + PASS; expect_error
  # proves it hard-fails instead.
  expect_error(
    analysis_snapshot_release_assert_coherent(snap, "functional"),
    class = "release_source_incoherent"
  )
})

test_that("build refuses an attested snapshot whose member set differs from the reference (H4)", {
  loader <- make_loader(list(
    functional_clusters = make_functional_snap_with_reference(
      list("1" = c("HGNC:1", "HGNC:2", "HGNC:99"), "2" = c("HGNC:4", "HGNC:5"))
    )
  ))
  withr::with_envvar(list(ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE = "false"), {
    expect_error(
      analysis_snapshot_release_build(
        conn = NULL, publish = TRUE,
        loader = loader, reproducibility_loader = present_repro_loader,
        coherence_assert = analysis_snapshot_release_assert_coherent # REAL default
      ),
      class = "release_source_incoherent"
    )
  })
})

test_that("build rejects layers with conflicting db_release provenance (M2)", {
  phen <- make_cluster_snap("phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH)
  phen$manifest$db_release_version <- "9.9.9" # conflicts with functional's 1.0.0
  loader <- make_loader(list(phenotype_clusters = phen))
  expect_error(
    analysis_snapshot_release_build(
      conn = NULL, publish = TRUE,
      loader = loader, reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence
    ),
    class = "release_source_version_mismatch"
  )
})

test_that("analysis_snapshot_release_assert_coherent enforces the functional channel match", {
  # Both channels present + equal -> passes; present + differ -> throws; absent -> skip.
  matched <- make_functional_snap_with_channels("experimental_database", "experimental_database")
  expect_invisible(analysis_snapshot_release_assert_coherent(matched, "functional"))

  mismatched <- make_functional_snap_with_channels("combined_score", "experimental_database")
  expect_error(
    analysis_snapshot_release_assert_coherent(mismatched, "functional"),
    class = "release_source_incoherent"
  )

  # No validation_json -> channel comparison skipped (older snapshots still pass).
  no_channels <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
  expect_invisible(analysis_snapshot_release_assert_coherent(no_channels, "functional"))
})

# --------------------------------------------------------------------------- #
# Success + idempotency (real release persistence).
# --------------------------------------------------------------------------- #

with_release_build_db <- function(code) {
  skip_if_no_test_db()

  schema_conn <- get_test_db_connection()
  ensure_test_release_schema(schema_conn)
  DBI::dbDisconnect(schema_conn)

  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))
  DBI::dbExecute(conn, "DELETE FROM analysis_snapshot_release")
  withr::defer(DBI::dbExecute(conn, "DELETE FROM analysis_snapshot_release"))

  code(conn)
}

test_that("build materializes a content-addressed release; repro hash + payload lineage anchor hold", {
  with_release_build_db(function(conn) {
    result <- analysis_snapshot_release_build(
      conn = conn, publish = TRUE, title = "SysNDD analysis snapshot release",
      scope_statement = "Curated derived cluster analysis.",
      loader = make_loader(), reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence
    )
    expect_true(result$created)
    release_id <- result$release$release_id
    expect_match(release_id, "^asr_[0-9a-f]{16}$")
    expect_equal(result$release$status, "published")

    # reproducibility.json hashes EXACTLY to the stored reproducibility_hash
    # (materialized from the raw pre-gzip bytes, not a parse round-trip).
    rf <- analysis_release_get_file(
      release_id, "functional_clusters/reproducibility.json",
      include_draft = TRUE, conn = conn
    )
    expect_false(is.null(rf))
    expect_identical(rf$content_sha256, FUNC_BUNDLE$reproducibility_hash)

    # manifest per-layer payload_hash is the cross-checkable LINEAGE ANCHOR
    # (== the source snapshot's payload_hash), NOT the payload.json file hash.
    manifest_file <- analysis_release_get_file(release_id, "manifest.json", include_draft = TRUE, conn = conn)
    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
    fc <- Filter(function(l) identical(l$analysis_type, "functional_clusters"), manifest$layers)[[1]]
    expect_identical(fc$payload_hash, FUNC_HASH)
    expect_identical(fc$reproducibility_hash, FUNC_BUNDLE$reproducibility_hash)

    payload_file <- analysis_release_get_file(
      release_id, "functional_clusters/payload.json",
      include_draft = TRUE, conn = conn
    )
    expect_false(is.null(payload_file))
    # the file's OWN hash is not the lineage payload_hash:
    expect_false(identical(payload_file$content_sha256, fc$payload_hash))

    # the correlation layer carries dependency lineage but no reproducibility file:
    corr <- Filter(function(l) identical(l$analysis_type, "phenotype_functional_correlations"), manifest$layers)[[1]]
    expect_false(is.null(corr$dependencies))
    expect_null(analysis_release_get_file(
      release_id, "phenotype_functional_correlations/reproducibility.json",
      include_draft = TRUE, conn = conn
    ))

    # the whole-archive bundle is retrievable and checksummed:
    bundle <- analysis_release_get_bundle(release_id, include_draft = TRUE, conn = conn)
    expect_false(is.null(bundle))
    expect_equal(bundle$sha256, result$release$bundle_sha256)
  })
})

test_that("build is idempotent by content: same sources -> same release_id, no duplicate row", {
  with_release_build_db(function(conn) {
    args <- list(
      conn = conn, publish = TRUE,
      loader = make_loader(), reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence
    )
    r1 <- do.call(analysis_snapshot_release_build, args)
    expect_true(r1$created)
    expect_match(r1$release$release_id, "^asr_[0-9a-f]{16}$")

    r2 <- do.call(analysis_snapshot_release_build, args)
    expect_false(r2$created)
    expect_identical(r1$release$release_id, r2$release$release_id)

    published <- analysis_release_list(status = "published", conn = conn)
    expect_identical(1L, length(published))
  })
})

test_that("pre-insert re-read catches a source snapshot refreshed mid-build (fresh, not tautological)", {
  with_release_build_db(function(conn) {
    # The stateful loader returns snapshot_id 101 on the first functional read but
    # snapshot_id 999 on the pre-insert re-read: if the re-read were tautological
    # (re-checking the cached `loaded`) this would build; a FRESH read must catch it.
    expect_error(
      analysis_snapshot_release_build(
        conn = conn, publish = TRUE,
        loader = make_stateful_loader("functional_clusters"),
        reproducibility_loader = present_repro_loader,
        coherence_assert = pass_coherence
      ),
      class = "release_dependency_lineage_mismatch"
    )
    # nothing was persisted (the mismatch fired before insert):
    expect_identical(0L, length(analysis_release_list(status = "published", conn = conn)))
  })
})

test_that("build head + manifest carry the DB release provenance from the source snapshots (M1)", {
  with_release_build_db(function(conn) {
    result <- analysis_snapshot_release_build(
      conn = conn, publish = TRUE,
      loader = make_loader(), reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence
    )
    expect_equal(result$release$db_release_version, DB_RELEASE_VERSION)
    expect_equal(result$release$db_release_commit, DB_RELEASE_COMMIT)

    manifest_file <- analysis_release_get_file(result$release$release_id, "manifest.json", include_draft = TRUE, conn = conn)
    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
    expect_equal(manifest$source$db_release$version, DB_RELEASE_VERSION)
    expect_equal(manifest$source$db_release$commit, DB_RELEASE_COMMIT)
  })
})

test_that("insert duplicate-key race resolves to idempotent created=FALSE, no double insert (H3b)", {
  with_release_build_db(function(conn) {
    # The inserter simulates the concurrent WINNER: it stores the identical
    # release, then this build's own insert loses the PK race (dup-key error).
    dup_inserter <- function(head, members, files, conn) {
      analysis_release_insert(head, members, files, conn)
      stop("Duplicate entry 'asr_xxxx' for key 'PRIMARY'")
    }
    result <- analysis_snapshot_release_build(
      conn = conn, publish = TRUE,
      loader = make_loader(), reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence, inserter = dup_inserter
    )
    expect_false(result$created)
    expect_match(result$release$release_id, "^asr_[0-9a-f]{16}$")
    # exactly one row total -- the release was NOT double-inserted:
    expect_identical(1L, length(analysis_release_list(status = NULL, conn = conn)))
  })
})

test_that("build with publish = FALSE leaves a draft (not visible as published)", {
  with_release_build_db(function(conn) {
    result <- analysis_snapshot_release_build(
      conn = conn, publish = FALSE,
      loader = make_loader(), reproducibility_loader = present_repro_loader,
      coherence_assert = pass_coherence
    )
    expect_true(result$created)
    expect_equal(result$release$status, "draft")
    expect_identical(0L, length(analysis_release_list(status = "published", conn = conn)))
  })
})
