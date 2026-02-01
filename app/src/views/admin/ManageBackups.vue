<!-- views/admin/ManageBackups.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
            <template #header>
              <BRow>
                <BCol>
                  <h5 class="mb-1 text-start">
                    <strong>Manage Backups</strong>
                    <BBadge variant="secondary" class="ms-2">
                      {{ meta.total_count }} backups
                    </BBadge>
                    <BBadge variant="info" class="ms-2">
                      {{ formatFileSize(meta.total_size_bytes) }} total
                    </BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    variant="outline-primary"
                    class="me-1"
                    :disabled="loading"
                    title="Refresh backup list"
                    aria-label="Refresh backup list"
                    @click="fetchBackupList"
                  >
                    <BSpinner v-if="loading" small />
                    <i v-else class="bi bi-arrow-clockwise" aria-hidden="true" />
                  </BButton>
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    :variant="hasActiveFilters ? 'primary' : 'outline-secondary'"
                    :title="hasActiveFilters ? 'Clear filters' : 'No active filters'"
                    :aria-label="hasActiveFilters ? 'Clear filters' : 'Filter backups'"
                    @click="clearFilters"
                  >
                    <i class="bi bi-funnel" aria-hidden="true" />
                  </BButton>
                </BCol>
              </BRow>
            </template>

            <!-- Quick filters row -->
            <BRow class="px-2 pt-2">
              <BCol>
                <div class="d-flex gap-2 align-items-center flex-wrap">
                  <span class="text-muted small">Quick filters:</span>
                  <BButton
                    v-for="preset in quickFilters"
                    :key="preset.value"
                    size="sm"
                    :variant="typeFilter === preset.value ? 'primary' : 'outline-secondary'"
                    class="py-0"
                    @click="setTypeFilter(preset.value)"
                  >
                    {{ preset.label }}
                    <BBadge v-if="preset.count > 0" variant="light" class="ms-1">
                      {{ preset.count }}
                    </BBadge>
                  </BButton>
                </div>
              </BCol>
            </BRow>

            <!-- Search + Pagination row -->
            <BRow class="px-2 py-2">
              <BCol sm="6">
                <BInputGroup>
                  <template #prepend>
                    <BInputGroupText><i class="bi bi-search" aria-hidden="true" /></BInputGroupText>
                  </template>
                  <BFormInput
                    v-model="searchQuery"
                    placeholder="Search by filename..."
                    debounce="300"
                    type="search"
                  />
                </BInputGroup>
              </BCol>
              <BCol sm="6">
                <div class="d-flex justify-content-end align-items-center gap-2">
                  <BFormGroup label="Per page" label-class="small text-muted me-2" class="mb-0">
                    <BFormSelect
                      v-model="perPage"
                      :options="pageOptions"
                      size="sm"
                      style="width: 80px"
                    />
                  </BFormGroup>
                  <BPagination
                    v-if="filteredBackups.length > perPage"
                    v-model="currentPage"
                    :total-rows="filteredBackups.length"
                    :per-page="perPage"
                    size="sm"
                    class="mb-0"
                    first-text="«"
                    prev-text="‹"
                    next-text="›"
                    last-text="»"
                  />
                </div>
              </BCol>
            </BRow>

            <!-- Filters + count row -->
            <BRow class="px-2 pb-2">
              <BCol sm="4">
                <BFormSelect v-model="typeFilter" size="sm">
                  <BFormSelectOption :value="null">All Types</BFormSelectOption>
                  <BFormSelectOption value="manual">Manual</BFormSelectOption>
                  <BFormSelectOption value="auto">Automatic</BFormSelectOption>
                  <BFormSelectOption value="pre-restore">Pre-Restore</BFormSelectOption>
                </BFormSelect>
              </BCol>
              <BCol sm="4">
                <BFormSelect v-model="compressionFilter" size="sm">
                  <BFormSelectOption :value="null">All Formats</BFormSelectOption>
                  <BFormSelectOption value="compressed">Compressed (.gz)</BFormSelectOption>
                  <BFormSelectOption value="uncompressed">Uncompressed (.sql)</BFormSelectOption>
                </BFormSelect>
              </BCol>
              <BCol sm="4" class="text-end">
                <span class="text-muted small">
                  Showing {{ paginationStart }}-{{ paginationEnd }} of {{ filteredBackups.length }}
                </span>
              </BCol>
            </BRow>

            <!-- Backup Table -->
            <BTable
              :items="paginatedBackups"
              :fields="backupFields"
              :busy="loading"
              striped
              hover
              small
              responsive
              :sort-by="sortBy"
              @sort-changed="onSortChanged"
            >
              <template #table-busy>
                <div class="text-center my-2">
                  <BSpinner class="align-middle" />
                  <strong class="ms-2">Loading backups...</strong>
                </div>
              </template>

              <template #cell(filename)="data">
                <div class="d-flex align-items-center">
                  <span class="font-monospace small text-start">{{ data.value }}</span>
                  <BBadge
                    v-if="getBackupType(String(data.value))"
                    :variant="getBackupTypeBadgeVariant(String(data.value))"
                    class="ms-2 flex-shrink-0"
                  >
                    {{ getBackupType(String(data.value)) }}
                  </BBadge>
                </div>
              </template>

              <template #cell(size_bytes)="data">
                {{ formatFileSize(data.value as number) }}
              </template>

              <template #cell(created_at)="data">
                {{ formatDate(data.value as string) }}
              </template>

              <template #cell(actions)="data">
                <div class="d-flex justify-content-end">
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    variant="link"
                    class="me-1 p-1 text-primary"
                    title="Download backup"
                    aria-label="Download backup"
                    @click="downloadBackup(data.item.filename)"
                  >
                    <i class="bi bi-download" aria-hidden="true" />
                  </BButton>
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    variant="link"
                    class="me-1 p-1 text-warning"
                    title="Restore from this backup"
                    aria-label="Restore from this backup"
                    @click="promptRestore(data.item)"
                  >
                    <i class="bi bi-arrow-counterclockwise" aria-hidden="true" />
                  </BButton>
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    variant="link"
                    class="p-1 text-danger"
                    title="Delete backup"
                    aria-label="Delete backup"
                    @click="promptDelete(data.item)"
                  >
                    <i class="bi bi-trash" aria-hidden="true" />
                  </BButton>
                </div>
              </template>
            </BTable>

            <div
              v-if="!loading && filteredBackups.length === 0"
              class="text-center text-muted py-3"
            >
              <template v-if="backups.length === 0">
                No backups available. Use "Backup Now" to create one.
              </template>
              <template v-else>
                No backups match the current filters.
                <BButton size="sm" variant="link" @click="clearFilters">Clear filters</BButton>
              </template>
            </div>
          </BCard>

          <!-- Backup Now Card -->
          <BCard
            header-tag="header"
            body-class="p-2"
            header-class="p-1"
            border-variant="dark"
            class="mt-3 text-start"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold">Create Manual Backup</h5>
            </template>

            <BButton variant="primary" :disabled="backupJob.isLoading.value" @click="triggerBackup">
              <BSpinner v-if="backupJob.isLoading.value" small type="grow" class="me-2" />
              {{ backupJob.isLoading.value ? 'Backing up...' : 'Backup Now' }}
            </BButton>

            <!-- Backup Progress display -->
            <div v-if="backupJob.isLoading.value || backupJob.status.value !== 'idle'" class="mt-3">
              <div class="d-flex align-items-center mb-2">
                <span class="badge me-2" :class="backupJob.statusBadgeClass.value">
                  {{ backupJob.status.value }}
                </span>
                <span class="text-muted">{{ backupJob.step.value }}</span>
              </div>

              <BProgress
                v-if="backupJob.isLoading.value"
                :value="
                  backupJob.hasRealProgress.value ? (backupJob.progressPercent.value ?? 0) : 100
                "
                :max="100"
                :animated="!backupJob.hasRealProgress.value"
                :striped="!backupJob.hasRealProgress.value"
                :variant="backupJob.progressVariant.value"
                height="1.5rem"
              >
                <template #default>
                  <span v-if="backupJob.hasRealProgress.value">
                    {{ backupJob.progress.value.current }}/{{ backupJob.progress.value.total }} ({{
                      backupJob.progressPercent.value
                    }}%)
                  </span>
                  <span v-else>Backing up... ({{ backupJob.elapsedTimeDisplay.value }})</span>
                </template>
              </BProgress>

              <div v-if="backupJob.isLoading.value" class="small text-muted mt-1">
                Elapsed: {{ backupJob.elapsedTimeDisplay.value }}
              </div>
            </div>
          </BCard>

          <!-- Restore Progress Card (shown when restoring) -->
          <BCard
            v-if="restoreJob.isLoading.value || restoreJob.status.value !== 'idle'"
            header-tag="header"
            body-class="p-2"
            header-class="p-1"
            border-variant="dark"
            class="mt-3 text-start"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold">Restore Progress</h5>
            </template>

            <div class="mt-1">
              <div class="d-flex align-items-center mb-2">
                <span class="badge me-2" :class="restoreJob.statusBadgeClass.value">
                  {{ restoreJob.status.value }}
                </span>
                <span class="text-muted">{{ restoreJob.step.value }}</span>
              </div>

              <BProgress
                v-if="restoreJob.isLoading.value"
                :value="
                  restoreJob.hasRealProgress.value ? (restoreJob.progressPercent.value ?? 0) : 100
                "
                :max="100"
                :animated="!restoreJob.hasRealProgress.value"
                :striped="!restoreJob.hasRealProgress.value"
                :variant="restoreJob.progressVariant.value"
                height="1.5rem"
              >
                <template #default>
                  <span v-if="restoreJob.hasRealProgress.value">
                    {{ restoreJob.progress.value.current }}/{{
                      restoreJob.progress.value.total
                    }}
                    ({{ restoreJob.progressPercent.value }}%)
                  </span>
                  <span v-else>Restoring... ({{ restoreJob.elapsedTimeDisplay.value }})</span>
                </template>
              </BProgress>

              <div v-if="restoreJob.isLoading.value" class="small text-muted mt-1">
                Elapsed: {{ restoreJob.elapsedTimeDisplay.value }}
              </div>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- Restore Confirmation Modal -->
      <BModal
        v-model="showRestoreModal"
        title="Restore Database"
        ok-variant="danger"
        ok-title="Restore"
        :ok-disabled="restoreConfirmText !== 'RESTORE'"
        @ok="confirmRestore"
        @hidden="restoreConfirmText = ''"
      >
        <BAlert variant="danger" :model-value="true">
          <i class="bi bi-exclamation-triangle-fill me-2" />
          <strong>Warning:</strong> This will overwrite the current database with the backup data.
        </BAlert>
        <p v-if="selectedBackup" class="mb-3">
          Restoring from: <code class="bg-light p-1">{{ selectedBackup.filename }}</code>
          <br />
          <small class="text-muted">
            Size: {{ formatFileSize(selectedBackup.size_bytes) }} | Created:
            {{ formatDate(selectedBackup.created_at) }}
          </small>
        </p>
        <p class="fw-bold">Type <code>RESTORE</code> to confirm:</p>
        <BFormInput v-model="restoreConfirmText" placeholder="RESTORE" autocomplete="off" />
      </BModal>

      <!-- Delete Confirmation Modal -->
      <BModal
        v-model="showDeleteModal"
        title="Delete Backup"
        ok-variant="danger"
        ok-title="Delete"
        :ok-disabled="deleteConfirmText !== 'DELETE'"
        @ok="confirmDelete"
        @hidden="deleteConfirmText = ''"
      >
        <BAlert variant="warning" :model-value="true">
          <i class="bi bi-exclamation-triangle-fill me-2" />
          <strong>Warning:</strong> This action cannot be undone.
        </BAlert>
        <p v-if="selectedBackup" class="mb-3">
          Deleting: <code class="bg-light p-1">{{ selectedBackup.filename }}</code>
          <br />
          <small class="text-muted">
            Size: {{ formatFileSize(selectedBackup.size_bytes) }} | Created:
            {{ formatDate(selectedBackup.created_at) }}
          </small>
        </p>
        <p class="fw-bold">Type <code>DELETE</code> to confirm:</p>
        <BFormInput v-model="deleteConfirmText" placeholder="DELETE" autocomplete="off" />
      </BModal>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import axios from 'axios';
