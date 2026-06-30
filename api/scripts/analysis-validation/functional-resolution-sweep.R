#!/usr/bin/env Rscript
# api/scripts/analysis-validation/functional-resolution-sweep.R
#
# Operator diagnostic (NOT wired into production, no endpoint, no public surface):
# functional Leiden resolution sweep + algorithm-factor attribution.
#
# For a fixed approved-gene input it reports, per resolution gamma:
#   {n_clusters, weighted_modularity, ari_vs_gamma1}
# (ARI via igraph::compare(method = "adjusted.rand")), then a factorial
# {unweighted, weighted} x {n_iterations 2, converged} x gamma-grid block with
# pairwise ARI so the default gamma is justified on a stability plateau and the
# unweighted/non-converged settings are quantified.
#
# Usage (inside the running API or worker container, which has STRINGdb + the
# full runtime + DB available):
#   docker exec sysndd-api-1 Rscript /app/scripts/analysis-validation/functional-resolution-sweep.R
#
# Writes reports/functional-resolution-sweep-<date>.json + a markdown summary.

setwd("/app")

source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)
source("bootstrap/load_modules.R", local = FALSE)
bootstrap_init_libraries()
bootstrap_load_modules()

env_mode <- Sys.getenv("ENVIRONMENT", "local")
api_config <- if (tolower(env_mode) == "production") {
  "sysndd_db"
} else if (tolower(env_mode) == "development") {
  "sysndd_db_dev"
} else {
  "sysndd_db_local"
}
Sys.setenv(API_CONFIG = api_config)
dw <- config::get(api_config)
if (!is.null(dw$workdir)) {
  setwd(dw$workdir)
}

pool <- bootstrap_create_pool(dw)
on.exit(pool::poolClose(pool), add = TRUE)

report_dir <- file.path("scripts", "analysis-validation", "reports")
if (!dir.exists(report_dir)) dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.Date(), "%Y-%m-%d")

genes <- analysis_snapshot_approved_gene_ids(conn = pool) # builder helper; arg is `conn` (NULL-tolerant)
subgraph_ref <- build_string_subgraph(genes, 400)
weights_ref <- igraph::E(subgraph_ref)$combined_score

# --- 1. Resolution sweep (weighted, converged) ------------------------------
gammas <- c(0.5, 0.7, 1.0, 1.4, 2.0)
ref <- NULL
rows <- list()
for (g in gammas) {
  set.seed(42)
  cl <- igraph::cluster_leiden(
    subgraph_ref,
    objective_function = "modularity",
    weights = weights_ref,
    resolution_parameter = g, beta = 0.01, n_iterations = -1
  )
  if (is.null(ref)) ref <- cl$membership
  rows[[as.character(g)]] <- list(
    gamma = g,
    n_clusters = length(unique(cl$membership)),
    weighted_modularity = igraph::modularity(subgraph_ref, cl$membership, weights = weights_ref),
    ari_vs_gamma1 = igraph::compare(cl$membership, ref, method = "adjusted.rand")
  )
}

# --- 2. Factorial attribution: {unweighted, weighted} x {2 iters, converged} -
leiden_partition <- function(weighted, iters, gamma = 1.0) {
  set.seed(42)
  igraph::cluster_leiden(
    subgraph_ref,
    objective_function = "modularity",
    weights = if (isTRUE(weighted)) weights_ref else NULL,
    resolution_parameter = gamma, beta = 0.01, n_iterations = iters
  )$membership
}

factor_cells <- list()
for (weighted in c(FALSE, TRUE)) {
  for (iters in c(2L, -1L)) {
    key <- sprintf("%s_%s", if (weighted) "weighted" else "unweighted",
                   if (iters == -1L) "converged" else "iter2")
    m <- leiden_partition(weighted, iters)
    factor_cells[[key]] <- list(
      weighted = weighted, n_iterations = iters,
      n_clusters = length(unique(m)),
      membership = m
    )
  }
}
# Pairwise ARI across the factorial cells (production = weighted_converged).
cell_names <- names(factor_cells)
pairwise_ari <- list()
for (i in seq_along(cell_names)) {
  for (j in seq_along(cell_names)) {
    if (j <= i) next
    a <- cell_names[[i]]; b <- cell_names[[j]]
    pairwise_ari[[paste(a, "vs", b)]] <- igraph::compare(
      factor_cells[[a]]$membership, factor_cells[[b]]$membership, method = "adjusted.rand"
    )
  }
}
factor_summary <- lapply(factor_cells, function(c) {
  c$membership <- NULL
  c
})

report <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  api_config = api_config,
  n_genes = length(genes),
  n_nodes = igraph::vcount(subgraph_ref),
  resolution_sweep = unname(rows),
  factorial_attribution = list(cells = factor_summary, pairwise_ari = pairwise_ari)
)

json_path <- file.path(report_dir, sprintf("functional-resolution-sweep-%s.json", stamp))
jsonlite::write_json(report, json_path, auto_unbox = TRUE, pretty = TRUE)

# --- Markdown summary -------------------------------------------------------
md <- c(
  sprintf("# Functional Leiden resolution sweep (%s)", stamp),
  "",
  sprintf("- API config: `%s`  |  genes: %d  |  graph nodes: %d",
          api_config, length(genes), igraph::vcount(subgraph_ref)),
  "",
  "## Resolution sweep (weighted combined_score, n_iterations = -1)",
  "",
  "| gamma | n_clusters | weighted_modularity | ARI vs gamma=1 |",
  "|---|---|---|---|"
)
for (r in rows) {
  md <- c(md, sprintf("| %.2f | %d | %.4f | %.4f |",
                      r$gamma, r$n_clusters, r$weighted_modularity, r$ari_vs_gamma1))
}
md <- c(md, "", "## Factorial attribution (weighted x converged, gamma = 1.0)", "",
        "| cell | n_clusters |", "|---|---|")
for (nm in names(factor_summary)) {
  md <- c(md, sprintf("| %s | %d |", nm, factor_summary[[nm]]$n_clusters))
}
md <- c(md, "", "### Pairwise ARI", "", "| pair | ARI |", "|---|---|")
for (nm in names(pairwise_ari)) {
  md <- c(md, sprintf("| %s | %.4f |", nm, pairwise_ari[[nm]]))
}
md_path <- file.path(report_dir, sprintf("functional-resolution-sweep-%s.md", stamp))
writeLines(md, md_path)

message(sprintf("[functional-resolution-sweep] wrote %s and %s", json_path, md_path))
