// views/admin/composables/useAdminTrendData.ts
import { ref, computed, watch, onUnmounted } from 'vue';
import type { AxiosInstance } from 'axios';
import { mergeGroupedCumulativeSeries, extractPerGroupSeries } from '@/utils/timeSeriesUtils';
import type { GroupedTimeSeries } from '@/utils/timeSeriesUtils';
import { safeArray } from '@/utils/apiUtils';

interface TrendDataPoint {
  date: string;
  count: number;
}

export function useAdminTrendData(
  axios: AxiosInstance | undefined,
  apiUrl: string,
  getAuthHeaders: () => Record<string, string>,
  makeToast: (msg: unknown, title: string, variant: string) => void
) {
  const trendData = ref<TrendDataPoint[]>([]);
  const trendCategoryData = ref<{ dates: string[]; series: Record<string, number[]> }>({
    dates: [],
    series: {},
  });

  const loading = ref(false);
  const trendYMax = ref<number | undefined>(undefined);

  // Filter controls
  const granularity = ref<'month' | 'week' | 'day'>('month');
  const nddFilter = ref<'ndd' | 'non_ndd' | 'all'>('ndd');
  const categoryDisplay = ref<'combined' | 'by_category'>('combined');
  const selectedCategories = ref<string[]>(['Definitive', 'Moderate', 'Limited', 'Refuted']);

  // Request versioning and AbortController
  let abortController: AbortController | null = null;
  let requestVersion = 0;

  function buildTrendFilter(): string | undefined {
    const parts: string[] = [];

    if (nddFilter.value === 'ndd') {
      parts.push('contains(ndd_phenotype_word,Yes)');
    } else if (nddFilter.value === 'non_ndd') {
      parts.push('contains(ndd_phenotype_word,No)');
    }

    if (selectedCategories.value.length > 0 && selectedCategories.value.length < 4) {
      parts.push(`any(category,${selectedCategories.value.join(',')})`);
    }

    if (parts.length === 0) return '';
    if (parts.length === 1 && parts[0] === 'contains(ndd_phenotype_word,Yes)') {
      return undefined;
    }
    return parts.join(',');
  }

  const trendDescription = computed(() => {
    const nddLabel =
      nddFilter.value === 'ndd' ? 'NDD' : nddFilter.value === 'non_ndd' ? 'non-NDD' : 'all';

    if (categoryDisplay.value === 'by_category') {
      return `Per-category cumulative counts of ${nddLabel} gene-disease associations curated over time.`;
    }
    return (
      `Cumulative count of ${nddLabel} gene-disease associations curated over time.` +
      ' The dashed trend line represents a 3-period moving average for temporal smoothing.'
    );
  });

  // Derived total entities from trend data (final cumulative value)
  const totalEntities = ref(0);

  async function fetchTrendData(): Promise<void> {
    if (!axios) return;

    abortController?.abort();
    abortController = new AbortController();
    const currentVersion = ++requestVersion;

    trendData.value = [];
    trendCategoryData.value = { dates: [], series: {} };
    loading.value = true;

    try {
      const params: Record<string, string> = {
        aggregate: 'entity_id',
        group: 'category',
        summarize: granularity.value,
      };
      const filterValue = buildTrendFilter();
      if (filterValue !== undefined) {
        params.filter = filterValue;
      }

      const response = await axios.get(`${apiUrl}/api/statistics/entities_over_time`, {
        params,
        headers: getAuthHeaders(),
        signal: abortController.signal,
      });

      if (currentVersion !== requestVersion) return;

      const allData = safeArray<GroupedTimeSeries>(response.data?.data);
      trendData.value = mergeGroupedCumulativeSeries(allData);
      trendCategoryData.value = extractPerGroupSeries(allData);

      if (trendData.value.length > 0) {
        const maxVal = trendData.value[trendData.value.length - 1].count;
        totalEntities.value = maxVal;
        trendYMax.value = Math.max(trendYMax.value ?? 0, maxVal);
      }

      abortController = null;
    } catch (error) {
      if ((error as Error).name !== 'AbortError') {
        console.error('Failed to fetch trend data:', error);
        makeToast('Failed to fetch trend data', 'Error', 'danger');
        trendData.value = [];
        trendCategoryData.value = { dates: [], series: {} };
      }
    } finally {
      loading.value = false;
    }
  }

  // Auto-refetch on control changes
  watch(granularity, () => fetchTrendData());
  watch(nddFilter, () => {
    trendYMax.value = undefined;
    fetchTrendData();
  });
  watch(selectedCategories, () => fetchTrendData());

  // Cleanup
  onUnmounted(() => {
    abortController?.abort();
    abortController = null;
  });

  return {
    trendData,
    trendCategoryData,
    trendYMax,
    totalEntities,
    loading,
    granularity,
    nddFilter,
    categoryDisplay,
    selectedCategories,
    trendDescription,
    fetchTrendData,
  };
}
