// app/src/api/user.ts
//
// User resource helpers.
//
// Mirrors api/endpoints/user_endpoints.R (mounted at /api/user).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by the UserAdmin/UserApproval/UserProfile views and the curate flows
// that surface contributor stats.
//
// NOTE: `PUT /api/user/password/update` is already typed in `auth.ts` as
// `changePassword(args)` (it cohabits with the auth flow because the
// reset-via-token endpoints live there). It is NOT re-exported here to
// avoid drift between the two surfaces.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ListUserTableParams {
  filter?: string;
  sort?: string;
  page_after?: string | number;
  page_size?: string;
  fspec?: string;
}

/**
 * One row of the user-table response. Admin sees every user; Curator sees
 * only the unapproved subset. Mirrors the columns the R handler `select`s.
 */
export interface UserTableRow {
  user_id: number;
  user_name: string;
  email: string | null;
  orcid: string | null;
  abbreviation: string | null;
  first_name: string | null;
  family_name: string | null;
  comment: string | null;
  terms_agreed: number | string | null;
  created_at: string | null;
  user_role: string;
  approved: number | string;
}

/**
 * Generic cursor-pagination envelope returned by the `table` listing.
 */
export interface UserTableResponse {
  links: unknown;
  meta: unknown;
  data: UserTableRow[];
}

/**
 * Response from `GET /api/user/<user_id>/contributions`.
 */
export interface UserContributions {
  user_id: number | string;
  active_status: number;
  active_reviews: number;
}

export interface ApproveUserParams {
  /** R coerces "TRUE"/"FALSE". */
  status_approval?: boolean;
}

/**
 * Response from `PUT /api/user/approval`.
 *
 * The R handler returns three different shapes depending on outcome:
 *   - rejection:                `{ message, user_id }`
 *   - approve + email success:  `{ message, user_id, user_name, email_sent: true }`
 *   - approve + email failure:  `{ message, user_id, user_name, email, email_sent: false, email_error }`
 */
export interface ApproveUserResponse {
  message: string;
  user_id: number;
  user_name?: string;
  email?: string;
  email_sent?: boolean;
  email_error?: string;
}

export interface ChangeRoleParams {
  /** Defaults to "Viewer" server-side when omitted. */
  role_assigned?: string;
}

/**
 * Response from `GET /api/user/role_list`.
 */
export interface UserRole {
  role: string;
}

export interface ListUsersByRoleParams {
  /** Comma-separated list of role names; defaults to "Viewer" server-side. */
  roles?: string;
}

/**
 * Compact user row returned by `GET /api/user/list?roles=...`.
 */
export interface UserListRow {
  user_id: number;
  user_name: string;
  user_role: string;
}

/**
 * Body for `PUT /api/user/profile` (self-service email/orcid update).
 */
export interface UpdateProfileRequest {
  email?: string;
  orcid?: string;
}

export interface UpdateProfileResponse {
  message: string;
  updated_fields: string[];
}

/**
 * Body for `POST /api/user/password/reset/request`. Email-only — the
 * endpoint returns 200 even when the email is unknown to avoid account
 * enumeration.
 */
export interface PasswordResetRequest {
  email: string;
}

/**
 * Body for `POST /api/user/password/reset/change`. The reset JWT travels
 * in the `Authorization: Bearer ...` header; passwords MUST be in the body.
 */
export interface PasswordResetChangeRequest {
  password: string;
  password_confirm: string;
}

export interface PasswordResetChangeResponse {
  message: string;
}

/**
 * Body for `PUT /api/user/update`. The R handler nests the user fields
 * under a `user_details` key. `user_id` is mandatory; everything else is
 * optional patch material.
 */
export interface UpdateUserRequest {
  user_details: {
    user_id: number;
    user_name?: string;
    email?: string;
    user_role?: string;
    approved?: boolean | number | string;
    abbreviation?: string;
    first_name?: string;
    family_name?: string;
    comment?: string;
    orcid?: string;
    [key: string]: unknown;
  };
}

export interface UpdateUserResponse {
  message: string;
}

/**
 * Common response shape for the bulk endpoints.
 */
export interface BulkUserResponse {
  processed: number;
  message: string;
}

export interface BulkApproveRequest {
  /** Max 20 ids per request (server-enforced). */
  user_ids: number[];
}

