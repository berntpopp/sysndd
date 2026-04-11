// test-utils/mocks/data/statuses.ts
/**
 * Static fixtures mirroring the OpenAPI response shapes for status endpoints
 * defined in api/endpoints/status_endpoints.R.
 *
 * Reference: api/config/openapi/schemas/inferred/api_status_GET.json,
 * api_list_status_GET.json.
 */

export interface StatusRow {
  status_id: number;
  entity_id: number;
  hgnc_id: string;
  symbol: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  category_id: number;
  status_value: string;
  status_date: string;
  status_user_name: string;
  status_user_role: string;
  status_approved: number;
  approving_user_name: string | null;
  approving_user_role: string | null;
  approving_user_id: number | null;
  comment: string | null;
}

export const statusByIdOk: StatusRow = {
  status_id: 201,
  entity_id: 501,
  hgnc_id: 'HGNC:12345',
  symbol: 'TEST1',
  disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
  disease_ontology_name: 'Test Disease',
  category_id: 1,
  status_value: 'Definitive',
  status_date: '2025-06-01 12:00:00',
  status_user_name: 'alice_admin',
  status_user_role: 'Administrator',
  status_approved: 0,
  approving_user_name: null,
  approving_user_role: null,
  approving_user_id: null,
  comment: null,
};

export const statusByIdNotFound = {
  error: 'Status not found.',
};

export const statusCreateOk = {
  message: 'Status successfully created.',
  status_id: [202],
};

export const statusCreateBadRequest = {
  error: 'Missing or invalid status fields.',
};

export const statusUpdateOk = {
  message: 'Status successfully updated.',
};

export const statusUpdateBadRequest = {
  error: 'Missing or invalid status fields.',
};

export const statusApproveByIdOk = {
  message: 'Status approved.',
  status_id: 201,
};

export const statusApproveByIdNotFound = {
  error: 'Status not found.',
};

export const statusApproveAllOk = {
  message: 'All pending statuses approved.',
  approved_count: 5,
};

export const statusApproveAllForbidden = {
  error: 'Bulk approval forbidden for non-admin.',
};
