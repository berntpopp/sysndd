// test-utils/mocks/data/entities.ts
/**
 * Static fixtures mirroring the OpenAPI response shapes for entity endpoints
 * defined in api/endpoints/entity_endpoints.R.
 *
 * Reference: api/config/openapi/schemas/inferred/api_entity_GET.json.
 *
 * NOTE: `GET /api/entity/<sysndd_id>` is listed in the Phase B.B1 locked
 * handler table but no bare `@get /<sysndd_id>` annotation exists in
 * entity_endpoints.R on master (only `/`, `/<sysndd_id>/phenotypes`, etc.).
 * The mock is kept to honour "do not widen, narrow, or rewrite the locked
 * table"; the drift is flagged in scripts/msw-openapi-exceptions.txt.
 */

export interface EntityDetail {
  entity_id: number;
  sysndd_id: string;
  symbol: string;
  hgnc_id: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term: string;
  hpo_mode_of_inheritance_term_name: string;
  category_id: number;
  category_value: string;
}

export const entityByIdOk: EntityDetail = {
  entity_id: 501,
  sysndd_id: 'sysndd:000501',
  symbol: 'TEST1',
  hgnc_id: 'HGNC:12345',
  disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
  disease_ontology_name: 'Test Disease',
  hpo_mode_of_inheritance_term: 'HP:0000006',
  hpo_mode_of_inheritance_term_name: 'Autosomal dominant',
  category_id: 1,
  category_value: 'Definitive',
};

export const entityByIdNotFound = {
  error: 'Entity not found.',
};

export const entityCreateOk = {
  message: 'Entity successfully created.',
  entity_id: [502],
};

export const entityCreateBadRequest = {
  error: 'Missing or invalid entity fields.',
};

export const entityCreateConflict = {
  error: 'Duplicate entity (gene + disease + inheritance) already exists.',
};

export const entityRenameOk = {
  message: 'Entity successfully renamed.',
  entity_id: 501,
};

export const entityRenameBadRequest = {
  error: 'New symbol is required.',
};

export const entityDeactivateOk = {
  message: 'Entity deactivated.',
  entity_id: 501,
};

export const entityDeactivateBadRequest = {
  error: 'Entity id missing.',
};

export const entityReviewListOk = [
  {
    review_id: 101,
    entity_id: 501,
    review_date: '2025-06-01 12:00:00',
    review_user_name: 'alice_admin',
    review_approved: 1,
    is_primary: 1,
  },
  {
    review_id: 102,
    entity_id: 501,
    review_date: '2025-07-01 12:00:00',
    review_user_name: 'bob_viewer',
    review_approved: 0,
    is_primary: 0,
  },
];

export const entityReviewListNotFound = {
  error: 'Entity not found.',
};

export const entityStatusListOk = [
  {
    status_id: 201,
    entity_id: 501,
    category_id: 1,
    status_date: '2025-06-01 12:00:00',
    status_user_name: 'alice_admin',
    status_approved: 1,
  },
];

export const entityStatusListNotFound = {
  error: 'Entity not found.',
};
