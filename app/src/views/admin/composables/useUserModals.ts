// app/src/views/admin/composables/useUserModals.ts
import { ref } from 'vue';

export interface UserSummary {
  user_id: number;
  user_name: string;
  user_role: string;
  email?: string;
  approved?: number | boolean;
  abbreviation?: string;
  first_name?: string;
  family_name?: string;
  orcid?: string;
  comment?: string;
}

export interface UseUserModalsOptions {
  onToast?: (...args: unknown[]) => void;
}

export function useUserModals(options: UseUserModalsOptions = {}) {
  const { onToast } = options;

  const isDeleteOpen = ref(false);
  const isUpdateOpen = ref(false);
  const isBulkApproveOpen = ref(false);
  const isBulkDeleteOpen = ref(false);
  const isBulkRoleOpen = ref(false);

  const userToDelete = ref<Partial<UserSummary>>({});
  const userToUpdate = ref<Partial<UserSummary>>({});
  const bulkApproveUsernames = ref<string[]>([]);
  const bulkDeleteUsernames = ref<string[]>([]);
  const bulkRoleUsernames = ref<string[]>([]);
  const deleteConfirmText = ref('');
  const bulkRoleSelection = ref('');

  function promptDelete(user: UserSummary): void {
    userToDelete.value = user;
    isDeleteOpen.value = true;
  }

  function editUser(user: UserSummary): void {
    userToUpdate.value = { ...user };
    isUpdateOpen.value = true;
  }

  function ensureNonEmpty(userIds: number[], action: string): void {
    if (userIds.length === 0) {
      const err = new Error('No users selected');
      onToast?.(err.message, action, 'warning');
      throw err;
    }
  }

  function openBulkApprove(userIds: number[], allUsers: UserSummary[]): void {
    ensureNonEmpty(userIds, 'Bulk Approve');
    bulkApproveUsernames.value = allUsers
      .filter((u) => userIds.includes(u.user_id))
      .map((u) => u.user_name);
    isBulkApproveOpen.value = true;
  }

  function openBulkDelete(userIds: number[], allUsers: UserSummary[]): void {
    ensureNonEmpty(userIds, 'Bulk Delete');
    const selected = allUsers.filter((u) => userIds.includes(u.user_id));
    const admins = selected.filter((u) => u.user_role === 'Administrator');
    if (admins.length > 0) {
      const err = new Error(`Cannot delete: selection contains ${admins.length} admin user(s)`);
      onToast?.(err.message, 'Delete Blocked', 'danger');
      throw err;
    }
    bulkDeleteUsernames.value = selected.map((u) => u.user_name);
    deleteConfirmText.value = '';
    isBulkDeleteOpen.value = true;
  }

  function openBulkRole(userIds: number[], allUsers: UserSummary[]): void {
    ensureNonEmpty(userIds, 'Assign Role');
    bulkRoleUsernames.value = allUsers
      .filter((u) => userIds.includes(u.user_id))
      .map((u) => u.user_name);
    bulkRoleSelection.value = '';
    isBulkRoleOpen.value = true;
  }

  function close(): void {
    isDeleteOpen.value = false;
    isUpdateOpen.value = false;
    isBulkApproveOpen.value = false;
    isBulkDeleteOpen.value = false;
    isBulkRoleOpen.value = false;
    userToDelete.value = {};
    userToUpdate.value = {};
    bulkApproveUsernames.value = [];
    bulkDeleteUsernames.value = [];
    bulkRoleUsernames.value = [];
    deleteConfirmText.value = '';
    bulkRoleSelection.value = '';
  }

  return {
    isDeleteOpen,
    isUpdateOpen,
    isBulkApproveOpen,
    isBulkDeleteOpen,
    isBulkRoleOpen,
    userToDelete,
    userToUpdate,
    bulkApproveUsernames,
    bulkDeleteUsernames,
    bulkRoleUsernames,
    deleteConfirmText,
    bulkRoleSelection,
    promptDelete,
    editUser,
    openBulkApprove,
    openBulkDelete,
    openBulkRole,
    close,
  };
}
