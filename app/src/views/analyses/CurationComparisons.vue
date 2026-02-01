<!-- views/analyses/CurationComparisons.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <div>
            <BCard no-body>
              <BCardHeader header-tag="nav" class="d-flex justify-content-between align-items-center flex-wrap">
                <div class="d-flex align-items-center">
                  <h5 class="mb-0 me-3">Curation comparisons</h5>
                  <span
                    v-if="metadata.last_full_refresh"
                    v-b-tooltip.hover.bottom
                    class="badge bg-secondary"
                    :title="`Last refresh: ${formatDateTime(metadata.last_full_refresh)} - ${metadata.sources_count} sources, ${metadata.rows_imported?.toLocaleString()} rows`"
                  >
                    Data: {{ formatDate(metadata.last_full_refresh) }}
                  </span>
                  <span
                    v-else-if="!loadingMetadata"
                    class="badge bg-warning text-dark"
                  >
                    No refresh data
                  </span>
                </div>
                <BNav card-header tabs class="border-0">
                  <BNavItem to="/CurationComparisons" exact exact-active-class="active">
                    Overlap
                  </BNavItem>
                  <BNavItem to="/CurationComparisons/Similarity" exact exact-active-class="active">
                    Similarity
                  </BNavItem>
                  <BNavItem to="/CurationComparisons/Table" exact exact-active-class="active">
                    Table
                  </BNavItem>
                </BNav>
              </BCardHeader>

              <BCardBody>
                <router-view />
              </BCardBody>
            </BCard>
          </div>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useHead } from '@unhead/vue';
import axios from 'axios';

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
    const response = await axios.get(
      `${import.meta.env.VITE_API_URL}/api/comparisons/metadata`
    );
    metadata.value = {
      last_full_refresh: unwrapValue(response.data.last_full_refresh),
      last_refresh_status: unwrapValue(response.data.last_refresh_status) ?? 'never',
      last_refresh_error: unwrapValue(response.data.last_refresh_error),
      sources_count: unwrapValue(response.data.sources_count) ?? 0,
      rows_imported: unwrapValue(response.data.rows_imported) ?? 0,
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
/* Ensure nav tabs align properly with header content */
.card-header .nav-tabs {
  margin-bottom: -1px;
}
</style>
