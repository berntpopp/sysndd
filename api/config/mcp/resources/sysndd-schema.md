# sysndd://schema/overview

SysNDD represents approved public gene-disease-inheritance entities for neurodevelopmental disorder curation. An entity joins a gene, disease ontology term, inheritance term, NDD phenotype flag, public category/status, primary approved review synopsis, HPO phenotype terms, variation ontology terms, and linked publications. Entities are not genes: one gene can have multiple entities.

MCP v1 is read-only. It uses active records from `ndd_entity_view` and review-derived evidence only from primary approved reviews.

# sysndd://schema/tool-guide

Use `search_sysndd` for routing user intent to genes, entities, diseases, phenotypes, and variation terms.

Use `get_gene_context` for compact gene summaries, `list_gene_entities` when only entity rows are needed, and `get_entity_context` for a curated gene-inheritance-disease entity. Use `get_entities_context` for 1-20 entity IDs when a gene or find tool returns multiple entities that need detail in one call.

Use `get_publication_context` for one PMID and `get_publications_context` for 2-20 PMIDs. Publication outputs include `recommended_citation`, `pubmed_publication_date`, `abstract_available`, `abstract_excerpt`, and `abstract_truncated`. Linked entity review dates are exposed as `sysndd_curation_date`.

`resources/list` advertises `sysndd://schema/overview` and `sysndd://schema/tool-guide`; `resources/read` returns those static documentation resources. Payload `sysndd://gene`, `sysndd://entity`, and `sysndd://publication` URIs are stable identifiers for returned records. In v1, use tools for record retrieval; parameterized resource templates are not exposed.

Use `find_entities_by_phenotype` and `find_entities_by_disease` for constrained discovery. V1 does not expose draft reviews, admin data, jobs, logs, raw SQL, raw R execution, external providers, or Gemini-backed generation.

Tools advertise read-only annotations and output schemas. Errors use stable JSON envelopes with `schema_version` and `error.code`, including `invalid_input`, `not_found`, `ambiguous_query`, and `temporarily_unavailable`; recoverable tool errors are returned as tool results with `isError = true` rather than JSON-RPC internal errors.
