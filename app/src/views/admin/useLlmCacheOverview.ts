// Cache-status overview presentation for the LLM Administration view.
// Extracted from ManageLLM.vue. These computeds summarize counts of
// admin-generated cached LLM summaries; all status copy stays here verbatim.

import { computed, type ComputedRef, type Ref } from 'vue';
import type { LlmConfig, CacheStats } from '@/types/llm';

export interface LlmCacheSummaryRow {
  key: string;
  label: string;
  value: string;
  status: string;
  tone: string;
  note: string;
}

export interface UseLlmCacheOverview {
  overviewDescription: ComputedRef<string>;
  cacheHealthLabel: ComputedRef<string>;
  cacheSummaryRows: ComputedRef<LlmCacheSummaryRow[]>;
}

export function useLlmCacheOverview(
  config: Ref<LlmConfig | null>,
  cacheStats: Ref<CacheStats | null>
): UseLlmCacheOverview {
  const overviewDescription = computed(() => {
    const model = config.value?.gemini_configured ? config.value.current_model : 'Not configured';
    return `Model ${model}. Cache and regeneration controls use the same compact table layout as public data views.`;
  });

  const cacheHealthLabel = computed(() => {
    if (!config.value?.gemini_configured) return 'Provider not configured';
    const pending = cacheStats.value?.by_status?.pending ?? 0;
    return pending > 0 ? `${pending} pending review` : 'No pending reviews';
  });

  const cacheSummaryRows = computed<LlmCacheSummaryRow[]>(() => [
    {
      key: 'total',
      label: 'Total summaries',
      value: String(cacheStats.value?.total_entries ?? 0),
      status: 'Cached',
      tone: 'neutral',
      note: 'All stored functional and phenotype summaries',
    },
    {
      key: 'validated',
      label: 'Validated',
      value: String(cacheStats.value?.by_status?.validated ?? 0),
      status: 'Accepted',
      tone: 'success',
      note: 'Summaries approved for display',
    },
    {
      key: 'pending',
      label: 'Pending review',
      value: String(cacheStats.value?.by_status?.pending ?? 0),
      status: 'Needs review',
      tone: 'warning',
      note: 'Generated summaries awaiting validation',
    },
    {
      key: 'cost',
      label: 'Estimated cost',
      value: `$${(cacheStats.value?.estimated_cost_usd ?? 0).toFixed(2)}`,
      status: 'USD',
      tone: 'info',
      note: 'Approximate generation spend',
    },
  ]);

  return {
    overviewDescription,
    cacheHealthLabel,
    cacheSummaryRows,
  };
}
