<template>
  <BContainer fluid class="py-3">
    <!-- Header with date controls -->
    <BRow class="mb-3 align-items-center">
      <BCol md="6">
        <h3 class="mb-1">Admin Statistics</h3>
        <small v-if="lastUpdated" class="text-muted">
          Data as of {{ formatDateTime(lastUpdated) }}
          <BButton size="sm" variant="link" class="p-0 ms-1" @click="refreshAll">
            <i class="bi bi-arrow-clockwise"></i> Refresh
          </BButton>
        </small>
      </BCol>
      <BCol md="6">
        <BForm inline class="justify-content-md-end" @submit.prevent="fetchStatistics">
          <BFormGroup label="From" label-class="small" class="mb-0 me-2">
            <BFormInput v-model="startDate" type="date" size="sm" />
          </BFormGroup>
          <BFormGroup label="To" label-class="small" class="mb-0 me-2">
            <BFormInput v-model="endDate" type="date" size="sm" />
          </BFormGroup>
          <BButton type="submit" variant="primary" size="sm" class="mt-3">
            Apply
          </BButton>
        </BForm>
      </BCol>
    </BRow>

    <!-- KPI Cards Row -->
    <BRow class="mb-4">
      <BCol md="3" v-for="stat in kpiCards" :key="stat.label" class="mb-3 mb-md-0">
        <StatCard
          :label="stat.label"
          :value="stat.value"
          :delta="stat.delta"
          :context="stat.context"
        />
      </BCol>
    </BRow>

    <!-- Entity Trend Chart -->
    <BRow class="mb-4">
      <BCol>
        <BCard>
          <template #header>
            <div class="d-flex justify-content-between align-items-center">
              <h5 class="mb-0">Entity Submissions Over Time</h5>
              <BFormRadioGroup
                v-model="granularity"
                :options="granularityOptions"
                button-variant="outline-primary"
                size="sm"
                buttons
                @change="fetchTrendData"
              />
            </div>
          </template>
          <p class="text-muted small mb-2">
            Cumulative count of gene-disease associations curated over time.
            The dashed trend line represents a 3-period moving average for temporal smoothing.
          </p>
          <EntityTrendChart
            :entity-data="trendData"
            :loading="loading.trend"
            :show-moving-average="true"
          />
        </BCard>
      </BCol>
    </BRow>

    <!-- Contributor Leaderboard -->
    <BRow class="mb-4">
      <BCol>
        <BCard>
          <template #header>
            <div class="d-flex justify-content-between align-items-center">
              <h5 class="mb-0">Top Contributors</h5>
              <BFormRadioGroup
                v-model="leaderboardScope"
                :options="leaderboardScopeOptions"
                button-variant="outline-primary"
                size="sm"
                buttons
                @change="fetchLeaderboard"
              />
            </div>
          </template>
          <p class="text-muted small mb-2">
            Curator leaderboard ranked by gene-disease association submissions.
            {{ leaderboardScope === 'all_time' ? 'Cumulative all-time contributions.' : `Contributions within selected ${periodLengthDays} day period.` }}
          </p>
          <ContributorBarChart
            :contributors="leaderboardData"
            :loading="loading.leaderboard"
          />
        </BCard>
      </BCol>
    </BRow>

    <!-- Existing text stats (kept for reference) -->
    <BRow v-if="statistics" class="mb-3">
      <BCol md="6" class="mb-3">
        <BCard
          header-tag="header"
          body-class="p-3"
          header-class="p-2"
          border-variant="dark"
        >
          <template #header>
            <h5 class="mb-0 text-start">
              Updates Statistics
              <small class="text-muted">({{ startDate }} to {{ endDate }})</small>
            </h5>
          </template>
          <p class="mb-1">
            Total new entities: <span class="stats-number">{{ statistics.total_new_entities }}</span>
          </p>
          <p class="mb-1">
            Unique genes: <span class="stats-number">{{ statistics.unique_genes }}</span>
          </p>
          <p class="mb-0">
            Average per day: <span class="stats-number">{{ formatDecimal(statistics.average_per_day) }}</span>
          </p>
        </BCard>
      </BCol>
      <BCol v-if="reReviewStatistics" md="6" class="mb-3">
        <BCard
          header-tag="header"
          body-class="p-3"
          header-class="p-2"
          border-variant="dark"
        >
          <template #header>
            <h5 class="mb-0 text-start">
              Re-review Statistics
              <small class="text-muted">({{ startDate }} to {{ endDate }})</small>
            </h5>
          </template>
          <p class="mb-1">
            Total re-reviews: <span class="stats-number">{{ reReviewStatistics.total_rereviews }}</span>
          </p>
          <p class="mb-1">
            Percentage finished: <span class="stats-number">{{ formatDecimal(reReviewStatistics.percentage_finished) }}%</span>
          </p>
          <p class="mb-0">
            Average per day: <span class="stats-number">{{ formatDecimal(reReviewStatistics.average_per_day) }}</span>
          </p>
        </BCard>
      </BCol>
    </BRow>
    <BRow v-if="updatedReviewsStatistics || updatedStatusesStatistics" class="mb-3">
      <BCol v-if="updatedReviewsStatistics" md="6" class="mb-3">
        <BCard
          header-tag="header"
          body-class="p-3"
          header-class="p-2"
          border-variant="dark"
        >
          <template #header>
            <h5 class="mb-0 text-start">
              Updated Reviews Statistics
              <small class="text-muted">({{ startDate }} to {{ endDate }})</small>
            </h5>
          </template>
          <p class="mb-0">
            Total updated reviews: <span class="stats-number">{{ updatedReviewsStatistics.total_updated_reviews }}</span>
          </p>
        </BCard>
      </BCol>
      <BCol v-if="updatedStatusesStatistics" md="6" class="mb-3">
        <BCard
          header-tag="header"
          body-class="p-3"
          header-class="p-2"
          border-variant="dark"
        >
          <template #header>
            <h5 class="mb-0 text-start">
              Updated Statuses Statistics
              <small class="text-muted">({{ startDate }} to {{ endDate }})</small>
            </h5>
          </template>
          <p class="mb-0">
            Total updated statuses: <span class="stats-number">{{ updatedStatusesStatistics.total_updated_statuses }}</span>
          </p>
        </BCard>
      </BCol>
    </BRow>
  </BContainer>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, inject } from 'vue';
