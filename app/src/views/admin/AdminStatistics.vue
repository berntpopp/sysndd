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
          <BButton type="submit" variant="primary" size="sm" class="mt-3"> Apply </BButton>
        </BForm>
      </BCol>
    </BRow>

    <!-- KPI Cards Row -->
    <BRow class="mb-4">
      <BCol v-for="stat in kpiCards" :key="stat.label" md="3" class="mb-3 mb-md-0">
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
              />
            </div>
            <div class="d-flex justify-content-between align-items-center mt-2">
              <div class="d-flex align-items-center gap-2">
                <BFormRadioGroup
                  v-model="nddFilter"
                  :options="nddFilterOptions"
                  button-variant="outline-secondary"
                  size="sm"
                  buttons
                />
                <BFormRadioGroup
                  v-model="categoryDisplay"
                  :options="categoryDisplayOptions"
                  button-variant="outline-secondary"
                  size="sm"
                  buttons
                />
              </div>
              <BFormCheckboxGroup
                v-model="selectedCategories"
                :options="categoryFilterOptions"
                size="sm"
                buttons
                button-variant="outline-secondary"
              />
            </div>
          </template>
          <p class="text-muted small mb-2">
            {{ trendDescription }}
          </p>
          <EntityTrendChart
            :entity-data="trendData"
            :category-data="categoryDisplay === 'by_category' ? trendCategoryData : undefined"
            :display-mode="categoryDisplay"
            :loading="loading.trend"
            :show-moving-average="categoryDisplay === 'combined'"
            :y-max="trendYMax"
          />
        </BCard>
      </BCol>
    </BRow>

    <!-- Contributor Leaderboard -->
    <BRow class="mb-4">
      <BCol md="6">
        <BCard class="h-100">
          <template #header>
            <div class="d-flex justify-content-between align-items-center">
              <h5 class="mb-0">Top Contributors</h5>
              <BFormRadioGroup
                v-model="leaderboardScope"
                :options="leaderboardScopeOptions"
                button-variant="outline-primary"
                size="sm"
                buttons
                @change="() => fetchLeaderboard(startDate, endDate)"
              />
            </div>
          </template>
          <p class="text-muted small mb-2">
            Curator leaderboard ranked by gene-disease association submissions.
            {{
              leaderboardScope === 'all_time'
                ? 'Cumulative all-time contributions.'
                : `Contributions within selected ${periodLengthDays} day period.`
            }}
          </p>
          <ContributorBarChart :contributors="leaderboardData" :loading="loading.leaderboard" />
        </BCard>
      </BCol>
      <BCol md="6">
        <BCard class="h-100">
          <template #header>
            <div class="d-flex justify-content-between align-items-center">
              <h5 class="mb-0">Top Re-Reviewers</h5>
              <BFormRadioGroup
                v-model="reReviewLeaderboardScope"
                :options="reReviewLeaderboardScopeOptions"
                button-variant="outline-primary"
                size="sm"
                buttons
                @change="() => fetchReReviewLeaderboard(startDate, endDate)"
              />
            </div>
          </template>
          <p class="text-muted small mb-2">
            Reviewer leaderboard ranked by submitted re-reviews.
            {{
              reReviewLeaderboardScope === 'all_time'
                ? 'Cumulative all-time re-reviews.'
                : `Re-reviews within selected ${periodLengthDays} day period.`
            }}
          </p>
          <ReReviewBarChart
            :reviewers="reReviewLeaderboardData"
            :loading="loading.reReviewLeaderboard"
          />
        </BCard>
      </BCol>
    </BRow>

    <!-- Existing text stats (kept for reference) -->
    <BRow v-if="statistics" class="mb-3">
      <BCol md="6" class="mb-3">
        <BCard header-tag="header" body-class="p-3" header-class="p-2" border-variant="dark">
          <template #header>
            <h5 class="mb-0 text-start">
              Updates Statistics
              <small class="text-muted">({{ startDate }} to {{ endDate }})</small>
            </h5>
          </template>
          <p class="mb-1">
            Total new entities:
            <span class="stats-number">{{ statistics.total_new_entities }}</span>
          </p>
          <p class="mb-1">
            Unique genes: <span class="stats-number">{{ statistics.unique_genes }}</span>
          </p>
          <p class="mb-0">
            Average per day:
            <span class="stats-number">{{ formatDecimal(statistics.average_per_day) }}</span>
          </p>
        </BCard>
      </BCol>
      <BCol v-if="reReviewStatistics" md="6" class="mb-3">
        <BCard header-tag="header" body-class="p-3" header-class="p-2" border-variant="dark">
          <template #header>
            <h5 class="mb-0 text-start">
              Re-review Statistics
              <small class="text-muted">({{ startDate }} to {{ endDate }})</small>
            </h5>
          </template>
          <p class="mb-1">
            Total re-reviews:
            <span class="stats-number">{{ reReviewStatistics.total_rereviews }}</span>
          </p>
          <p class="mb-1">
            Percentage finished:
            <span class="stats-number"
              >{{ formatDecimal(reReviewStatistics.percentage_finished) }}%</span
            >
          </p>
          <p class="mb-0">
            Average per day:
            <span class="stats-number">{{
              formatDecimal(reReviewStatistics.average_per_day)
            }}</span>
          </p>
        </BCard>
      </BCol>
    </BRow>
    <BRow v-if="updatedReviewsStatistics || updatedStatusesStatistics" class="mb-3">
      <BCol v-if="updatedReviewsStatistics" md="6" class="mb-3">
        <BCard header-tag="header" body-class="p-3" header-class="p-2" border-variant="dark">
          <template #header>
            <h5 class="mb-0 text-start">
              Updated Reviews Statistics
              <small class="text-muted">({{ startDate }} to {{ endDate }})</small>
            </h5>
          </template>
          <p class="mb-0">
            Total updated reviews:
            <span class="stats-number">{{ updatedReviewsStatistics.total_updated_reviews }}</span>
          </p>
        </BCard>
      </BCol>
      <BCol v-if="updatedStatusesStatistics" md="6" class="mb-3">
        <BCard header-tag="header" body-class="p-3" header-class="p-2" border-variant="dark">
          <template #header>
            <h5 class="mb-0 text-start">
              Updated Statuses Statistics
              <small class="text-muted">({{ startDate }} to {{ endDate }})</small>
            </h5>
          </template>
          <p class="mb-0">
            Total updated statuses:
            <span class="stats-number">{{ updatedStatusesStatistics.total_updated_statuses }}</span>
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
  BFormCheckboxGroup,
} from 'bootstrap-vue-next';
import useToast from '@/composables/useToast';
import { inclusiveDayCount } from '@/utils/dateUtils';
import { useAdminTrendData } from './composables/useAdminTrendData';
import { useLeaderboardData } from './composables/useLeaderboardData';
import { useKPIStats } from './composables/useKPIStats';
import EntityTrendChart from './components/charts/EntityTrendChart.vue';
import ContributorBarChart from './components/charts/ContributorBarChart.vue';
import ReReviewBarChart from './components/charts/ReReviewBarChart.vue';
import StatCard from './components/statistics/StatCard.vue';

