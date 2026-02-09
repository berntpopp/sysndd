// views/admin/composables/useKPIStats.ts
import { ref } from 'vue';
import type { AxiosInstance } from 'axios';
import { unwrapScalar } from '@/utils/apiUtils';
import { previousPeriod } from '@/utils/dateUtils';

interface UpdatesStatistics {
  total_new_entities: number;
  unique_genes: number;
  average_per_day: number;
}

interface ReReviewStatistics {
  total_rereviews: number;
  percentage_finished: number;
  average_per_day: number;
}

interface KpiStats {
  newThisPeriod: number;
  avgPerDay: number;
  trendDelta: number | undefined;
}

export function useKPIStats(
  axios: AxiosInstance | undefined,
  apiUrl: string,
  getAuthHeaders: () => Record<string, string>,
  makeToast: (msg: unknown, title: string, variant: string) => void
) {
  const loading = ref(false);
  const kpiStats = ref<KpiStats>({
    newThisPeriod: 0,
    avgPerDay: 0,
    trendDelta: undefined,
  });

  // Legacy backward-compat statistics
  const statistics = ref<UpdatesStatistics | null>(null);
  const reReviewStatistics = ref<ReReviewStatistics | null>(null);
  const updatedReviewsStatistics = ref<{ total_updated_reviews: number } | null>(null);
  const updatedStatusesStatistics = ref<{ total_updated_statuses: number } | null>(null);

  async function fetchUpdatesStats(start: string, end: string): Promise<UpdatesStatistics | null> {
    if (!axios) return null;

    try {
      const response = await axios.get(`${apiUrl}/api/statistics/updates`, {
        params: { start_date: start, end_date: end },
        headers: getAuthHeaders(),
      });
      return {
        total_new_entities: unwrapScalar(response.data.total_new_entities, 0)!,
        unique_genes: unwrapScalar(response.data.unique_genes, 0)!,
        average_per_day: unwrapScalar(response.data.average_per_day, 0)!,
      };
    } catch (error) {
      console.error('Failed to fetch updates stats:', error);
      return null;
    }
  }

  async function calculateTrendDelta(
    startDate: string,
    endDate: string
  ): Promise<number | undefined> {
    const prev = previousPeriod(startDate, endDate);
    const [currentStats, prevStats] = await Promise.all([
      fetchUpdatesStats(startDate, endDate),
      fetchUpdatesStats(prev.start, prev.end),
    ]);

    if (!currentStats || !prevStats) return undefined;
    if (prevStats.total_new_entities === 0) {
      return currentStats.total_new_entities > 0 ? 100 : 0;
    }
    return Math.round(
      ((currentStats.total_new_entities - prevStats.total_new_entities) /
        prevStats.total_new_entities) *
        100
    );
  }

  async function fetchKPIStats(startDate: string, endDate: string): Promise<void> {
    if (!axios) return;

    loading.value = true;
    try {
      const currentStats = await fetchUpdatesStats(startDate, endDate);
      if (currentStats) {
        kpiStats.value.newThisPeriod = currentStats.total_new_entities;
        kpiStats.value.avgPerDay = Math.round(currentStats.average_per_day * 100) / 100;
        statistics.value = currentStats;
      }
      const delta = await calculateTrendDelta(startDate, endDate);
      kpiStats.value.trendDelta = delta;
    } catch (error) {
      console.error('Failed to fetch KPI stats:', error);
      makeToast('Failed to fetch KPI statistics', 'Error', 'danger');
    } finally {
      loading.value = false;
    }
  }

  async function fetchExistingStatistics(startDate: string, endDate: string): Promise<void> {
    if (!axios) return;

    try {
      const reReviewResponse = await axios.get(`${apiUrl}/api/statistics/rereview`, {
        params: { start_date: startDate, end_date: endDate },
        headers: getAuthHeaders(),
      });
      reReviewStatistics.value = {
        total_rereviews: unwrapScalar(reReviewResponse.data.total_rereviews, 0)!,
        percentage_finished: unwrapScalar(reReviewResponse.data.percentage_finished, 0)!,
        average_per_day: unwrapScalar(reReviewResponse.data.average_per_day, 0)!,
      };

      const updatedReviewsResponse = await axios.get(`${apiUrl}/api/statistics/updated_reviews`, {
        params: { start_date: startDate, end_date: endDate },
        headers: getAuthHeaders(),
      });
      updatedReviewsStatistics.value = {
        total_updated_reviews: unwrapScalar(updatedReviewsResponse.data.total_updated_reviews, 0)!,
      };

      const updatedStatusesResponse = await axios.get(`${apiUrl}/api/statistics/updated_statuses`, {
        params: { start_date: startDate, end_date: endDate },
        headers: getAuthHeaders(),
      });
      updatedStatusesStatistics.value = {
        total_updated_statuses: unwrapScalar(
          updatedStatusesResponse.data.total_updated_statuses,
          0
        )!,
      };
    } catch (error) {
      console.error('Failed to fetch existing statistics:', error);
      makeToast('Failed to fetch statistics', 'Error', 'danger');
    }
  }

  return {
    loading,
    kpiStats,
    statistics,
    reReviewStatistics,
    updatedReviewsStatistics,
    updatedStatusesStatistics,
    fetchKPIStats,
    fetchExistingStatistics,
  };
}
