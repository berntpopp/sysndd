# Read-Only MCP API Design

## Problem

SysNDD exposes rich public REST endpoints for genes, entities, publications,
phenotypes, variation ontology, comparisons, panels, statistics, and network
analyses. Those endpoints are useful for the web application, but they are not
ideal as a direct Model Context Protocol (MCP) surface for language models:

- Many responses are frontend table payloads with `links`, `meta`, `fspec`, and
  optional XLSX export behavior.
- Several routes collect broad tables or trigger expensive computations.
- Some GET routes are operational, user/admin-oriented, or authentication-shaped.
- LLM clients need compact, stable, citation-friendly context for answering
  questions about neurodevelopmental disorder (NDD) associated genes and
  gene-disease-inheritance entities.

The goal is to add read-only MCP access that lets LLM clients search, retrieve,
and summarize SysNDD facts without blocking the existing R/Plumber API.

## Current API Review

### High-Value Data Sources

The MCP layer should read from the same public data surfaces that power the web
app, but reshape them for LLM use.

- `api/endpoints/search_endpoints.R`
  - `/api/search/<searchterm>` searches entity ID, HGNC ID, symbol, disease
    ontology ID, and disease ontology name.
  - `/api/search/gene/<searchterm>` resolves symbols and HGNC IDs.
  - `/api/search/ontology/<searchterm>` resolves disease ontology IDs/names.
  - Good for intent routing, but the response shape is UI-oriented and can be
    noisy when `helper = TRUE`.
- `api/endpoints/gene_endpoints.R`
  - `/api/gene/` exposes paginated gene/entity-grouped records from
    `ndd_entity_view`.
  - `/api/gene/<gene_input>` returns gene identifiers and external IDs from
    `non_alt_loci_set`, including OMIM, Ensembl, UniProt, STRING, MGI, RGD,
    MANE, and optional gnomAD/AlphaFold fields.
  - Good for canonical gene identity and entity counts.
- `api/endpoints/entity_endpoints.R`
  - `/api/entity/` exposes active entity rows from `ndd_entity_view` plus
    primary review synopsis.
  - `/api/entity/<id>/review` returns primary clinical synopsis.
  - `/api/entity/<id>/status` returns active category/status.
  - `/api/entity/<id>/phenotypes` returns HPO terms for the primary review.
  - `/api/entity/<id>/variation` returns variation ontology terms for the
    primary review.
  - `/api/entity/<id>/publications` returns publications linked to the primary
    review.
  - These are the most important sources for a complete entity context pack.
- `api/endpoints/publication_endpoints.R`
  - `/api/publication/<pmid>` returns PMID metadata: title, abstract, journal,
    date, author fields, and keywords.
  - `/api/publication/` is a broad table endpoint and should not be exposed
    directly.
  - PubTator table/gene/search endpoints are useful for discovery but are
    cache/search-review oriented rather than core SysNDD evidence.
- `api/endpoints/list_endpoints.R`
  - `/api/list/phenotype`, `/api/list/inheritance`, and
    `/api/list/variation_ontology` provide dictionary context for HPO,
    inheritance, and variation terms.
  - Useful as MCP resources or lookup tools with pagination.
- `api/endpoints/ontology_endpoints.R`
  - `/api/ontology/<ontology_input>` returns disease ontology cross-references
    and linked HGNC/inheritance fields.
  - `variant/table` requires Administrator privileges and should not be exposed.
- `api/endpoints/panels_endpoints.R`
  - `/api/panels/browse` provides clinically useful filtered gene panels, but
    defaults to `page_size = all`.
  - MCP should expose a capped wrapper, not the raw route behavior.
- `api/endpoints/comparisons_endpoints.R`
  - `/api/comparisons/browse` maps genes across SysNDD, DDG2P,
    PanelApp/Radboud, SFARI, Geisinger DBD, Orphanet, and OMIM NDD sources.
  - Valuable for "is this gene known elsewhere?" questions.
  - `/api/comparisons/upset` and `/api/comparisons/similarity` are analysis/plot
    payloads and are not useful first-tier LLM tools.
- `api/endpoints/analysis_endpoints.R`
  - Functional and phenotype clustering endpoints can be useful for broad
    biological context, but they are heavier and more UI/visualization-shaped.
  - `functional_cluster_summary` and `phenotype_cluster_summary` may generate
    Gemini summaries on cache miss. MCP should not expose these directly because
    they can trigger additional LLM calls and hidden latency.
