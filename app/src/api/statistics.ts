// app/src/api/statistics.ts
//
// Statistics resource helpers (charts, news, leaderboards).
//
// Mirrors api/endpoints/statistics_endpoints.R (mounted at /api/statistics).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by `AdminStatistics.vue`, the home news ticker, and admin dashboards.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface CategoryCountParams {
  sort?: string;
  /** Default `"gene"`. */
  type?: string;
}

/**
 * Row shape from `GET /api/statistics/category_count`. Keys depend on the
 * memoised tibble layout — surface as a generic record with the well-known
 * fields documented inline.
 */
export type CategoryCountRow = Record<string, unknown>;

export interface NewsParams {
  /** Default 5. */
  n?: number;
}

/**
 * Row shape from `GET /api/statistics/news` — recently-added Definitive
 * entries.
 */
export type NewsRow = Record<string, unknown>;

export interface EntitiesOverTimeParams {
  /** `"entity_id"` (default) or `"symbol"`. */
  aggregate?: string;
  /** `"category"` (default), `"inheritance_filter"`, `"inheritance_multiple"`. */
  group?: string;
  /** Time bucket level — default `"month"`. */
  summarize?: string;
  filter?: string;
}

export interface EntitiesOverTimeResponse {
  meta: unknown;
  data: unknown[];
}

export interface AdminDateRangeParams {
  /** ISO date `YYYY-MM-DD`. */
  start_date: string;
  end_date: string;
}

export interface UpdatesStats {
  total_new_entities: number;
  unique_genes: number;
  average_per_day: number | null;
}

export interface RereviewStats {
  total_rereviews: number;
  percentage_finished: number;
  average_per_day: number | null;
}

export interface UpdatedReviewsStats {
  total_updated_reviews: number;
}

export interface UpdatedStatusesStats {
  total_updated_statuses: number;
}

export interface PublicationStatsParams {
  time_aggregate?: 'year' | 'month' | 'week' | 'day' | string;
  filter?: string;
  min_journal_count?: number;
  min_lastname_count?: number;
  min_keyword_count?: number;
}

/**
 * Top-level shape from `GET /api/statistics/publication_stats`. Inner arrays
 * are tibble rows — surface as opaque records.
 */
export interface PublicationStatsResponse {
  publication_type_counts: Array<Record<string, unknown>>;
  journal_counts: Array<Record<string, unknown>>;
  last_name_counts: Array<Record<string, unknown>>;
  update_date_aggregated: Array<Record<string, unknown>>;
  publication_date_aggregated: Array<Record<string, unknown>>;
  keyword_counts: Array<Record<string, unknown>>;
  time_aggregate_used: string;
  filter_used: string;
  min_journal_count_used: number;
  min_lastname_count_used: number;
  min_keyword_count_used: number;
}

export interface LeaderboardParams {
  top?: number;
  start_date?: string;
  end_date?: string;
  /** `"all_time"` (default) or `"range"`. */
  scope?: 'all_time' | 'range' | string;
}

export interface ContributorRow {
  user_id: number;
  user_name: string;
  display_name: string;
  entity_count: number;
}

export interface ContributorLeaderboardResponse {
  data: ContributorRow[];
  meta: {
    top: number;
    scope: string;
    start_date: string | null;
    end_date: string | null;
    total_contributors: number;
  };
}

export interface RereviewLeaderboardRow {
  user_id: number;
  user_name?: string;
  display_name?: string;
  re_review_count: number;
  [key: string]: unknown;
}

