/**
 * usePubtatorAdmin - Composable for PubTator cache administration
 *
 * Provides functions for managing PubTator3 cache:
 * - Check cache status for a query
 * - Submit async fetch jobs with progress tracking
 * - Clear cache (hard reset)
 * - Backfill gene symbols for existing cache entries
 */

import { ref, computed } from 'vue';
import axios from 'axios';
import URLS from '@/assets/js/constants/url_constants';
import { useAsyncJob } from '@/composables/useAsyncJob';

/** Cache status response from API (unwrapped from Plumber array wrappers) */
export interface CacheStatus {
  query: string;
  cached: boolean;
  query_id: number | null;
  pages_cached: number;
  publications_cached: number;
  total_pages_available: number;
  total_results_available: number;
  pages_remaining: number;
  cache_date: string | null;
  estimated_fetch_time_minutes: number;
  message: string;
}

/** Job submit response from async API */
export interface JobSubmitResponse {
  job_id: string;
  status: string;
  query: string;
  max_pages: number;
  estimated_seconds: number;
  status_url: string;
}

/** Job result when completed */
export interface JobResult {
  status: string;
  success: boolean;
  query_id?: number;
  query?: string;
  pages_cached?: number;
  pages_total?: number;
  publications_count?: number;
  annotations_count?: number;
  message?: string;
}

/** Clear cache response (unwrapped from Plumber array wrappers) */
export interface ClearResponse {
  success: boolean;
  deleted?: {
    queries: number;
    publications: number;
    annotations: number;
  };
  message: string;
}

/** Backfill response (unwrapped from Plumber array wrappers) */
export interface BackfillResponse {
  success: boolean;
  updated_count?: number;
  message: string;
}

/**
 * Composable for PubTator admin operations with async job support
 */
export function usePubtatorAdmin() {
  const error = ref<string | null>(null);
  const lastStatus = ref<CacheStatus | null>(null);
  const isCheckingStatus = ref(false);
  const isClearing = ref(false);
  const isBackfilling = ref(false);

  const baseUrl = `${URLS.API_URL}/api/publication/pubtator`;

  // Use the async job composable for fetch operations
  const asyncJob = useAsyncJob(
    (jobId: string) => `${URLS.API_URL}/api/jobs/${jobId}/status`,
    { pollingInterval: 3000 }
  );

  /**
   * Get cache status for a query
   */
  async function getCacheStatus(query: string): Promise<CacheStatus> {
    isCheckingStatus.value = true;
    error.value = null;

    try {
      const response = await axios.get<CacheStatus>(`${baseUrl}/cache-status`, {
        params: { query },
      });
      lastStatus.value = response.data;
      return response.data;
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to get cache status';
      throw err;
    } finally {
      isCheckingStatus.value = false;
    }
  }

  /**
   * Submit async PubTator fetch job (non-blocking)
   * Returns immediately with job_id, use asyncJob state to track progress
   *
   * @param query - Search query
   * @param maxPages - Maximum pages to fetch (default 10)
   * @param clearOld - Whether to clear existing cache first (hard update)
   */
  async function submitFetchJob(
    query: string,
    maxPages: number = 10,
    clearOld: boolean = false
  ): Promise<JobSubmitResponse> {
    error.value = null;

    try {
      const response = await axios.post<JobSubmitResponse>(
        `${baseUrl}/update/submit`,
        null,
        {
          params: { query, max_pages: maxPages, clear_old: clearOld },
        }
      );

      // Start tracking the job with useAsyncJob
      asyncJob.startJob(response.data.job_id);

      return response.data;
    } catch (err) {
      if (axios.isAxiosError(err) && err.response?.status === 409) {
        // Duplicate job - extract existing job ID and track it
        const existingJobId = err.response.data.existing_job_id;
        if (existingJobId) {
          asyncJob.startJob(existingJobId);
          return {
            job_id: existingJobId,
            status: 'accepted',
            query,
            max_pages: maxPages,
            estimated_seconds: 0,
            status_url: `/api/jobs/${existingJobId}/status`,
          };
        }
      }
      error.value = err instanceof Error ? err.message : 'Failed to submit fetch job';
      throw err;
    }
  }

  /**
   * Clear cache for all queries
   */
  async function clearCache(): Promise<ClearResponse> {
    isClearing.value = true;
    error.value = null;

    try {
      const response = await axios.post<ClearResponse>(`${baseUrl}/clear-cache`);
      return response.data;
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to clear cache';
      throw err;
    } finally {
      isClearing.value = false;
    }
  }

  /**
   * Backfill gene symbols for existing cache entries
   * @param queryId - Optional query ID to backfill; if not provided, backfills all
   */
  async function backfillGeneSymbols(queryId?: number): Promise<BackfillResponse> {
    isBackfilling.value = true;
    error.value = null;

    try {
      const params: Record<string, number> = {};
      if (queryId !== undefined) params.query_id = queryId;

      const response = await axios.post<BackfillResponse>(`${baseUrl}/backfill-genes`, null, {
        params,
        timeout: 120000, // 2 minutes for potentially large backfill
      });
      return response.data;
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to backfill gene symbols';
      throw err;
    } finally {
      isBackfilling.value = false;
    }
  }

  /**
   * Get job result when completed
   */
  const jobResult = computed<JobResult | null>(() => {
    if (asyncJob.status.value !== 'completed') return null;
    // The result is stored in the job status response
    // Access it via the last status check
    return null; // Will be populated from job status polling
  });

  /**
   * Progress percentage (cached / total)
   */
  const cacheProgress = computed(() => {
    if (!lastStatus.value) return 0;
    const cached = lastStatus.value.pages_cached || 0;
    const total = lastStatus.value.total_pages_available || 1;
    return Math.round((cached / total) * 100);
  });

  return {
    // Local state
    error,
    lastStatus,
    isCheckingStatus,
    isClearing,
    isBackfilling,

    // Async job state (from useAsyncJob)
    jobId: asyncJob.jobId,
    jobStatus: asyncJob.status,
    jobStep: asyncJob.step,
    jobProgress: asyncJob.progress,
    jobError: asyncJob.error,
    jobElapsedSeconds: asyncJob.elapsedSeconds,

    // Async job computed
    hasRealProgress: asyncJob.hasRealProgress,
    progressPercent: asyncJob.progressPercent,
    elapsedTimeDisplay: asyncJob.elapsedTimeDisplay,
    progressVariant: asyncJob.progressVariant,
    statusBadgeClass: asyncJob.statusBadgeClass,
    isJobLoading: asyncJob.isLoading,
    isPolling: asyncJob.isPolling,

    // Local computed
    cacheProgress,
    jobResult,

    // Methods
    getCacheStatus,
    submitFetchJob,
    clearCache,
    backfillGeneSymbols,

    // Async job controls
    stopPolling: asyncJob.stopPolling,
    resetJob: asyncJob.reset,
  };
}

export default usePubtatorAdmin;