- `api/endpoints/phenotype_endpoints.R` and `api/endpoints/variant_endpoints.R`
  - Count endpoints can provide global context.
  - Correlation endpoints return matrices better suited to visualization than
    conversational retrieval.

### Endpoints Not Suitable for MCP Exposure

Do not expose the following through MCP:

- Write routes: all `POST`, `PUT`, `PATCH`, and `DELETE` routes.
- Auth/user/admin routes: `/api/auth/*`, `/api/user/*`, `/api/admin/*`,
  `/api/logs/*`, `/api/backup/*`, `/api/jobs/*`.
- Curation workflow routes: `/api/review/*`, `/api/re_review/*`, except no
  read-only inclusion unless a future authenticated MCP role is designed.
- Broad export routes or any route preserving `format = "xlsx"`.
- Existing LLM-generation endpoints under `/api/analysis/*_cluster_summary`.
- External proxy routes as first-tier tools, because they add network egress,
  upstream instability, and result-shape variability. A later version can add
  selected cached external annotations if needed.

## MCP Protocol Direction

Use MCP over Streamable HTTP for remote clients. The current MCP specification
defines JSON-RPC over stdio and Streamable HTTP, where a remote server provides
one MCP endpoint such as `/mcp`. Streamable HTTP servers must validate `Origin`
headers, should authenticate remote connections, and should return JSON or SSE
according to the transport contract.

Expose model-invocable functionality as MCP tools with explicit input schemas
and structured outputs. MCP resources should be reserved for stable context that
host applications may choose to include, such as schema summaries and selected
record resources.

R implementation note: Posit's `mcptools` can run an R MCP server and accepts a
list of `ellmer::tool()` definitions. Its HTTP transport is available, but the
current HTTP implementation is authless. It also blocks the R process that runs
the server. Therefore SysNDD should run MCP as a separate process/service rather
than embedding it in `api/start_sysndd_api.R`.

References:

- MCP Streamable HTTP transport:
  https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
- MCP tools:
  https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- MCP resources:
  https://modelcontextprotocol.io/specification/2025-11-25/server/resources
- MCP security best practices:
  https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices
- R `mcptools` server guide:
  https://posit-dev.github.io/mcptools/articles/server.html
- R `mcptools` changelog:
  https://posit-dev.github.io/mcptools/news/index.html

## Design Goals

1. Provide read-only MCP access for LLM clients to find and summarize NDD genes
   and SysNDD entities.
2. Keep the existing Plumber API non-blocking by running MCP outside the web API
   process.
3. Return compact, deterministic, schema-bound payloads that fit in model
   context.
4. Reuse existing R bootstrap, database helpers, repository patterns, and
   field semantics.
5. Avoid raw SQL, arbitrary R execution, hidden LLM calls, broad table exports,
   and write-capable tools.
6. Keep the first implementation small enough to test with unit tests and an MCP
   protocol smoke test.

## Non-Goals

- Do not implement authenticated curator/admin MCP access.
- Do not expose write, approval, re-review, user, backup, log, or job actions.
- Do not mirror the whole REST API.
- Do not add a custom JavaScript/Python runtime unless the R HTTP MCP server
  cannot pass protocol smoke testing.
- Do not create embeddings, vector search, or a separate retrieval index in the
  first version.
- Do not trigger Gemini or other LLM providers from MCP.

## Recommended Architecture

Add a dedicated read-only MCP service using the existing API image:

- New entrypoint: `api/start_sysndd_mcp.R`
- New read-only domain files:
  - `api/functions/mcp-repository.R`
  - `api/services/mcp-service.R`
  - `api/services/mcp-tools.R`
- Optional support file for static resource text:
  - `api/config/mcp/resources/sysndd-schema.md`
- Compose service:
  - `mcp`, built from `./api`, with its own command, DB pool settings, health
    behavior, and Traefik route.
- Public route:
  - `/mcp`, routed to the MCP service, separate from `/api`.

The MCP service should call `bootstrap_init_libraries()`,
`bootstrap_load_modules()`, `bootstrap_create_pool()`, and
`bootstrap_init_globals()` in the same order as the API, then register only MCP
tools/resources. It should not mount Plumber endpoints or run migrations. The
main API remains responsible for migrations at startup.

