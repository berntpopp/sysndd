import type { Ref } from 'vue';
import { ref, computed, toRef } from 'vue';
import axios from 'axios';
import type { ClinVarVariant } from '@/types';

/**
 * Return type for useGeneExternalData composable
 *
 * Simplified to ClinVar-only after gnomAD constraints were moved to
 * pre-annotated database columns (Plan 42-04).
 */
export interface UseGeneExternalDataReturn {
  /** ClinVar variants state */
  clinvar: {
    loading: Ref<boolean>;
    error: Ref<string | null>;
    data: Ref<ClinVarVariant[] | null>;
  };

  /** Overall loading state */
  loading: Ref<boolean>;

  /** Fetch ClinVar data from the per-source endpoint */
  fetchData: () => Promise<void>;

  /** Retry fetch (convenience method that calls fetchData) */
  retry: () => Promise<void>;
}

/**
 * Composable for fetching ClinVar variant data from the per-source endpoint
 *
 * @description
 * Fetches ClinVar variants from /api/external/gnomad/variants/<symbol>.
 * gnomAD constraint scores are no longer fetched live — they are pre-annotated
 * into the non_alt_loci_set database table during the HGNC update process
 * and served directly from the gene endpoint (Plan 42-04).
 *
 * @param geneSymbol - HGNC gene symbol (reactive ref or plain string)
 *
 * @returns ClinVar state, overall loading state, and fetch methods
 *
 * @example
 * ```ts
 * const symbol = ref('BRCA1');
 * const { clinvar, loading, fetchData } = useGeneExternalData(symbol);
 *
 * onMounted(() => fetchData());
 *
 * // Template access:
 * // <p v-if="clinvar.loading.value">Loading ClinVar data...</p>
 * // <p v-else-if="clinvar.error.value">{{ clinvar.error.value }}</p>
 * // <p v-else-if="clinvar.data.value">{{ clinvar.data.value.length }} variants</p>
 * ```
 */
export function useGeneExternalData(
  geneSymbol: Ref<string> | string,
): UseGeneExternalDataReturn {
  // Normalize to ref (handles both ref and plain string)
  const symbol = toRef(geneSymbol);

  // ClinVar state
  const clinvar = {
    loading: ref<boolean>(true),
    error: ref<string | null>(null),
    data: ref<ClinVarVariant[] | null>(null),
  };

  /**
   * Overall loading state
   */
  const loading = computed<boolean>(() => clinvar.loading.value);

  /**
   * Fetch ClinVar data from the per-source endpoint
   *
   * @description
   * - Resets loading to true, error to null
   * - GET /api/external/gnomad/variants/<symbol> (no auth header - public endpoint)
   * - Handles not found (404) as "no data" (not error)
   * - Handles errors from backend
   */
  async function fetchData(): Promise<void> {
    // Reset state
    clinvar.loading.value = true;
    clinvar.error.value = null;

    try {
      const response = await axios.get(
        `${import.meta.env.VITE_API_URL}/api/external/gnomad/variants/${symbol.value}`,
      );

      const result = response.data;

      // Backend returns { source, gene_symbol, gene_id, variants, variant_count }
      if (result.variants) {
        clinvar.data.value = result.variants;
        clinvar.error.value = null;
      } else {
        // No variants key in response
        clinvar.data.value = null;
        clinvar.error.value = null;
      }
    } catch (err) {
      if (axios.isAxiosError(err) && err.response?.status === 404) {
        // Gene not found in gnomAD ClinVar — not an error, just no data
        clinvar.data.value = null;
        clinvar.error.value = null;
      } else {
        const message =
          err instanceof Error ? err.message : 'Failed to fetch ClinVar data';
        clinvar.error.value = message;
        clinvar.data.value = null;
      }
    } finally {
      clinvar.loading.value = false;
    }
  }

  /**
   * Retry fetch (convenience method)
   */
  async function retry(): Promise<void> {
    await fetchData();
  }

  return {
    clinvar,
    loading,
    fetchData,
    retry,
  };
}
