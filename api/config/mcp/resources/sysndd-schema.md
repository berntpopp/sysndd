# sysndd://schema/overview

SysNDD represents approved public gene-disease-inheritance entities for neurodevelopmental disorder curation. An entity joins a gene, disease ontology term, inheritance term, NDD phenotype flag, public category/status, primary approved review synopsis, HPO phenotype terms, variation ontology terms, and linked publications.

MCP v1 is read-only. It uses active records from `ndd_entity_view` and review-derived evidence only from primary approved reviews.

# sysndd://schema/tool-guide

Use `search_sysndd` for routing user intent to genes, entities, diseases, phenotypes, and variation terms.

Use `get_gene_context` for compact gene summaries, `list_gene_entities` when only entity rows are needed, and `get_entity_context` for a curated gene-inheritance-disease entity.

Use `get_publication_context` for PubMed citation context linked to approved primary reviews.

Use `find_entities_by_phenotype` and `find_entities_by_disease` for constrained discovery. V1 does not expose draft reviews, admin data, jobs, logs, raw SQL, raw R execution, external providers, or Gemini-backed generation.