// Inject axios
const axios = inject<AxiosInstance>('axios');
const { makeToast } = useToast();

// API base URL
const apiUrl = import.meta.env.VITE_API_URL;

function getAuthHeaders() {
  return {
    Authorization: `Bearer ${localStorage.getItem('token')}`,
  };
}

// Date range (default: last 12 months)
const today = new Date();
const twelveMonthsAgo = new Date(today.getFullYear() - 1, today.getMonth(), today.getDate());
const startDate = ref(twelveMonthsAgo.toISOString().split('T')[0]);
const endDate = ref(today.toISOString().split('T')[0]);

const lastUpdated = ref<Date | null>(null);

// --- Composables ---
const {
  trendData,
  trendCategoryData,
  trendYMax,
  totalEntities,
  loading: trendLoading,
  granularity,
  nddFilter,
  categoryDisplay,
  selectedCategories,
  trendDescription,
  fetchTrendData,
} = useAdminTrendData(axios, apiUrl, getAuthHeaders, makeToast);

const {
  leaderboardData,
  reReviewLeaderboardData,
  totalContributors,
  loadingLeaderboard,
  loadingReReview,
  leaderboardScope,
  reReviewLeaderboardScope,
  fetchLeaderboard,
  fetchReReviewLeaderboard,
} = useLeaderboardData(axios, apiUrl, getAuthHeaders, makeToast);

