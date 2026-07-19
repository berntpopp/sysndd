test_that("missingness_sensitivity round-trips through validation_json as a keyed object; validation_hash tracks it, payload_hash does not", {
  validation <- list(
    algorithm = "mca_hcpc",
    missingness_sensitivity = list(
      status = "ok",
      adjusted_rand_index = 0.82,
      per_cluster_max_jaccard = list("1" = 0.9, "2" = 0.7),
      silhouette_served_partition = 0.31
    )
  )
  json <- jsonlite::toJSON(validation, auto_unbox = TRUE, digits = NA, null = "null")
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  ms <- parsed$missingness_sensitivity
  expect_equal(ms$status, "ok")
  expect_equal(ms$adjusted_rand_index, 0.82)
  # per_cluster_max_jaccard MUST serialize as a keyed JSON object, not an array.
  expect_true(is.list(ms$per_cluster_max_jaccard))
  expect_named(ms$per_cluster_max_jaccard, c("1", "2"))

  # payload_hash is computed on a payload that EXCLUDES partition_validation, so a change in
  # the missingness block cannot move it; validation_hash (a hash of validation_json) does.
  base_validation <- validation
  changed <- validation
  changed$missingness_sensitivity$adjusted_rand_index <- 0.11
  vhash <- function(v) digest::digest(jsonlite::toJSON(v, auto_unbox = TRUE, digits = NA), algo = "sha256")
  expect_false(identical(vhash(base_validation), vhash(changed)))
})
