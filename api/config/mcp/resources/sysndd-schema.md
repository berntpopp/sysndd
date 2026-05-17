# sysndd://schema/overview

SysNDD represents approved public gene-disease-inheritance entities for neurodevelopmental disorder curation. An entity joins a gene, disease ontology term, inheritance term, NDD phenotype flag, public category/status, primary approved review synopsis, HPO phenotype terms, variation ontology terms, and linked publications. Entities are not genes: one gene can have multiple entities.

MCP v1 is read-only. It uses active records from `ndd_entity_view` and review-derived evidence only from primary approved reviews.

# sysndd://schema/tool-guide

Use `search_sysndd` for routing user intent to genes, entities, diseases, phenotypes, and variation terms.

Use `get_sysndd_capabilities` for in-band workflows, limits, payload modes, citations, resources, errors, prompts, and safety scope.

Use `get_gene_context` for compact gene summaries, `get_genes_context` for batch context for 1-10 genes in one call, `list_gene_entities` when only entity rows are needed, and `get_entity_context` for a curated gene-inheritance-disease entity. `get_gene_context` examples: `{"gene":"PNKP","include_entities":true,"include_comparisons":false,"response_mode":"compact"}` for a cheap summary, or `{"gene":"PNKP","expand":"entities","abstract_mode":"metadata"}` for one-call gene plus entity detail. `get_genes_context` returns per-gene errors and cross-gene deduplicated publications; use `expand=entities` for one-call multi-gene detail. Legacy gene-parameter aliases are accepted silently for client self-correction but are not advertised in the input schema. Use `get_entities_context` for 1-20 entity IDs when a gene or find tool returns multiple entities that need detail in one call. Batch entity context deduplicates shared publications into top-level `publications` by default and leaves per-entity `publication_refs`.

Payload controls: `response_mode` is `compact`, `standard`, or `full`; `abstract_mode` is `none`, `metadata`, or `excerpt`; `synopsis_mode` is `none`, `excerpt`, or `full`. Use `abstract_mode:"metadata"` for citation lists; it returns `abstract_available` but omits `abstract_excerpt` and `abstract_truncated`. Use `abstract_mode:"excerpt"` only when summarizing abstract content. `include_entities`, `include_publications`, `include_phenotypes`, and `include_variants` default to true where available. `include_comparisons` defaults to false on `get_gene_context`.

`get_gene_context` reports `meta.entity_total`, `meta.entity_returned`, `meta.entity_has_more`, and `meta.next_entity_offset` for its first-page entity rows. If `entity_has_more` is true, use `list_gene_entities` with `offset` or call `get_gene_context` with a larger `entity_limit` up to 25. When `expand:"entities"` is used, detailed entity expansion is capped at 20 IDs per call and `meta.entity_detail_truncated_by_batch_cap` reports whether the requested entity limit exceeded that detail cap. `comparison_sources` are external source cross-references, not cross-gene biological comparison results.

Use `get_publication_context` for one PMID and `get_publications_context` for 1-20 PMIDs. Publication records expose `publication_date_sysndd_record` with a `publication_date_confidence` flag (`pubmed_verified`, `pubmed_partial`, `matches_curation_date`, `unverified`). Treat the date as a real publication date only when confidence is `pubmed_verified` or `pubmed_partial`. Publication outputs include `recommended_citation` and, depending on `abstract_mode`, `abstract_available`, `abstract_excerpt`, and `abstract_truncated`. Linked entity review dates are exposed as `sysndd_curation_date`.

`resources/list` advertises `sysndd://schema/overview` and `sysndd://schema/tool-guide`; `resources/read` returns those static documentation resources. Payload `sysndd://gene`, `sysndd://entity`, and `sysndd://publication` URIs are stable identifiers for returned records. In v1, use tools for record retrieval; parameterized resource templates are not exposed.

Use `find_entities_by_phenotype` and `find_entities_by_disease` for constrained discovery. MCP prompts are available for common user-invoked workflows: `sysndd_gene_evidence_summary`, `sysndd_entity_evidence_brief`, `sysndd_publication_citation_pack`, and `sysndd_phenotype_entity_discovery`. V1 does not expose draft reviews, admin data, jobs, logs, raw SQL, raw R execution, external providers, or Gemini-backed generation.

Tools advertise read-only annotations and output schemas. Errors use stable JSON envelopes with `schema_version` and `error.code`, including `invalid_input`, `not_found`, `ambiguous_query`, and `temporarily_unavailable`; recoverable tool errors are returned as tool results with `isError = true` rather than JSON-RPC internal errors.
