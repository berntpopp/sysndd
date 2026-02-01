<!-- components/llm/LlmLogViewer.vue -->
<template>
  <BCard>
    <template #header>
      <BRow class="align-items-center">
        <BCol>
          <h6 class="mb-0">Generation Logs</h6>
        </BCol>
        <BCol md="2">
          <BFormSelect
            v-model="filters.cluster_type"
            :options="typeOptions"
            size="sm"
            @change="loadLogs"
          />
        </BCol>
        <BCol md="2">
          <BFormSelect
            v-model="filters.status"
            :options="statusOptions"
            size="sm"
            @change="loadLogs"
          />
        </BCol>
        <BCol md="2">
          <BFormInput
            v-model="filters.from_date"
            type="date"
            size="sm"
            placeholder="From"
            @change="loadLogs"
          />
        </BCol>
        <BCol md="2">
          <BFormInput
            v-model="filters.to_date"
            type="date"
            size="sm"
            placeholder="To"
            @change="loadLogs"
          />
        </BCol>
        <BCol md="1" class="text-end">
          <BButton
            variant="outline-secondary"
            size="sm"
            :disabled="loading"
            title="Refresh logs"
            @click="loadLogs"
          >
            <BSpinner v-if="loading" small />
            <i v-else class="bi bi-arrow-clockwise" />
          </BButton>
        </BCol>
      </BRow>
    </template>

    <BTable :items="logs" :fields="fields" :busy="loading" responsive hover small striped>
      <template #cell(cluster_type)="data">
        <BBadge :variant="data.value === 'functional' ? 'primary' : 'info'">
          {{ data.value }}
        </BBadge>
      </template>
      <template #cell(status)="data">
        <BBadge :variant="statusVariant(data.value)">
          {{ formatStatus(data.value) }}
        </BBadge>
      </template>
      <template #cell(tokens)="data">
        <span v-if="data.item.tokens_input">
          {{ data.item.tokens_input?.toLocaleString() }} / {{ data.item.tokens_output?.toLocaleString() }}
        </span>
        <span v-else class="text-muted">-</span>
      </template>
      <template #cell(latency)="data">
        <span v-if="data.item.latency_ms">
          {{ (data.item.latency_ms / 1000).toFixed(2) }}s
        </span>
        <span v-else class="text-muted">-</span>
      </template>
      <template #cell(error_message)="data">
        <span
          v-if="data.value"
          class="text-danger text-truncate d-inline-block"
          style="max-width: 200px; cursor: help;"
          :title="data.value"
        >
          {{ truncateText(data.value, 30) }}
        </span>
        <span v-else class="text-muted">-</span>
      </template>
      <template #cell(created_at)="data">
        <small>{{ formatDateTime(data.value) }}</small>
      </template>
      <template #cell(actions)="data">
        <BButton
          variant="outline-secondary"
          size="sm"
          title="View log details"
          @click="viewDetails(data.item)"
        >
          View
        </BButton>
      </template>
    </BTable>

    <!-- Empty State -->
    <div v-if="!loading && logs.length === 0" class="text-center text-muted py-4">
      <i class="bi bi-inbox fs-1 d-block mb-2" />
      <span>No generation logs found. Try adjusting filters or generating summaries.</span>
    </div>

    <!-- Pagination -->
    <BRow class="mt-3">
      <BCol>
        <BPagination
          v-model="page"
          :total-rows="totalRows"
          :per-page="perPage"
          size="sm"
          @update:model-value="loadLogs"
        />
      </BCol>
      <BCol class="text-end text-muted small">
        Showing {{ logs.length }} of {{ totalRows }} logs
      </BCol>
    </BRow>

    <!-- Log Detail Modal -->
    <BModal
      v-model="showDetailModal"
      size="xl"
      :title="`Log #${selectedLog?.log_id} - ${selectedLog?.cluster_type} cluster ${selectedLog?.cluster_number}`"
    >
      <div v-if="selectedLog">
        <!-- Log Metadata -->
        <BRow class="mb-3">
          <BCol md="3">
            <small class="text-muted">Model:</small>
            <div>{{ selectedLog.model_name }}</div>
          </BCol>
          <BCol md="3">
            <small class="text-muted">Status:</small>
            <div>
              <BBadge :variant="statusVariant(selectedLog.status)">
                {{ formatStatus(selectedLog.status) }}
              </BBadge>
            </div>
          </BCol>
          <BCol md="3">
            <small class="text-muted">Tokens (In/Out):</small>
            <div v-if="selectedLog.tokens_input">
              {{ selectedLog.tokens_input?.toLocaleString() }} / {{ selectedLog.tokens_output?.toLocaleString() }}
            </div>
            <div v-else class="text-muted">N/A</div>
          </BCol>
          <BCol md="3">
            <small class="text-muted">Latency:</small>
            <div v-if="selectedLog.latency_ms">
              {{ (selectedLog.latency_ms / 1000).toFixed(2) }} seconds
            </div>
            <div v-else class="text-muted">N/A</div>
          </BCol>
        </BRow>

        <BRow class="mb-3">
          <BCol md="6">
            <small class="text-muted">Created:</small>
            <div>{{ formatDateTime(selectedLog.created_at) }}</div>
          </BCol>
          <BCol md="6">
            <small class="text-muted">Cluster Hash:</small>
            <div class="font-monospace small">{{ selectedLog.cluster_hash }}</div>
          </BCol>
        </BRow>

        <!-- Error Message -->
        <BAlert
          v-if="selectedLog.error_message"
          variant="danger"
          :model-value="true"
          class="mb-3"
        >
          <strong>Error:</strong> {{ selectedLog.error_message }}
        </BAlert>

        <!-- Validation Errors -->
        <BAlert
          v-if="selectedLog.validation_errors"
          variant="warning"
          :model-value="true"
          class="mb-3"
        >
          <strong>Validation Errors:</strong>
          <pre class="mb-0 mt-2" style="font-size: 0.8rem;">{{ selectedLog.validation_errors }}</pre>
        </BAlert>

        <!-- Prompt Text -->
        <BCard class="mb-3" bg-variant="light">
          <template #header>
            <small class="fw-bold">Prompt Text</small>
          </template>
          <pre class="mb-0 overflow-auto" style="max-height: 30vh; font-size: 0.75rem; white-space: pre-wrap;">{{
            selectedLog.prompt_text
          }}</pre>
        </BCard>

        <!-- Response JSON -->
        <BCard v-if="selectedLog.response_json" bg-variant="light">
          <template #header>
            <small class="fw-bold">Response JSON</small>
          </template>
          <pre class="mb-0 overflow-auto" style="max-height: 30vh; font-size: 0.8rem;">{{
            JSON.stringify(selectedLog.response_json, null, 2)
          }}</pre>
        </BCard>
      </div>
    </BModal>
  </BCard>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useAuth } from '@/composables/useAuth';