export interface RereviewLeaderboardResponse {
  data: RereviewLeaderboardRow[];
  meta?: Record<string, unknown>;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/statistics/category_count
 * Mirrors api/endpoints/statistics_endpoints.R:27 (handler `@get /category_count`).
 *
 * Returns the entity-by-category-and-inheritance count tibble.
 */
export async function getCategoryCount(
  params: CategoryCountParams = {},
  config?: AxiosRequestConfig,
): Promise<CategoryCountRow[]> {
  return apiClient.get<CategoryCountRow[]>('/api/statistics/category_count', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/statistics/news
 * Mirrors api/endpoints/statistics_endpoints.R:49 (handler `@get /news`).
 *
 * Returns the latest `n` Definitive entries for the news ticker.
 */
export async function getNews(
  params: NewsParams = {},
  config?: AxiosRequestConfig,
): Promise<NewsRow[]> {
  return apiClient.get<NewsRow[]>('/api/statistics/news', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/statistics/entities_over_time
 * Mirrors api/endpoints/statistics_endpoints.R:74 (handler `@get /entities_over_time`).
 *
 * Returns cumulative-entity time-series data with grouped meta information.
 */
export async function getEntitiesOverTime(
  params: EntitiesOverTimeParams = {},
  config?: AxiosRequestConfig,
): Promise<EntitiesOverTimeResponse> {
  return apiClient.get<EntitiesOverTimeResponse>('/api/statistics/entities_over_time', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/statistics/updates
 * Mirrors api/endpoints/statistics_endpoints.R:234 (handler `@get /updates`).
 *
 * Administrator-only. Returns new-entity counts within the given date range.
 */
export async function getUpdatesStats(
  params: AdminDateRangeParams,
  config?: AxiosRequestConfig,
): Promise<UpdatesStats> {
  return apiClient.get<UpdatesStats>('/api/statistics/updates', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/statistics/rereview
 * Mirrors api/endpoints/statistics_endpoints.R:279 (handler `@get /rereview`).
 *
 * Administrator-only. Returns submitted re-review counts within range.
 */
export async function getRereviewStats(
  params: AdminDateRangeParams,
  config?: AxiosRequestConfig,
): Promise<RereviewStats> {
  return apiClient.get<RereviewStats>('/api/statistics/rereview', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/statistics/updated_reviews
 * Mirrors api/endpoints/statistics_endpoints.R:348 (handler `@get /updated_reviews`).
 *
 * Administrator-only. Counts entities whose review changed in range.
 */
export async function getUpdatedReviewsStats(
  params: AdminDateRangeParams,
  config?: AxiosRequestConfig,
): Promise<UpdatedReviewsStats> {
  return apiClient.get<UpdatedReviewsStats>('/api/statistics/updated_reviews', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/statistics/updated_statuses
 * Mirrors api/endpoints/statistics_endpoints.R:386 (handler `@get /updated_statuses`).
 *
 * Administrator-only. Counts entities whose status changed in range.
 */
export async function getUpdatedStatusesStats(
  params: AdminDateRangeParams,
  config?: AxiosRequestConfig,
): Promise<UpdatedStatusesStats> {
  return apiClient.get<UpdatedStatusesStats>('/api/statistics/updated_statuses', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/statistics/publication_stats
 * Mirrors api/endpoints/statistics_endpoints.R:439 (handler `@get /publication_stats`).
 *
 * Aggregated counts for the publication table (journals, lastnames, keywords,
 * dates) with min-count thresholds.
 */
export async function getPublicationStats(
  params: PublicationStatsParams = {},
  config?: AxiosRequestConfig,
): Promise<PublicationStatsResponse> {
  return apiClient.get<PublicationStatsResponse>('/api/statistics/publication_stats', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/statistics/contributor_leaderboard
 * Mirrors api/endpoints/statistics_endpoints.R:565 (handler `@get /contributor_leaderboard`).
 *
 * Administrator-only. Top contributors by entity count.
 */
export async function getContributorLeaderboard(
  params: LeaderboardParams = {},
  config?: AxiosRequestConfig,
): Promise<ContributorLeaderboardResponse> {
  return apiClient.get<ContributorLeaderboardResponse>(
    '/api/statistics/contributor_leaderboard',
    {
      ...config,
      params: { ...(config?.params as object | undefined), ...params },
    },
  );
}

/**
 * GET /api/statistics/rereview_leaderboard
 * Mirrors api/endpoints/statistics_endpoints.R:651 (handler `@get /rereview_leaderboard`).
 *
 * Administrator-only. Top reviewers by submitted re-review count.
 */
export async function getRereviewLeaderboard(
  params: LeaderboardParams = {},
  config?: AxiosRequestConfig,
): Promise<RereviewLeaderboardResponse> {
  return apiClient.get<RereviewLeaderboardResponse>(
    '/api/statistics/rereview_leaderboard',
    {
      ...config,
      params: { ...(config?.params as object | undefined), ...params },
    },
  );
}
