<!-- views/admin/ManageBackups.vue -->
<template>
  <AuthenticatedPageShell
    title="Manage Backups"
    content-class="authenticated-route-content"
    full-width
  >
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center py-2">
          <BCol md="12">
            <TableShell
              title="Backup inventory"
              :meta="`${meta.total_count} backups · ${formatFileSize(meta.total_size_bytes)} total`"
              description="Download, restore, delete, or create database backups from one inventory surface."
            >
              <template #actions>
                <BButton
                  v-b-tooltip.hover
                  variant="primary"
                  size="sm"
                  data-testid="backup-manual-operation"
                  :disabled="backupJob.isLoading.value"
                  title="Create an on-demand database backup"
                  @click="triggerBackup"
                >
                  <BSpinner v-if="backupJob.isLoading.value" small type="grow" class="me-1" />
                  {{ backupJob.isLoading.value ? 'Backing up...' : 'Backup now' }}
                </BButton>
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
              </template>

              <template #toolbar>
                <div class="backup-toolbar">
                  <div class="backup-toolbar__filters" aria-label="Backup type quick filters">
                    <span class="backup-toolbar__label">Type</span>
                    <div class="backup-toolbar__chips">
                      <BButton
                        v-for="preset in quickFilters"
                        :key="preset.value"
                        size="sm"
                        :variant="typeFilter === preset.value ? 'primary' : 'outline-secondary'"
                        class="backup-filter-chip"
                        @click="setTypeFilter(preset.value)"
                      >
                        {{ preset.label }}
                        <BBadge v-if="preset.count > 0" variant="light" class="ms-1">
                          {{ preset.count }}
                        </BBadge>
                      </BButton>
                    </div>
                  </div>

                  <div class="backup-toolbar__controls">
                    <div class="backup-search">
                      <i class="bi bi-search backup-search__icon" aria-hidden="true" />
                      <BFormInput
                        v-model="searchQuery"
                        placeholder="Search by filename..."
                        class="backup-search__input"
                        debounce="300"
                        type="search"
                      />
                    </div>

                    <label class="backup-select-label">
                      <span>Format</span>
                      <BFormSelect v-model="compressionFilter" size="sm">
                        <BFormSelectOption :value="null">All</BFormSelectOption>
                        <BFormSelectOption value="compressed">.gz</BFormSelectOption>
                        <BFormSelectOption value="uncompressed">.sql</BFormSelectOption>
                      </BFormSelect>
                    </label>

                    <label class="backup-select-label">
                      <span>Per page</span>
                      <BFormSelect v-model="perPage" :options="pageOptions" size="sm" />
                    </label>
                  </div>

                  <div class="backup-toolbar__footer">
                    <span class="backup-count">
                      Showing {{ paginationStart }}-{{ paginationEnd }} of
                      {{ filteredBackups.length }}
                    </span>
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

                  <label class="backup-select-label backup-select-label--mobile-sort d-md-none">
                    <span>Sort</span>
                    <BFormSelect v-model="mobileSortValue" :options="mobileSortOptions" size="sm" />
                  </label>
                </div>
              </template>

              <!-- Backup Table -->
              <BTable
                class="backup-table d-none d-md-table"
                :items="paginatedBackups"
                :fields="backupFields"
                :busy="loading"
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

              <div v-if="loading" class="d-md-none text-center text-muted py-3">
                <BSpinner small class="me-2" />
                Loading backups...
              </div>

              <BackupMobileRows
                v-if="!loading && paginatedBackups.length > 0"
                class="d-md-none"
                :items="paginatedBackups"
                @download="(backup) => downloadBackup(backup.filename)"
                @restore="promptRestore"
                @delete="promptDelete"
              />

              <div
                v-if="!loading && filteredBackups.length === 0"
                class="text-center text-muted py-3"
              >
                <template v-if="backups.length === 0">
                  No backups available. Use "Backup now" to create one.
                </template>
                <template v-else>
                  No backups match the current filters.
                  <BButton size="sm" variant="link" @click="clearFilters">Clear filters</BButton>
                </template>
              </div>

              <div class="backup-job-stack">
                <section
                  v-if="backupJob.isLoading.value || backupJob.status.value !== 'idle'"
                  class="backup-job-row"
                  aria-label="Backup progress"
                >
                  <div class="backup-job-row__header">
                    <strong>Backup progress</strong>
                    <span class="badge" :class="backupJob.statusBadgeClass.value">
                      {{ backupJob.status.value }}
                    </span>
                  </div>
                  <p class="backup-job-row__step">{{ backupJob.step.value }}</p>

                  <BProgress
                    v-if="backupJob.isLoading.value"
                    :value="
                      backupJob.hasRealProgress.value ? (backupJob.progressPercent.value ?? 0) : 100
                    "
                    :max="100"
                    :animated="!backupJob.hasRealProgress.value"
                    :striped="!backupJob.hasRealProgress.value"
                    :variant="backupJob.progressVariant.value"
                    height="0.875rem"
                  >
                    <template #default>
                      <span v-if="backupJob.hasRealProgress.value">
                        {{ backupJob.progress.value.current }}/{{
                          backupJob.progress.value.total
                        }}
                        ({{ backupJob.progressPercent.value }}%)
                      </span>
                      <span v-else>Backing up... ({{ backupJob.elapsedTimeDisplay.value }})</span>
                    </template>
                  </BProgress>
                </section>

                <section
                  v-if="restoreJob.isLoading.value || restoreJob.status.value !== 'idle'"
                  class="backup-job-row"
                  aria-label="Restore progress"
                >
                  <div class="backup-job-row__header">
                    <strong>Restore progress</strong>
                    <span class="badge" :class="restoreJob.statusBadgeClass.value">
                      {{ restoreJob.status.value }}
                    </span>
                  </div>
                  <p class="backup-job-row__step">{{ restoreJob.step.value }}</p>

                  <BProgress
                    v-if="restoreJob.isLoading.value"
                    :value="
                      restoreJob.hasRealProgress.value
                        ? (restoreJob.progressPercent.value ?? 0)
                        : 100
                    "
                    :max="100"
                    :animated="!restoreJob.hasRealProgress.value"
                    :striped="!restoreJob.hasRealProgress.value"
                    :variant="restoreJob.progressVariant.value"
                    height="0.875rem"
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
                </section>
              </div>
            </TableShell>
          </BCol>
        </BRow>

        <!-- Restore Confirmation Modal -->
        <BModal
          v-model="showRestoreModal"
          title="Restore Database"
          centered
          header-bg-variant="danger"
          header-text-variant="light"
          @hidden="restoreConfirmText = ''"
        >
          <div class="backup-danger-panel">
            <i class="bi bi-exclamation-triangle-fill backup-danger-panel__icon" />
            <div>
              <h3 class="backup-danger-panel__title">Restore will overwrite current data</h3>
              <p class="backup-danger-panel__copy">
                The current database will be replaced with the selected backup. This action starts a
                restore job and should only be used after confirming the backup file.
              </p>
            </div>
          </div>
          <dl v-if="selectedBackup" class="backup-confirm-details">
            <div>
              <dt>Backup</dt>
              <dd>
                <code>{{ selectedBackup.filename }}</code>
              </dd>
            </div>
            <div>
              <dt>Size</dt>
              <dd>{{ formatFileSize(selectedBackup.size_bytes) }}</dd>
            </div>
            <div>
              <dt>Created</dt>
              <dd>{{ formatDate(selectedBackup.created_at) }}</dd>
            </div>
          </dl>
          <label class="form-label fw-bold" for="restore-confirm-input">
            Type <code>RESTORE</code> to confirm
          </label>
          <BFormInput
            id="restore-confirm-input"
            v-model="restoreConfirmText"
            placeholder="RESTORE"
            autocomplete="off"
          />
          <template #footer>
            <div class="backup-confirm-footer">
              <BButton variant="outline-secondary" @click="showRestoreModal = false">
                Cancel
              </BButton>
              <BButton
                variant="danger"
                :disabled="restoreConfirmText !== 'RESTORE'"
                @click="confirmRestore"
              >
                Restore Database
              </BButton>
            </div>
          </template>
        </BModal>

        <!-- Delete Confirmation Modal -->
        <BModal
          v-model="showDeleteModal"
          title="Delete Backup"
          centered
          header-bg-variant="danger"
          header-text-variant="light"
          @hidden="deleteConfirmText = ''"
        >
          <div class="backup-danger-panel backup-danger-panel--delete">
            <i class="bi bi-exclamation-triangle-fill backup-danger-panel__icon" />
            <div>
              <h3 class="backup-danger-panel__title">Delete this backup permanently</h3>
              <p class="backup-danger-panel__copy">
                The selected backup file will be removed and cannot be restored from this inventory
                after deletion.
              </p>
            </div>
          </div>
          <dl v-if="selectedBackup" class="backup-confirm-details">
            <div>
              <dt>Backup</dt>
              <dd>
                <code>{{ selectedBackup.filename }}</code>
              </dd>
            </div>
            <div>
              <dt>Size</dt>
              <dd>{{ formatFileSize(selectedBackup.size_bytes) }}</dd>
            </div>
            <div>
              <dt>Created</dt>
              <dd>{{ formatDate(selectedBackup.created_at) }}</dd>
            </div>
          </dl>
          <label class="form-label fw-bold" for="delete-confirm-input">
            Type <code>DELETE</code> to confirm
          </label>
          <BFormInput
            id="delete-confirm-input"
            v-model="deleteConfirmText"
            placeholder="DELETE"
            autocomplete="off"
          />
          <template #footer>
            <div class="backup-confirm-footer">
              <BButton variant="outline-secondary" @click="showDeleteModal = false">
                Cancel
              </BButton>
              <BButton
                variant="danger"
                :disabled="deleteConfirmText !== 'DELETE'"
                @click="confirmDelete"
              >
                Delete Backup
              </BButton>
            </div>
          </template>
        </BModal>
      </BContainer>
    </div>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import TableShell from '@/components/table/TableShell.vue';
