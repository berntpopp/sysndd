// src/composables/usePubtatorGenePublications.ts
//
// Per-gene publication-detail cache for the PubtatorNDD gene-prioritization
// table. Each expandable gene row lazily fetches the full publication rows for
// its PMIDs from the PubTator table endpoint and caches them by gene_symbol.
//
// Extracted from PubtatorNDDGenes.vue (issue: frontend perf & UX sprint) to:
//   - keep that component under the file-size ceiling,
//   - scope the cache to the current filter/sort so a filter change cannot show
//     stale publications in an expanded row (correctness fix), and
//   - handle aborts and real fetch errors correctly (genuine aborts are
//     silent; real errors exit the loading state and surface a toast).

import { ref } from 'vue';
import { listPubtatorTable } from '@/api/publication';
import type useToast from '@/composables/useToast';

export interface PubtatorPublicationData {
  search_id?: number;
  pmid: number;
  doi?: string;
  title?: string;
  journal?: string;
  date?: string;
  score?: number;
  gene_symbols?: string;
  text_hl?: string;
}

// Derive from the real useToast signature (accepts ToastVariant, not bare
// string) so consumers can pass useToast().makeToast under strict type-check.
type MakeToast = ReturnType<typeof useToast>['makeToast'];

/**
 * Typed API clients surface cancellation as either the platform AbortError or
 * Axios's transport-shaped CanceledError. Keep that implementation detail at
 * the boundary without importing the raw client into this composable.
 */
function isCancellation(error: unknown): boolean {
  if (error instanceof DOMException && error.name === 'AbortError') return true;
  if (typeof error !== 'object' || error === null) return false;
  const candidate = error as { name?: unknown; code?: unknown };
  return (
    candidate.name === 'AbortError' ||
    candidate.name === 'CanceledError' ||
    candidate.code === 'ERR_CANCELED'
  );
}

export function usePubtatorGenePublications(options: { makeToast: MakeToast }) {
  const { makeToast } = options;

  // Publication data cache (keyed by gene_symbol).
  const publicationCache = ref<Record<string, PubtatorPublicationData[]>>({});
  const loadingPublications = ref<Record<string, boolean>>({});

  // AbortControllers for per-gene fetches (prevents orphaned requests).
  const abortControllers = new Map<string, AbortController>();
  const requestGenerations = new Map<string, number>();
  let cacheGeneration = 0;

  /**
   * Reset the entire cache. Call when the gene filter/sort changes so an
   * expanded row never shows publications fetched under a previous query.
   * In-flight fetches are aborted so their late responses cannot repopulate
   * the freshly-cleared cache.
   */
  const resetCache = (): void => {
    cacheGeneration += 1;
    abortControllers.forEach((controller) => controller.abort());
    abortControllers.clear();
    requestGenerations.clear();
    publicationCache.value = {};
    loadingPublications.value = {};
  };

  /** Abort and clear every in-flight fetch (call on component unmount). */
  const cancelAll = (): void => {
    cacheGeneration += 1;
    abortControllers.forEach((controller) => controller.abort());
    abortControllers.clear();
    requestGenerations.clear();
  };

  /**
   * Fetch publication rows for a gene's PMIDs if not already cached.
   * Genuine aborts (filter change, unmount) are ignored silently; a real
   * upstream failure exits the loading state and surfaces a toast.
   */
  const fetchPublications = async (geneSymbol: string, pmids: string[]): Promise<void> => {
    if (pmids.length === 0) return;
    if (publicationCache.value[geneSymbol]) return; // Already cached

    // Cancel any in-flight request for this gene.
    abortControllers.get(geneSymbol)?.abort();
    const controller = new AbortController();
    const requestGeneration = (requestGenerations.get(geneSymbol) ?? 0) + 1;
    const startedCacheGeneration = cacheGeneration;
    const ownsRequest = () =>
      cacheGeneration === startedCacheGeneration &&
      requestGenerations.get(geneSymbol) === requestGeneration &&
      abortControllers.get(geneSymbol) === controller;
    requestGenerations.set(geneSymbol, requestGeneration);
    abortControllers.set(geneSymbol, controller);

    loadingPublications.value[geneSymbol] = true;

    try {
      const response = await listPubtatorTable(
        {
          filter: `any(pmid,${pmids.join(',')})`,
          fields: 'search_id,pmid,doi,title,journal,date,score,gene_symbols,text_hl',
          page_size: String(pmids.length),
        },
        { signal: controller.signal }
      );
      if (!ownsRequest()) return;
      publicationCache.value[geneSymbol] = (response.data as PubtatorPublicationData[]) || [];
    } catch (error) {
      if (!ownsRequest()) return;
      // Genuine aborts are not errors — the caller intentionally cancelled.
      // `isCancellation` recognises the typed client's transport shape without
      // pulling the raw Axios client into this composable.
      if (isCancellation(error)) {
        return;
      }
      // Real failure: surface it and record an empty result so the row exits
      // its spinner and shows the PMID fallback rather than spinning forever.
      makeToast(error, 'Error loading publication details', 'danger');
      publicationCache.value[geneSymbol] = [];
    } finally {
      if (ownsRequest()) {
        abortControllers.delete(geneSymbol);
        loadingPublications.value[geneSymbol] = false;
      }
    }
  };

  const getPublications = (geneSymbol: string): PubtatorPublicationData[] =>
    publicationCache.value[geneSymbol] || [];

  const isLoading = (geneSymbol: string): boolean => loadingPublications.value[geneSymbol] || false;

  const isCached = (geneSymbol: string): boolean =>
    publicationCache.value[geneSymbol] !== undefined;

  return {
    publicationCache,
    loadingPublications,
    fetchPublications,
    getPublications,
    isLoading,
    isCached,
    resetCache,
    cancelAll,
  };
}

export default usePubtatorGenePublications;
