<!-- views/admin/ManageBackups.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="10">
          <h3>Manage Backups</h3>

          <!-- Backup List Card -->
          <BCard
            header-tag="header"
            body-class="p-2"
            header-class="p-1"
            border-variant="dark"
            class="mb-3 text-start"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold d-flex align-items-center">
                Available Backups
                <BButton
                  size="sm"
                  variant="outline-secondary"
                  class="ms-auto"
                  :disabled="loading"
                  @click="fetchBackupList"
                >
                  <BSpinner v-if="loading" small class="me-1" />
                  Refresh
                </BButton>
              </h5>
            </template>

            <BTable
              :items="backups"
              :fields="backupFields"
              :busy="loading"
              striped
              hover
              small
              responsive
              :sort-by="[{ key: 'created_at', order: 'desc' }]"
            >
              <template #table-busy>
                <div class="text-center my-2">
                  <BSpinner class="align-middle" />
                  <strong class="ms-2">Loading backups...</strong>
                </div>
              </template>

              <template #cell(filename)="data">
                <span class="font-monospace">{{ data.value }}</span>
              </template>

              <template #cell(size_bytes)="data">
                {{ formatFileSize(data.value as number) }}
              </template>

              <template #cell(created_at)="data">
                {{ formatDate(data.value as string) }}
              </template>

              <template #cell(actions)="data">
                <BButton
                  size="sm"
                  variant="outline-primary"
                  class="me-1"
                  @click="downloadBackup(data.item.filename)"
                >
                  <i class="bi bi-download" /> Download
                </BButton>
                <BButton size="sm" variant="outline-danger" @click="promptRestore(data.item)">
                  <i class="bi bi-arrow-counterclockwise" /> Restore
                </BButton>
              </template>
            </BTable>

            <div v-if="!loading && backups.length === 0" class="text-center text-muted py-3">
              No backups available. Use "Backup Now" to create one.
            </div>
          </BCard>

          <!-- Backup Now Card -->
          <BCard
            header-tag="header"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3 text-start"
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
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3 text-start"
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
        <p class="text-danger fw-bold">
          This will overwrite the current database. Type RESTORE to confirm.
        </p>
        <p v-if="selectedBackup" class="text-muted small">
          Restoring from: <code>{{ selectedBackup.filename }}</code>
        </p>
        <BFormInput v-model="restoreConfirmText" placeholder="RESTORE" autocomplete="off" />
      </BModal>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
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
const loading = ref(false);
const showRestoreModal = ref(false);
const selectedBackup = ref<BackupItem | null>(null);
const restoreConfirmText = ref('');

// Table fields
const backupFields = [
  { key: 'filename', label: 'Filename', sortable: true },
  { key: 'size_bytes', label: 'Size', sortable: true },
  { key: 'created_at', label: 'Created', sortable: true },
  { key: 'actions', label: 'Actions', sortable: false },
];

// Helper to unwrap R/Plumber array values (scalars come as single-element arrays)
function unwrapValue<T>(val: T | T[]): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}

// Format file size to human-readable
function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
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

// Fetch backup list from API
async function fetchBackupList() {
  loading.value = true;
  try {
    const response = await axios.get(`${import.meta.env.VITE_API_URL}/api/backup/list`, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem('token')}`,
      },
    });

    const data = response.data;
    if (data && Array.isArray(data.data)) {
      // Unwrap R/Plumber values
      backups.value = data.data.map((backup: Record<string, unknown>) => ({
        filename: unwrapValue(backup.filename) as string,
        size_bytes: Number(unwrapValue(backup.size_bytes)) || 0,
        created_at: unwrapValue(backup.created_at) as string,
        table_count: backup.table_count ? Number(unwrapValue(backup.table_count)) : null,
      }));
    } else {
      backups.value = [];
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
      }
    );

    if (response.data.error) {
      makeToast(response.data.message || 'Failed to start restore', 'Error', 'danger');
      return;
    }

    // Start tracking the job
    restoreJob.startJob(response.data.job_id);
  } catch (error) {
    console.error('Failed to start restore:', error);
    makeToast('Failed to start restore', 'Error', 'danger');
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
      }
    );

    if (response.data.error) {
      makeToast(response.data.message || 'Failed to start backup', 'Error', 'danger');
      return;
    }

    // Start tracking the job
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

// Lifecycle
onMounted(() => {
  fetchBackupList();
});
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
</style>
