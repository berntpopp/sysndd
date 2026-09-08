<template>
  <section class="home-panel home-stats-panel" aria-labelledby="home-stats-title">
    <header class="home-panel__header">
      <div>
        <h2 id="home-stats-title" class="home-panel__title">Database statistics</h2>
        <p class="home-panel__description">Current curated entity and gene coverage.</p>
      </div>
      <span v-if="loading" class="home-panel__meta home-skeleton-meta" aria-hidden="true" />
      <span v-else-if="!error" class="home-panel__meta">Updated {{ lastUpdate }}</span>
    </header>

    <!-- Loading skeleton matching loaded 2-column grid geometry -->
    <div
      v-if="loading"
      class="home-stats-grid home-stats-grid--skeleton"
      aria-busy="true"
      aria-label="Loading database statistics"
    >
      <div v-for="block in 2" :key="`skeleton-block-${block}`" class="home-stats-block">
        <div class="home-stats-block__header">
          <h3><span class="home-skeleton-text home-skeleton-text--title" /></h3>
          <span><span class="home-skeleton-text home-skeleton-text--subtitle" /></span>
        </div>
        <table class="home-stats-table">
          <thead>
            <tr>
              <th scope="col">Category</th>
              <th scope="col" class="text-end">Count</th>
              <th scope="col" class="text-end">Details</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in 3" :key="`skeleton-row-${row}`">
              <td>
                <div class="home-category">
                  <div class="home-skeleton-dot" />
                  <div class="home-skeleton-text home-skeleton-text--label" />
                </div>
              </td>
              <td class="text-end">
                <div class="home-skeleton-text home-skeleton-text--count ms-auto" />
              </td>
              <td class="text-end">
                <div class="home-skeleton-circle ms-auto" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Inline error state -->
    <div v-else-if="error" class="home-panel-state home-panel-state--error" role="alert">
      <i class="bi bi-exclamation-circle home-panel-state__icon" aria-hidden="true" />
      <span>{{ error }}</span>
    </div>

    <div v-else class="home-stats-grid">
      <div class="home-stats-block">
        <div class="home-stats-block__header">
          <h3>Entities</h3>
          <span>Gene-inheritance-disease units</span>
        </div>
        <table class="home-stats-table">
          <thead>
            <tr>
              <th scope="col">Category</th>
              <th scope="col" class="text-end">Count</th>
              <th scope="col" class="text-end">Details</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="row in entityRows" :key="`entity-${row.category}`">
              <tr>
                <td>
                  <div class="home-category">
                    <CategoryIcon :category="row.category" size="sm" />
                    <span>{{ row.category }}</span>
                  </div>
                </td>
                <td class="text-end">
                  <BLink :to="`/Entities?filter=any(category,${row.category})`">
                    {{ formatNumber(row.n) }}
                  </BLink>
                </td>
                <td class="text-end">
                  <BButton
                    size="sm"
                    variant="outline-primary"
                    class="home-icon-button"
                    :aria-expanded="isExpanded('entity', row.category)"
                    :aria-label="`${isExpanded('entity', row.category) ? 'Hide' : 'Show'} ${row.category} entity inheritance details`"
                    @click="toggle('entity', row.category)"
                  >
                    <i
                      class="bi"
                      :class="
                        isExpanded('entity', row.category) ? 'bi-chevron-up' : 'bi-chevron-down'
                      "
                      aria-hidden="true"
                    />
                  </BButton>
                </td>
              </tr>
              <tr v-if="isExpanded('entity', row.category)" class="home-detail-row">
                <td colspan="3">
                  <div class="home-detail-grid">
                    <BLink
                      v-for="detail in row.groups"
                      :key="`${row.category}-${detail.inheritance}`"
                      class="home-detail-chip"
                      :to="entityDetailLink(detail)"
                    >
                      <span>{{ inheritanceOverviewText[detail.inheritance] }}</span>
                      <strong>{{ formatNumber(detail.n) }}</strong>
                    </BLink>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>

      <div class="home-stats-block">
        <div class="home-stats-block__header">
          <h3>Genes</h3>
          <span>Panel-ready gene aggregation</span>
        </div>
        <table class="home-stats-table">
          <thead>
            <tr>
              <th scope="col">Category</th>
              <th scope="col" class="text-end">Count</th>
              <th scope="col" class="text-end">Details</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="row in geneRows" :key="`gene-${row.category}`">
              <tr>
                <td>
                  <div class="home-category">
                    <CategoryIcon :category="row.category" size="sm" />
                    <span>{{ row.category }}</span>
                  </div>
                </td>
                <td class="text-end">
                  <BLink :to="`/Panels/${row.category}/${row.inheritance}`">
                    {{ formatNumber(row.n) }}
                  </BLink>
                </td>
                <td class="text-end">
                  <BButton
                    size="sm"
                    variant="outline-primary"
                    class="home-icon-button"
                    :aria-expanded="isExpanded('gene', row.category)"
                    :aria-label="`${isExpanded('gene', row.category) ? 'Hide' : 'Show'} ${row.category} gene inheritance details`"
                    @click="toggle('gene', row.category)"
                  >
                    <i
                      class="bi"
                      :class="
                        isExpanded('gene', row.category) ? 'bi-chevron-up' : 'bi-chevron-down'
                      "
                      aria-hidden="true"
                    />
                  </BButton>
                </td>
              </tr>
              <tr v-if="isExpanded('gene', row.category)" class="home-detail-row">
                <td colspan="3">
                  <div class="home-detail-grid">
                    <BLink
                      v-for="detail in row.groups"
                      :key="`${row.category}-${detail.inheritance}`"
                      class="home-detail-chip"
                      :to="`/Panels/${detail.category}/${detail.inheritance}`"
                    >
                      <span>{{ inheritanceOverviewText[detail.inheritance] }}</span>
                      <strong>{{ formatNumber(detail.n) }}</strong>
                    </BLink>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';

