// test-utils/mocks/data/users.ts
/**
 * Static fixtures mirroring the OpenAPI response shapes for user admin
 * endpoints defined in api/endpoints/user_endpoints.R.
 *
 * Reference: api/config/openapi/schemas/inferred/api_user_table_GET.json,
 * api_user_list_GET.json, api_user_role_list_GET.json.
 */

export interface UserTableRow {
  user_id: number;
  user_name: string;
  email: string;
  orcid: string | null;
  abbreviation: string;
  first_name: string;
  family_name: string;
  comment: string;
  terms_agreed: number;
  created_at: string;
  user_role: string;
  approved: number;
}

export interface PaginatedEnvelope<T> {
  links: Array<{
    prev: string;
    self: string;
    next: string;
    last: string;
  }>;
  meta: Array<{
    perPage: number;
    currentPage: number;
    totalPages: number;
    prevItemID: string | number;
    currentItemID: number;
    nextItemID: number;
    lastItemID: number;
    totalItems: number;
    fspec: unknown[];
    executionTime: string;
  }>;
  data: T[];
}

export const userTableOk: PaginatedEnvelope<UserTableRow> = {
  links: [
    {
      prev: '',
      self: '/api/user/table',
      next: '',
      last: '/api/user/table',
    },
  ],
  meta: [
    {
      perPage: 20,
      currentPage: 1,
      totalPages: 1,
      prevItemID: '',
      currentItemID: 1,
      nextItemID: 2,
      lastItemID: 2,
      totalItems: 2,
      fspec: [],
      executionTime: '0.01s',
    },
  ],
  data: [
    {
      user_id: 1,
      user_name: 'alice_admin',
      email: 'alice@example.org',
      orcid: null,
      abbreviation: 'AA',
      first_name: 'Alice',
      family_name: 'Admin',
      comment: '',
      terms_agreed: 1,
      created_at: '2025-01-01 00:00:00',
      user_role: 'Administrator',
      approved: 1,
    },
    {
      user_id: 2,
      user_name: 'bob_viewer',
      email: 'bob@example.org',
      orcid: '0000-0002-1234-5678',
      abbreviation: 'BV',
      first_name: 'Bob',
      family_name: 'Viewer',
      comment: '',
      terms_agreed: 1,
      created_at: '2025-01-02 00:00:00',
      user_role: 'Viewer',
      approved: 1,
    },
  ],
};

export const userListOk = [
  { user_id: 1, user_name: 'alice_admin', user_role: 'Administrator' },
  { user_id: 2, user_name: 'bob_viewer', user_role: 'Viewer' },
  { user_id: 3, user_name: 'carol_curator', user_role: 'Reviewer' },
];

export const userRoleListOk = [
  { user_role: 'Administrator' },
  { user_role: 'Curator' },
  { user_role: 'Reviewer' },
  { user_role: 'Viewer' },
];

export const userUpdateOk = {
  message: 'User successfully updated.',
};

export const userUpdateForbidden = {
  error: 'User update not authorized.',
};

export const userDeleteOk = {
  message: 'User successfully deleted.',
};

export const userDeleteNotFound = {
  error: 'User not found.',
};

export const bulkApproveOk = {
  message: 'Bulk approval successful.',
  approved_count: 2,
};

export const bulkApproveBadRequest = {
  error: 'No user ids provided.',
};

export const bulkAssignRoleOk = {
  message: 'Bulk role assignment successful.',
  updated_count: 2,
};

export const bulkAssignRoleBadRequest = {
  error: 'Invalid role or empty user list.',
};

export const bulkDeleteOk = {
  message: 'Bulk delete successful.',
  deleted_count: 2,
};

export const bulkDeleteBadRequest = {
  error: 'No user ids provided.',
};

export const passwordUpdateOk = {
  message: 'Password successfully changed.',
};

export const passwordUpdateConflict = {
  error: 'Password input problem.',
};
