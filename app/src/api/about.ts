// app/src/api/about.ts
//
// About / CMS resource helpers.
//
// Mirrors api/endpoints/about_endpoints.R (mounted at /api/about).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// The about endpoints implement a simple draft/publish CMS used by the public
// About page (`/published` is unauthenticated) and the admin editor (`/draft`
// + `/publish`, both Administrator-gated by `require_role`). Sections are an
// arbitrary array of section objects — the R endpoint stores them as a JSON
// blob, so we surface an opaque `unknown[]` shape rather than locking the
// frontend into a specific section schema.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * A single section object stored in `about_content.sections_json`. The R
 * endpoint round-trips the array via `jsonlite::fromJSON` / `jsonlite::toJSON`
 * without inspecting the inner shape, so we type each section as an opaque
 * record. Callers can narrow it further via their own schema.
 */
export type AboutSection = Record<string, unknown>;

/**
 * Response from `PUT /api/about/draft` and `POST /api/about/publish` —
 * the R handler returns a `{ message: ..., version?: ... }` envelope.
 */
export interface AboutMutationResponse {
  message: string;
  /** Only present on `POST /api/about/publish`. */
  version?: number;
  /** Present on the 4xx/5xx error branches. */
  error?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/about/draft
 * Mirrors api/endpoints/about_endpoints.R:34 (handler `@get /draft`).
 *
 * Administrator-only. Returns the current user's draft if it exists, else the
 * latest published content, else an empty array.
 *
 * Throws AxiosError on non-2xx (401/403 if the caller is not an Administrator).
 */
export async function getAboutDraft(
  config?: AxiosRequestConfig,
): Promise<AboutSection[]> {
  return apiClient.get<AboutSection[]>('/api/about/draft', config);
}

/**
 * PUT /api/about/draft
 * Mirrors api/endpoints/about_endpoints.R:92 (handler `@put /draft`).
 *
 * Administrator-only. Replaces the current user's draft with the supplied
 * sections (atomic upsert via DB transaction).
 *
 * Throws AxiosError on non-2xx (400 for empty `sections`, 401/403 for the
 * auth filter, 500 if the DB transaction fails).
 */
export async function saveAboutDraft(
  sections: AboutSection[],
  config?: AxiosRequestConfig,
): Promise<AboutMutationResponse> {
  return apiClient.put<AboutMutationResponse, { sections: AboutSection[] }>(
    '/api/about/draft',
    { sections },
    config,
  );
}

/**
 * POST /api/about/publish
 * Mirrors api/endpoints/about_endpoints.R:168 (handler `@post /publish`).
 *
 * Administrator-only. Creates a new published version (auto-incremented from
 * the highest existing `version`) and deletes the user's draft.
 *
 * Throws AxiosError on non-2xx (same shape as `saveAboutDraft`).
 */
export async function publishAbout(
  sections: AboutSection[],
  config?: AxiosRequestConfig,
): Promise<AboutMutationResponse> {
  return apiClient.post<AboutMutationResponse, { sections: AboutSection[] }>(
    '/api/about/publish',
    { sections },
    config,
  );
}

/**
 * GET /api/about/published
 * Mirrors api/endpoints/about_endpoints.R:249 (handler `@get /published`).
 *
 * Public — no auth filter. Returns the latest published sections, or an empty
 * array when nothing has been published yet.
 *
 * Throws AxiosError on non-2xx (network errors only — 5xx is the typical
 * failure mode here).
 */
export async function getPublishedAbout(
  config?: AxiosRequestConfig,
): Promise<AboutSection[]> {
  return apiClient.get<AboutSection[]>('/api/about/published', config);
}
