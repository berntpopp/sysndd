// app/src/composables/useGeneClinVarCounts.ts
//
// Lightweight ClinVar classification-counts hook used by the GeneClinVarCard
// summary tile. Calls /api/external/gnomad/variants/<symbol>?summary=true,
// which returns a sub-1KB payload of per-classification counts instead of the
// full ~520KB variant list. The full-variant hook (useGeneClinVar) is still
// used by GenomicVisualizationTabs for the protein/structure plots.
//
// See .planning/perf/2026-04-26-deep-load-analysis.md (P1.3).
import axios from 'axios';
import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { useResource, type ResourceState } from './useResource';

const apiBase = import.meta.env.VITE_API_URL ?? '';

export interface ClinVarClassificationCounts {
  pathogenic: number;
  likely_pathogenic: number;
  vus: number;
  likely_benign: number;
  benign: number;
}

export interface ClinVarSummary {
  source: string;
  gene_symbol: string;
  gene_id: string | null;
  counts: ClinVarClassificationCounts;
  variant_count: number;
  summary: true;
}

export function useGeneClinVarCounts(
  symbol: string | Ref<string | null> | ComputedRef<string | null>
): ResourceState<ClinVarSummary | null> {
  const symRef = computed<string | null>(() => {
    if (typeof symbol === 'string') return symbol || null;
    if (isRef(symbol)) return symbol.value;
    return null;
  });
  const key = computed<string | null>(() =>
    symRef.value ? `clinvar-counts:${symRef.value}` : null
  );
  return useResource<ClinVarSummary | null>(
    key,
    async (signal) => {
      try {
        const res = await axios.get<ClinVarSummary>(
          `${apiBase}/api/external/gnomad/variants/${symRef.value}`,
          { withCredentials: true, signal, params: { summary: 'true' } }
        );
        return res.data ?? null;
      } catch (err) {
        if (axios.isAxiosError(err) && err.response?.status === 404) return null;
        throw err;
      }
    },
    { ttlMs: 5 * 60_000 }
  );
}
