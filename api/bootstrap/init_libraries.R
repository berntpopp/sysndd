## -------------------------------------------------------------------##
# api/bootstrap/init_libraries.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Attaches every library the Plumber runtime needs on its search
# path. Kept in one place so the top-level composer stays thin.
#
# The ordering mirrors the pre-refactor script. Tidyverse is loaded
# LAST so it wins over packages that mask dplyr::select (STRINGdb,
# biomaRt → AnnotationDbi). For the mirai worker side the same
# ordering is enforced in api/bootstrap/setup_workers.R.
## -------------------------------------------------------------------##

#' Attach every library the Plumber runtime needs.
#'
#' Also loads the `.env` file if present, so environment variables
#' (MYSQL_*, CACHE_VERSION, …) are available before the rest of
#' the bootstrap starts. This must run BEFORE any code that reads
#' `Sys.getenv()`.
#'
#' @param lane Optional runtime lane string ("mcp", "api", "enrichment", "worker").
#'   Defaults to SYSNDD_RUNTIME or API_LANE env vars.
#' @return invisible(TRUE) — called for side effects only.
#' @export
bootstrap_init_libraries <- function(lane = NULL) {
  if (file.exists(".env")) {
    dotenv::load_dot_env(file = ".env")
  }

  if (is.null(lane) || !nzchar(lane)) {
    lane <- Sys.getenv("SYSNDD_RUNTIME", Sys.getenv("API_LANE", "api"))
  }

  suppressPackageStartupMessages({
    library(dotenv)
    library(logger)
    library(jsonlite)
    library(DBI)
    library(RMariaDB)
    library(pool)
    library(rlang)

    # MCP lane only needs DB, pool, logging, jsonlite, and rlang
    if (identical(lane, "mcp")) {
      return(invisible(TRUE))
    }

    library(plumber)
    library(tictoc)
    library(fs)
    library(config)

    # Order matters: STRINGdb / biomaRt first, tidyverse last
    library(STRINGdb)
    library(biomaRt)
    library(tidyverse)
    library(stringr)
    library(jose)
    library(stringdist)
    library(writexl)
    library(xml2)
    library(rvest)
    library(lubridate)
    library(memoise)
    library(coop)
    library(reshape2)
    library(blastula)
    library(FactoMineR)
    library(vctrs)
    library(httr)
    library(httr2)
    library(ontologyIndex)
    library(httpproblems)
    library(mirai)
    library(promises)
    library(uuid)
  })

  options_plumber(trailingSlash = TRUE)

  invisible(TRUE)
}