import { ref, computed, onMounted, watch } from 'vue';
import useToast from '@/composables/useToast';
import { useAsyncJob } from '@/composables/useAsyncJob';
import BackupMobileRows from './components/BackupMobileRows.vue';
// v11.0 closeout F2b: every authed call now flows through the shared
// apiClient so the request interceptor injects the Bearer from
// `useAuth().token.value` — no direct localStorage reads.
import { apiClient } from '@/api/client';

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
const mobileSortOptions = [
  { value: '-created_at', text: 'Newest first' },
  { value: '+created_at', text: 'Oldest first' },
  { value: '+filename', text: 'Filename ascending' },
  { value: '-filename', text: 'Filename descending' },
  { value: '-size_bytes', text: 'Largest first' },
  { value: '+size_bytes', text: 'Smallest first' },
];

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

const mobileSortValue = computed({
  get() {
    const current = sortBy.value[0] || { key: 'created_at', order: 'desc' as const };
    return `${current.order === 'desc' ? '-' : '+'}${current.key}`;
  },
  set(value: string) {
    sortBy.value = [
      {
        key: value.slice(1),
        order: value.startsWith('-') ? 'desc' : 'asc',
      },
    ];
    currentPage.value = 1;
  },
});

const sortedBackups = computed(() => {
  const current = sortBy.value[0] || { key: 'created_at', order: 'desc' as const };
  const multiplier = current.order === 'desc' ? -1 : 1;
  return [...filteredBackups.value].sort((left, right) => {
    const leftValue = left[current.key as keyof BackupItem];
    const rightValue = right[current.key as keyof BackupItem];
    if (typeof leftValue === 'number' && typeof rightValue === 'number') {
      return (leftValue - rightValue) * multiplier;
    }
    return String(leftValue ?? '').localeCompare(String(rightValue ?? '')) * multiplier;
  });
});

