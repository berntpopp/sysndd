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
 * Human-facing database version surface (issue #22).
 *
 * Mirrors the `database` block of `GET /api/version`, read from the
 * `db_version` table (migration 028). `available` is `false` when the API
 * could not read the table (it then reports `version`/`commit` as
 * `"unknown"`). `commit` is the last db/-folder git short hash, captured at
 * release time via `db/scripts/update-db-version.sh`. `description` and
 * `updated_at` may be omitted/null.
 */
export interface DbVersion {
  version: string;
  commit: string;
  description?: string | null;
  updated_at?: string | null;
  available: boolean;
}

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
 *
 * `database` is the issue #22 DB-version block. It is optional in the type so
 * older fixtures and any pre-#22 API still type-check.
 */
export interface ApiVersion {
  version: string;
  commit: string;
  title: string;
  description: string;
  database?: DbVersion;
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
