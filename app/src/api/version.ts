// app/src/api/version.ts
//
// Version resource helper.
//
// Mirrors api/endpoints/version_endpoints.R (mounted at /api/version).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// The version endpoint is unauthenticated and lightweight — used by the
// AboutView footer, Wave 0's Playwright stack-readiness check, and the
// frontend's diagnostic banner.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Wire shape from `GET /api/version`. The R handler reads `version_spec.json`
 * and resolves the git commit hash from `GIT_COMMIT` env var or `git rev-parse`.
 * `commit` falls back to the literal string `"unknown"` if both sources fail.
 *
 * `@serializer json` (no `unboxedJSON`), but the response is a flat list with
 * scalar values that R/Plumber emits as 1-element arrays for plumber's
 * default JSON path; this happens to flatten cleanly to plain strings here
 * because `list()` of named scalars round-trips as `{ key: value }`. Confirmed
 * by inspecting the live response — no `unwrapScalar` needed.
 */
export interface ApiVersion {
  version: string;
  commit: string;
  title: string;
  description: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/version
 * Mirrors api/endpoints/version_endpoints.R:16 (handler `@get /`).
 *
 * Public — no auth filter. Throws AxiosError on non-2xx (5xx is the only
 * realistic failure mode for this endpoint).
 */
export async function getVersion(config?: AxiosRequestConfig): Promise<ApiVersion> {
  return apiClient.get<ApiVersion>('/api/version', config);
}