Because `mcptools::mcp_server()` blocks, blocking is contained to the `mcp`
service process. The existing `api` service continues serving Plumber traffic
with its own R process and DB pool.

## Non-Blocking Deployment Behavior

The MCP service must not contend heavily with the web API:

- Use a separate process/container.
- Use a small dedicated DB pool, default `MCP_DB_POOL_SIZE=2`.
- Use bounded result sizes for every tool.
- Use query limits at the SQL layer where possible.
- Avoid broad `collect()` calls in MCP service code.
- Return "too broad" tool errors when input would require scanning or returning
  excessive rows.
- Do not call external providers or Gemini from MCP tools.
- Keep no required per-client state in the first version; prefer stateless HTTP
  behavior so replicas can be added later.

## MCP Tool Surface

The first version should expose these tools.

### `search_sysndd`

Purpose: route user intent to likely genes, entities, diseases, or ontology
terms.

Inputs:

- `query` string, required, 2-100 characters.
- `types` string array, optional, enum: `gene`, `entity`, `disease`,
  `phenotype`, `variant`.
- `limit` integer, optional, default 10, max 25.

Output:

- `query`
- `matches[]` with `type`, `id`, `label`, `description`, `score`,
  `resource_uri`, and `suggested_tools`.

Implementation:

- Reuse search views where practical:
  - `search_non_alt_loci_view`
  - `search_disease_ontology_set`
  - `ndd_entity_view`
  - optionally `phenotype_list` and `variation_ontology_list`
- Prefer direct prefix/exact matches before fuzzy/string distance.
- Include `resource_uri` values such as `sysndd://gene/SYMBOL` and
  `sysndd://entity/1234`.

### `get_gene_context`

Purpose: provide a compact gene-centric context pack for summarization.

Inputs:

- `gene` string, required; accepts symbol, `HGNC:1234`, or bare HGNC number.
- `include_entities` boolean, optional, default true.
- `include_comparisons` boolean, optional, default true.
- `entity_limit` integer, optional, default 10, max 25.

Output:

- `gene` with canonical IDs/names from `non_alt_loci_set`.
- `entity_summary` with entity count, categories, inheritance modes, disease
  names, and NDD phenotype flags.
- `entities[]` compact rows: `entity_id`, `symbol`, `hgnc_id`,
  `disease_ontology_id_version`, `disease_ontology_name`,
  `hpo_mode_of_inheritance_term_name`, `category`, `ndd_phenotype_word`,
  `synopsis_excerpt`.
- `comparison_sources[]` from `ndd_database_comparison_view`.
- `resource_links[]` for the gene and entity resources.

Implementation:

- Query `non_alt_loci_set` by symbol/HGNC.
- Query `ndd_entity_view` by HGNC ID and left join the primary review synopsis.
- Query `ndd_database_comparison_view` by HGNC ID, capped and grouped.
- Truncate synopsis excerpts to a configured max, e.g. 1,500 characters per
  entity.

### `get_entity_context`

Purpose: provide a complete, entity-centric context pack for a curated
gene-inheritance-disease unit.

Inputs:

- `entity_id` integer, required.
- `include_publications` boolean, optional, default true.
- `include_phenotypes` boolean, optional, default true.
- `include_variants` boolean, optional, default true.
- `publication_limit` integer, optional, default 10, max 25.

Output:

- `entity` compact row from `ndd_entity_view`.
- `status` active category/status metadata.
- `review` primary synopsis and review date, without user names/comments unless
  those are explicitly deemed public.
- `phenotypes[]` HPO IDs and terms.
- `variation_terms[]` variation ontology IDs and names.
- `publications[]` linked PMIDs with title, journal, date, first author, and
  abstract excerpt.
- `suggested_followups[]`, for example `get_publication_context` or
  `search_sysndd`.

Implementation:

- Use parameterized SQL in a repository helper rather than calling Plumber
  endpoint functions.
- Join only active entity records.
- Use primary review only (`is_primary = 1`) for synopsis, phenotypes,
  variation terms, and publications.

### `list_gene_entities`

Purpose: list SysNDD entities for one gene without returning full context.

Inputs:

