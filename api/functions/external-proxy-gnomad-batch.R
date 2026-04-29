# api/functions/external-proxy-gnomad-batch.R
#### Batched gnomAD GraphQL fallback for HGNC-update pipeline
#### See spec: .planning/superpowers/specs/2026-04-29-gnomad-constraints-x-chr-fallback-design.md

require(httr2)
require(jsonlite)

# Sentinel value stored in cache_static when gnomAD confirmed a symbol has no constraint data.
# We need to distinguish "we asked, gnomAD said no" from "we never asked", and the
# cachem filesystem cache treats NULL and missing identically. The literal string is
# never a valid JSON-object response so it's safe as a tag.
GNOMAD_BATCH_NA_SENTINEL <- "__GNOMAD_NA__"

# Cache key namespace. Bumping the suffix is a clean way to invalidate after a JSON-shape change.
GNOMAD_BATCH_CACHE_PREFIX <- "gnomad_constraint_v1::"

# 19 fields the bulk pipeline emits. Keep this list aligned with
# GNOMAD_TSV_COLUMN_MAP in api/functions/hgnc-enrichment-gnomad.R.
GNOMAD_BATCH_FIELDS <- c(
  "pLI",
  "oe_lof", "oe_lof_lower", "oe_lof_upper",
  "oe_mis", "oe_mis_lower", "oe_mis_upper",
  "oe_syn", "oe_syn_lower", "oe_syn_upper",
  "exp_lof", "obs_lof",
  "exp_mis", "obs_mis",
  "exp_syn", "obs_syn",
  "lof_z", "mis_z", "syn_z"
)

# gnomAD's GraphQL server enforces a query-cost limit of 25 (one cost unit per gene).
# Verified empirically 2026-04-29.
GNOMAD_BATCH_MAX_PER_REQUEST <- 25L

# gnomAD GraphQL endpoint. The ?raw query bypasses the GraphiQL HTML wrapper that
# would otherwise be served when the Accept header does not survive a proxy.
GNOMAD_BATCH_ENDPOINT <- "https://gnomad.broadinstitute.org/api?raw"
