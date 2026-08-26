// app/src/api/curate_variation.ts
//
// Typed client for the Curator variation-ontology curation queue (#612).
//
// Mirrors api/endpoints/curate_variation_endpoints.R (mounted at
// /api/curate/variation). Used by `views/curate/VariationSuggestions.vue`
// through `composables/useVariationSuggestions.ts`.
//
// THE ACTION ASYMMETRY IS SERVER-OWNED
// ------------------------------------
// `served` and `state` decide which action is legitimate:
//
//   Confirm  requires active_unconfirmed AND served
//   Dismiss  requires suggested          AND NOT served
//
// The UI uses those fields to decide what to OFFER, but the server re-derives
// both under a row lock before it writes. A client that offered the wrong action
// gets a `skipped` entry with a reason, never a wrong write.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';
import {
  normalizeApplyResult,
  normalizeSuggestionPage,
} from './curate-variation-wire';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type VariationSuggestionState = 'active_unconfirmed' | 'suggested';
export type VariationSuggestionSort = 'strength_desc' | 'strength_asc' | 'entity_asc';

/** One evidence record behind a queued assertion. `evidence_json` is NOT here. */
export interface VariationSuggestionEvidence {
  source_type: string | null;
  source_key: string | null;
  batch_id: string | null;
  /** 0-4, or `null` for NOT RECORDED — never render null as zero. */
  strength: number | null;
  /** The source's own stored wording. Displayed verbatim, never synthesised. */
  summary: string | null;
}

export interface VariationSuggestionRow {
  entity_id: number;
  symbol: string | null;
  disease_ontology_name: string | null;
  vario_id: string;
  vario_name: string | null;
  /** Part of the identity: `present` (1) and `absent` (5) are distinct claims. */
  modifier_id: number;
  state: VariationSuggestionState;
  /** True when the entity's primary approved review currently carries the term. */
  served: boolean;
  /** True when a curator review has displaced the import that wrote the evidence. */
  moved: boolean;
  max_strength: number | null;
  evidence: VariationSuggestionEvidence[];
}

export interface VariationSuggestionPage {
  meta: { page: number; page_size: number; total: number };
  data: VariationSuggestionRow[];
}

export interface VariationSuggestionIdentity {
  entity_id: number;
  vario_id: string;
  modifier_id: number;
}

export interface VariationSuggestionSkip extends VariationSuggestionIdentity {
  /** `not_found` | `wrong_state` | `not_served` | `served` | `state_changed`. */
  reason: string;
}

export interface VariationSuggestionApplyResult {
  requested: number;
  applied: number;
  /** Never empty-by-omission: a partial success reports every skip. */
  skipped: VariationSuggestionSkip[];
}

export interface ListVariationSuggestionsParams {
  state?: VariationSuggestionState;
  source_key?: string;
  max_strength?: number;
  /** Only `true` narrows the page; the client omits the param otherwise. */
  moved?: boolean;
  q?: string;
  sort?: VariationSuggestionSort;
  page?: number;
  page_size?: number;
}

const BASE = '/api/curate/variation';

// ---------------------------------------------------------------------------
// Requests
// ---------------------------------------------------------------------------

/**
 * One page of the queue.
 *
 * Undefined filters are omitted rather than sent empty: the API rejects an
 * unrecognised value with a 400 instead of silently ignoring it, which is what
 * keeps a mistyped filter from quietly showing a curator the wrong page.
 */
export async function listVariationSuggestions(
  params: ListVariationSuggestionsParams = {},
  config?: AxiosRequestConfig
): Promise<VariationSuggestionPage> {
  const query: Record<string, string | number> = {};
  if (params.state) query.state = params.state;
  if (params.source_key) query.source_key = params.source_key;
  if (params.max_strength !== undefined && params.max_strength !== null) {
    query.max_strength = params.max_strength;
  }
  if (params.moved) query.moved = 'true';
  if (params.q) query.q = params.q;
  if (params.sort) query.sort = params.sort;
  if (params.page) query.page = params.page;
  if (params.page_size) query.page_size = params.page_size;

  // apiClient already unwraps the axios envelope, so this is the payload itself.
  const payload = await apiClient.get<unknown>(`${BASE}/suggestions`, {
    params: query,
    ...config,
  });
  return normalizeSuggestionPage(payload);
}

async function applyVariationSuggestions(
  action: 'confirm' | 'dismiss',
  items: VariationSuggestionIdentity[],
  config?: AxiosRequestConfig
): Promise<VariationSuggestionApplyResult> {
  const payload = await apiClient.post<unknown, { items: VariationSuggestionIdentity[] }>(
    `${BASE}/suggestions/${action}`,
    { items },
    config
  );
  return normalizeApplyResult(payload);
}

/** Record a curator's confirmation for served, unconfirmed assertions. */
export function confirmVariationSuggestions(
  items: VariationSuggestionIdentity[],
  config?: AxiosRequestConfig
): Promise<VariationSuggestionApplyResult> {
  return applyVariationSuggestions('confirm', items, config);
}

/** Record a curator's rejection of unserved candidate terms. */
export function dismissVariationSuggestions(
  items: VariationSuggestionIdentity[],
  config?: AxiosRequestConfig
): Promise<VariationSuggestionApplyResult> {
  return applyVariationSuggestions('dismiss', items, config);
}
