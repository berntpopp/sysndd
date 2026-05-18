nddscore_fixture_path <- function(name = "nddscore_fixture_release.tar.gz") {
  fixture_dir <- file.path(
    get_api_dir(),
    "tests", "testthat", "fixtures", "nddscore"
  )
  archive <- file.path(fixture_dir, name)
  if (!file.exists(archive)) {
    generator <- file.path(fixture_dir, "make-fixture-archive.R")
    withr::with_dir(dirname(get_api_dir()), {
      source(generator, local = TRUE)
    })
  }
  archive
}

nddscore_fixture_good_md5 <- function() {
  digest::digest(file = nddscore_fixture_path(), algo = "md5")
}

nddscore_migration_path <- function() {
  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", "023_add_nddscore_prediction_release.sql"),
    file.path(get_api_dir(), "db", "migrations", "023_add_nddscore_prediction_release.sql")
  )

  for (candidate in candidates) {
    if (file.exists(candidate)) {
      return(candidate)
    }
  }

  candidates[[1]]
}

ensure_nddscore_schema <- function(conn) {
  if (DBI::dbExistsTable(conn, "nddscore_release")) {
    return(invisible(TRUE))
  }
  if (!DBI::dbExistsTable(conn, "user")) {
    DBI::dbExecute(
      conn,
      paste(
        "CREATE TABLE user (",
        "user_id INT NOT NULL PRIMARY KEY,",
        "user_name VARCHAR(255) NULL",
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
        sep = " "
      ),
      immediate = TRUE
    )
  }

  if (!exists("split_sql_statements", mode = "function")) {
    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
  }

  migration_path <- nddscore_migration_path()
  if (!file.exists(migration_path)) {
    stop("NDDScore migration file is missing: ", migration_path)
  }

  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
  for (statement in split_sql_statements(sql)) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  invisible(TRUE)
}

nddscore_clean_tables <- function(conn) {
  ensure_nddscore_schema(conn)
  DBI::dbExecute(conn, "DELETE FROM nddscore_release")
  invisible(TRUE)
}

nddscore_stub_deps <- function(
    fixture = "nddscore_fixture_release.tar.gz",
    archive_md5 = NULL) {
  archive <- nddscore_fixture_path(fixture)
  if (is.null(archive_md5)) {
    archive_md5 <- digest::digest(file = archive, algo = "md5")
  }

  list(
    fetch_metadata = function(record_id) {
      list(
        record_id = as.character(record_id),
        record_url = paste0("https://zenodo.org/records/", record_id),
        version = "2026.05.17",
        version_doi = "10.5281/zenodo.20258027",
        concept_doi = "10.5281/zenodo.20258026",
        archive_name = basename(archive),
        archive_bytes = file.size(archive),
        archive_md5 = archive_md5,
        content_url = paste0(
          "https://zenodo.org/api/records/",
          record_id,
          "/files/",
          basename(archive),
          "/content"
        )
      )
    },
    download = function(url, destfile) {
      file.copy(archive, destfile, overwrite = TRUE)
      invisible(destfile)
    }
  )
}
