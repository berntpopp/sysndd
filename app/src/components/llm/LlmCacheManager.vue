<!-- components/llm/LlmCacheManager.vue -->
<template>
  <div>
    <!-- Stats Summary -->
    <BRow class="g-3 mb-4">
      <BCol md="6">
        <BCard>
          <template #header>
            <h6 class="mb-0">Functional Clusters</h6>
          </template>
          <div class="d-flex justify-content-around text-center">
            <div>
              <div class="h4 mb-0">{{ stats?.by_type?.functional?.count ?? 0 }}</div>
              <small class="text-muted">Total</small>
            </div>
            <div>
              <div class="h4 mb-0 text-success">
                {{ stats?.by_type?.functional?.validated ?? 0 }}
              </div>
              <small class="text-muted">Validated</small>
            </div>
            <div>
              <div class="h4 mb-0 text-warning">
                {{ stats?.by_type?.functional?.pending ?? 0 }}
              </div>
              <small class="text-muted">Pending</small>
            </div>
          </div>
          <template #footer>
            <BButtonGroup size="sm" class="w-100">
              <BButton variant="outline-danger" @click="$emit('clear', 'functional')">
                Clear
              </BButton>
              <BButton variant="outline-primary" @click="$emit('regenerate', 'functional')">
                Regenerate
              </BButton>
            </BButtonGroup>
          </template>
        </BCard>
      </BCol>
      <BCol md="6">
        <BCard>
          <template #header>
            <h6 class="mb-0">Phenotype Clusters</h6>
          </template>
          <div class="d-flex justify-content-around text-center">
            <div>
              <div class="h4 mb-0">{{ stats?.by_type?.phenotype?.count ?? 0 }}</div>
              <small class="text-muted">Total</small>
            </div>
            <div>
              <div class="h4 mb-0 text-success">
                {{ stats?.by_type?.phenotype?.validated ?? 0 }}
              </div>
              <small class="text-muted">Validated</small>
            </div>
            <div>
              <div class="h4 mb-0 text-warning">
                {{ stats?.by_type?.phenotype?.pending ?? 0 }}
              </div>
              <small class="text-muted">Pending</small>
            </div>
          </div>
          <template #footer>
            <BButtonGroup size="sm" class="w-100">
              <BButton variant="outline-danger" @click="$emit('clear', 'phenotype')">
                Clear
              </BButton>
              <BButton variant="outline-primary" @click="$emit('regenerate', 'phenotype')">
                Regenerate
              </BButton>
            </BButtonGroup>
          </template>
        </BCard>
      </BCol>
    </BRow>

    <!-- Cached Summaries Table -->
    <BCard>
      <template #header>
        <BRow class="align-items-center">
          <BCol>
            <h6 class="mb-0">Cached Summaries</h6>
          </BCol>
          <BCol md="3">
            <BFormSelect
              v-model="filters.cluster_type"
              :options="typeOptions"
              size="sm"
              @change="loadSummaries"
            />
          </BCol>
          <BCol md="3">
            <BFormSelect
              v-model="filters.validation_status"
              :options="statusOptions"
              size="sm"
              @change="loadSummaries"
            />
          </BCol>
        </BRow>
      </template>

      <BTable :items="summaries" :fields="fields" :busy="loading" responsive hover small striped>
        <template #cell(cluster_type)="data">
          <BBadge :variant="data.value === 'functional' ? 'primary' : 'info'">
            {{ data.value }}
          </BBadge>
        </template>
        <template #cell(validation_status)="data">
          <BBadge :variant="statusVariant(String(data.value))">
            {{ data.value }}
          </BBadge>
        </template>
        <template #cell(is_current)="data">
          <BBadge v-if="data.value" variant="success">Current</BBadge>
          <BBadge v-else variant="secondary">Stale</BBadge>
        </template>
        <template #cell(created_at)="data">
          <small>{{ formatDateTime(String(data.value)) }}</small>
        </template>
        <template #cell(actions)="data">
          <BButtonGroup size="sm">
            <BButton
              v-if="data.item.validation_status === 'pending'"
              variant="outline-success"
              title="Approve this summary"
              @click="$emit('validate', data.item.cache_id, 'validate')"
            >
              Approve
            </BButton>
            <BButton
              v-if="data.item.validation_status === 'pending'"
              variant="outline-danger"
              title="Reject this summary"
              @click="$emit('validate', data.item.cache_id, 'reject')"
            >
              Reject
            </BButton>
            <BButton
              variant="outline-secondary"
              title="View summary details"
              @click="viewDetails(data.item)"
            >
              View
            </BButton>
          </BButtonGroup>
        </template>
      </BTable>

      <!-- Empty State -->
      <div v-if="!loading && summaries.length === 0" class="text-center text-muted py-4">
        <i class="bi bi-inbox fs-1 d-block mb-2" />
        <span>No cached summaries found. Try adjusting filters or generating summaries.</span>
      </div>

      <!-- Pagination -->
      <BRow class="mt-3">
        <BCol>
          <BPagination
            v-model="page"
            :total-rows="totalRows"
            :per-page="perPage"
            size="sm"
            @update:model-value="loadSummaries"
          />
        </BCol>
        <BCol class="text-end text-muted small">
          Showing {{ summaries.length }} of {{ totalRows }} summaries
        </BCol>
      </BRow>
    </BCard>

    <!-- Summary Detail Modal -->
    <BModal
      v-model="showDetailModal"
      size="xl"
      :title="`Summary #${selectedSummary?.cache_id} - ${selectedSummary?.cluster_type} cluster ${selectedSummary?.cluster_number}`"
    >
      <div v-if="selectedSummary">
        <!-- Summary Metadata -->
        <BRow class="mb-3">
          <BCol md="4">
            <small class="text-muted">Model:</small>
            <div>{{ selectedSummary.model_name }}</div>
          </BCol>
          <BCol md="4">
            <small class="text-muted">Prompt Version:</small>
            <div>{{ selectedSummary.prompt_version }}</div>
          </BCol>
          <BCol md="4">
            <small class="text-muted">Created:</small>
            <div>{{ formatDateTime(selectedSummary.created_at) }}</div>
          </BCol>
        </BRow>

        <!-- Tags -->
        <div v-if="selectedSummary.tags?.length" class="mb-3">
          <small class="text-muted d-block mb-1">Tags:</small>
          <BBadge
            v-for="tag in selectedSummary.tags"
            :key="tag"
            variant="secondary"
            class="me-1"
          >
            {{ tag }}
          </BBadge>
        </div>

        <!-- Summary JSON -->
        <BCard bg-variant="light">
          <template #header>
            <small class="fw-bold">Summary Content</small>
          </template>
          <pre class="mb-0 overflow-auto" style="max-height: 50vh; font-size: 0.8rem;">{{
            JSON.stringify(selectedSummary.summary_json, null, 2)
          }}</pre>
        </BCard>
      </div>
    </BModal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useLlmAdmin } from '@/composables/useLlmAdmin';
