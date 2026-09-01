# Admin curation metadata vocabularies

> Extracted verbatim from `AGENTS.md` (2026-09-01) to keep the root instruction file lean.
> This is the authoritative detail for this subsystem.

The Administrator `/ManageMetadata` page (`app/src/views/admin/ManageMetadata.vue`) administers the small SysNDD-managed curation controlled vocabularies through `/api/metadata` (`api/endpoints/metadata_endpoints.R` -> `services/metadata-vocabulary-service.R` -> `functions/metadata-vocabulary-repository.R`). The vocabulary catalog and editability tiers live in `metadata_vocabulary_registry()`; keep it the single source of truth for which tables/columns the admin surface can touch.

Editability is tiered on purpose. `modifier_list` and `ndd_entity_status_categories_list` are fully editable (create / update / soft-delete) because they are SysNDD-managed and never refreshed from an external source. `mode_of_inheritance_list` (HPO) and `variation_ontology_list` (VariO) are `"anchored"`: curated display fields and the `is_active` flag are editable, but terms cannot be created or deleted because they are sourced from an external ontology and may be overwritten on refresh. Ontology-derived tables (`phenotype_list`, `disease_ontology_set`, `non_alt_loci_set`) are never writable here; they are refreshed via `api/functions/metadata-refresh.R` and the admin annotation jobs.

Deletes are soft-deletes (`is_active = 0`) guarded by an in-use reference check: a value still referenced by curation data (`metadata_vocabulary_usage_count()`) fails fast with a 400 instead of being removed. There are no enforced DB foreign keys to these lookup tables, so this application-level guard is the only protection — keep the `usage` reference list in the registry in sync when a new table starts referencing a vocabulary. Migration `033_add_metadata_lookup_admin_columns.sql` added the `is_active`/`sort` columns the two SysNDD-managed lookups needed.