const {
  loading: kpiLoading,
  kpiStats,
  statistics,
  reReviewStatistics,
  updatedReviewsStatistics,
  updatedStatusesStatistics,
  fetchKPIStats,
  fetchExistingStatistics,
} = useKPIStats(axios, apiUrl, getAuthHeaders, makeToast);

// --- Composite loading state for template ---
const loading = computed(() => ({
  trend: trendLoading.value,
  leaderboard: loadingLeaderboard.value,
  reReviewLeaderboard: loadingReReview.value,
  stats: kpiLoading.value,
}));

// --- Options arrays ---
const granularityOptions = [
  { text: 'Monthly', value: 'month' },
  { text: 'Weekly', value: 'week' },
  { text: 'Daily', value: 'day' },
];

const leaderboardScopeOptions = [
  { text: 'All Time', value: 'all_time' },
  { text: 'Date Range', value: 'range' },
];

const reReviewLeaderboardScopeOptions = [
  { text: 'All Time', value: 'all_time' },
  { text: 'Date Range', value: 'range' },
];

const nddFilterOptions = [
  { text: 'NDD', value: 'ndd' },
  { text: 'Non-NDD', value: 'non_ndd' },
  { text: 'All', value: 'all' },
];

const categoryDisplayOptions = [
  { text: 'Combined', value: 'combined' },
  { text: 'By Category', value: 'by_category' },
];

const categoryFilterOptions = [
  { text: 'Definitive', value: 'Definitive' },
  { text: 'Moderate', value: 'Moderate' },
  { text: 'Limited', value: 'Limited' },
  { text: 'Refuted', value: 'Refuted' },
];

// --- Computed ---
const periodLengthDays = computed(() => inclusiveDayCount(startDate.value, endDate.value));

// KPI cards — orchestrates values from trend, leaderboard, and KPI composables
const kpiCards = computed(() => [
  {
    label: 'Total Entities',
    value: totalEntities.value,
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
    value: totalContributors.value,
    context: 'Curators with entity submissions',
  },
  {
    label: 'Avg Per Day',
    value: kpiStats.value.avgPerDay,
    context: `Mean daily rate (${periodLengthDays.value} day period)`,
  },
]);

// --- Helpers ---
function formatDateTime(date: Date): string {
  return date.toLocaleString();
}

function formatDecimal(value: number | undefined | null): string {
  if (value === undefined || value === null || typeof value !== 'number' || isNaN(value))
    return 'N/A';
  return value.toFixed(2);
}

// --- Orchestration ---
async function fetchStatistics(): Promise<void> {
  const start = startDate.value;
  const end = endDate.value;
  await Promise.all([
    fetchTrendData(),
    fetchLeaderboard(start, end),
    fetchReReviewLeaderboard(start, end),
    fetchKPIStats(start, end),
    fetchExistingStatistics(start, end),
  ]);
  lastUpdated.value = new Date();
}

function refreshAll(): void {
  fetchStatistics();
}

onMounted(() => {
  fetchStatistics();
});
</script>

<style scoped>
.stats-number {
  font-weight: bold;
}
</style>
