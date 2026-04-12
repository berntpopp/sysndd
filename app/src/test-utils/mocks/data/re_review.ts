// test-utils/mocks/data/re_review.ts
/**
 * Static fixtures for the re-review table endpoint used by Review.vue and
 * ManageReReview.vue.  Mirrors the `{links, meta, data}` cursor envelope
 * that `api/endpoints/re_review_endpoints.R` `@get table` emits.
 *
 * R/Plumber serialises scalars as single-element arrays inside the `data`
 * rows — Review.vue's table consumer tolerates both, but we follow the
 * wire contract by keeping the array envelope on `meta` and the row
 * objects as plain scalars (Review.vue reads `response.data.data` as
 * plain row records via BTable).
 */

export interface ReReviewRow {
  re_review_entity_id: number;
  entity_id: number;
  hgnc_id: string;
  symbol: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term: string;
  hpo_mode_of_inheritance_term_name: string;
  category_id: number;
  category: string;
  ndd_phenotype: number;
  re_review_batch: number;
  re_review_review_saved: number;
  re_review_status_saved: number;
  re_review_submitted: number;
  re_review_approved: number;
  status_id: number;
  review_id: number;
  review_date: string;
  review_user_id: number;
  review_user_name: string;
  review_user_role: string;
  review_approving_user_id: number | null;
  status_date: string;
  status_user_id: number;
  status_user_name: string;
  status_user_role: string;
  status_approving_user_id: number | null;
}

export const reReviewTableOk: {
  links: Array<Record<string, string>>;
  meta: Array<Record<string, unknown>>;
  data: ReReviewRow[];
} = {
  links: [
    {
      self: 'null',
      prev: 'null',
      next: 'null',
    },
  ],
  meta: [
    {
      perPage: 10,
      currentPage: 1,
      totalPages: 1,
      totalItems: 1,
      pageItems: 1,
    },
  ],
  data: [
    {
      re_review_entity_id: 9001,
      entity_id: 501,
      hgnc_id: 'HGNC:12345',
      symbol: 'TEST1',
      disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
      disease_ontology_name: 'Test Disease',
      hpo_mode_of_inheritance_term: 'HP:0000006',
      hpo_mode_of_inheritance_term_name: 'Autosomal dominant',
      category_id: 1,
      category: 'Definitive',
      ndd_phenotype: 1,
      re_review_batch: 5,
      re_review_review_saved: 0,
      re_review_status_saved: 0,
      re_review_submitted: 0,
      re_review_approved: 0,
      status_id: 201,
      review_id: 101,
      review_date: '2025-06-01 12:00:00',
      review_user_id: 3,
      review_user_name: 'alice_admin',
      review_user_role: 'Administrator',
      review_approving_user_id: null,
      status_date: '2025-06-01 12:00:00',
      status_user_id: 3,
      status_user_name: 'alice_admin',
      status_user_role: 'Administrator',
      status_approving_user_id: null,
    },
  ],
};
