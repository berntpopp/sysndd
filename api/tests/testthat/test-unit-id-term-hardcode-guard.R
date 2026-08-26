# The ID-severity term list must have exactly ONE definition (#630).
#
# It previously existed as three hardcoded copies (the served snapshot path, the
# interactive job submission service, and the durable job payload). Three copies
# of a clinical definition is three chances for them to drift apart silently,
# which is the same class of defect as the model-generated syndromicity this
# change removes.

test_that("no file outside the registry hardcodes the ID severity term list", {
  root <- get_api_dir()
  dirs <- file.path(root, c("functions", "services", "endpoints"))
  files <- list.files(dirs, pattern = "[.]R$", full.names = TRUE, recursive = TRUE)
  files <- files[basename(files) != "syndromicity-registry.R"]

  offenders <- Filter(function(f) {
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    # Two of the six severity grades co-located is the signature of a copy;
    # a single mention (e.g. in a comment or a phenotype example) is not.
    grepl("HP:0001249", txt, fixed = TRUE) && grepl("HP:0010864", txt, fixed = TRUE)
  }, files)

  expect_equal(
    basename(offenders), character(0),
    info = paste(
      "These files must call syndromicity_id_severity_terms() instead:",
      paste(basename(offenders), collapse = ", ")
    )
  )
})

test_that("the retired phenotype_non_id_count is gone from the analysis paths", {
  root <- get_api_dir()
  files <- c(
    file.path(root, "functions/analysis-phenotype-functions.R"),
    file.path(root, "services/job-phenotype-submission-service.R"),
    file.path(root, "functions/async-job-handlers.R")
  )
  for (f in files) {
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_false(
      grepl("phenotype_non_id_count", txt, fixed = TRUE),
      info = paste(basename(f), "still computes the retired flat non-ID count")
    )
  }
})
