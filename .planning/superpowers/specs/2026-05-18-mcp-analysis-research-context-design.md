# SysNDD MCP Analysis Research Context Design

## Problem

The SysNDD read-only MCP sidecar currently exposes approved public gene,
entity, phenotype, publication, and capability tools. It does not yet expose
the analysis surfaces that researchers use in the web application:

- Curation comparison table and source overlap context.
- Phenotype correlations and phenotype clusters.
- Gene network and functional cluster context.
- Phenotype-functional cluster correlations.
- NDDScore model-derived predictions.
- Gene-level research context that combines these views for hypothesis
  generation.

The target user flow is an LLM client asking questions such as:

- "For HGNC:61 / ABCD1, what curated SysNDD evidence exists, what model-derived
  NDDScore signals exist, and which analysis clusters or comparison sources
  place the gene in context?"
- "Which phenotype clusters or gene network neighborhoods suggest follow-up
  hypotheses for this gene?"
- "Which observations are curated SysNDD evidence, which are derived analyses,
  which are ML predictions, and which are LLM-generated summaries?"

The MCP extension must support research and hypothesis generation without
weakening the existing sidecar contract: read-only, public data only, no raw
SQL/R execution, no write tools, no admin/review/job/user/log data, no Gemini or
other LLM generation, and no live external-provider calls from MCP.

## Approved Scope

Implement scope B from the brainstorming pass:

1. `get_sysndd_analysis_catalog`
2. `get_gene_research_context`
3. `get_nddscore_context`
4. `get_curation_comparison_context`
5. `get_phenotype_analysis_context`
6. `get_gene_network_context`
7. Cache-only LLM summary fields where useful

Hard LLM boundary:

- MCP may read cached LLM outputs only.
- MCP must never expose an LLM query or prompt endpoint.
- MCP must never trigger Gemini or any other LLM generation.
- If a cached summary is missing, MCP returns `summary_available = false`.
- Admin-only LLM workflows remain outside MCP.
- The default cache policy is current and validated summaries only.

External gene data boundary:

- This design may expose existing gene identifiers and external reference IDs
  already stored in SysNDD gene rows.
- This design must not call live external proxy routes such as gnomAD, ClinVar,
  UniProt, AlphaFold, Ensembl, MGI, or RGD.
- Rich external per-gene annotations require a separately approved cached
  snapshot design.

Schema version:

- This extension bumps `MCP_SCHEMA_VERSION` from `1.1` to `1.2` because it adds
  new analysis tool families and a data-class provenance contract.
- Existing v1.1 tools keep their field meanings and remain backward-compatible;
  the version bump signals added capabilities, not a breaking shape change.

## Evidence Reviewed

Current MCP implementation:

- `api/start_sysndd_mcp.R` runs a dedicated sidecar and explicitly avoids
  Plumber endpoint mounting, migrations, workers, Gemini, and external
  providers.
- `api/services/mcp-tools.R` registers 12 tools, patches `mcptools` metadata,
  exposes static resources, serializes tool-visible application errors, and
  advertises read-only annotations.
- `api/services/mcp-service.R` defines `MCP_SCHEMA_VERSION = "1.1"`, payload
  modes, batch caps, publication citation semantics, public-data shaping, and
  the current `get_sysndd_capabilities` guide.
- `api/functions/mcp-repository.R` reads active public entities from
  `ndd_entity_view` and review-derived data only from primary approved reviews.

Analysis and model surfaces:

- `api/endpoints/comparisons_endpoints.R` exposes comparison options, upset,
  similarity, browse, and metadata over `ndd_database_comparison_view` and
  `comparisons_metadata`.
- `api/endpoints/analysis_endpoints.R` exposes functional clustering,
  phenotype clustering, phenotype-functional cluster correlation, network
  edges, and LLM cluster summaries.
- `api/endpoints/phenotype_endpoints.R` exposes phenotype correlation and
  phenotype count views.
- `api/functions/nddscore-repository.R` provides read-only repository helpers
  over active-release NDDScore views.