import useToast from '@/composables/useToast';
import { useAsyncJob } from '@/composables/useAsyncJob';

// Types
interface BackupItem {
  filename: string;
  size_bytes: number;
  created_at: string;
  table_count: number | null;
}

interface BackupMeta {
  total_count: number;
  total_size_bytes: number;
}

// Composables
const { makeToast } = useToast();

// Create job instances for backup and restore operations
const backupJob = useAsyncJob(
  (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
);
const restoreJob = useAsyncJob(
  (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
);

// Reactive state
const backups = ref<BackupItem[]>([]);
const meta = ref<BackupMeta>({ total_count: 0, total_size_bytes: 0 });
const loading = ref(false);

// Modal state
const showRestoreModal = ref(false);
const showDeleteModal = ref(false);
const selectedBackup = ref<BackupItem | null>(null);
const restoreConfirmText = ref('');
const deleteConfirmText = ref('');

// Filter and pagination state
const searchQuery = ref('');
const typeFilter = ref<string | null>(null);
const compressionFilter = ref<string | null>(null);
const currentPage = ref(1);
const perPage = ref(10);
const pageOptions = [10, 25, 50, 100];
const sortBy = ref<Array<{ key: string; order: 'asc' | 'desc' }>>([
  { key: 'created_at', order: 'desc' },
]);

// Table fields
const backupFields = [
  { key: 'filename', label: 'Filename', sortable: true, class: 'text-start' },
  {
    key: 'size_bytes',
    label: 'Size',
    sortable: true,
    class: 'text-end',
    thStyle: { width: '100px' },
  },
  {
    key: 'created_at',
    label: 'Created',
    sortable: true,
    class: 'text-center',
    thStyle: { width: '160px' },
  },
  {
    key: 'actions',
    label: 'Actions',
    sortable: false,
    class: 'text-end',
    thStyle: { width: '120px' },
  },
];

// Computed: Quick filter counts
const quickFilters = computed(() => {
  const manual = backups.value.filter((b) => b.filename.startsWith('manual_')).length;
  const auto = backups.value.filter(
    (b) => !b.filename.startsWith('manual_') && !b.filename.startsWith('pre-restore_')
  ).length;
  const preRestore = backups.value.filter((b) => b.filename.startsWith('pre-restore_')).length;

  return [
    { label: 'Manual', value: 'manual', count: manual },
    { label: 'Automatic', value: 'auto', count: auto },
    { label: 'Pre-Restore', value: 'pre-restore', count: preRestore },
  ];
});

// Computed: Filtered backups
const filteredBackups = computed(() => {
  let result = [...backups.value];

  // Search filter
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase();
    result = result.filter((b) => b.filename.toLowerCase().includes(query));
  }

  // Type filter
  if (typeFilter.value === 'manual') {
    result = result.filter((b) => b.filename.startsWith('manual_'));
  } else if (typeFilter.value === 'auto') {
    result = result.filter(
      (b) => !b.filename.startsWith('manual_') && !b.filename.startsWith('pre-restore_')
    );
  } else if (typeFilter.value === 'pre-restore') {
    result = result.filter((b) => b.filename.startsWith('pre-restore_'));
  }

  // Compression filter
  if (compressionFilter.value === 'compressed') {
    result = result.filter((b) => b.filename.endsWith('.gz'));
  } else if (compressionFilter.value === 'uncompressed') {
    result = result.filter((b) => !b.filename.endsWith('.gz'));
  }

  return result;
});

// Computed: Paginated backups
const paginatedBackups = computed(() => {
  const start = (currentPage.value - 1) * perPage.value;
  const end = start + perPage.value;
  return filteredBackups.value.slice(start, end);
});

// Computed: Pagination display
const paginationStart = computed(() => {
  if (filteredBackups.value.length === 0) return 0;
  return (currentPage.value - 1) * perPage.value + 1;
});

const paginationEnd = computed(() => {
  return Math.min(currentPage.value * perPage.value, filteredBackups.value.length);
});

// Computed: Has active filters
const hasActiveFilters = computed(() => {
  return searchQuery.value !== '' || typeFilter.value !== null || compressionFilter.value !== null;
});

// Helper to unwrap R/Plumber array values
function unwrapValue<T>(val: T | T[]): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}

