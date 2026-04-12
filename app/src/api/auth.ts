// app/src/api/auth.ts
/**
 * Authentication resource helpers.
 *
 * Phase E.E1 template: this file and `genes.ts` are the two fully implemented
 * resource modules that establish the shape of every future `api/<family>.ts`.
 * The other 25 families are stub files that v11.1 will fill in as each view
 * migrates off direct-axios calls.
 *
 * Wire shapes mirror the real plumber endpoints in
 * `api/endpoints/authentication_endpoints.R` and
 * `api/endpoints/user_endpoints.R` (Phase A.A1 JSON-body migration; the
 * legacy query-string form will be removed in Phase E.E7). Credentials MUST
 * always travel in the request body — query params leak into access logs,
 * Traefik logs, and browser history (OWASP, see A1 rationale in the
 * repo-root `CLAUDE.md`).
 */

import type { AxiosRequestConfig } from 'axios';
import { apiClient, unwrapScalar } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Response from GET /api/auth/signin. R/Plumber wraps most scalar columns in
 * 1-element arrays (`dplyr::mutate(across(..., str_split))` plus JSON scalar
 * serialisation). The shape mirrors the canonical fixture in
 * `app/src/test-utils/mocks/data/auth.ts`.
 */
export interface UserProfile {
  user_id: number[];
  user_name: string[];
  email: string[];
  user_role: string[];
  user_created: string[];
  abbreviation: string[];
  orcid: Record<string, unknown>;
  exp: number[];
}

export interface PasswordUpdateArgs {
  user_id_pass_change: number;
  old_pass: string;
  new_pass_1: string;
  new_pass_2: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * POST /api/auth/authenticate
 * Body: `{ user_name, password }` (A1 JSON-body shape)
 * Returns the bare JWT string (plumber serialises it as `[token]`, which
 * `unwrapScalar` collapses before handing it back).
 */
export async function authenticate(user_name: string, password: string): Promise<string> {
  const body = await apiClient.post<[string]>('/api/auth/authenticate', {
    user_name,
    password,
  });
  return unwrapScalar(body);
}

/**
 * GET /api/auth/signin
 * Call with the token already installed on the default `Authorization`
 * header (see `@/plugins/axios`), or pass a fresh one via `config.headers`
 * — the LoginView flow does exactly that immediately after `authenticate`
 * returns, before the plugin's default header has been refreshed.
 */
export async function signin(config?: AxiosRequestConfig): Promise<UserProfile> {
  return apiClient.get<UserProfile>('/api/auth/signin', config);
}

/**
 * GET /api/auth/refresh
 * Returns a fresh JWT string (plumber serialises it as `[token]`).
 */
export async function refresh(): Promise<string> {
  const body = await apiClient.get<[string]>('/api/auth/refresh');
  return unwrapScalar(body);
}

/**
 * PUT /api/user/password/update
 * Body: `{ user_id_pass_change, old_pass, new_pass_1, new_pass_2 }`
 * (A1 JSON-body shape; query-string fallback removed in E7).
 */
export async function changePassword(args: PasswordUpdateArgs): Promise<void> {
  await apiClient.put<void, PasswordUpdateArgs>('/api/user/password/update', args);
}