import type { CacheStats, CachedSummary, ClusterType, ValidationStatus } from '@/types/llm';

defineProps<{
  stats: CacheStats | null;
}>();

defineEmits<{
  (e: 'clear', type: ClusterType): void;
  (e: 'validate', cacheId: number, action: 'validate' | 'reject'): void;
  (e: 'regenerate', type: ClusterType): void;
}>();

const { fetchCachedSummaries } = useLlmAdmin();

// Helper to get auth token from localStorage
function getToken(): string | null {
  return localStorage.getItem('token');
}

const summaries = ref<CachedSummary[]>([]);
const loading = ref(false);
const page = ref(1);
const perPage = ref(20);
const totalRows = ref(0);
const showDetailModal = ref(false);
const selectedSummary = ref<CachedSummary | null>(null);

const filters = reactive({
  cluster_type: undefined as ClusterType | undefined,
  validation_status: undefined as ValidationStatus | undefined,
});

const typeOptions = [
  { value: undefined, text: 'All Types' },
  { value: 'functional', text: 'Functional' },
  { value: 'phenotype', text: 'Phenotype' },
];

const statusOptions = [
  { value: undefined, text: 'All Statuses' },
  { value: 'validated', text: 'Validated' },
  { value: 'pending', text: 'Pending' },
  { value: 'rejected', text: 'Rejected' },
];

const fields = [
  { key: 'cache_id', label: 'ID', sortable: true },
  { key: 'cluster_type', label: 'Type', sortable: true },
  { key: 'cluster_number', label: 'Cluster #', sortable: true },
  { key: 'model_name', label: 'Model', sortable: true },
  { key: 'validation_status', label: 'Status', sortable: true },
  { key: 'is_current', label: 'Current', sortable: true },
  { key: 'created_at', label: 'Created', sortable: true },
  { key: 'actions', label: 'Actions' },
];

function statusVariant(status: string) {
  switch (status) {
    case 'validated':
      return 'success';
    case 'pending':
      return 'warning';
    case 'rejected':
      return 'danger';
    default:
      return 'secondary';
  }
}

function formatDateTime(dateString: string | null): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;
  return date.toLocaleString();
}

function viewDetails(summary: CachedSummary) {
  selectedSummary.value = summary;
  showDetailModal.value = true;
}

async function loadSummaries() {
  const token = getToken();
  if (!token) return;

  loading.value = true;
  try {
    const result = await fetchCachedSummaries(token, {
      cluster_type: filters.cluster_type,
      validation_status: filters.validation_status,
      page: page.value,
      per_page: perPage.value,
    });
    summaries.value = result.data;
    totalRows.value = result.total;
  } finally {
    loading.value = false;
  }
}

onMounted(() => loadSummaries());
</script>