- `gene` string, required.
- `category` string, optional.
- `ndd_phenotype` string, optional, enum: `yes`, `no`, `any`, default `any`.
- `limit` integer, optional, default 25, max 50.
- `offset` integer, optional, default 0.

Output:

- `gene`
- `data[]` compact entity rows.
- `meta` with `total`, `limit`, `offset`, and `has_more`.

Implementation:

- Query by resolved HGNC ID.
- Apply filters in SQL.
- Do not expose arbitrary REST filter syntax to MCP clients.

### `get_publication_context`

Purpose: retrieve publication metadata for citations and evidence summaries.

Inputs:

- `pmid` string, required; accepts `PMID:123`, `123`, or a URL containing a PMID.
- `abstract_max_chars` integer, optional, default 2,000, max 4,000.

Output:

- `publication_id`
- `title`
- `journal`
- `publication_date`
- `first_author`
- `keywords`
- `abstract_excerpt`
- `linked_entities[]` compact entity references where this PMID is linked to a
  primary review.

Implementation:

- Query `publication`.
- Join through `ndd_review_publication_join` and `ndd_entity_review` to
  `ndd_entity_view` where the review is primary.

### `find_entities_by_phenotype`

Purpose: retrieve entities associated with HPO terms or phenotype text.

Inputs:

- `phenotype` string, required; accepts HPO ID or text.
- `modifier` string, optional, enum-like text such as `present`, `excluded`,
  `unknown`; default `present`.
- `category` string, optional, default `Definitive`.
- `limit` integer, optional, default 25, max 50.
- `offset` integer, optional, default 0.

Output:

- `phenotype`
- `resolved_phenotypes[]`
- `entities[]` compact entity rows.
- `meta`

Implementation:

- Resolve phenotype through `phenotype_list`.
- Join `ndd_review_phenotype_connect`, `modifier_list`, primary
  `ndd_entity_review`, and `ndd_entity_view`.

### `find_entities_by_disease`

Purpose: retrieve entities by disease ontology ID or disease name.

Inputs:

- `disease` string, required.
- `limit` integer, optional, default 25, max 50.
- `offset` integer, optional, default 0.

Output:

- `resolved_diseases[]`
- `entities[]`
- `meta`

Implementation:

- Resolve disease through `disease_ontology_set`.
- Query `ndd_entity_view` by disease ontology ID version.

### `get_sysndd_stats`

Purpose: answer broad overview questions without calling expensive table routes.

Inputs:

- none.

Output:

- high-level counts: entities, genes, categories, NDD phenotype yes/no,
  publications, last update fields where available.
- `generated_at`.

Implementation:

- Use targeted aggregate SQL queries.
- Do not call route helpers that build large frontend payloads.

### Deferred Tools

These are useful but should not ship in the first version:

- Functional/phenotype cluster summary tools, unless changed to cache-only.
- Network edge retrieval.
- External proxy tools for gnomAD, UniProt, Ensembl, AlphaFold, MGI, or RGD.
- PubTator discovery tools.
- Comparison matrix/upset/correlation tools.

## MCP Resources

Expose a small resource set:

- `sysndd://schema/overview`
  - Plain-language explanation of SysNDD concepts: gene, entity, disease
    ontology, inheritance, NDD phenotype, category, review, status, HPO
    phenotype, variation ontology, publication.
- `sysndd://schema/tool-guide`
  - Which tool to call for common LLM tasks.
- `sysndd://gene/{symbol}`
  - Same compact payload as `get_gene_context`, using default limits.
- `sysndd://entity/{entity_id}`
  - Same compact payload as `get_entity_context`, using default limits.
- `sysndd://publication/{pmid}`
  - Same compact payload as `get_publication_context`.

The resource interface should be treated as stable context selection, while
tools remain the model-controlled active query surface.

## Data Shaping Rules

All MCP outputs should follow these conventions:

- Return JSON-compatible lists with predictable names.
- Include compact text fields suitable for direct model use.
- Include original identifiers and source table semantics.
- Include `resource_uri` or `source_url` fields where possible.
- Include `meta` with `limit`, `offset`, `total`, and truncation flags when
  records are capped.
- Truncate long text and mark it as truncated.
- Prefer plain arrays of objects over frontend envelopes.
- Do not expose `fspec`, XLSX attachments, raw query logs, user emails, password
  reset fields, or curator workflow comments.

## Security

The MCP service is read-only but still public-facing and model-controlled:

