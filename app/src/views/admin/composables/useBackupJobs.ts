// app/src/views/admin/composables/useBackupJobs.ts
import { ref, watch } from 'vue';
import { apiClient } from '@/api/client';
import { useAsyncJob } from '@/composables/useAsyncJob';
import type { BackupItem } from './useBackupInventory';

export interface UseBackupJobsOptions {
  /**
   * Called after a backup/restore/delete completes so the inventory can refresh.
   */
  onRefresh: () => void | Promise<void>;
  onToast?: ReturnType<typeof import('@/composables/useToast').default>['makeToast'];
}

/**
 * Backup/restore job orchestration + confirm-modal state for the backup manager.
 *
 * Extracted from `ManageBackups.vue`. Owns the two durable async-job trackers
 * (backup + restore), the restore/delete confirmation modal state, and the
 * trigger/confirm action handlers that submit the jobs and surface their
 * terminal-state toasts. The inventory list/filtering lives in the sibling
 * `useBackupInventory` composable.
 */
export function useBackupJobs(options: UseBackupJobsOptions) {
  const { onRefresh, onToast } = options;

  // Create job instances for backup and restore operations
  const backupJob = useAsyncJob(
    (jobId: string) => `/api/jobs/${encodeURIComponent(jobId)}/status`
  );
  const restoreJob = useAsyncJob(
    (jobId: string) => `/api/jobs/${encodeURIComponent(jobId)}/status`
  );

  // Confirm-modal state
  const showRestoreModal = ref(false);
  const showDeleteModal = ref(false);
  const selectedBackup = ref<BackupItem | null>(null);
  const restoreConfirmText = ref('');
  const deleteConfirmText = ref('');

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
        onToast?.(response.data.message || 'Failed to start restore', 'Error', 'danger');
        return;
      }

      restoreJob.startJob(response.data.job_id);
    } catch (error) {
      console.error('Failed to start restore:', error);
      onToast?.('Failed to start restore', 'Error', 'danger');
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
        onToast?.(response.data.message || 'Failed to delete backup', 'Error', 'danger');
        return;
      }

      onToast?.(`Backup '${filename}' deleted successfully`, 'Success', 'success');
      onRefresh();
    } catch (error) {
      console.error('Failed to delete backup:', error);
      onToast?.('Failed to delete backup', 'Error', 'danger');
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
        onToast?.(response.data.message || 'Failed to start backup', 'Error', 'danger');
        return;
      }

      backupJob.startJob(response.data.job_id);
    } catch (error) {
      console.error('Failed to start backup:', error);
      onToast?.('Failed to start backup', 'Error', 'danger');
    }
  }

  // Watch for backup job completion/failure
  watch(
    () => backupJob.status.value,
    (newStatus) => {
      if (newStatus === 'completed') {
        onToast?.('Backup created successfully', 'Success', 'success');
        onRefresh();
      } else if (newStatus === 'failed') {
        const errorMsg = backupJob.error.value || 'Backup failed';
        onToast?.(errorMsg, 'Error', 'danger');
      }
    }
  );

  // Watch for restore job completion/failure
  watch(
    () => restoreJob.status.value,
    (newStatus) => {
      if (newStatus === 'completed') {
        onToast?.(
          'Database restored. You may need to log out and log back in for changes to take effect.',
          'Success',
          'success'
        );
        onRefresh();
      } else if (newStatus === 'failed') {
        const errorMsg = restoreJob.error.value || 'Restore failed';
        onToast?.(errorMsg, 'Error', 'danger');
      }
    }
  );

  return {
    // Job trackers
    backupJob,
    restoreJob,
    // Modal state
    showRestoreModal,
    showDeleteModal,
    selectedBackup,
    restoreConfirmText,
    deleteConfirmText,
    // Methods
    promptRestore,
    promptDelete,
    confirmRestore,
    confirmDelete,
    triggerBackup,
  };
}
