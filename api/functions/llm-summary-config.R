# functions/llm-summary-config.R
#
# Central version constant for the LLM cluster-summary generation/validation
# layer. This is the code/prompt-version dimension of the summary cache key.
#
# Why this exists (#485): the summary cache is keyed on the per-cluster
# `cluster_hash` (member composition). When a deploy changes the generation
# prompt or the summary/judge logic WITHOUT changing a cluster's membership, the
# hash is unchanged, so the cache-first lookup would otherwise keep serving the
# pre-deploy summary. Binding `prompt_version` into every write AND every lookup
# makes such a code/prompt change invalidate the affected rows (they no longer
# match the current version) so they regenerate on the next refresh.
#
# Bump this string whenever the summary prompt template or the
# generation/validation logic changes in a way that should retire previously
# cached summaries. It mirrors how ANALYSIS_SNAPSHOT_SCHEMA_VERSION lives in
# analysis-snapshot-presets.R.
#
# Sourced FIRST in the LLM block of bootstrap/load_modules.R (and
# bootstrap/setup_workers.R for the async worker daemon) so it is defined before
# the cache repository, service, judge and batch generator that reference it.

LLM_SUMMARY_PROMPT_VERSION <- "1.1"
