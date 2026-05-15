library(testthat)

find_repo_root <- function(start = getwd()) {
  current <- normalizePath(start, mustWork = TRUE)
  repeat {
    candidate <- file.path(current, "docker-compose.yml")
    if (file.exists(candidate)) {
      return(current)
    }
    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("docker-compose.yml not found from ", start, call. = FALSE)
    }
    current <- parent
  }
}

repo_root <- find_repo_root()
compose_path <- file.path(repo_root, "docker-compose.yml")

test_that("async worker has outbound egress for external provider calls", {
  skip_if_not_installed("yaml")

  compose <- yaml::read_yaml(compose_path)

  expect_true(isTRUE(compose$networks$backend$internal))
  expect_true("backend" %in% compose$services$worker$networks)
  expect_true("proxy" %in% compose$services$worker$networks)
})
