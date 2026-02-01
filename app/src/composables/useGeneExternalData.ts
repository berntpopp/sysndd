import type { Ref } from 'vue';
import { ref, computed, toRef } from 'vue';
import axios from 'axios';
import type { ClinVarVariant } from '@/types';
import type { AlphaFoldMetadata } from '@/types/alphafold';

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

  /** AlphaFold 3D structure metadata state */
  alphafold: {
    loading: Ref<boolean>;
    error: Ref<string | null>;
    data: Ref<AlphaFoldMetadata | null>;
  };

  /** Overall loading state */
  loading: Ref<boolean>;

  /** Fetch ClinVar data from the per-source endpoint */
  fetchData: () => Promise<void>;

  /** Retry fetch (convenience method that calls fetchData) */
  retry: () => Promise<void>;
}

/**
 * Composable for fetching ClinVar and AlphaFold data from per-source endpoints
 *
 * @description
 * Fetches ClinVar variants from /api/external/gnomad/variants/<symbol>
 * and AlphaFold structure metadata from /api/external/alphafold/structure/<symbol>.
 * gnomAD constraint scores are no longer fetched live — they are pre-annotated
 * into the non_alt_loci_set database table during the HGNC update process
 * and served directly from the gene endpoint (Plan 42-04).
 *
 * @param geneSymbol - HGNC gene symbol (reactive ref or plain string)
 *
 * @returns ClinVar state, AlphaFold state, overall loading state, and fetch methods
 *
 * @example
 * ```ts
 * const symbol = ref('BRCA1');
 * const { clinvar, alphafold, loading, fetchData } = useGeneExternalData(symbol);
 *
 * onMounted(() => fetchData());
 *
 * // Template access:
 * // <p v-if="clinvar.loading.value">Loading ClinVar data...</p>
 * // <p v-else-if="clinvar.error.value">{{ clinvar.error.value }}</p>
 * // <p v-else-if="clinvar.data.value">{{ clinvar.data.value.length }} variants</p>
 * ```
 */
export function useGeneExternalData(geneSymbol: Ref<string> | string): UseGeneExternalDataReturn {
  // Normalize to ref (handles both ref and plain string)
  const symbol = toRef(geneSymbol);

  // ClinVar state
  const clinvar = {
    loading: ref<boolean>(true),
    error: ref<string | null>(null),
    data: ref<ClinVarVariant[] | null>(null),
  };

  // AlphaFold state
  const alphafold = {
    loading: ref<boolean>(true),
    error: ref<string | null>(null),
    data: ref<AlphaFoldMetadata | null>(null),
  };

  /**
   * Overall loading state
   */
  const loading = computed<boolean>(() => clinvar.loading.value || alphafold.loading.value);

  /**
   * Fetch ClinVar and AlphaFold data from per-source endpoints
   *
   * @description
   * - Resets loading to true, error to null for both sources
   * - GET /api/external/gnomad/variants/<symbol> (ClinVar)
   * - GET /api/external/alphafold/structure/<symbol> (AlphaFold)
   * - Handles not found (404) as "no data" (not error)
   * - Handles errors from backend
   */
  async function fetchData(): Promise<void> {
    // Reset state
    clinvar.loading.value = true;
    clinvar.error.value = null;
    alphafold.loading.value = true;
    alphafold.error.value = null;

    // Fetch both sources in parallel
    await Promise.allSettled([
      // Fetch ClinVar
      (async () => {
        try {
          const response = await axios.get(
            `${import.meta.env.VITE_API_URL}/api/external/gnomad/variants/${symbol.value}`,
            { withCredentials: true }
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
            const message = err instanceof Error ? err.message : 'Failed to fetch ClinVar data';
            clinvar.error.value = message;
            clinvar.data.value = null;
          }
        } finally {
          clinvar.loading.value = false;
        }
      })(),

      // Fetch AlphaFold
      (async () => {
        try {
          const response = await axios.get(
            `${import.meta.env.VITE_API_URL}/api/external/alphafold/structure/${symbol.value}`,
            { withCredentials: true }
          );

          const result = response.data;

          // Check if AlphaFold data has found=false (no structure available)
          if (result.found === false) {
            alphafold.data.value = null;
            alphafold.error.value = null; // Not an error, just no structure available
          } else {
            alphafold.data.value = result as AlphaFoldMetadata;
            alphafold.error.value = null;
          }
        } catch (err) {
          if (axios.isAxiosError(err) && err.response?.status === 404) {
            // Gene not found in AlphaFold — not an error, just no data
            alphafold.data.value = null;
            alphafold.error.value = null;
          } else {
            const message =
              err instanceof Error ? err.message : 'Failed to fetch AlphaFold structure';
            alphafold.error.value = message;
            alphafold.data.value = null;
          }
        } finally {
          alphafold.loading.value = false;
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
    clinvar,
    alphafold,
    loading,
    fetchData,
    retry,
  };
}
