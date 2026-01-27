import type { Ref } from 'vue';
import { ref, computed, toRef } from 'vue';
import axios from 'axios';
import type {
  ExternalDataResponse,
  GnomADConstraints,
  ClinVarVariant,
} from '@/types';

/**
 * Return type for useGeneExternalData composable
 */
export interface UseGeneExternalDataReturn {
  /** gnomAD constraint scores state */
  gnomad: {
    loading: Ref<boolean>;
    error: Ref<string | null>;
    data: Ref<GnomADConstraints | null>;
  };

  /** ClinVar variants state */
  clinvar: {
    loading: Ref<boolean>;
    error: Ref<string | null>;
    data: Ref<ClinVarVariant[] | null>;
  };

  /** Overall loading state (true if any source is loading) */
  loading: Ref<boolean>;

  /** Fetch data from the combined aggregation endpoint */
  fetchData: () => Promise<void>;

  /** Retry fetch (convenience method that calls fetchData) */
  retry: () => Promise<void>;
}

/**
 * Composable for fetching external genomic data from the combined aggregation endpoint
 *
 * @description
 * Fetches gnomAD constraints and ClinVar variants from /api/external/gene/<symbol>
 * with per-source state isolation. Each source has independent loading/error/data state,
 * enabling graceful degradation (one source fails, others still render).
 *
 * Pattern: COMPOSE-01/02/03 requirements from Phase 42 plan
 * - COMPOSE-01: Fetches from combined endpoint without auth header (public endpoints)
 * - COMPOSE-02: Per-source loading states (gnomad.loading, clinvar.loading)
 * - COMPOSE-03: Per-source error states (gnomad.error, clinvar.error)
 *
 * @param geneSymbol - HGNC gene symbol (reactive ref or plain string)
 *
 * @returns Per-source state objects, overall loading state, and fetch methods
 *
 * @example
 * ```ts
 * const symbol = ref('BRCA1');
 * const { gnomad, clinvar, loading, fetchData } = useGeneExternalData(symbol);
 *
 * onMounted(() => fetchData());
 *
 * // Template access:
 * // <p v-if="gnomad.loading.value">Loading constraints...</p>
 * // <p v-else-if="gnomad.error.value">{{ gnomad.error.value }}</p>
 * // <p v-else-if="gnomad.data.value">pLI: {{ gnomad.data.value.pLI }}</p>
 * ```
 */
export function useGeneExternalData(
  geneSymbol: Ref<string> | string,
): UseGeneExternalDataReturn {
  // Normalize to ref (handles both ref and plain string)
  const symbol = toRef(geneSymbol);

  // Per-source state objects (COMPOSE-02/03)
  // Pattern: Plain objects with ref properties (NOT ref of object)
  // This allows template access like gnomad.loading.value
  const gnomad = {
    loading: ref<boolean>(true),
    error: ref<string | null>(null),
    data: ref<GnomADConstraints | null>(null),
  };

  const clinvar = {
    loading: ref<boolean>(true),
    error: ref<string | null>(null),
    data: ref<ClinVarVariant[] | null>(null),
  };

  /**
   * Overall loading state (true if any source is loading)
   */
  const loading = computed<boolean>(
    () => gnomad.loading.value || clinvar.loading.value,
  );

  /**
   * Fetch data from the combined aggregation endpoint
   *
   * @description
   * - Resets all loading states to true, errors to null
   * - GET /api/external/gene/<symbol> (no auth header - public endpoint)
   * - Distributes response to per-source state objects
   * - Handles partial success (some sources succeed, others fail)
   * - Sets loading to false for each source after processing
   */
  async function fetchData(): Promise<void> {
    // Reset all loading states
    gnomad.loading.value = true;
    gnomad.error.value = null;
    clinvar.loading.value = true;
    clinvar.error.value = null;

    try {
      // Fetch from combined aggregation endpoint (COMPOSE-01)
      // No Authorization header - external proxy endpoints are public (AUTH_ALLOWLIST per 40-04)
      const response = await axios.get<ExternalDataResponse>(
        `${import.meta.env.VITE_API_URL}/api/external/gene/${symbol.value}`,
      );

      const result = response.data;

      // Process gnomAD constraints
      if (result.sources?.gnomad_constraints) {
        // Backend returns data with found: true/false
        // If found: false, treat as "no data available" (not error)
        const gnomadSource = result.sources.gnomad_constraints as any;
        if (gnomadSource.found === false) {
          gnomad.data.value = null;
          gnomad.error.value = null; // Not an error, just no data
        } else {
          gnomad.data.value = gnomadSource.constraints;
          gnomad.error.value = null;
        }
      } else if (result.errors?.gnomad_constraints) {
        // Source failed with error
        const error = result.errors.gnomad_constraints;
        gnomad.error.value = error.detail || error.title || 'Failed to load gnomAD constraints';
        gnomad.data.value = null;
      } else {
        // Source not present in response (unexpected)
        gnomad.error.value = 'gnomAD constraints data not available';
        gnomad.data.value = null;
      }

      // Process ClinVar variants
      if (result.sources?.gnomad_clinvar) {
        const clinvarSource = result.sources.gnomad_clinvar as any;
        if (clinvarSource.found === false) {
          clinvar.data.value = null;
          clinvar.error.value = null; // Not an error, just no data
        } else {
          clinvar.data.value = clinvarSource.variants;
          clinvar.error.value = null;
        }
      } else if (result.errors?.gnomad_clinvar) {
        // Source failed with error
        const error = result.errors.gnomad_clinvar;
        clinvar.error.value = error.detail || error.title || 'Failed to load ClinVar variants';
        clinvar.data.value = null;
      } else {
        // Source not present in response (unexpected)
        clinvar.error.value = 'ClinVar variants data not available';
        clinvar.data.value = null;
      }

      // Set loading to false for all sources (even if errors occurred)
      gnomad.loading.value = false;
      clinvar.loading.value = false;
    } catch (err) {
      // Network error or timeout - set both sources to error state
      const message =
        err instanceof Error ? err.message : 'Failed to fetch external data';

      gnomad.error.value = message;
      gnomad.data.value = null;
      gnomad.loading.value = false;

      clinvar.error.value = message;
      clinvar.data.value = null;
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
    gnomad,
    clinvar,
    loading,
    fetchData,
    retry,
  };
}