- `api/endpoints/nddscore_endpoints.R` already labels NDDScore as
  model-derived/read-only and states that curated SysNDD evidence is never
  reclassified.
- `api/functions/llm-cache-repository.R` can read current cached LLM summaries.
  The public analysis summary endpoints are not suitable for MCP because they
  generate on cache miss through `llm-service.R`.

MCP and LLM research guidance:

- MCP tools are model-controlled and should have explicit input schemas,
  predictable structured output, tool-visible errors, and clear annotations:
  https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- MCP resources are application-controlled contextual material, suitable for
  schema and tool-guide documentation rather than exploratory fanout:
  https://modelcontextprotocol.io/specification/2025-11-25/server/resources
- MCP security guidance treats tool descriptions and annotations as hints, not
  security boundaries; servers must validate inputs, keep least privilege, and
  prevent data exfiltration and prompt/tool poisoning:
  https://modelcontextprotocol.io/specification/2025-06-18/basic/security_best_practices
- Google's current Gemini model documentation says Gemini 3 Pro Preview and
  Gemini 3 Flash Preview shut down on March 9, 2026, which means existing LLM
  generation defaults should be updated separately from this MCP work:
  https://ai.google.dev/gemini-api/docs/models/gemini

## Design Goals

1. Give LLM clients compact, bounded access to SysNDD analysis context for
   research and hypothesis generation.
2. Preserve the read-only MCP sidecar safety boundary.
3. Clearly label curated SysNDD evidence, curated-derived analyses, ML
   predictions, and LLM-generated summaries.
4. Avoid exposing web-app table payloads or visualization payloads directly.
5. Use stable schemas with caps, pagination, and tool-visible errors.
6. Keep LLM-generated summaries cache-only and admin-generated.
7. Make one-gene exploration ergonomic through `get_gene_research_context`.
8. Keep broad analysis computation bounded and deterministic. Network and
   functional-cluster data may be served only from a proven local/disk cache hit
   or future persisted snapshot; otherwise the standalone tool raises
   `temporarily_unavailable` and the gene aggregator records that section as
   unavailable.

## Non-Goals

- Do not expose curation, review, re-review, admin, job, user, log, or backup
  data.
- Do not add write-capable tools.
- Do not expose raw SQL, arbitrary R execution, or broad exports.
- Do not mirror the analysis REST endpoints one-for-one.
- Do not call Gemini or any LLM provider from MCP.
- Do not expose LLM prompt/query inputs through MCP.
- Do not call live external proxy providers from MCP.
- Do not reclassify curated SysNDD evidence based on NDDScore or analysis
  outputs.
- Do not add a cached external gene annotation snapshot in this iteration.

## Data Classification Contract

Every new MCP analysis payload must include a top-level provenance envelope:

```json
{
  "schema_version": "1.2",
  "data_class": "curated_sysndd_evidence",
  "curation_effect": "curated_evidence",
  "not_evidence_tier": false,
  "source": "SysNDD",
  "provenance": {
    "source_table_or_view": "ndd_entity_view",
    "filters": ["active records", "primary approved reviews"],
    "generated_by": "human_curation"
  },
  "limitations": []
}
```

Allowed `data_class` values:

- `curated_sysndd_evidence`: Human-curated approved SysNDD evidence.
- `curated_derived_analysis`: Deterministic analysis derived from approved
  SysNDD data, such as phenotype correlations or source overlap.
- `ml_prediction`: Model-derived NDDScore output.
- `llm_generated_summary`: Cached admin-generated LLM summary.
- `external_reference_identifier`: External IDs or links stored in SysNDD gene
  metadata.
- `operational_metadata`: Non-sensitive metadata such as cache status, release
  IDs, and analysis availability.

Rules:

- `curation_effect = "none"` for all derived analyses, ML predictions, LLM
  summaries, and external identifiers.
- `not_evidence_tier = true` for all `ml_prediction` and
  `llm_generated_summary` payloads.
- NDDScore copy must use language such as `ML prediction`, `Model-derived`,
  `Prediction layer`, `Separate from curated SysNDD evidence`, and `Not an
  evidence tier`.