// Format file size to human-readable
function formatFileSize(bytes: number): string {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

// Format date as "YYYY-MM-DD HH:mm"
function formatDate(dateString: string): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day} ${hours}:${minutes}`;
}

// Get backup type from filename
function getBackupType(filename: string): string | null {
  if (filename.startsWith('manual_')) return 'manual';
  if (filename.startsWith('pre-restore_')) return 'pre-restore';
  return null;
}

// Get badge variant for backup type
function getBackupTypeBadgeVariant(filename: string): 'primary' | 'warning' | 'secondary' {
  if (filename.startsWith('manual_')) return 'primary';
  if (filename.startsWith('pre-restore_')) return 'warning';
  return 'secondary';
}

// Set type filter from quick filter button
function setTypeFilter(value: string) {
  if (typeFilter.value === value) {
    typeFilter.value = null;
  } else {
    typeFilter.value = value;
  }
  currentPage.value = 1;
}

// Clear all filters
function clearFilters() {
  searchQuery.value = '';
  typeFilter.value = null;
  compressionFilter.value = null;
  currentPage.value = 1;
}

// Handle sort change
function onSortChanged(ctx: { sortBy: string; sortDesc: boolean }) {
  sortBy.value = [{ key: ctx.sortBy, order: ctx.sortDesc ? 'desc' : 'asc' }];
}

// Fetch backup list from API
async function fetchBackupList() {
  loading.value = true;
  try {
    const response = await axios.get(`${import.meta.env.VITE_API_URL}/api/backup/list`, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem('token')}`,
      },
      withCredentials: true,
    });

    const data = response.data;
    if (data && Array.isArray(data.data)) {
      backups.value = data.data.map((backup: Record<string, unknown>) => ({
        filename: unwrapValue(backup.filename) as string,
        size_bytes: Number(unwrapValue(backup.size_bytes)) || 0,
        created_at: unwrapValue(backup.created_at) as string,
        table_count: backup.table_count ? Number(unwrapValue(backup.table_count)) : null,
      }));
    } else {
      backups.value = [];
    }

    // Update meta
    if (data && data.meta) {
      meta.value = {
        total_count: Number(unwrapValue(data.meta.total_count)) || 0,
        total_size_bytes: Number(unwrapValue(data.meta.total_size_bytes)) || 0,
      };
    }
  } catch (error) {
    console.error('Failed to fetch backup list:', error);
    makeToast('Failed to load backup list', 'Error', 'danger');
    backups.value = [];
  } finally {
    loading.value = false;
  }
}

