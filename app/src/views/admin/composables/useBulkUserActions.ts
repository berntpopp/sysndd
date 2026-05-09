// app/src/views/admin/composables/useBulkUserActions.ts
import { ref } from 'vue';
import { apiClient } from '@/api/client';

const apiBase = import.meta.env.VITE_API_URL ?? '';

export interface UseBulkUserActionsOptions {
  onToast?: (...args: unknown[]) => void;
  onSuccess?: () => void;
}

export function useBulkUserActions(options: UseBulkUserActionsOptions = {}) {
  const { onToast, onSuccess } = options;
  const bulkActing = ref(false);

  function ensureNonEmpty(ids: number[], action: string): void {
    if (ids.length === 0) {
      const err = new Error(`No users selected for ${action}`);
      onToast?.(err.message, action, 'warning');
      throw err;
    }
  }

  async function bulkApprove(userIds: number[]): Promise<void> {
    ensureNonEmpty(userIds, 'Bulk Approve');
    bulkActing.value = true;
    try {
      const response = await apiClient.raw.post(`${apiBase}/api/user/bulk_approve`, {
        user_ids: userIds,
      });
      if (response.status === 200) {
        const processed = (response.data as { processed?: number }).processed;
        onToast?.(
          `Successfully approved ${processed || userIds.length} users`,
          'Bulk Approve Complete',
          'success',
          true,
          5000
        );
        onSuccess?.();
      }
    } catch (e: any) {
      const errorMsg = e.response?.data?.message || e.response?.data?.error || 'Unknown error';
      onToast?.(errorMsg, 'Bulk Approve Failed', 'danger');
      throw e;
    } finally {
      bulkActing.value = false;
    }
  }

  async function bulkAssignRole(userIds: number[], role: string): Promise<void> {
    ensureNonEmpty(userIds, 'Assign Role');
    if (!role) {
      const err = new Error('Please select a role');
      onToast?.(err.message, 'Invalid Role', 'warning');
      throw err;
    }
    bulkActing.value = true;
    try {
      const response = await apiClient.raw.post(`${apiBase}/api/user/bulk_assign_role`, {
        user_ids: userIds,
        role,
      });
      if (response.status === 200) {
        const processed = (response.data as { processed?: number }).processed;
        onToast?.(
          `Successfully assigned ${role} role to ${processed || userIds.length} users`,
          'Bulk Role Assignment Complete',
          'success',
          true,
          5000
        );
        onSuccess?.();
      }
    } catch (e: any) {
      const errorMsg = e.response?.data?.message || e.response?.data?.error || 'Unknown error';
      onToast?.(errorMsg, 'Bulk Role Assignment Failed', 'danger');
      throw e;
    } finally {
      bulkActing.value = false;
    }
  }

  async function bulkDelete(userIds: number[]): Promise<void> {
    ensureNonEmpty(userIds, 'Bulk Delete');
    bulkActing.value = true;
    try {
      const response = await apiClient.raw.post(`${apiBase}/api/user/bulk_delete`, {
        user_ids: userIds,
      });
      if (response.status === 200) {
        const processed = (response.data as { processed?: number }).processed;
        onToast?.(
          `Successfully deleted ${processed || userIds.length} users`,
          'Bulk Delete Complete',
          'success',
          true,
          5000
        );
        onSuccess?.();
      }
    } catch (e: any) {
      const errorMsg = e.response?.data?.message || e.response?.data?.error || 'Unknown error';
      onToast?.(errorMsg, 'Bulk Delete Failed', 'danger');
      throw e;
    } finally {
      bulkActing.value = false;
    }
  }

  return { bulkActing, bulkApprove, bulkAssignRole, bulkDelete };
}
