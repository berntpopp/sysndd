<!-- views/analyses/CurationComparisons.vue -->
<template>
  <div class="curation-comparisons-page">
    <div data-testid="curation-comparisons-frame" class="analysis-frame">
      <header class="analysis-header">
        <div class="analysis-title-group">
          <h1 class="analysis-title">Curation comparisons</h1>
          <p class="analysis-subtitle">
            Compare SysNDD gene coverage with external neurodevelopmental disorder curation lists.
          </p>
        </div>

        <span
          v-if="metadata.last_full_refresh"
          v-b-tooltip.hover.bottom
          data-testid="comparisons-refresh-badge"
          class="analysis-meta-badge"
          :aria-label="`Last comparisons refresh ${formatDateTime(metadata.last_full_refresh)} with ${metadata.sources_count} sources and ${metadata.rows_imported?.toLocaleString()} rows`"
          :title="`Last refresh: ${formatDateTime(metadata.last_full_refresh)} - ${metadata.sources_count} sources, ${metadata.rows_imported?.toLocaleString()} rows`"
        >
          Data {{ formatDate(metadata.last_full_refresh) }}
        </span>
        <span
          v-else-if="!loadingMetadata"
          data-testid="comparisons-refresh-badge"
          class="analysis-meta-badge analysis-meta-badge-warning"
          aria-label="No comparisons refresh data available"
        >
          No refresh data
        </span>
      </header>

      <nav class="analysis-tabs" aria-label="Curation comparison views">
        <RouterLink to="/CurationComparisons" class="analysis-tab" exact-active-class="active">
          Overlap
        </RouterLink>
        <RouterLink
          to="/CurationComparisons/Similarity"
          class="analysis-tab"
          exact-active-class="active"
        >
          Similarity
        </RouterLink>
        <RouterLink
          to="/CurationComparisons/Table"
          class="analysis-tab"
          exact-active-class="active"
        >
          Table
        </RouterLink>
      </nav>

      <main class="analysis-content">
        <router-view />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useHead } from '@unhead/vue';
import { getComparisonsMetadata } from '@/api/comparisons';

// Types
interface ComparisonsMetadata {
  last_full_refresh: string | null;
  last_refresh_status: string;
  last_refresh_error: string | null;
  sources_count: number;
  rows_imported: number;
}

// State
const metadata = ref<ComparisonsMetadata>({
  last_full_refresh: null,
  last_refresh_status: 'never',
  last_refresh_error: null,
  sources_count: 0,
  rows_imported: 0,
});
const loadingMetadata = ref(false);

// SEO
useHead({
  title: 'Curation comparisons',
  meta: [
    {
      name: 'description',
      content:
        'The Comparisons analysis can be used to compare different curation efforts for neurodevelopmental disorders (including attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability) based on UpSet plots, similarity matrix or tabular views.',
    },
  ],
});

// Helper to unwrap R/Plumber array values (scalars come as single-element arrays)
function unwrapValue<T>(val: T | T[]): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}

// Format date for display (date only)
function formatDate(dateString: string | null): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;
  return date.toLocaleDateString();
}

// Format datetime for tooltip
function formatDateTime(dateString: string | null): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;
  return date.toLocaleString();
}

// Fetch comparisons metadata on mount
async function fetchMetadata() {
  loadingMetadata.value = true;
  try {
    const data = await getComparisonsMetadata();
    metadata.value = {
      last_full_refresh: unwrapValue(data.last_full_refresh),
      last_refresh_status: unwrapValue(data.last_refresh_status) ?? 'never',
      last_refresh_error: unwrapValue(data.last_refresh_error),
      sources_count: unwrapValue(data.sources_count) ?? 0,
      rows_imported: unwrapValue(data.rows_imported) ?? 0,
    };
  } catch (error) {
    console.warn('Failed to fetch comparisons metadata:', error);
    // Silent fail - metadata is optional enhancement
  } finally {
    loadingMetadata.value = false;
  }
}

// Lifecycle
onMounted(() => {
  fetchMetadata();
});
</script>

<style scoped>
.curation-comparisons-page {
  box-sizing: border-box;
  min-height: 100%;
  padding: 0.75rem 1rem 1.5rem;
  background: #f6f8fb;
}

.analysis-frame {
  width: min(100%, 1480px);
  margin: 0 auto;
  overflow: hidden;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
}

.analysis-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem 1rem 0.7rem;
  border-bottom: 1px solid #e6ebf2;
}

.analysis-title-group {
  min-width: 0;
  text-align: left;
}

.analysis-title {
  margin: 0;
  color: #172033;
  font-size: 1.05rem;
  font-weight: 700;
  line-height: 1.2;
}

.analysis-subtitle {
  max-width: 58rem;
  margin: 0.25rem 0 0;
  color: #526070;
  font-size: 0.875rem;
  line-height: 1.35;
}

.analysis-meta-badge {
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

.analysis-meta-badge-warning {
  border-color: #f2cf6d;
  background: #fff6d8;
  color: #4a3700;
}

.analysis-tabs {
  display: flex;
  gap: 0.25rem;
  padding: 0 1rem;
  border-bottom: 1px solid #e6ebf2;
  background: #fbfcfe;
}

.analysis-tab {
  display: inline-flex;
  align-items: center;
  min-height: 2.45rem;
  padding: 0 0.75rem;
  border-bottom: 2px solid transparent;
  color: #244b7a;
  font-size: 0.92rem;
  font-weight: 700;
  text-decoration: none;
}

.analysis-tab:hover,
.analysis-tab:focus {
  color: #0b5ed7;
  background: #eef5ff;
}

.analysis-tab.active {
  border-bottom-color: #0d6efd;
  color: #111827;
  background: #fff;
}

.analysis-content {
  padding: 1rem;
}

@media (max-width: 575.98px) {
  .curation-comparisons-page {
    padding: 0.5rem 0.75rem 1rem;
  }

  .analysis-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.45rem;
    padding: 0.75rem;
  }

  .analysis-subtitle {
    font-size: 0.8125rem;
  }

  .analysis-tabs {
    justify-content: space-between;
    padding: 0 0.4rem;
  }

  .analysis-tab {
    flex: 1 1 0;
    justify-content: center;
    padding: 0 0.35rem;
  }

  .analysis-content {
    padding: 0.75rem;
  }
}
</style>
