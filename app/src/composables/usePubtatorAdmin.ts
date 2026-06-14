/**
 * usePubtatorAdmin - Composable for PubTator cache administration
 *
 * Provides functions for managing PubTator3 cache:
 * - Check cache status for a query
 * - Submit async fetch jobs with progress tracking
 * - Clear cache (hard reset)
 * - Backfill gene symbols for existing cache entries
 *
 * Network access goes through the typed `@/api/publication` client (which
 * routes via the `apiClient` axios singleton, inheriting the Authorization
 * header + 401 interceptor). The hand-rolled response interfaces were removed
 * in favour of the canonical types exported by that client.
 */

import { ref, computed } from 'vue';
import { useAsyncJob } from '@/composables/useAsyncJob';
import {
  getPubtatorCacheStatus,
  submitPubtatorUpdate,
  clearPubtatorCache,
  backfillPubtatorGenes,
  type PubtatorCacheStatus,
  type PubtatorAsyncSubmitResponse,
  type PubtatorClearCacheResponse,
  type PubtatorBackfillResponse,
} from '@/api/publication';
import { isApiError } from '@/api/client';

/**
 * Composable for PubTator admin operations with async job support
 */
export function usePubtatorAdmin() {
  const error = ref<string | null>(null);
  const lastStatus = ref<PubtatorCacheStatus | null>(null);
  const isCheckingStatus = ref(false);
  const isClearing = ref(false);
  const isBackfilling = ref(false);

  // Use the async job composable for fetch operations
  const asyncJob = useAsyncJob((jobId: string) => `/api/jobs/${encodeURIComponent(jobId)}/status`, {
    pollingInterval: 3000,
  });

  /**
   * Get cache status for a query
   */
  async function getCacheStatus(query: string): Promise<PubtatorCacheStatus> {
    isCheckingStatus.value = true;
    error.value = null;

    try {
      const status = await getPubtatorCacheStatus({ query });
      lastStatus.value = status;
      return status;
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
  ): Promise<PubtatorAsyncSubmitResponse> {
    error.value = null;

    try {
      const submit = await submitPubtatorUpdate({
        query,
        max_pages: maxPages,
        clear_old: clearOld,
      });

      // Start tracking the job with useAsyncJob
      asyncJob.startJob(submit.job_id);

      return submit;
    } catch (err) {
      if (isApiError<{ existing_job_id?: string }>(err) && err.response?.status === 409) {
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
  async function clearCache(): Promise<PubtatorClearCacheResponse> {
    isClearing.value = true;
    error.value = null;

    try {
      return await clearPubtatorCache();
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to clear cache';
      throw err;
    } finally {
      isClearing.value = false;
    }
  }

  /**
   * Backfill gene symbols for existing cache entries.
   *
   * The `queryId` argument is retained for call-site compatibility, but the
   * server endpoint always backfills every cached row whose `gene_symbols` is
   * NULL (it does not read a `query_id` parameter), so the argument is not
   * forwarded — behavior is identical to the previous implementation.
   *
   * @param _queryId - Optional query ID (accepted for compatibility; unused)
   */
  async function backfillGeneSymbols(
    _queryId?: string | number | null
  ): Promise<PubtatorBackfillResponse> {
    isBackfilling.value = true;
    error.value = null;

    try {
      return await backfillPubtatorGenes({
        timeout: 120000, // 2 minutes for potentially large backfill
      });
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to backfill gene symbols';
      throw err;
    } finally {
      isBackfilling.value = false;
    }
  }

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