interface StatDetail {
  category: string;
  inheritance: string;
  n: number;
}

interface StatRow {
  category: string;
  inheritance: string;
  n: number;
  groups?: StatDetail[];
}

interface StatisticsPayload {
  data?: StatRow[];
}

const props = defineProps<{
  entityStatistics: StatisticsPayload;
  geneStatistics: StatisticsPayload;
  lastUpdate: string;
  inheritanceOverviewText: Record<string, string>;
  inheritanceLink: Record<string, string[]>;
  loading?: boolean;
  error?: string | null;
}>();

const expanded = ref<Record<string, boolean>>({});

const entityRows = computed(() => props.entityStatistics.data ?? []);
const geneRows = computed(() => props.geneStatistics.data ?? []);

function rowKey(kind: 'entity' | 'gene', category: string) {
  return `${kind}:${category}`;
}

function isExpanded(kind: 'entity' | 'gene', category: string) {
  return Boolean(expanded.value[rowKey(kind, category)]);
}

function toggle(kind: 'entity' | 'gene', category: string) {
  const key = rowKey(kind, category);
  expanded.value[key] = !expanded.value[key];
}

function formatNumber(value: number) {
  return Number(value || 0).toLocaleString();
}

function entityDetailLink(detail: StatDetail) {
  const inheritanceTerms = props.inheritanceLink[detail.inheritance] ?? [detail.inheritance];
  return `/Entities?filter=any(category,${detail.category}),any(hpo_mode_of_inheritance_term_name,${inheritanceTerms.join(',')})`;
}
</script>

<style scoped>
.home-panel {
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
}

.home-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem 1rem 0.7rem;
  border-bottom: 1px solid #e6ebf2;
  border-top-left-radius: 7px;
  border-top-right-radius: 7px;
  background: #fbfcfe;
}

.home-panel__title {
  margin: 0;
  color: #172033;
  font-size: 1.05rem;
  font-weight: 700;
  line-height: 1.2;
}

.home-panel__description {
  margin: 0.25rem 0 0;
  color: #526070;
  font-size: 0.875rem;
  line-height: 1.35;
}

.home-panel__meta {
  flex: 0 0 auto;
  display: inline-flex;
  align-items: center;
  min-height: 1.55rem;
  padding: 0.2rem 0.55rem;
  border: 1px solid #bdc7d4;
  border-radius: 999px;
  background: #eef2f7;
  color: #223044;
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

.home-stats-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
  padding: 1rem;
}

.home-stats-block {
  min-width: 0;
}

.home-stats-block__header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.35rem;
}

.home-stats-block__header h3 {
  margin: 0;
  color: #27364a;
  font-size: 0.95rem;
  font-weight: 700;
}

.home-stats-block__header span {
  color: #64748b;
  font-size: 0.75rem;
}

