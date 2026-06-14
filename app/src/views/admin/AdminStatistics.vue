<template>
  <AuthenticatedPageShell
    title="Admin Statistics"
    content-class="authenticated-route-content"
    full-width
  >
    <BContainer fluid class="py-3">
      <section class="admin-statistics-controls" data-testid="admin-statistics-controls">
        <div class="admin-statistics-controls__status">
          <span class="admin-statistics-controls__eyebrow">Reporting window</span>
          <span v-if="lastUpdated" class="admin-statistics-controls__updated">
            Data as of {{ formatDateTime(lastUpdated) }}
          </span>
        </div>
        <BForm class="admin-statistics-controls__form" @submit.prevent="fetchStatistics">
          <BFormGroup
            label="From"
            label-for="admin-statistics-start-date"
            label-class="admin-statistics-controls__label"
            class="admin-statistics-controls__field"
          >
            <BFormInput
              id="admin-statistics-start-date"
              v-model="startDate"
              type="date"
              size="sm"
            />
          </BFormGroup>
          <BFormGroup
            label="To"
            label-for="admin-statistics-end-date"
            label-class="admin-statistics-controls__label"
            class="admin-statistics-controls__field"
          >
            <BFormInput id="admin-statistics-end-date" v-model="endDate" type="date" size="sm" />
          </BFormGroup>
          <div class="admin-statistics-controls__actions">
            <BButton type="submit" variant="primary" size="sm">Apply</BButton>
            <BButton
              variant="outline-secondary"
              size="sm"
              :disabled="loading.trend || loading.leaderboard || loading.reReviewLeaderboard"
              @click="refreshAll"
            >
              <i class="bi bi-arrow-clockwise" aria-hidden="true"></i>
              Refresh
            </BButton>
          </div>
        </BForm>
      </section>

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
              <div class="admin-chart-header">
                <div>
                  <h2 class="admin-chart-title">Entity Submissions Over Time</h2>
                  <p class="admin-chart-description">
                    {{ trendDescription }}
                  </p>
                </div>
                <BFormRadioGroup
                  v-model="granularity"
                  :options="granularityOptions"
                  button-variant="outline-primary"
                  class="admin-chart-control"
                  size="sm"
                  buttons
                />
              </div>
              <div class="admin-chart-toolbar">
                <div class="admin-chart-toolbar__group">
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
                  class="admin-chart-toolbar__categories"
                  size="sm"
                  buttons
                  button-variant="outline-secondary"
                />
              </div>
            </template>
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
          <AdminOperationPanel
            title="Updates Statistics"
            :meta="`${startDate} to ${endDate}`"
            icon="bi-activity"
            heading-tag="h3"
          >
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
          </AdminOperationPanel>
        </BCol>
        <BCol v-if="reReviewStatistics" md="6" class="mb-3">
          <AdminOperationPanel
            title="Re-review Statistics"
            :meta="`${startDate} to ${endDate}`"
            icon="bi-clipboard-check"
            heading-tag="h3"
          >
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
          </AdminOperationPanel>
        </BCol>
      </BRow>
      <BRow v-if="updatedReviewsStatistics || updatedStatusesStatistics" class="mb-3">
        <BCol v-if="updatedReviewsStatistics" md="6" class="mb-3">
          <AdminOperationPanel
            title="Updated Reviews Statistics"
            :meta="`${startDate} to ${endDate}`"
            icon="bi-card-checklist"
            heading-tag="h3"
          >
            <p class="mb-0">
              Total updated reviews:
              <span class="stats-number">{{ updatedReviewsStatistics.total_updated_reviews }}</span>
            </p>
          </AdminOperationPanel>
        </BCol>
        <BCol v-if="updatedStatusesStatistics" md="6" class="mb-3">
          <AdminOperationPanel
            title="Updated Statuses Statistics"
            :meta="`${startDate} to ${endDate}`"
            icon="bi-list-check"
            heading-tag="h3"
          >
            <p class="mb-0">
              Total updated statuses:
              <span class="stats-number">{{
                updatedStatusesStatistics.total_updated_statuses
              }}</span>
            </p>
          </AdminOperationPanel>
        </BCol>
      </BRow>
    </BContainer>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import { ref, computed, onMounted } from 'vue';
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

const { makeToast } = useToast();

// Statistics requests go through the typed `@/api/statistics` clients used by
// the sub-composables (`useAdminTrendData`, `useLeaderboardData`,
// `useKPIStats`). Those delegate to the shared `apiClient`, whose request
// interceptor (`@/api/client`) injects the `Authorization` header on every
// outbound call, reading `useAuth().token.value` — so no injected axios,
// base URL, or auth-header plumbing is needed here.

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
} = useAdminTrendData(makeToast);

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
} = useLeaderboardData(makeToast);

const {
  loading: kpiLoading,
  kpiStats,
  statistics,
  reReviewStatistics,
  updatedReviewsStatistics,
  updatedStatusesStatistics,
  fetchKPIStats,
  fetchExistingStatistics,
} = useKPIStats(makeToast);

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
.admin-statistics-controls {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem 1rem;
  align-items: end;
  justify-content: space-between;
  margin-bottom: 1rem;
  padding: 0.875rem 1rem;
  border: 1px solid #d7dee8;
  border-radius: 8px;
  background: #f8fafc;
}

.admin-statistics-controls__status {
  display: flex;
  min-width: 13rem;
  flex-direction: column;
  gap: 0.125rem;
}

.admin-statistics-controls__eyebrow {
  color: #24364b;
  font-size: 0.875rem;
  font-weight: 700;
}

.admin-statistics-controls__updated {
  color: #5c6f82;
  font-size: 0.8125rem;
}

.admin-statistics-controls__form {
  display: flex;
  flex-wrap: wrap;
  gap: 0.625rem;
  align-items: end;
  justify-content: flex-end;
}

.admin-statistics-controls__field {
  margin-bottom: 0;
}

.admin-statistics-controls__field :deep(input) {
  min-width: 9.5rem;
}

.admin-statistics-controls__label {
  margin-bottom: 0.25rem;
  color: #41576f;
  font-size: 0.75rem;
  font-weight: 700;
}

.admin-statistics-controls__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.admin-chart-header {
  display: flex;
  gap: 1rem;
  align-items: flex-start;
  justify-content: space-between;
}

.admin-chart-title {
  margin: 0;
  color: #24364b;
  font-size: 1rem;
  font-weight: 700;
}

.admin-chart-description {
  max-width: 52rem;
  margin: 0.25rem 0 0;
  color: #5c6f82;
  font-size: 0.8125rem;
}

.admin-chart-control {
  flex-shrink: 0;
}

.admin-chart-toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.625rem 1rem;
  align-items: center;
  justify-content: space-between;
  margin-top: 0.875rem;
}

.admin-chart-toolbar__group,
.admin-chart-toolbar__categories {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.stats-number {
  font-weight: bold;
}

@media (max-width: 767.98px) {
  .admin-statistics-controls,
  .admin-statistics-controls__form,
  .admin-statistics-controls__actions,
  .admin-chart-header,
  .admin-chart-toolbar {
    align-items: stretch;
  }

  .admin-statistics-controls,
  .admin-statistics-controls__form,
  .admin-chart-header {
    flex-direction: column;
  }

  .admin-statistics-controls__form,
  .admin-statistics-controls__field,
  .admin-statistics-controls__actions,
  .admin-statistics-controls__actions :deep(.btn),
  .admin-chart-control {
    width: 100%;
  }

  .admin-statistics-controls__field :deep(input) {
    width: 100%;
  }
}
</style>
