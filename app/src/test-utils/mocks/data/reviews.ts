// test-utils/mocks/data/reviews.ts
/**
 * Static fixtures mirroring the OpenAPI response shapes for review endpoints
 * defined in api/endpoints/review_endpoints.R.
 *
 * Reference: api/config/openapi/schemas/inferred/api_review_GET.json.
 */

export interface ReviewRow {
  review_id: number;
  entity_id: number;
  hgnc_id: string;
  symbol: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term: string;
  hpo_mode_of_inheritance_term_name: string;
  synopsis: string;
  is_primary: number;
  review_date: string;
  review_user_name: string;
  review_user_role: string;
  review_approved: number;
  approving_user_name: string | null;
  approving_user_role: string | null;
  approving_user_id: number | null;
  comment: string | null;
  duplicate: string;
  active_status: number;
  active_category: number;
  newest_status: number;
  newest_category: number;
  status_change: number;
}

export const reviewByIdOk: ReviewRow = {
  review_id: 101,
  entity_id: 501,
  hgnc_id: 'HGNC:12345',
  symbol: 'TEST1',
  disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
  disease_ontology_name: 'Test Disease',
  hpo_mode_of_inheritance_term: 'HP:0000006',
  hpo_mode_of_inheritance_term_name: 'Autosomal dominant',
  synopsis: 'A test synopsis.',
  is_primary: 1,
  review_date: '2025-06-01 12:00:00',
  review_user_name: 'alice_admin',
  review_user_role: 'Administrator',
  review_approved: 0,
  approving_user_name: null,
  approving_user_role: null,
  approving_user_id: null,
  comment: null,
  duplicate: 'none',
  active_status: 3,
  active_category: 1,
  newest_status: 3,
  newest_category: 1,
  status_change: 0,
};

export const reviewByIdNotFound = {
  error: 'Review not found.',
};

export const reviewPhenotypesOk = [
  {
    review_id: 101,
    hpo_id: 'HP:0001250',
    hpo_term: 'Seizure',
    modifier: 'none',
  },
  {
    review_id: 101,
    hpo_id: 'HP:0001263',
    hpo_term: 'Global developmental delay',
    modifier: 'none',
  },
];

export const reviewPhenotypesNotFound = {
  error: 'Review not found.',
};

export const reviewVariationOk = [
  {
    review_id: 101,
    variation_ontology_id: 'SO:0001583',
    variation_ontology_name: 'missense_variant',
  },
];

export const reviewVariationNotFound = {
  error: 'Review not found.',
};

export const reviewPublicationsOk = [
  {
    review_id: 101,
    pmid: 12345678,
    title: 'A Study of Test Disease',
    journal: 'J Test Med',
    year: 2024,
  },
  {
    review_id: 101,
    pmid: 87654321,
    title: 'Follow-up Report',
    journal: 'J Test Med',
    year: 2025,
  },
];

export const reviewPublicationsNotFound = {
  error: 'Review not found.',
};

export const reviewCreateOk = {
  message: 'Review successfully created.',
  review_id: [102],
};

export const reviewCreateBadRequest = {
  error: 'Missing or invalid review fields.',
};

export const reviewUpdateOk = {
  message: 'Review successfully updated.',
};

export const reviewUpdateBadRequest = {
  error: 'Missing or invalid review fields.',
};

export const reviewApproveByIdOk = {
  message: 'Review approved.',
  review_id: 101,
};

export const reviewApproveByIdNotFound = {
  error: 'Review not found.',
};

export const reviewApproveAllOk = {
  message: 'All pending reviews approved.',
  approved_count: 3,
};

export const reviewApproveAllForbidden = {
  error: 'Bulk approval forbidden for non-admin.',
};