// Download backup file
async function downloadBackup(filename: string) {
  try {
    const response = await axios({
      url: `${import.meta.env.VITE_API_URL}/api/backup/download/${filename}`,
      method: 'GET',
      responseType: 'blob',
      headers: {
        Authorization: `Bearer ${localStorage.getItem('token')}`,
      },
      withCredentials: true,
    });

    const url = window.URL.createObjectURL(new Blob([response.data]));
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  } catch (error) {
    console.error('Download failed:', error);
    makeToast('Download failed', 'Error', 'danger');
  }
}

// Show restore confirmation modal
function promptRestore(backup: BackupItem) {
  selectedBackup.value = backup;
  restoreConfirmText.value = '';
  showRestoreModal.value = true;
}

// Show delete confirmation modal
function promptDelete(backup: BackupItem) {
  selectedBackup.value = backup;
  deleteConfirmText.value = '';
  showDeleteModal.value = true;
}

// Confirm and start restore
async function confirmRestore() {
  if (!selectedBackup.value || restoreConfirmText.value !== 'RESTORE') return;

  restoreJob.reset();
  showRestoreModal.value = false;

  try {
    const response = await axios.post(
      `${import.meta.env.VITE_API_URL}/api/backup/restore`,
      { filename: selectedBackup.value.filename },
      {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json',
        },
        withCredentials: true,
      }
    );

    if (response.data.error) {
      makeToast(response.data.message || 'Failed to start restore', 'Error', 'danger');
      return;
    }

    restoreJob.startJob(response.data.job_id);
  } catch (error) {
    console.error('Failed to start restore:', error);
    makeToast('Failed to start restore', 'Error', 'danger');
  }
}

