---
name: sysndd-curation-data-sources
description: Use when changing the cross-database curation comparator, its source parsers or refresh job, disease cross-ontology (MONDO) mappings, the admin curation metadata vocabularies, the NDDScore prediction layer, or re-review batch sizing
---

# SysNDD Curation Data Sources

Covers the externally-sourced data that sits *beside* curated SysNDD evidence: the comparator, ontology mappings, the admin-editable vocabularies, and NDDScore.

## Non-negotiables

- **The comparator refresh is resilient, not all-or-nothing.** Each source downloads and parses independently; a failed source keeps its previous rows via a per-list replace. `comparisons_refresh_outcome()` is the single decision point.
- **Comparison categories are normalized at READ time**, not stored normalized — so a mapping-policy change takes effect on an **API restart**, not on a refresh or worker restart. No PanelApp tier maps to Refuted.
- **NDD membership = the seed HPO term OR ANY DESCENDANT**, expanded explicitly. `phenotype_to_genes.txt` is not upward-propagated, so filtering the bare seed silently drops ~600 diseases.
- **Metadata vocabulary editability is tiered on purpose** (fully editable / `anchored` / never writable). `metadata_vocabulary_registry()` is the single source of truth; deletes are soft and guarded by an in-use check, which is the only protection because there are no DB foreign keys.
- **NDDScore is a model-derived prediction layer**, never a curation status and never an evidence tier. Copy: `ML prediction`, `Model-derived`, `Separate from curated SysNDD evidence`.
- **`OMIMPS` is never canonicalized to OMIM**; `target_id` is always a full CURIE.
- **Restart the worker** after changing comparison or refresh code — durable job code is sourced at worker startup.

## Deep reference

Authoritative detail, extracted from `AGENTS.md`:

- `references/comparisons-and-nddscore.md` — source keys, parsers, the per-list replace, category normalization, the OMIM-NDD seed, NDDScore imports.
- `references/disease-ontology-mappings.md` — MONDO-as-hub ingest, the refresh job and its binding rules, the collation trap, the public read endpoint.
- `references/metadata-vocabularies.md` — the vocabulary registry and editability tiers.
- `references/re-review-batching.md` — the gene-atomic soft LIMIT.