import type { AxiosInstance } from 'axios';
import {
  BContainer,
  BRow,
  BCol,
  BCard,
  BButton,
  BForm,
  BFormGroup,
  BFormInput,
  BFormRadioGroup,
} from 'bootstrap-vue-next';
import useToast from '@/composables/useToast';
import EntityTrendChart from './components/charts/EntityTrendChart.vue';
import ContributorBarChart from './components/charts/ContributorBarChart.vue';
import StatCard from './components/statistics/StatCard.vue';

// Types
interface TrendDataPoint {
  date: string;
  count: number;
}

interface ContributorData {
  user_name: string;
  entity_count: number;
}

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

interface UpdatedReviewsStatistics {
  total_updated_reviews: number;
}

interface UpdatedStatusesStatistics {
  total_updated_statuses: number;
}

interface KpiStats {
  totalEntities: number;
  newThisPeriod: number;
  totalContributors: number;
  avgPerDay: number;
  trendDelta: number | undefined;
}

// Inject axios
const axios = inject<AxiosInstance>('axios');
const { makeToast } = useToast();

// API base URL
const apiUrl = import.meta.env.VITE_API_URL;

// Loading states
const loading = ref({
  trend: false,
  leaderboard: false,
  stats: false,
});

// Date range and granularity
const granularity = ref<'month' | 'week' | 'day'>('month');
const leaderboardScope = ref<'all_time' | 'range'>('all_time');

// Set default date range to last 12 months
const today = new Date();
const twelveMonthsAgo = new Date(today.getFullYear() - 1, today.getMonth(), today.getDate());
const startDate = ref(twelveMonthsAgo.toISOString().split('T')[0]);
const endDate = ref(today.toISOString().split('T')[0]);

const lastUpdated = ref<Date | null>(null);

// Chart data
const trendData = ref<TrendDataPoint[]>([]);
const leaderboardData = ref<ContributorData[]>([]);

// KPI data
const kpiStats = ref<KpiStats>({
  totalEntities: 0,
  newThisPeriod: 0,
  totalContributors: 0,
  avgPerDay: 0,
  trendDelta: undefined,
});

// Existing statistics data (kept for backward compatibility)
const statistics = ref<UpdatesStatistics | null>(null);
const reReviewStatistics = ref<ReReviewStatistics | null>(null);
const updatedReviewsStatistics = ref<UpdatedReviewsStatistics | null>(null);
const updatedStatusesStatistics = ref<UpdatedStatusesStatistics | null>(null);

// Options for granularity toggle
const granularityOptions = [
  { text: 'Monthly', value: 'month' },
  { text: 'Weekly', value: 'week' },
  { text: 'Daily', value: 'day' },
];

// Options for leaderboard scope toggle
const leaderboardScopeOptions = [
  { text: 'All Time', value: 'all_time' },
  { text: 'Date Range', value: 'range' },
];

