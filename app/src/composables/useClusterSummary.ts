// src/composables/useClusterSummary.ts
//
// LLM cluster-summary state and fetch logic shared by the functional
// gene-clusters (AnalyseGeneClusters.vue) and phenotype-clusters
// (AnalysesPhenotypeClusters.vue) analyses. Extracted so each component stays a
// thinner shell and the request-id race guard is unit-testable in isolation.
//
// The fetch is request-id guarded: a slower in-flight response for a previously
// selected cluster must never replace the summary of the cluster the user is
// currently viewing.
//
// The summary fetcher is injected (functional vs. phenotype endpoint) so the
// same guard/state logic serves both analyses. The set of HTTP status codes
// treated as "no summary yet" (cleared silently, no toast) is configurable
// because the functional path silences only a 404 while the phenotype path also
// silences a transient 503.

import { ref } from 'vue';
import type { Ref } from 'vue';
import type { ClusterSummary, ClusterSummaryParams } from '@/api/analysis';
import { isApiError } from '@/api/client';

/** Toast helper signature (matches `useToast().makeToast`). */
export type MakeToast = (message: unknown, title: string, variant: string) => void;

/** Injected summary fetcher (functional or phenotype cluster-summary endpoint). */
export type ClusterSummaryFetcher = (params: ClusterSummaryParams) => Promise<ClusterSummary>;

export interface UseClusterSummaryOptions {
  /**
   * HTTP status codes treated as "no summary yet" — cleared silently without a
   * toast. Defaults to `[404]` (functional path); the phenotype path passes
   * `[404, 503]` so a transient 503 stays silent too.
   */
  noSummaryStatuses?: number[];
}

export interface UseClusterSummary {
  /** Current AI summary payload, or null when none is loaded. */
  currentSummary: Ref<ClusterSummary | null>;
  /** True while a summary request is in flight. */
  summaryLoading: Ref<boolean>;
  /**
   * Fetch the LLM-generated summary for a specific cluster. Uses the cluster's
   * `hash_filter` as the `cluster_hash` parameter. A "no summary" status (404,
   * and optionally 503) is treated as "no summary yet" (not an error).
   */
  fetchClusterSummary: (
    clusterHash: string | null | undefined,
    clusterNumber: number | string
  ) => Promise<void>;
  /** Clear the current summary and invalidate any in-flight request. */
  clearClusterSummary: () => void;
}

export function useClusterSummary(
  makeToast: MakeToast,
  fetchSummary: ClusterSummaryFetcher,
  options: UseClusterSummaryOptions = {}
): UseClusterSummary {
  const noSummaryStatuses = options.noSummaryStatuses ?? [404];
  const currentSummary = ref<ClusterSummary | null>(null);
  const summaryLoading = ref(false);
  // Monotonic request id: only the newest request may commit its result.
  let summaryRequestId = 0;

  function clearClusterSummary(): void {
    summaryRequestId += 1;
    currentSummary.value = null;
    summaryLoading.value = false;
  }

  async function fetchClusterSummary(
    clusterHash: string | null | undefined,
    clusterNumber: number | string
  ): Promise<void> {
    if (!clusterHash) {
      clearClusterSummary();
      return;
    }

    const requestId = ++summaryRequestId;
    summaryLoading.value = true;
    try {
      const data = await fetchSummary({
        cluster_hash: clusterHash,
        cluster_number: String(clusterNumber),
      });
      if (requestId !== summaryRequestId) return;
      currentSummary.value = data;
    } catch (error) {
      if (requestId !== summaryRequestId) return;
      // Expected "no summary" statuses (404, optionally 503) are silent.
      if (
        isApiError(error) &&
        error.response &&
        noSummaryStatuses.includes(error.response.status)
      ) {
        currentSummary.value = null;
        return;
      }
      // Only reaches here for actual errors (network, 500, etc.)
      makeToast(
        'Unable to load AI summary. The summary may still be generating.',
        'Info',
        'info'
      );
      currentSummary.value = null;
    } finally {
      if (requestId === summaryRequestId) {
        summaryLoading.value = false;
      }
    }
  }

  return {
    currentSummary,
    summaryLoading,
    fetchClusterSummary,
    clearClusterSummary,
  };
}
