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
# Bump this string ONLY when the summary GENERATION prompt/logic changes in a way
# that makes previously cached summary text wrong and should retire prior rows.
# A change to the JUDGE (validation gate) alone does NOT warrant a bump: a
# more-lenient judge still accepts prior validations, so already-`validated` rows
# stay correct — bumping there would gratuitously blank every served summary
# until a manual regeneration (there is no auto-regeneration on a bare bump; see
# documentation/09-deployment.qmd). It mirrors how ANALYSIS_SNAPSHOT_SCHEMA_VERSION
# lives in analysis-snapshot-presets.R.
#
# Kept at "1.0" through the #485/#488/#490 batch: that work changed the judge and
# the (admin) regenerate path, not the generation prompt, so existing validated
# summaries remain accurate and continue to serve.
#
# Sourced FIRST in the LLM block of bootstrap/load_modules.R (and
# bootstrap/setup_workers.R for the async worker daemon) so it is defined before
# the cache repository, service, judge and batch generator that reference it.

LLM_SUMMARY_PROMPT_VERSION <- "1.0"
