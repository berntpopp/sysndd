# tests/testthat/test-unit-external-fetcher-allowlist.R
# Pure test (no DB / no network) — runs on host.
#
# #344 bulkhead boundary guard: `/api/external/*` is Traefik-routed to the
# dedicated `api-enrichment` process pool so a slow upstream cannot block cheap
# routes. That guarantee holds only if the public request-path files that invoke
# an external fetcher are a KNOWN allowlist. This test fails if a new endpoint
# file starts calling an external fetcher without being routed to the enrichment
# lane (or added, with justification, to the allowlist below).

test_that("only allowlisted endpoint files invoke external fetchers on the request path", {
  edir <- file.path(get_api_dir(), "endpoints")
  # Files legitimately allowed to call external fetchers from a request handler:
  allowlist <- c(
    "external_endpoints.R", # THE enrichment-lane surface (/api/external/*)
    "entity_endpoints.R",   # Curator-gated POST /entity/create -> GeneReviews
                            # (write path, low-frequency, budget-bounded; the
                            # fetcher lives in a service, so this is a documented
                            # defensive entry rather than a direct pattern match).
    "genereviews_endpoints.R" # Curator-gated /api/genereviews availability +
                              # include_live coverage. Live NCBI lookups are
                              # bounded by external_proxy_budget("genereviews")
                              # and cached (memoise_external_success_only). Same
                              # accepted-residual class the spec (#344 §6) assigns
                              # to the entity-create GeneReviews call: auth-gated,
                              # low-frequency, budget-bounded -> stays on the core
                              # lane rather than being routed. Revisit only if it
                              # ever shows in [request-timing] as a core offender.
  )
  pattern <- "external_proxy_[a-z]|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)"
  offenders <- character()
  for (path in list.files(edir, pattern = "_endpoints\\.R$", full.names = TRUE)) {
    fname <- basename(path)
    if (fname %in% allowlist) next
    src <- readLines(path, warn = FALSE)
    src <- src[!grepl("^\\s*#", src)]
    hits <- grep(pattern, src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(fname, ": ", trimws(hits)))
  }
  expect_identical(
    offenders, character(),
    info = paste(
      "New external-fetcher caller outside the enrichment-lane allowlist —",
      "route it under /api/external or justify + add to the allowlist:",
      paste(offenders, collapse = " | ")
    )
  )
})

test_that("the enrichment-lane surface actually calls external fetchers (guard is live)", {
  # Sanity: if this fails, the pattern drifted and the guard above is inert.
  path <- file.path(get_api_dir(), "endpoints", "external_endpoints.R")
  src <- readLines(path, warn = FALSE)
  pattern <- "external_proxy_[a-z]|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd)"
  expect_true(any(grepl(pattern, src)))
})
