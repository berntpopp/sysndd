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
                        aria-label="Filter by filename"
                      />
                    </div>

                    <label class="backup-select-label">
                      <span>Format</span>
                      <BFormSelect v-model="compressionFilter" size="sm" aria-label="Filter by format">
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
        <BackupConfirmModal
          v-model="showRestoreModal"
          v-model:confirm-text="restoreConfirmText"
          :backup="selectedBackup"
          variant="restore"
          title="Restore Database"
          panel-title="Restore will overwrite current data"
          panel-copy="The current database will be replaced with the selected backup. This action starts a restore job and should only be used after confirming the backup file."
          confirm-word="RESTORE"
          confirm-label="Restore Database"
          @confirm="confirmRestore"
        />

        <!-- Delete Confirmation Modal -->
        <BackupConfirmModal
          v-model="showDeleteModal"
          v-model:confirm-text="deleteConfirmText"
          :backup="selectedBackup"
          variant="delete"
          title="Delete Backup"
          panel-title="Delete this backup permanently"
          panel-copy="The selected backup file will be removed and cannot be restored from this inventory after deletion."
          confirm-word="DELETE"
          confirm-label="Delete Backup"
          @confirm="confirmDelete"
        />
      </BContainer>
    </div>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import TableShell from '@/components/table/TableShell.vue';
import { onMounted } from 'vue';
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
import BackupMobileRows from './components/BackupMobileRows.vue';
import BackupConfirmModal from './components/BackupConfirmModal.vue';
import { useBackupInventory } from './composables/useBackupInventory';
import { useBackupJobs } from './composables/useBackupJobs';

useHead({ title: 'Manage Backups' });

// Composables
const { makeToast } = useToast();

// Inventory: list state, filters, sort, pagination, plus list fetch + download.
const {
  backups,
  meta,
  loading,
  searchQuery,
  typeFilter,
  compressionFilter,
  currentPage,
  perPage,
  pageOptions,
  sortBy,
  mobileSortOptions,
  quickFilters,
  filteredBackups,
  mobileSortValue,
  paginatedBackups,
  paginationStart,
  paginationEnd,
  hasActiveFilters,
  formatFileSize,
  formatDate,
  getBackupType,
  getBackupTypeBadgeVariant,
  setTypeFilter,
  clearFilters,
  onSortChanged,
  fetchBackupList,
  downloadBackup,
} = useBackupInventory({ onToast: makeToast });

// Jobs: backup/restore trackers, confirm-modal state, trigger/confirm actions.
const {
  backupJob,
  restoreJob,
  showRestoreModal,
  showDeleteModal,
  selectedBackup,
  restoreConfirmText,
  deleteConfirmText,
  promptRestore,
  promptDelete,
  confirmRestore,
  confirmDelete,
  triggerBackup,
} = useBackupJobs({ onRefresh: fetchBackupList, onToast: makeToast });

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
