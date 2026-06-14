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
 * `@serializer json` (no `unboxedJSON`), so R/Plumber emits every scalar as a
 * 1-element array (`version: ["0.22.0"]`, `commit: ["unknown"]`, and likewise
 * for the `database` block). `getVersion()` unwraps these to plain scalars so
 * callers (AppVersionInfo) render `0.22.0` / `unknown` rather than the raw
 * `["0.22.0"]` / `["unknown"]` (the latter also broke the commit-badge guard,
 * since `["unknown"] !== "unknown"`).
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

// Plumber emits scalars as 1-element arrays on this endpoint; values may also
// already be plain scalars (test fixtures / a future unboxed serializer), so
// accept both shapes.
type MaybeArray<T> = T | T[];

interface RawDbVersion {
  version?: MaybeArray<string>;
  commit?: MaybeArray<string>;
  description?: MaybeArray<string | null>;
  updated_at?: MaybeArray<string | null>;
  available?: MaybeArray<boolean>;
}

interface RawApiVersion {
  version?: MaybeArray<string>;
  commit?: MaybeArray<string>;
  title?: MaybeArray<string>;
  description?: MaybeArray<string>;
  database?: RawDbVersion;
}

function unwrap<T>(value: MaybeArray<T> | null | undefined): T | undefined {
  if (value == null) return undefined;
  return Array.isArray(value) ? value[0] : value;
}

/**
 * GET /api/version
 * Mirrors api/endpoints/version_endpoints.R:16 (handler `@get /`).
 *
 * Public — no auth filter. Unwraps Plumber's 1-element-array scalars. Throws
 * AxiosError on non-2xx (5xx is the only realistic failure mode here).
 */
export async function getVersion(config?: AxiosRequestConfig): Promise<ApiVersion> {
  const raw = await apiClient.get<RawApiVersion>('/api/version', config);
  const result: ApiVersion = {
    version: unwrap(raw.version) ?? 'unknown',
    commit: unwrap(raw.commit) ?? 'unknown',
    title: unwrap(raw.title) ?? '',
    description: unwrap(raw.description) ?? '',
  };
  if (raw.database) {
    const db = raw.database;
    result.database = {
      version: unwrap(db.version) ?? 'unknown',
      commit: unwrap(db.commit) ?? 'unknown',
      description: unwrap(db.description) ?? null,
      updated_at: unwrap(db.updated_at) ?? null,
      available: unwrap(db.available) ?? false,
    };
  }
  return result;
}