// Computed: Paginated backups
const paginatedBackups = computed(() => {
  const start = (currentPage.value - 1) * perPage.value;
  const end = start + perPage.value;
  return sortedBackups.value.slice(start, end);
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
    const response = await apiClient.raw.get<{
      data?: Record<string, unknown>[];
      meta?: Record<string, unknown>;
    }>(`${import.meta.env.VITE_API_URL}/api/backup/list`, {
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
    const response = await apiClient.raw.get<Blob>(
      `${import.meta.env.VITE_API_URL}/api/backup/download/${filename}`,
      {
        responseType: 'blob',
        withCredentials: true,
      }
    );

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
    const response = await apiClient.raw.post<{
      error?: unknown;
      message?: string;
      job_id: string;
    }>(
      `${import.meta.env.VITE_API_URL}/api/backup/restore`,
      { filename: selectedBackup.value.filename },
      {
        headers: {
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
    const response = await apiClient.raw.delete<{
      error?: unknown;
      message?: string;
    }>(`${import.meta.env.VITE_API_URL}/api/backup/delete/${filename}`, {
      headers: {
        'Content-Type': 'application/json',
      },
      data: { confirm: 'DELETE' },
      withCredentials: true,
    });

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
    const response = await apiClient.raw.post<{
      error?: unknown;
      message?: string;
      job_id: string;
    }>(
      `${import.meta.env.VITE_API_URL}/api/backup/create`,
      {},
      {
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

.backup-toolbar {
  display: grid;
  gap: 0.75rem;
}

.backup-toolbar__filters,
.backup-toolbar__controls,
.backup-toolbar__footer {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
}

.backup-toolbar__controls {
  display: grid;
  grid-template-columns: minmax(18rem, 1fr) minmax(7rem, 9rem) minmax(7rem, 8rem);
}

.backup-toolbar__footer {
  justify-content: space-between;
}

.backup-toolbar__footer :deep(.pagination) {
  flex-wrap: nowrap;
}

.backup-toolbar__footer :deep(.page-link) {
  min-width: 2rem;
  padding: 0.25rem 0.45rem;
}

.backup-toolbar__label,
.backup-select-label span,
.backup-count {
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
  font-weight: 700;
}

.backup-toolbar__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.backup-filter-chip {
  min-height: 1.75rem;
  padding-top: 0.125rem;
  padding-bottom: 0.125rem;
  border-radius: 999px;
}

.backup-search {
  position: relative;
  min-width: 0;
}

.backup-search__icon {
  position: absolute;
  top: 50%;
  left: 0.65rem;
  z-index: 2;
  color: var(--neutral-600, #757575);
  transform: translateY(-50%);
}

.backup-search__input {
  padding-left: 2rem;
}

.backup-select-label {
  display: grid;
  gap: 0.25rem;
  min-width: 0;
}

.backup-table {
  margin-bottom: 0;
}

.backup-table :deep(thead th) {
  color: #475569;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0;
}

.backup-table :deep(td),
.backup-table :deep(th) {
  vertical-align: middle;
}

.backup-job-row__step {
  margin: 0.2rem 0 0;
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
}

.backup-job-stack {
  display: grid;
  gap: 0.75rem;
  margin-top: 0.75rem;
}

.backup-job-row {
  padding: 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.5rem;
  background: #f8fafc;
}

.backup-job-row__header {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.backup-danger-panel {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 0.75rem;
  margin-bottom: 1rem;
  padding: 0.875rem;
  border: 1px solid rgba(220, 53, 69, 0.28);
  border-radius: 0.5rem;
  background: rgba(220, 53, 69, 0.08);
}

.backup-danger-panel--delete {
  background: rgba(255, 193, 7, 0.12);
}

.backup-danger-panel__icon {
  color: #dc3545;
  font-size: 1.35rem;
  line-height: 1;
}

.backup-danger-panel__title {
  margin: 0;
  color: #842029;
  font-size: 0.95rem;
  font-weight: 800;
}

.backup-danger-panel__copy {
  margin: 0.25rem 0 0;
  color: #495057;
  font-size: 0.875rem;
}

.backup-confirm-details {
  display: grid;
  gap: 0.5rem;
  margin: 0 0 1rem;
}

.backup-confirm-details div {
  display: grid;
  grid-template-columns: 5rem minmax(0, 1fr);
  gap: 0.75rem;
}

.backup-confirm-details dt {
  color: #64748b;
  font-size: 0.8125rem;
  font-weight: 700;
}

.backup-confirm-details dd {
  min-width: 0;
  margin: 0;
  overflow-wrap: anywhere;
}

.backup-confirm-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  width: 100%;
}

@media (max-width: 767.98px) {
  .backup-toolbar__controls {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }

  .backup-search {
    grid-column: 1 / -1;
  }

  .backup-toolbar__footer {
    display: flex;
    align-items: center;
  }
}
</style>
