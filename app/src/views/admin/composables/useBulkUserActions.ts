// app/src/views/admin/composables/useBulkUserActions.ts
import { ref } from 'vue';
import { bulkApproveUsers, bulkAssignRole as apiBulkAssignRole, bulkDeleteUsers } from '@/api/user';
import { extractApiErrorMessage } from '@/utils/api-errors';

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
      const result = await bulkApproveUsers({ user_ids: userIds });
      const processed = result.processed;
      onToast?.(
        `Successfully approved ${processed || userIds.length} users`,
        'Bulk Approve Complete',
        'success',
        true,
        5000
      );
      onSuccess?.();
    } catch (e) {
      const errorMsg = extractApiErrorMessage(e, 'Failed to approve users');
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
      const result = await apiBulkAssignRole({ user_ids: userIds, role });
      const processed = result.processed;
      onToast?.(
        `Successfully assigned ${role} role to ${processed || userIds.length} users`,
        'Bulk Role Assignment Complete',
        'success',
        true,
        5000
      );
      onSuccess?.();
    } catch (e) {
      const errorMsg = extractApiErrorMessage(e, 'Failed to assign role');
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
      const result = await bulkDeleteUsers({ user_ids: userIds });
      const processed = result.processed;
      onToast?.(
        `Successfully deleted ${processed || userIds.length} users`,
        'Bulk Delete Complete',
        'success',
        true,
        5000
      );
      onSuccess?.();
    } catch (e) {
      const errorMsg = extractApiErrorMessage(e, 'Failed to delete users');
      onToast?.(errorMsg, 'Bulk Delete Failed', 'danger');
      throw e;
    } finally {
      bulkActing.value = false;
    }
  }

  return { bulkActing, bulkApprove, bulkAssignRole, bulkDelete };
}