- Validate all tool inputs with explicit length, type, enum, and range checks.
- Reject raw SQL, raw REST filter expressions, arbitrary R code, and arbitrary
  URL fetches.
- Use parameterized SQL through repository helpers.
- Apply origin allowlisting for Streamable HTTP requests.
- Keep the first release unauthenticated only if routed behind public-rate-limit
  controls and read-only tool definitions. If the chosen R HTTP MCP server cannot
  validate Origin or add headers, place it behind a small proxy layer or defer
  public exposure.
- Rate-limit `/mcp` separately from `/api`.
- Log tool name, sanitized arguments, status, duration, and row counts. Do not
  log raw long text or secrets.
- Run the container with existing `no-new-privileges` hardening.
- Do not mount or expose files that are not needed by the MCP service.

## Error Handling

Use tool execution errors, not protocol errors, for model-correctable problems:

- `not_found`: gene/entity/publication/phenotype not found.
- `ambiguous_query`: multiple likely matches; include choices and suggested
  follow-up tool call.
- `too_broad`: requested result set exceeds limits; include narrowing
  suggestions.
- `invalid_input`: bad identifier, overlong query, invalid enum, or limit above
  max.
- `temporarily_unavailable`: database unavailable or MCP pool exhausted.

Each error should return concise text plus structured fields where supported.

## Testing Strategy

### Unit Tests

Add focused tests for:

- Gene identifier normalization.
- PMID normalization.
- Limit/offset validation and max caps.
- Truncation helper behavior.
- Each repository query helper with mocked DB responses.
- Service-layer shaping for:
  - `search_sysndd`
  - `get_gene_context`
  - `get_entity_context`
  - `get_publication_context`
  - phenotype/disease lookup tools.

### Integration Tests

Add API-side integration tests that source the MCP service files and call tool
functions directly against the test database fixture or mocked pool. These tests
should assert shape, caps, and read-only behavior.

### Protocol Smoke Test

Add a lightweight MCP smoke test that starts `api/start_sysndd_mcp.R` on a test
port and checks:

- server initializes,
- tools can be listed,
- `get_sysndd_stats` can be called,
- invalid input returns a tool execution error,
- the process can be stopped cleanly.

If the R HTTP MCP implementation cannot be tested reliably in CI, keep protocol
smoke local-only and make `make test-api-fast` cover all repository/service
logic.

### Non-Blocking Checks

Verify that:

- starting `mcp` does not change `api` health behavior,
- MCP has its own DB pool settings,
- broad MCP calls return capped payloads,
- no MCP tool invokes Plumber route functions, external providers, or Gemini.

## Documentation

Update:

- `documentation/03-api.qmd`
  - Add a short MCP section, public route, read-only policy, and tool summary.
- `documentation/09-deployment.qmd`
  - Add MCP service configuration, resource limits, route, rate-limit, and
    origin/security notes.
- `README.md`
  - Mention optional read-only MCP access once deployed.
- `AGENTS.md`
  - Add persistent guidance that MCP tools are read-only, separate from Plumber,
    and must not call external providers or LLM-generation endpoints.

## Open Decisions

These decisions are explicit for the first implementation:

- Use R `mcptools` first, because it fits the R stack and accepts R tool
  functions directly.
- Run MCP as a sidecar service, not inside Plumber.
- Start with read-only public data only.
- Prefer compact service/repository helpers over wrapping existing Plumber
  endpoint functions.

The only implementation-dependent decision is whether `mcptools` HTTP transport
can satisfy required public security behavior directly. If it cannot validate
Origin and support the deployment route cleanly, add a small reverse-proxy guard
or expose MCP initially only on an internal/private route until a compliant
transport layer is available.

## Acceptance Criteria

- A separate MCP service can run without blocking or modifying the Plumber API
  process.
- MCP exposes only read-only tools and resources.
- LLM clients can search SysNDD, retrieve a gene context, retrieve an entity
  context, and retrieve publication context.
- Tool outputs are capped, structured, and useful for summarizing NDD-associated
  genes and entities.
- No tool can write to the database, execute raw SQL/R code, call Gemini, or
  fetch arbitrary external URLs.
- Tests cover input validation, response shaping, capped outputs, and read-only
  service behavior.
- Documentation describes MCP scope, route, deployment, and security limits.