export interface BulkDeleteRequest {
  /** Max 20 ids per request. Rejected with 403 if any id is an Administrator. */
  user_ids: number[];
}

export interface BulkAssignRoleRequest {
  /** Max 20 ids per request. */
  user_ids: number[];
  /** One of "Administrator", "Curator", "Reviewer", "Viewer". */
  role: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/user/table
 * Mirrors api/endpoints/user_endpoints.R:28 (handler `@get table`).
 *
 * Curator+ only. Admin sees all users, Curator sees only unapproved users.
 * Supports filter/sort/cursor pagination; returns the `{ links, meta, data }`
 * envelope. Throws AxiosError on non-2xx (401/403).
 */
export async function getUserTable(
  params: ListUserTableParams = {},
  config?: AxiosRequestConfig
): Promise<UserTableResponse> {
  return apiClient.get<UserTableResponse>('/api/user/table', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/user/<user_id>/contributions
 * Mirrors api/endpoints/user_endpoints.R:159 (handler `@get <user_id>/contributions`).
 *
 * Users may view their own contributions; Reviewer+ may view any user.
 * Throws AxiosError on non-2xx (401/403).
 */
export async function getUserContributions(
  user_id: number | string,
  config?: AxiosRequestConfig
): Promise<UserContributions> {
  const path = `/api/user/${encodeURIComponent(String(user_id))}/contributions`;
  return apiClient.get<UserContributions>(path, config);
}

/**
 * PUT /api/user/approval
 * Mirrors api/endpoints/user_endpoints.R:202 (handler `@put approval`).
 *
 * Curator+ only. `status_approval=true` approves and sends a welcome
 * email; `false` (or omitted) rejects + deletes the user.
 *
 * Throws AxiosError on non-2xx (409 if user does not exist or is already
 * active).
 */
export async function approveUser(
  user_id: number | string,
  params: ApproveUserParams = {},
  config?: AxiosRequestConfig
): Promise<ApproveUserResponse> {
  return apiClient.put<ApproveUserResponse>('/api/user/approval', undefined, {
    ...config,
    params: {
      ...(config?.params as object | undefined),
      user_id,
      ...params,
    },
  });
}

/**
 * PUT /api/user/change_role
 * Mirrors api/endpoints/user_endpoints.R:305 (handler `@put change_role`).
 *
 * Curator+ only. Admin can assign any role; Curator can only assign
 * non-Administrator roles. Returns 403 on the latter violation.
 */
export async function changeUserRole(
  user_id: number | string,
  params: ChangeRoleParams = {},
  config?: AxiosRequestConfig
): Promise<unknown> {
  return apiClient.put<unknown>('/api/user/change_role', undefined, {
    ...config,
    params: {
      ...(config?.params as object | undefined),
      user_id,
      ...params,
    },
  });
}

/**
 * GET /api/user/role_list
 * Mirrors api/endpoints/user_endpoints.R:332 (handler `@get role_list`).
 *
 * Curator+ only. Admin sees every role; Curator sees every role except
 * "Administrator".
 */
export async function getRoleList(config?: AxiosRequestConfig): Promise<UserRole[]> {
  return apiClient.get<UserRole[]>('/api/user/role_list', config);
}

/**
 * GET /api/user/list
 * Mirrors api/endpoints/user_endpoints.R:357 (handler `@get list`).
 *
 * Curator+ only. Returns approved users matching `roles` (comma-separated).
 * Throws AxiosError on non-2xx (400 when any role is not in the allowed
 * set).
 */
export async function listUsersByRole(
  params: ListUsersByRoleParams = {},
  config?: AxiosRequestConfig
): Promise<UserListRow[]> {
  return apiClient.get<UserListRow[]>('/api/user/list', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * PUT /api/user/profile
 * Mirrors api/endpoints/user_endpoints.R:549 (handler `@put profile`).
 *
 * Self-service. Authenticated users update their own email and/or ORCID.
 * Throws AxiosError on non-2xx (400 invalid format / email already in use,
 * 401 unauthenticated).
 */
export async function updateProfile(
  body: UpdateProfileRequest,
  config?: AxiosRequestConfig
): Promise<UpdateProfileResponse> {
  return apiClient.put<UpdateProfileResponse, UpdateProfileRequest>(
    '/api/user/profile',
    body,
    config
  );
}

/**
 * POST /api/user/password/reset/request
 * Mirrors api/endpoints/user_endpoints.R:645 (handler `@post password/reset/request`).
 *
 * Public. Always returns 200 on a well-formed email to avoid account
 * enumeration; 400 only on a syntactically invalid email.
 */
export async function requestPasswordReset(
  body: PasswordResetRequest,
  config?: AxiosRequestConfig
): Promise<unknown> {
  return apiClient.post<unknown, PasswordResetRequest>(
    '/api/user/password/reset/request',
    body,
    config
  );
}

/**
 * POST /api/user/password/reset/change
 * Mirrors api/endpoints/user_endpoints.R:721 (handler `@post password/reset/change`).
 *
 * Public — but requires a Bearer reset-token in `Authorization`. The
 * password fields travel in the JSON body per OWASP. Throws AxiosError on
 * non-2xx (401 expired token, 404 user not found, 409 password rule
 * violation).
 */
export async function resetPasswordWithToken(
  body: PasswordResetChangeRequest,
  config?: AxiosRequestConfig
): Promise<PasswordResetChangeResponse> {
  return apiClient.post<PasswordResetChangeResponse, PasswordResetChangeRequest>(
    '/api/user/password/reset/change',
    body,
    config
  );
}

/**
 * DELETE /api/user/delete
 * Mirrors api/endpoints/user_endpoints.R:801 (handler `@delete delete`).
 *
 * Administrator only. Throws AxiosError on non-2xx (400 invalid id, 404
 * user not found, 500 delete failed).
 */
export async function deleteUser(
  user_id: number | string,
  config?: AxiosRequestConfig
): Promise<{ message: string }> {
  return apiClient.delete<{ message: string }>('/api/user/delete', {
    ...config,
    params: {
      ...(config?.params as object | undefined),
      user_id,
    },
  });
}

/**
 * PUT /api/user/update
 * Mirrors api/endpoints/user_endpoints.R:855 (handler `@put update`).
 *
 * Administrator only. Updates the wrapped `user_details`. If `approved`
 * flips to `1` the handler also sends the welcome email and generates a
 * password when one isn't already on file.
 *
 * Throws AxiosError on non-2xx (400 missing user_id / abbreviation /
 * invalid `approved`; 500 update failed).
 */
export async function updateUser(
  body: UpdateUserRequest,
  config?: AxiosRequestConfig
): Promise<UpdateUserResponse> {
  return apiClient.put<UpdateUserResponse, UpdateUserRequest>('/api/user/update', body, config);
}

/**
 * POST /api/user/bulk_approve
 * Mirrors api/endpoints/user_endpoints.R:965 (handler `@post bulk_approve`).
 *
 * Curator+ only. Atomic; max 20 ids. Throws AxiosError on non-2xx (400
 * empty/over-cap, 409 service failure).
 */
export async function bulkApproveUsers(
  body: BulkApproveRequest,
  config?: AxiosRequestConfig
): Promise<BulkUserResponse> {
  return apiClient.post<BulkUserResponse, BulkApproveRequest>(
    '/api/user/bulk_approve',
    body,
    config
  );
}

/**
 * POST /api/user/bulk_delete
 * Mirrors api/endpoints/user_endpoints.R:1015 (handler `@post bulk_delete`).
 *
 * Administrator only. Atomic; max 20 ids. Rejects with 403 when the
 * selection contains any Administrator. Throws AxiosError on non-2xx
 * (400 empty/over-cap, 409 service failure).
 */
export async function bulkDeleteUsers(
  body: BulkDeleteRequest,
  config?: AxiosRequestConfig
): Promise<BulkUserResponse> {
  return apiClient.post<BulkUserResponse, BulkDeleteRequest>('/api/user/bulk_delete', body, config);
}

/**
 * POST /api/user/bulk_assign_role
 * Mirrors api/endpoints/user_endpoints.R:1072 (handler `@post bulk_assign_role`).
 *
 * Curator+ only. Atomic; max 20 ids. Curators cannot assign Administrator.
 * Throws AxiosError on non-2xx (400 invalid input, 403 Curator assigning
 * Administrator, 409 service failure).
 */
export async function bulkAssignRole(
  body: BulkAssignRoleRequest,
  config?: AxiosRequestConfig
): Promise<BulkUserResponse> {
  return apiClient.post<BulkUserResponse, BulkAssignRoleRequest>(
    '/api/user/bulk_assign_role',
    body,
    config
  );
}
