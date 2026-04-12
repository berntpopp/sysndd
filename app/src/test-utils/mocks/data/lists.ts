// test-utils/mocks/data/lists.ts
/**
 * Static fixtures for /api/list/* dropdown endpoints used by curate views
 * during Phase E rewrites (entity/gene/disease pickers).
 *
 * These handlers are additive stubs introduced by the reinforcing-phase-b
 * handler-gaps follow-up: the real `api/endpoints/list_endpoints.R` only
 * implements `status`, `phenotype`, `inheritance`, and `variation_ontology`
 * today — the `entity`, `gene`, and `disease` routes are contracts the
 * Phase E rewrites will target and the API will grow to honour.  The stubs
 * here let the rewriting specs exercise the call sites without each spec
 * having to install a per-test handler.
 *
 * Shape follows the `tree=true` convention already used by
 * list_endpoints.R (flat arrays of `{id, label}` or domain-specific
 * key/value pairs) rather than the `{links, meta, data}` cursor envelope.
 */

export interface ListEntityItem {
  entity_id: number;
  label: string;
}

export interface ListGeneItem {
  hgnc_id: string;
  symbol: string;
}

export interface ListDiseaseItem {
  disease_ontology_id_version: string;
  disease_ontology_name: string;
}

export const listEntityOk: ListEntityItem[] = [
  { entity_id: 501, label: 'TEST1 — Test Disease (Autosomal dominant)' },
  { entity_id: 502, label: 'TEST2 — Another Test Disease (Autosomal recessive)' },
];

export const listGeneOk: ListGeneItem[] = [
  { hgnc_id: 'HGNC:12345', symbol: 'TEST1' },
  { hgnc_id: 'HGNC:54321', symbol: 'TEST2' },
];

export const listDiseaseOk: ListDiseaseItem[] = [
  {
    disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
    disease_ontology_name: 'Test Disease',
  },
  {
    disease_ontology_id_version: 'MONDO:0000456_2025-01-01',
    disease_ontology_name: 'Another Test Disease',
  },
];