- LLM summary copy must state `LLM-generated cached summary`, `Admin-generated`,
  `Cache-only`, and `Does not change curated SysNDD evidence`.
- Derived analysis copy must state that correlations, clusters, and networks
  are hypothesis-generation views, not causal claims.

## Tool Designs

### `get_sysndd_analysis_catalog`

Purpose: let clients discover analysis capabilities before choosing a specific
tool.

Inputs:

- `include_unavailable`: boolean, default `false`.

Output:

- Schema version and server version.
- Analysis entries with `analysis_id`, `tool`, `data_class`, `source`,
  `availability`, `default_limits`, `supports_gene_filter`,
  `supports_cache_only_summary`, `limitations`, and `example_call`.
- Explicit entries for NDDScore, curation comparisons, phenotype correlations,
  phenotype clusters, phenotype-functional correlations, gene networks,
  functional clusters, and cached LLM summaries.

### `get_gene_research_context`

Purpose: one-call gene-centered research context for an LLM agent.

Inputs:

- `gene`: HGNC ID or symbol, required.
- `sections`: optional array. Supported values:
  `curated`, `comparison`, `nddscore`, `phenotype_clusters`,
  `phenotype_correlations`, `phenotype_functional_correlations`,
  `gene_network`, `cached_llm_summaries`, `external_identifiers`.
- `response_mode`: `minimal`, `compact`, `standard`, or `full`; default
  `compact`.
- `entity_limit`: default `10`, max `20`.
- `publication_limit`: default `5`, max `20`.
- `include_cached_llm_summaries`: boolean, default `true`.

Output:

- Resolved gene identity.
- Existing curated gene/entity context using current public MCP service helpers.
- Optional comparison source rows.
- Optional NDDScore gene detail.
- Optional analysis memberships and top correlated context.
- Optional network neighborhood.
- Optional current validated cached LLM summaries attached to matching
  functional or phenotype clusters.
- Existing external IDs from the gene row as `external_reference_identifier`,
  not fetched external data.
- `section_status` for each requested section: `available`, `empty`,
  `not_requested`, or `temporarily_unavailable`.

### `get_nddscore_context`

Purpose: expose model-derived prediction context without mixing it into curated
classification.

Inputs:

- `gene`: optional HGNC ID or symbol.
- `mode`: `gene`, `ranked_genes`, or `release`; default `gene` when `gene` is
  supplied, otherwise `ranked_genes`.
- `risk_tier`, `confidence_tier`, `known_sysndd_gene`, `hpo_terms`, `search`:
  optional filters for ranked mode.
- `sort`: default `rank`; invalid sort values return `invalid_input`.
- `page`: default `1`.
- `page_size`: default `25`, max `50`.

Output:

- `data_class = "ml_prediction"`.
- `curation_effect = "none"`.
- `not_evidence_tier = true`.
- Bounded active release metadata; large release JSON blobs are omitted from
  normal gene/ranked payloads.
- Gene prediction rows or one gene detail with HPO predictions.
- The existing prediction note that SHAP/statistical signal is not causation.

### `get_curation_comparison_context`

Purpose: expose comparison table and source-overlap context in MCP-friendly
form.

Inputs:

- `gene`: optional HGNC ID or symbol.
- `mode`: `gene_sources` or `browse`; default `gene_sources` when `gene` is
  supplied, otherwise `browse`.
- `sources`: optional source-name array.
- `category`: optional curated/source category filter.
- `limit`: default `25`, max `50`.
- `offset`: default `0`.

Output:

- `data_class = "curated_derived_analysis"`.
- Source rows from `ndd_database_comparison_view`.
- Metadata from `comparisons_metadata` when available.
- Clear note that external comparison sources are cross-references and do not
  alter SysNDD classifications.
- Web-app overlap/similarity plot modes are not included in this MCP iteration;
  requests for those modes return `unsupported_mode`.

### `get_phenotype_analysis_context`