// Computed period length for context display
const periodLengthDays = computed(() => {
  const startDateObj = new Date(startDate.value);
  const endDateObj = new Date(endDate.value);
  return Math.round(
    Math.abs((endDateObj.getTime() - startDateObj.getTime()) / (1000 * 60 * 60 * 24))
  );
});

// KPI cards computed with scientific context
const kpiCards = computed(() => [
  {
    label: 'Total Entities',
    value: kpiStats.value.totalEntities,
    context: 'Gene-disease associations with NDD phenotype',
  },
  {
    label: 'New This Period',
    value: kpiStats.value.newThisPeriod,
    delta: kpiStats.value.trendDelta,
    context: `vs previous ${periodLengthDays.value} days`,
  },
  {
    label: 'Contributors',
    value: kpiStats.value.totalContributors,
    context: 'Curators with entity submissions',
  },
  {
    label: 'Avg Per Day',
    value: kpiStats.value.avgPerDay,
    context: `Mean daily rate (${periodLengthDays.value} day period)`,
  },
]);

// Helper functions
function formatDateTime(date: Date): string {
  return date.toLocaleString();
}

function formatDecimal(value: number | undefined | null): string {
  if (value === undefined || value === null) return 'N/A';
  return value.toFixed(2);
}

function getAuthHeaders() {
  return {
    Authorization: `Bearer ${localStorage.getItem('token')}`,
  };
}

// Fetch trend data from /entities_over_time endpoint
async function fetchTrendData(): Promise<void> {
  if (!axios) return;

  loading.value.trend = true;
  try {
    const response = await axios.get(
      `${apiUrl}/api/statistics/entities_over_time`,
      {
        params: {
          aggregate: 'entity_id',
          group: 'category',
          summarize: granularity.value,
        },
        headers: getAuthHeaders(),
      }
    );

    // Transform response: data[0].values array contains { entry_date, count, cumulative_count }
    // Aggregate across all categories for the overall trend
    const allData = response.data.data || [];
    const dateCountMap = new Map<string, number>();

    allData.forEach((group: { group: string; values: Array<{ entry_date: string; count: number }> }) => {
      group.values?.forEach((item) => {
        const existing = dateCountMap.get(item.entry_date) || 0;
        dateCountMap.set(item.entry_date, existing + item.count);
      });
    });

    // Convert to sorted array
    const sortedDates = Array.from(dateCountMap.entries())
      .sort(([a], [b]) => a.localeCompare(b));

    // Calculate cumulative totals
    let cumulative = 0;
    trendData.value = sortedDates.map(([date, count]) => {
      cumulative += count;
      return { date, count: cumulative };
    });
  } catch (error) {
    console.error('Failed to fetch trend data:', error);
    makeToast('Failed to fetch trend data', 'Error', 'danger');
    trendData.value = [];
  } finally {
    loading.value.trend = false;
  }
}

// Fetch leaderboard data from /contributor_leaderboard endpoint
async function fetchLeaderboard(): Promise<void> {
  if (!axios) return;

  loading.value.leaderboard = true;
  try {
    const params: Record<string, string | number> = {
      top: 10,
      scope: leaderboardScope.value,
    };

    if (leaderboardScope.value === 'range') {
      params.start_date = startDate.value;
      params.end_date = endDate.value;
    }

    const response = await axios.get(
      `${apiUrl}/api/statistics/contributor_leaderboard`,
      {
        params,
        headers: getAuthHeaders(),
      }
    );

    // Map response to chart format: use display_name for user_name
    const data = response.data.data || [];
    leaderboardData.value = data.map((item: { display_name: string; entity_count: number }) => ({
      user_name: item.display_name || 'Unknown',
      entity_count: item.entity_count,
    }));

    // Update total contributors from meta
    if (response.data.meta?.total_contributors) {
      kpiStats.value.totalContributors = response.data.meta.total_contributors;
    }
  } catch (error) {
    console.error('Failed to fetch leaderboard:', error);
    makeToast('Failed to fetch leaderboard data', 'Error', 'danger');
    leaderboardData.value = [];
  } finally {
    loading.value.leaderboard = false;
  }
}

// Fetch updates statistics (for KPIs and backward compatibility)
async function fetchUpdatesStats(start: string, end: string): Promise<UpdatesStatistics | null> {
  if (!axios) return null;

  try {
    const response = await axios.get(
      `${apiUrl}/api/statistics/updates`,
      {
        params: { start_date: start, end_date: end },
        headers: getAuthHeaders(),
      }
    );
    return {
      total_new_entities: response.data.total_new_entities,
      unique_genes: response.data.unique_genes,
      average_per_day: response.data.average_per_day,
    };
  } catch (error) {
    console.error('Failed to fetch updates stats:', error);
    return null;
  }
}

