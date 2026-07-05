#!/usr/bin/env Rscript
# api/scripts/build-string-expdb.R
#
# Build the compact text-mining-free STRING edge file used by the functional
# clustering pipeline (#510). Reads the full STRING detailed links file, recombines
# ONLY the experimental + database channels with STRING's probabilistic-OR formula
# (dropping text-mining / co-mention, which contaminates functional modularity with
# literature co-study signal), thresholds, and writes a compact
# `protein1 protein2 exp_db_score` gzip file that `string_expdb_subgraph()` reads.
#
# One-time / release data-prep. The detailed input is ~115 MB (~12M rows); the
# output is ~3 MB (~0.5M edges >= 400). Run in the API container/image where the
# STRING data dir and data.table are available:
#
#   docker exec sysndd-api-1 Rscript /app/scripts/build-string-expdb.R
#
# Env:
#   STRING_DETAILED_FILE  input  (default data/9606.protein.links.detailed.v11.5.txt.gz)
#   STRING_EXPDB_EDGES_FILE output (default data/9606.protein.links.expdb.v11.5.min400.txt.gz)
#   STRING_EXPDB_THRESHOLD  min recombined score to keep (default 400)
#   STRING_WEIGHT_CHANNELS  channels to OR-combine (default "experimental,database")

suppressWarnings(suppressMessages({
  # analysis-string-channels.R provides string_recompute_score / string_weight_channels
  src <- Sys.getenv("STRING_CHANNELS_SRC", "functions/analysis-string-channels.R")
  if (!file.exists(src) && file.exists(file.path("/app", src))) src <- file.path("/app", src)
  source(src)
}))

detailed <- Sys.getenv("STRING_DETAILED_FILE", "data/9606.protein.links.detailed.v11.5.txt.gz")
out <- Sys.getenv("STRING_EXPDB_EDGES_FILE", "data/9606.protein.links.expdb.v11.5.min400.txt.gz")
threshold <- as.numeric(Sys.getenv("STRING_EXPDB_THRESHOLD", "400"))
channels <- string_weight_channels()

if (!file.exists(detailed)) {
  stop("STRING detailed file not found: ", detailed,
       "\nDownload it first, e.g.:\n  curl -o ", detailed,
       " https://stringdb-downloads.org/download/protein.links.detailed.v11.5/",
       "9606.protein.links.detailed.v11.5.txt.gz", call. = FALSE)
}

message(sprintf("[string-expdb] reading %s (channels: %s)", detailed, paste(channels, collapse = "+")))
t0 <- Sys.time()
dt <- data.table::fread(cmd = paste("zcat", shQuote(detailed)),
                        select = c("protein1", "protein2", channels))
message(sprintf("[string-expdb] %d edges read in %.1fs", nrow(dt), as.numeric(Sys.time() - t0)))

dt[, exp_db_score := .string_or_combine(lapply(channels, function(cn) dt[[cn]]))]
# STRING lists every undirected pair in both directions; keep the canonical
# `protein1 < protein2` half so the written file is a de-duplicated undirected edge
# list (string_expdb_subgraph also simplify()s at read time, so an older
# both-directions file stays correct).
keep <- dt[exp_db_score >= threshold & protein1 < protein2,
           .(protein1, protein2, exp_db_score = round(exp_db_score))]
message(sprintf("[string-expdb] %d unique undirected edges >= %g retained", nrow(keep), threshold))

data.table::fwrite(keep, file = out, sep = " ", compress = "gzip")
message(sprintf("[string-expdb] wrote %s (%d bytes)", out, file.info(out)$size))