.home-stats-table {
  width: 100%;
  table-layout: fixed;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.home-stats-table th:nth-child(1),
.home-stats-table td:nth-child(1) {
  width: 52%;
}

.home-stats-table th:nth-child(2),
.home-stats-table td:nth-child(2) {
  width: 32%;
  font-variant-numeric: tabular-nums;
  text-align: right;
}

.home-stats-table th:nth-child(3),
.home-stats-table td:nth-child(3) {
  width: 16%;
  text-align: right;
}

.home-stats-table th {
  padding: 0.45rem 0.4rem;
  border-bottom: 1px solid #d8e0ea;
  background: #f6f8fb;
  color: #172033;
  font-weight: 700;
}

.home-stats-table td {
  padding: 0.5rem 0.4rem;
  border-bottom: 1px solid #edf1f5;
  vertical-align: middle;
}

.home-category {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  min-width: 0;
}

.home-icon-button {
  width: 1.65rem;
  height: 1.65rem;
  padding: 0;
  border-radius: 999px;
}

.home-detail-row td {
  background: #f8fafc;
}

.home-detail-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.home-detail-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 1.55rem;
  padding: 0.2rem 0.5rem;
  border: 1px solid #cdd7e4;
  border-radius: 999px;
  background: #fff;
  color: #244b7a;
  font-size: 0.75rem;
  font-weight: 700;
  text-decoration: none;
  transition:
    transform 0.14s ease,
    border-color 0.14s ease,
    box-shadow 0.14s ease,
    background-color 0.14s ease;
}

.home-detail-chip span {
  color: #526070;
  font-weight: 600;
}

.home-detail-chip:hover,
.home-detail-chip:focus {
  border-color: #0f172a;
  background: #fff;
  box-shadow: 0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
  color: #0f172a;
  outline: none;
  transform: translateY(-1px);
}

.home-detail-chip:focus-visible {
  box-shadow:
    0 0 0 0.16rem rgba(0, 121, 107, 0.25),
    0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
}

/* Loading skeleton styles */
@keyframes home-stats-shimmer {
  0% {
    background-position: -200% 0;
  }
  100% {
    background-position: 200% 0;
  }
}

.home-skeleton-meta,
.home-skeleton-text,
.home-skeleton-dot,
.home-skeleton-circle {
  background: linear-gradient(90deg, #edf2f7 25%, #f8fafc 37%, #edf2f7 63%);
  background-size: 400% 100%;
  animation: home-stats-shimmer 1.4s ease infinite;
}

.home-skeleton-meta {
  display: inline-block;
  width: 6.5rem;
  height: 0.85rem;
  border-radius: 4px;
}

.home-skeleton-text {
  display: inline-block;
  height: 0.85rem;
  border-radius: 4px;
}

.home-skeleton-text--title {
  width: 4rem;
}

.home-skeleton-text--subtitle {
  width: 7.5rem;
  height: 0.75rem;
}

.home-skeleton-text--label {
  width: 4.5rem;
}

.home-skeleton-text--count {
  width: 2.75rem;
}

.home-skeleton-dot {
  width: 0.875rem;
  height: 0.875rem;
  border-radius: 50%;
  flex-shrink: 0;
}

.home-skeleton-circle {
  width: 1.65rem;
  height: 1.65rem;
  border-radius: 50%;
}

.home-panel-state {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 1.25rem 1rem;
  color: var(--neutral-700, #616161);
  font-size: 0.875rem;
}

.home-panel-state--error {
  color: #b71c1c;
}

.home-panel-state--empty {
  color: var(--neutral-600, #757575);
}

.home-panel-state__icon {
  flex: 0 0 auto;
  font-size: 1rem;
}

@media (max-width: 991.98px) {
  .home-stats-grid {
    grid-template-columns: 1fr;
  }
}

@media (prefers-reduced-motion: reduce) {
  .home-detail-chip {
    transition: none;
  }

  .home-detail-chip:hover,
  .home-detail-chip:focus {
    transform: none;
  }

  .home-skeleton-meta,
  .home-skeleton-text,
  .home-skeleton-dot,
  .home-skeleton-circle {
    animation: none;
    background: #edf2f7;
  }
}

@media (max-width: 575.98px) {
  .home-panel__header {
    flex-direction: column;
    gap: 0.5rem;
    padding: 0.75rem;
  }

  .home-stats-grid {
    padding: 0.75rem;
  }

  .home-stats-block__header {
    align-items: flex-start;
    flex-direction: column;
    gap: 0.1rem;
  }
}
</style>