// Calculate trend delta by comparing current period with previous equal-length period
async function calculateTrendDelta(): Promise<number | undefined> {
  // Get date range length in days
  const startDateObj = new Date(startDate.value);
  const endDateObj = new Date(endDate.value);
  const rangeLength = Math.abs(
    (endDateObj.getTime() - startDateObj.getTime()) / (1000 * 60 * 60 * 24)
  );

  // Calculate previous period dates
  const prevEndDate = new Date(startDateObj);
  prevEndDate.setDate(prevEndDate.getDate() - 1);
  const prevStartDate = new Date(prevEndDate);
  prevStartDate.setDate(prevStartDate.getDate() - rangeLength);

  // Fetch both periods
  const [currentStats, prevStats] = await Promise.all([
    fetchUpdatesStats(startDate.value, endDate.value),
    fetchUpdatesStats(
      prevStartDate.toISOString().split('T')[0],
      prevEndDate.toISOString().split('T')[0]
    ),
  ]);

  if (!currentStats || !prevStats) return undefined;

  // Calculate percentage change
  if (prevStats.total_new_entities === 0) {
    return currentStats.total_new_entities > 0 ? 100 : 0;
  }
  return Math.round(
    ((currentStats.total_new_entities - prevStats.total_new_entities) /
      prevStats.total_new_entities) *
      100
  );
}

// Fetch KPI stats
async function fetchKPIStats(): Promise<void> {
  if (!axios) return;

  loading.value.stats = true;
  try {
    // Fetch current period updates stats
    const currentStats = await fetchUpdatesStats(startDate.value, endDate.value);

    if (currentStats) {
      kpiStats.value.newThisPeriod = currentStats.total_new_entities;
      kpiStats.value.avgPerDay = Math.round(currentStats.average_per_day * 100) / 100;

      // Store for backward compatibility display
      statistics.value = currentStats;
    }

    // Calculate total entities (from trend data max cumulative)
    if (trendData.value.length > 0) {
      kpiStats.value.totalEntities = trendData.value[trendData.value.length - 1].count;
    }

    // Calculate trend delta
    const delta = await calculateTrendDelta();
    kpiStats.value.trendDelta = delta;
  } catch (error) {
    console.error('Failed to fetch KPI stats:', error);
    makeToast('Failed to fetch KPI statistics', 'Error', 'danger');
  } finally {
    loading.value.stats = false;
  }
}

// Fetch existing statistics (backward compatibility)
async function fetchExistingStatistics(): Promise<void> {
  if (!axios) return;

  try {
    // Re-review statistics
    const reReviewResponse = await axios.get(
      `${apiUrl}/api/statistics/rereview`,
      {
        params: { start_date: startDate.value, end_date: endDate.value },
        headers: getAuthHeaders(),
      }
    );
    reReviewStatistics.value = {
      total_rereviews: reReviewResponse.data.total_rereviews,
      percentage_finished: reReviewResponse.data.percentage_finished,
      average_per_day: reReviewResponse.data.average_per_day,
    };

    // Updated reviews statistics
    const updatedReviewsResponse = await axios.get(
      `${apiUrl}/api/statistics/updated_reviews`,
      {
        params: { start_date: startDate.value, end_date: endDate.value },
        headers: getAuthHeaders(),
      }
    );
    updatedReviewsStatistics.value = {
      total_updated_reviews: updatedReviewsResponse.data.total_updated_reviews,
    };

    // Updated statuses statistics
    const updatedStatusesResponse = await axios.get(
      `${apiUrl}/api/statistics/updated_statuses`,
      {
        params: { start_date: startDate.value, end_date: endDate.value },
        headers: getAuthHeaders(),
      }
    );
    updatedStatusesStatistics.value = {
      total_updated_statuses: updatedStatusesResponse.data.total_updated_statuses,
    };
  } catch (error) {
    console.error('Failed to fetch existing statistics:', error);
    makeToast('Failed to fetch statistics', 'Error', 'danger');
  }
}

// Main fetch function triggered by Apply button
async function fetchStatistics(): Promise<void> {
  await Promise.all([
    fetchTrendData(),
    fetchLeaderboard(),
    fetchKPIStats(),
    fetchExistingStatistics(),
  ]);
  lastUpdated.value = new Date();
}

// Refresh all data
function refreshAll(): void {
  fetchStatistics();
}

// On mount, fetch initial data
onMounted(() => {
  fetchStatistics();
});
</script>

<style scoped>
.stats-number {
  font-weight: bold;
}
</style>
