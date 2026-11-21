import { describe, it, expect } from 'vitest';
import { ref } from 'vue';
import type { CacheStats, LlmConfig } from '@/types/llm';
import { useLlmCacheOverview } from './useLlmCacheOverview';

describe('useLlmCacheOverview', () => {
  it('uses user-facing copy and only flags pending summaries when there are some', () => {
    const config = ref({ gemini_configured: false } as LlmConfig);
    const stats = ref({ total_entries: 4, by_status: { pending: 0 } } as unknown as CacheStats);
    const { overviewDescription, cacheSummaryRows } = useLlmCacheOverview(config, stats);

    expect(overviewDescription.value).toBe(
      'No model configured. Set a provider under Configuration to regenerate summaries.'
    );
    const pending = cacheSummaryRows.value.find((row) => row.key === 'pending')!;
    expect(pending.status).toBe('None pending');
    expect(pending.tone).toBe('neutral');
    expect(cacheSummaryRows.value.find((row) => row.key === 'cost')!.status).toBe('');

    stats.value = { total_entries: 4, by_status: { pending: 2 } } as unknown as CacheStats;
    const pendingNow = cacheSummaryRows.value.find((row) => row.key === 'pending')!;
    expect(pendingNow.status).toBe('Needs review');
    expect(pendingNow.tone).toBe('warning');
  });
});
