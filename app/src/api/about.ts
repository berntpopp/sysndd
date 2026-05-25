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
// blob, but the current admin/public About UI owns the CMS section schema in
// `@/types`.

import type { AxiosRequestConfig } from 'axios';
import type { AboutSection } from '@/types';
import { apiClient } from './client';

export type { AboutSection };

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

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

type AboutSectionsPayload = AboutSection[] | { sections?: AboutSection[] | null };

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Normalize the canonical backend bare-array response while defensively
 * accepting the legacy `{ sections }` envelope used by older callers/tests.
 */
export function normalizeAboutSections(
  payload: AboutSectionsPayload | null | undefined
): AboutSection[] {
  if (Array.isArray(payload)) {
    return payload;
  }
  if (payload && Array.isArray(payload.sections)) {
    return payload.sections;
  }
  return [];
}

/**
 * GET /api/about/draft
 * Mirrors api/endpoints/about_endpoints.R:34 (handler `@get /draft`).
 *
 * Administrator-only. Returns the current user's draft if it exists, else the
 * latest published content, else an empty array.
 *
 * Throws AxiosError on non-2xx (401/403 if the caller is not an Administrator).
 */
export async function getAboutDraft(config?: AxiosRequestConfig): Promise<AboutSection[]> {
  const payload = await apiClient.get<AboutSectionsPayload>('/api/about/draft', config);
  return normalizeAboutSections(payload);
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
  config?: AxiosRequestConfig
): Promise<AboutMutationResponse> {
  return apiClient.put<AboutMutationResponse, { sections: AboutSection[] }>(
    '/api/about/draft',
    { sections },
    config
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
  config?: AxiosRequestConfig
): Promise<AboutMutationResponse> {
  return apiClient.post<AboutMutationResponse, { sections: AboutSection[] }>(
    '/api/about/publish',
    { sections },
    config
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
export async function getPublishedAbout(config?: AxiosRequestConfig): Promise<AboutSection[]> {
  const payload = await apiClient.get<AboutSectionsPayload>('/api/about/published', config);
  return normalizeAboutSections(payload);
}