// Confirm and execute delete
async function confirmDelete() {
  if (!selectedBackup.value || deleteConfirmText.value !== 'DELETE') return;

  showDeleteModal.value = false;
  const filename = selectedBackup.value.filename;

  try {
    const response = await axios.delete(
      `${import.meta.env.VITE_API_URL}/api/backup/delete/${filename}`,
      {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json',
        },
        data: { confirm: 'DELETE' },
        withCredentials: true,
      }
    );

    if (response.data.error) {
      makeToast(response.data.message || 'Failed to delete backup', 'Error', 'danger');
      return;
    }

    makeToast(`Backup '${filename}' deleted successfully`, 'Success', 'success');
    fetchBackupList();
  } catch (error) {
    console.error('Failed to delete backup:', error);
    makeToast('Failed to delete backup', 'Error', 'danger');
  }
}

// Trigger manual backup
async function triggerBackup() {
  backupJob.reset();

  try {
    const response = await axios.post(
      `${import.meta.env.VITE_API_URL}/api/backup/create`,
      {},
      {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
        },
        withCredentials: true,
      }
    );

    if (response.data.error) {
      makeToast(response.data.message || 'Failed to start backup', 'Error', 'danger');
      return;
    }

    backupJob.startJob(response.data.job_id);
  } catch (error) {
    console.error('Failed to start backup:', error);
    makeToast('Failed to start backup', 'Error', 'danger');
  }
}

// Watch for backup job completion/failure
watch(
  () => backupJob.status.value,
  (newStatus) => {
    if (newStatus === 'completed') {
      makeToast('Backup created successfully', 'Success', 'success');
      fetchBackupList();
    } else if (newStatus === 'failed') {
      const errorMsg = backupJob.error.value || 'Backup failed';
      makeToast(errorMsg, 'Error', 'danger');
    }
  }
);

// Watch for restore job completion/failure
watch(
  () => restoreJob.status.value,
  (newStatus) => {
    if (newStatus === 'completed') {
      makeToast(
        'Database restored. You may need to log out and log back in for changes to take effect.',
        'Success',
        'success'
      );
      fetchBackupList();
    } else if (newStatus === 'failed') {
      const errorMsg = restoreJob.error.value || 'Restore failed';
      makeToast(errorMsg, 'Error', 'danger');
    }
  }
);

// Reset to page 1 when filters change
watch([searchQuery, typeFilter, compressionFilter], () => {
  currentPage.value = 1;
});

// Lifecycle
onMounted(() => {
  fetchBackupList();
});
</script>

<style scoped>
.font-monospace {
  font-family:
    'SFMono-Regular', Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
}
</style>