import { useLlmAdmin } from '@/composables/useLlmAdmin';
import type { GenerationLog, ClusterType, LogStatus } from '@/types/llm';

const { getToken } = useAuth();
const { fetchLogs: fetchLogsApi } = useLlmAdmin();

const logs = ref<GenerationLog[]>([]);
const loading = ref(false);
const page = ref(1);
const perPage = ref(50);
const totalRows = ref(0);
const showDetailModal = ref(false);
const selectedLog = ref<GenerationLog | null>(null);

const filters = reactive({
  cluster_type: undefined as ClusterType | undefined,
  status: undefined as LogStatus | undefined,
  from_date: undefined as string | undefined,
  to_date: undefined as string | undefined,
});

const typeOptions = [
  { value: undefined, text: 'All Types' },
  { value: 'functional', text: 'Functional' },
  { value: 'phenotype', text: 'Phenotype' },
];

const statusOptions = [
  { value: undefined, text: 'All Statuses' },
  { value: 'success', text: 'Success' },
  { value: 'validation_failed', text: 'Validation Failed' },
  { value: 'api_error', text: 'API Error' },
  { value: 'timeout', text: 'Timeout' },
];

const fields = [
  { key: 'log_id', label: 'ID', sortable: true },
  { key: 'cluster_type', label: 'Type' },
  { key: 'cluster_number', label: 'Cluster #' },
  { key: 'model_name', label: 'Model' },
  { key: 'status', label: 'Status' },
  { key: 'tokens', label: 'Tokens (In/Out)' },
  { key: 'latency', label: 'Latency' },
  { key: 'error_message', label: 'Error' },
  { key: 'created_at', label: 'Time', sortable: true },
  { key: 'actions', label: '' },
];

function statusVariant(status: string) {
  switch (status) {
    case 'success':
      return 'success';
    case 'validation_failed':
      return 'warning';
    case 'api_error':
      return 'danger';
    case 'timeout':
      return 'secondary';
    default:
      return 'light';
  }
}

function formatStatus(status: string) {
  return status.replace(/_/g, ' ');
}

function formatDateTime(dateString: string | null): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;
  return date.toLocaleString();
}

function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength) + '...';
}

function viewDetails(log: GenerationLog) {
  selectedLog.value = log;
  showDetailModal.value = true;
}

async function loadLogs() {
  const token = await getToken();
  if (!token) return;

  loading.value = true;
  try {
    const result = await fetchLogsApi(token, {
      cluster_type: filters.cluster_type,
      status: filters.status,
      from_date: filters.from_date,
      to_date: filters.to_date,
      page: page.value,
      per_page: perPage.value,
    });
    logs.value = result.data;
    totalRows.value = result.total;
  } finally {
    loading.value = false;
  }
}

onMounted(() => loadLogs());
</script>
