// views/admin/composables/useKPIStats.ts
import { ref } from 'vue';
import { unwrapScalar } from '@/utils/apiUtils';
import { previousPeriod } from '@/utils/dateUtils';
import {
  getUpdatesStats,
  getRereviewStats,
  getUpdatedReviewsStats,
  getUpdatedStatusesStats,
} from '@/api/statistics';

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
    try {
      const response = await getUpdatesStats({ start_date: start, end_date: end });
      return {
        total_new_entities: unwrapScalar(response.total_new_entities, 0)!,
        unique_genes: unwrapScalar(response.unique_genes, 0)!,
        average_per_day: unwrapScalar(response.average_per_day, 0)!,
      };
    } catch (error) {
      console.error('Failed to fetch updates stats:', error);
      return null;
    }
  }

  async function calculateTrendDelta(
    startDate: string,
    endDate: string,
    currentStatsArg?: UpdatesStatistics | null
  ): Promise<number | undefined> {
    const prev = previousPeriod(startDate, endDate);
    // Reuse the already-fetched current-period stats when the caller passes
    // them in (fetchKPIStats does) to avoid a duplicate /statistics/updates
    // request; only fetch the current period when no value was provided.
    const [currentStats, prevStats] = await Promise.all([
      currentStatsArg !== undefined
        ? Promise.resolve(currentStatsArg)
        : fetchUpdatesStats(startDate, endDate),
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
    loading.value = true;
    try {
      const currentStats = await fetchUpdatesStats(startDate, endDate);
      if (currentStats) {
        kpiStats.value.newThisPeriod = currentStats.total_new_entities;
        kpiStats.value.avgPerDay = Math.round(currentStats.average_per_day * 100) / 100;
        statistics.value = currentStats;
      }
      // Pass the current-period stats we just fetched so calculateTrendDelta
      // only needs to fetch the previous period (avoids a redundant request).
      const delta = await calculateTrendDelta(startDate, endDate, currentStats);
      kpiStats.value.trendDelta = delta;
    } catch (error) {
      console.error('Failed to fetch KPI stats:', error);
      makeToast('Failed to fetch KPI statistics', 'Error', 'danger');
    } finally {
      loading.value = false;
    }
  }

  async function fetchExistingStatistics(startDate: string, endDate: string): Promise<void> {
    try {
      const reReviewResponse = await getRereviewStats({
        start_date: startDate,
        end_date: endDate,
      });
      reReviewStatistics.value = {
        total_rereviews: unwrapScalar(reReviewResponse.total_rereviews, 0)!,
        percentage_finished: unwrapScalar(reReviewResponse.percentage_finished, 0)!,
        average_per_day: unwrapScalar(reReviewResponse.average_per_day, 0)!,
      };

      const updatedReviewsResponse = await getUpdatedReviewsStats({
        start_date: startDate,
        end_date: endDate,
      });
      updatedReviewsStatistics.value = {
        total_updated_reviews: unwrapScalar(updatedReviewsResponse.total_updated_reviews, 0)!,
      };

      const updatedStatusesResponse = await getUpdatedStatusesStats({
        start_date: startDate,
        end_date: endDate,
      });
      updatedStatusesStatistics.value = {
        total_updated_statuses: unwrapScalar(updatedStatusesResponse.total_updated_statuses, 0)!,
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
