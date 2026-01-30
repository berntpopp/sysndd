import type { Ref } from 'vue';
import { ref, computed, toRef } from 'vue';
import axios from 'axios';
import type { MGIPhenotypeData, RGDPhenotypeData } from '@/types/external';

/**
 * Return type for useModelOrganismData composable
 *
 * Provides per-source state isolation for MGI and RGD phenotype data,
 * enabling independent loading/error/data tracking for graceful degradation.
 */
export interface UseModelOrganismDataReturn {
  /** MGI (Mouse Genome Informatics) phenotype data state */
  mgi: {
    loading: Ref<boolean>;
    error: Ref<string | null>;
    data: Ref<MGIPhenotypeData | null>;
  };

  /** RGD (Rat Genome Database) phenotype data state */
  rgd: {
    loading: Ref<boolean>;
    error: Ref<string | null>;
    data: Ref<RGDPhenotypeData | null>;
  };

  /** Overall loading state (true if any source is loading) */
  loading: Ref<boolean>;

  /** Fetch MGI and RGD data from per-source endpoints */
  fetchData: () => Promise<void>;

  /** Retry fetch (convenience method that calls fetchData) */
  retry: () => Promise<void>;
}

/**
 * Composable for fetching model organism phenotype data from MGI and RGD
 *
 * @description
 * Fetches mouse phenotype data from /api/external/mgi/phenotypes/<symbol>
 * and rat phenotype data from /api/external/rgd/phenotypes/<symbol>.
 *
 * Follows the per-source state isolation pattern from useGeneExternalData:
 * - Each source has independent loading/error/data refs
 * - 404 responses treated as "no data" (not error)
 * - Parallel fetching with Promise.allSettled
 * - No auto-fetch (consumer calls fetchData() explicitly)
 *
 * @param geneSymbol - HGNC gene symbol (reactive ref or plain string)
 *
 * @returns MGI state, RGD state, overall loading state, and fetch methods
 *
 * @example
 * ```ts
 * const symbol = ref('MECP2');
 * const { mgi, rgd, loading, fetchData } = useModelOrganismData(symbol);
 *
 * onMounted(() => fetchData());
 *
 * // Template access:
 * // <p v-if="mgi.loading.value">Loading MGI data...</p>
 * // <p v-else-if="mgi.error.value">{{ mgi.error.value }}</p>
 * // <p v-else-if="mgi.data.value">{{ mgi.data.value.phenotype_count }} mouse phenotypes</p>
 * ```
 */
export function useModelOrganismData(geneSymbol: Ref<string> | string): UseModelOrganismDataReturn {
  // Normalize to ref (handles both ref and plain string)
  const symbol = toRef(geneSymbol);

  // MGI state
  const mgi = {
    loading: ref<boolean>(true),
    error: ref<string | null>(null),
    data: ref<MGIPhenotypeData | null>(null),
  };

  // RGD state
  const rgd = {
    loading: ref<boolean>(true),
    error: ref<string | null>(null),
    data: ref<RGDPhenotypeData | null>(null),
  };

  /**
   * Overall loading state
   */
  const loading = computed<boolean>(() => mgi.loading.value || rgd.loading.value);

  /**
   * Fetch MGI and RGD data from per-source endpoints
   *
   * @description
   * - Resets loading to true, error to null for both sources
   * - GET /api/external/mgi/phenotypes/<symbol> (MGI)
   * - GET /api/external/rgd/phenotypes/<symbol> (RGD)
   * - Handles not found (404) as "no data" (not error)
   * - Handles errors from backend
   */
  async function fetchData(): Promise<void> {
    // Reset state
    mgi.loading.value = true;
    mgi.error.value = null;
    rgd.loading.value = true;
    rgd.error.value = null;

    // Fetch both sources in parallel
    await Promise.allSettled([
      // Fetch MGI
      (async () => {
        try {
          const response = await axios.get(
            `${import.meta.env.VITE_API_URL}/api/external/mgi/phenotypes/${symbol.value}`
          );

          const result = response.data;

          // Backend returns MGIPhenotypeData interface
          if (result && result.source === 'mgi') {
            mgi.data.value = result as MGIPhenotypeData;
            mgi.error.value = null;
          } else {
            // Unexpected response format
            mgi.data.value = null;
            mgi.error.value = null;
          }
        } catch (err) {
          if (axios.isAxiosError(err) && err.response?.status === 404) {
            // Gene not found in MGI — not an error, just no data
            mgi.data.value = null;
            mgi.error.value = null;
          } else {
            const message =
              err instanceof Error ? err.message : 'Failed to fetch MGI phenotype data';
            mgi.error.value = message;
            mgi.data.value = null;
          }
        } finally {
          mgi.loading.value = false;
        }
      })(),

      // Fetch RGD
      (async () => {
        try {
          const response = await axios.get(
            `${import.meta.env.VITE_API_URL}/api/external/rgd/phenotypes/${symbol.value}`
          );

          const result = response.data;

          // Backend returns RGDPhenotypeData interface
          if (result && result.source === 'rgd') {
            rgd.data.value = result as RGDPhenotypeData;
            rgd.error.value = null;
          } else {
            // Unexpected response format
            rgd.data.value = null;
            rgd.error.value = null;
          }
        } catch (err) {
          if (axios.isAxiosError(err) && err.response?.status === 404) {
            // Gene not found in RGD — not an error, just no data
            rgd.data.value = null;
            rgd.error.value = null;
          } else {
            const message =
              err instanceof Error ? err.message : 'Failed to fetch RGD phenotype data';
            rgd.error.value = message;
            rgd.data.value = null;
          }
        } finally {
          rgd.loading.value = false;
        }
      })(),
    ]);
  }

  /**
   * Retry fetch (convenience method)
   */
  async function retry(): Promise<void> {
    await fetchData();
  }

  return {
    mgi,
    rgd,
    loading,
    fetchData,
    retry,
  };
}
