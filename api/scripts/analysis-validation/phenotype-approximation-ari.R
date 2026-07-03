#!/usr/bin/env Rscript
# api/scripts/analysis-validation/phenotype-approximation-ari.R
#
# Operator diagnostic (NOT wired into production, no endpoint, no public surface):
# quantify the phenotype MCA/HCPC speed approximations.
#
#   1. ARI(partition(ncp = 8) vs partition(ncp = 15))  -- does ncp truncation move
#      the partition? Keep the fast ncp = 8 only if ARI is high (>= ~0.9).
#   2. ARI across >= 5 kk k-means pre-partition seeds   -- is the kk = 50 k-means
#      pre-clustering seed-stable?
#
# Codex note (1c): FactoMineR 2.13 HCPC DISABLES `consol` when `kk != Inf`, so the
# production call's `consol = TRUE` with `kk = 50` is effectively FALSE. This
# diagnostic therefore runs HCPC with `consol = FALSE` (and holds it constant
# across the ARI comparisons) and records the fact; the production inline comment
# is misleading and should be read with this in mind.
#
# Usage:
#   docker exec sysndd-api-1 Rscript /app/scripts/analysis-validation/phenotype-approximation-ari.R
#
# Writes reports/phenotype-approximation-ari-<date>.json + a markdown summary.

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

ARI_KEEP_THRESHOLD <- 0.9

mat <- generate_phenotype_cluster_input()$matrix
stopifnot(is.data.frame(mat), nrow(mat) > 0L)

# Production MCA/HCPC params (quali.sup = 1, quanti.sup = 2:4). consol = FALSE
# because kk != Inf disables consolidation anyway (see header).
hcpc_membership <- function(ncp, kk = 50, seed = 42) {
  set.seed(seed)
  mca <- FactoMineR::MCA(mat, ncp = ncp, quali.sup = 1:1, quanti.sup = 2:4, graph = FALSE)
  hc <- FactoMineR::HCPC(mca, nb.clust = -1, kk = kk, mi = 3, max = 25,
                         consol = FALSE, graph = FALSE)
  as.integer(hc$data.clust$clust)
}

# --- 1. ncp = 8 vs ncp = 15 -------------------------------------------------
m8 <- hcpc_membership(ncp = 8)
m15 <- hcpc_membership(ncp = 15)
ari_ncp <- igraph::compare(m8, m15, method = "adjusted.rand")

# --- 2. kk k-means seed stability (>= 5 seeds) ------------------------------
seeds <- c(42L, 1L, 7L, 13L, 99L, 2024L)
seed_memberships <- lapply(seeds, function(s) hcpc_membership(ncp = 8, kk = 50, seed = s))
kk_pairwise <- list()
for (i in seq_along(seeds)) {
  for (j in seq_along(seeds)) {
    if (j <= i) next
    kk_pairwise[[sprintf("seed%d_vs_seed%d", seeds[i], seeds[j])]] <-
      igraph::compare(seed_memberships[[i]], seed_memberships[[j]], method = "adjusted.rand")
  }
}
kk_min_ari <- if (length(kk_pairwise)) min(unlist(kk_pairwise)) else NA_real_
kk_mean_ari <- if (length(kk_pairwise)) mean(unlist(kk_pairwise)) else NA_real_

ncp_flag <- if (ari_ncp >= ARI_KEEP_THRESHOLD) "keep_ncp8" else "FLAG_review_ncp8"
kk_flag <- if (!is.na(kk_min_ari) && kk_min_ari >= ARI_KEEP_THRESHOLD) "keep_kk50" else "FLAG_review_kk50"

report <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  api_config = api_config,
  n_entities = nrow(mat),
  consol_note = "HCPC consol disabled because kk != Inf (FactoMineR 2.13); diagnostic uses consol = FALSE",
  ari_keep_threshold = ARI_KEEP_THRESHOLD,
  ncp = list(ari_ncp8_vs_ncp15 = ari_ncp, decision = ncp_flag),
  kk = list(seeds = seeds, pairwise_ari = kk_pairwise,
            min_ari = kk_min_ari, mean_ari = kk_mean_ari, decision = kk_flag)
)

json_path <- file.path(report_dir, sprintf("phenotype-approximation-ari-%s.json", stamp))
jsonlite::write_json(report, json_path, auto_unbox = TRUE, pretty = TRUE)

md <- c(
  sprintf("# Phenotype MCA/HCPC approximation ARI (%s)", stamp),
  "",
  sprintf("- API config: `%s`  |  entities: %d", api_config, nrow(mat)),
  "- HCPC `consol` is disabled (kk != Inf) — diagnostic holds `consol = FALSE` constant.",
  "",
  sprintf("## ncp truncation: ARI(ncp=8 vs ncp=15) = %.4f  ->  %s", ari_ncp, ncp_flag),
  "",
  sprintf("## kk k-means seed stability: min ARI = %.4f, mean ARI = %.4f  ->  %s",
          kk_min_ari, kk_mean_ari, kk_flag),
  "",
  "| seed pair | ARI |", "|---|---|"
)
for (nm in names(kk_pairwise)) {
  md <- c(md, sprintf("| %s | %.4f |", nm, kk_pairwise[[nm]]))
}
md_path <- file.path(report_dir, sprintf("phenotype-approximation-ari-%s.md", stamp))
writeLines(md, md_path)

message(sprintf("[phenotype-approximation-ari] wrote %s and %s", json_path, md_path))
