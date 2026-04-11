// test-utils/mocks/data/auth.ts
/**
 * Static fixtures mirroring the OpenAPI response shapes for authentication
 * endpoints defined in api/endpoints/authentication_endpoints.R (post Phase A1).
 *
 * Shapes follow R/Plumber's convention of wrapping JSON scalars in arrays — see
 * api/config/openapi/schemas/inferred/api_auth_signin_GET.json for the canonical
 * reference.
 */

export interface AuthSigninResponse {
  user_id: number[];
  user_name: string[];
  email: string[];
  user_role: string[];
  user_created: string[];
  abbreviation: string[];
  orcid: Record<string, unknown>;
  exp: number[];
}

export const signinOk: AuthSigninResponse = {
  user_id: [42],
  user_name: ['test_user'],
  email: ['test_user@example.org'],
  user_role: ['Viewer'],
  user_created: ['2025-01-01 00:00:00'],
  abbreviation: ['TU'],
  orcid: {},
  exp: [Math.floor(Date.now() / 1000) + 3600],
};

export const signinUnauthorized = {
  error: 'Authentication not successful.',
};

/**
 * POST /api/auth/authenticate returns the raw JWT token string (post A1).
 * Plumber serialises it as a one-element JSON array, so the mock mirrors
 * that shape.
 */
export const authenticateTokenOk: [string] = [
  'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.mock.signature',
];

export const authenticateBadRequest = 'Please provide valid username and password.';
export const authenticateUnauthorized = 'User or password wrong.';

export const refreshTokenOk: [string] = [
  'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.refreshed.signature',
];

export const refreshTokenUnauthorized = {
  error: 'Authentication not successful.',
};