Purpose: expose phenotype correlations, phenotype clusters, and
phenotype-functional correlations without raw visualization matrices.

Inputs:

- `mode`: `correlations`, `clusters`, or `phenotype_functional_correlations`.
- `gene`: optional HGNC ID or symbol for cluster membership or gene-neighborhood
  filtering.
- `phenotype`: optional HPO ID or phenotype text for correlation filtering.
- `min_abs_correlation`: default `0.3`.
- `cluster_id`: optional cluster identifier.
- `limit`: default `25`, max `50`.
- `include_cached_llm_summaries`: boolean, default `true`.

Output:

- Bounded top correlations or cluster membership records.
- Method metadata: phenotype source, category filters, modifiers, algorithms,
  and correlation method.
- `data_class = "curated_derived_analysis"` for computed correlations/clusters.
- Optional `llm_generated_summary` blocks only when current validated cache rows
  exist.
- Phenotype clusters are local MCA/HCPC-derived analysis and should be
  implemented through shared helper code rather than endpoint copy-paste.
- Phenotype-functional correlations depend on functional clusters; serve only
  from cache-hit-safe functional cluster data or return `temporarily_unavailable`.

### `get_gene_network_context`

Purpose: expose bounded gene network context for research hypotheses.

Inputs:

- `gene`: optional HGNC ID or symbol.
- `cluster_type`: `clusters` or `subclusters`; default `clusters`.
- `min_confidence`: STRING confidence, default `400`, valid range `0-1000`.
- `max_edges`: default `100`, max `250`.
- `include_cached_llm_summaries`: boolean, default `true`.

Output:

- Bounded node and edge records, not Cytoscape layout payloads.
- Cluster membership for the requested gene when supplied.
- `data_class = "curated_derived_analysis"`.
- STRING method/version metadata when available.
- A standalone call raises `temporarily_unavailable` if
  `memoise::has_cache(gen_network_edges_mem)` does not confirm a cache hit for
  the requested arguments. It must not initialize `STRINGdb` or call
  `gen_network_edges_mem()` on a cache miss.

## Cache-Only LLM Summary Contract

MCP must not call `get_cluster_summary()` from
`api/functions/llm-endpoint-helpers.R`, because that path generates on cache
miss.

Instead, add MCP repository reads that query `llm_cluster_summary_cache`
directly:

- `is_current = TRUE`
- `validation_status = 'validated'` by default
- `cluster_type IN ('functional', 'phenotype')`
- selected by exact `cluster_hash` or by bounded cluster IDs resolved from
  analysis data

Returned summary blocks must include:

- `data_class = "llm_generated_summary"`
- `curation_effect = "none"`
- `not_evidence_tier = true`
- `summary_available`
- `cache_id`
- `cluster_type`
- `cluster_number`
- `cluster_hash`
- `model_name`
- `prompt_version`
- `validation_status`
- `created_at`
- `validated_at`
- parsed `summary_json`

Missing summaries return:

```json
{
  "data_class": "llm_generated_summary",
  "curation_effect": "none",
  "not_evidence_tier": true,
  "summary_available": false,
  "cache_only": true
}
```

## Gene Research Context For HGNC:61

For `HGNC:61` / ABCD1, the new MCP path should be able to return:

- Curated SysNDD gene/entity context from existing MCP helpers.
- Comparison-source memberships from `ndd_database_comparison_view`.
- NDDScore model-derived gene prediction and HPO predictions.
- Phenotype cluster membership and correlation context if available.
- Gene network cluster membership and bounded neighboring edges if available
  without live external initialization.
- Existing external identifiers read through a dedicated bounded
  `non_alt_loci_set` repository helper, such as OMIM, Ensembl, UniProt, STRING,
  MGI, RGD, MANE, and AlphaFold IDs, labeled as
  `external_reference_identifier`.

It must not return live gnomAD/ClinVar/UniProt/AlphaFold/MGI/RGD proxy data in
this iteration.

## Error Handling

Known failures must be tool-visible MCP application errors, not raw JSON-RPC
internal errors.

Use existing `mcp_error()` and `mcp_error_payload()` with codes:

- `invalid_input`: bad enum, limit, identifier, threshold, or mode.
- `not_found`: gene, release, cluster, or analysis record not found.
- `temporarily_unavailable`: local/cache-only analysis data is not available
  without a prohibited live call, or no active NDDScore release exists.
- `unsupported_mode`: mode is valid for the web app but not this MCP tool.

For partially available gene research context, return a successful payload with
per-section `section_status` instead of failing the whole tool.

## Capability And Resource Updates

Update `get_sysndd_capabilities` to document:

- The analysis catalog workflow.
- The gene research workflow.
- The data classification contract.
- NDDScore as ML prediction, separate from curated evidence.
- LLM cached summaries as admin-generated and cache-only.
- External identifiers versus external live data.
- Limits and unavailable-section behavior.

Update `sysndd://schema/tool-guide` and `sysndd://schema/overview` with the same
contract. Do not add parameterized resources in this iteration.

## Testing Strategy

Unit tests:

- Data classification envelope helpers.
- Cache-only LLM summary reads and missing-cache behavior.
- NDDScore MCP shaping with model-derived labels.
- Comparison context modes and pagination metadata.
- Phenotype analysis mode validation and capped outputs.
- Gene network cache/local-only unavailable behavior.
- Gene research context partial section statuses.
- Tool registry names, descriptions, schemas, read-only annotations, and output
  schemas.

Repository tests:

- Public-data filters remain active.
- NDDScore uses active-release current views.
- LLM cache reads never source `llm-service.R`, never call
  `get_or_generate_summary()`, and never call `chat_google_gemini()`.
- Comparison reads use `ndd_database_comparison_view` and bounded limits.

Smoke test:

- `initialize`
- `tools/list`
- `resources/read`
- `get_sysndd_analysis_catalog`
- `get_nddscore_context` for a known gene if an active release is available
- `get_gene_research_context` for a known public gene
- malformed mode/limit calls return tool-visible errors

Verification commands:

- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-service.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-repository.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"`
- `make test-api-fast`
- `make mcp-smoke` or the existing MCP smoke command if no make target exists.

## Documentation Updates

Update durable docs in the implementation:

- `AGENTS.md`: add the v1.2 analysis MCP contract and LLM cache-only rule.
- `documentation/03-api.qmd`: document tools and data classes.
- `documentation/08-development.qmd`: document local MCP analysis verification.
- `documentation/09-deployment.qmd`: document sidecar runtime, cache-only
  limits, and disabled live external/LLM calls.

## Open Implementation Risk

`gen_string_clust_obj()` and `gen_network_edges()` use STRINGdb. The current
code notes that `STRINGdb$new()` checks `string-db.org/api/version` when a new
object is initialized. Because MCP must not call external providers, the
network and functional-cluster portions must either:

1. Serve from an already available local/disk cache only after
   `memoise::has_cache()` confirms a hit for the exact arguments, or
2. Return `temporarily_unavailable`, or
3. Be backed by a future persisted analysis snapshot.

The implementation plan uses option 1 when `memoise::has_cache()` proves a hit
and option 2 otherwise. A future snapshot table can upgrade this without
changing the public MCP tool names.

## Acceptance Criteria

- New analysis tools are listed in `tools/list` with schemas, output schemas,
  and read-only annotations.
- `get_sysndd_analysis_catalog` explains available and unavailable analysis
  surfaces.
- `get_gene_research_context(gene = "HGNC:61")` returns a bounded gene-centered
  payload with clearly labeled sections.
- NDDScore outputs are always marked `ml_prediction`, `curation_effect = none`,
  and `not_evidence_tier = true`.
- Cached LLM summaries are never generated by MCP and are labeled
  `llm_generated_summary`.
- Missing LLM summaries produce `summary_available = false`, not an LLM call.
- No MCP analysis code calls external proxy functions, PubMed/PubTator,
  Gemini, raw SQL execution tools, write helpers, or admin-only endpoints.
- Existing MCP tools continue to pass their unit and smoke tests.
