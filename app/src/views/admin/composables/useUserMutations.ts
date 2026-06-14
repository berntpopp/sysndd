// app/src/views/admin/composables/useUserMutations.ts
import { computed, ref } from 'vue';
import { apiClient } from '@/api/client';
import { extractApiErrorMessage } from '@/utils/api-errors';

const apiBase = import.meta.env.VITE_API_URL ?? '';

export interface UseUserMutationsOptions {
  onToast?: (...args: unknown[]) => void;
  onSuccess?: () => void;
}

export interface ChangePasswordArgs {
  userId: number;
  newPassword: string;
  confirmPassword: string;
}

export interface UpdateUserPayload {
  user_id: number;
  user_name: string;
  email: string;
  abbreviation: string;
  first_name: string;
  family_name: string;
  user_role: string;
  approved: boolean | number;
  orcid?: string;
  comment?: string;
}

export function useUserMutations(options: UseUserMutationsOptions = {}) {
  const { onToast, onSuccess } = options;
  const isUpdating = ref(false);
  const isDeleting = ref(false);
  const isChangingPassword = ref(false);

  const passwordChange = ref({
    newPassword: '',
    confirmPassword: '',
    showPassword: false,
  });

  const passwordValidation = computed(() => {
    const pw = passwordChange.value.newPassword;
    const rules = {
      minLength: { label: 'At least 8 characters', valid: pw.length >= 8 },
      hasUppercase: { label: 'At least one uppercase letter', valid: /[A-Z]/.test(pw) },
      hasLowercase: { label: 'At least one lowercase letter', valid: /[a-z]/.test(pw) },
      hasNumber: { label: 'At least one number', valid: /[0-9]/.test(pw) },
      hasSpecial: {
        label: 'At least one special character (!@#$%^&*)',
        valid: /[!@#$%^&*]/.test(pw),
      },
    };
    const isValid = pw.length > 0 && Object.values(rules).every((r) => r.valid);
    return { rules, isValid: pw.length > 0 ? isValid : null };
  });

  async function deleteUser(user: { user_id: number }): Promise<void> {
    isDeleting.value = true;
    try {
      const response = await apiClient.raw.delete(`${apiBase}/api/user/delete`, {
        data: { user_id: user.user_id },
      });
      if (response.status === 200) {
        onToast?.('User deleted successfully', 'Success', 'success');
        onSuccess?.();
      } else {
        throw new Error('Failed to delete the user.');
      }
    } catch (e) {
      onToast?.(extractApiErrorMessage(e, 'Failed to delete the user.'), 'Error', 'danger');
      throw e;
    } finally {
      isDeleting.value = false;
    }
  }

  async function updateUser(payload: UpdateUserPayload): Promise<void> {
    isUpdating.value = true;
    const updatePayload: Record<string, unknown> = {
      user_id: payload.user_id,
      user_name: payload.user_name,
      email: payload.email,
      abbreviation: payload.abbreviation,
      first_name: payload.first_name,
      family_name: payload.family_name,
      user_role: payload.user_role,
      approved: payload.approved ? 1 : 0,
    };
    // Send orcid/comment unconditionally so an admin clearing an existing
    // value to empty is persisted (the API maps these to user table columns).
    // `?? ''` lets a cleared field reach the API as '' instead of being dropped.
    if (payload.orcid !== undefined) updatePayload.orcid = payload.orcid ?? '';
    if (payload.comment !== undefined) updatePayload.comment = payload.comment ?? '';
    try {
      const response = await apiClient.raw.put(`${apiBase}/api/user/update`, {
        user_details: updatePayload,
      });
      if (response.status === 200) {
        onToast?.('User updated successfully', 'Success', 'success');
        onSuccess?.();
      } else {
        throw new Error('Failed to update the user.');
      }
    } catch (e) {
      onToast?.(extractApiErrorMessage(e, 'Failed to update the user.'), 'Error', 'danger');
      throw e;
    } finally {
      isUpdating.value = false;
    }
  }

  async function changePassword(args: ChangePasswordArgs): Promise<void> {
    if (args.newPassword !== args.confirmPassword) {
      const err = new Error('Passwords do not match');
      onToast?.(err.message, 'Validation Error', 'warning');
      throw err;
    }
    isChangingPassword.value = true;
    try {
      const response = await apiClient.raw.put(`${apiBase}/api/user/password/update`, {
        user_id_pass_change: args.userId,
        old_pass: '',
        new_pass_1: args.newPassword,
        new_pass_2: args.confirmPassword,
      });
      if (response.status !== 200) {
        throw new Error('Failed to change password');
      }
      onToast?.(`Password changed successfully`, 'Password Changed', 'success', true, 5000);
      passwordChange.value.newPassword = '';
      passwordChange.value.confirmPassword = '';
    } catch (e) {
      const errorMsg = extractApiErrorMessage(e, 'Failed to change password');
      onToast?.(errorMsg, 'Password Change Failed', 'danger');
      throw e;
    } finally {
      isChangingPassword.value = false;
    }
  }

  function generatePassword(): string {
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const special = '!@#$%^&*';
    const required = [
      lower[Math.floor(Math.random() * lower.length)],
      upper[Math.floor(Math.random() * upper.length)],
      numbers[Math.floor(Math.random() * numbers.length)],
      special[Math.floor(Math.random() * special.length)],
    ];
    const all = lower + upper + numbers + special;
    while (required.length < 16) required.push(all[Math.floor(Math.random() * all.length)]);
    for (let i = required.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [required[i], required[j]] = [required[j], required[i]];
    }
    const pw = required.join('');
    passwordChange.value.newPassword = pw;
    passwordChange.value.confirmPassword = pw;
    passwordChange.value.showPassword = true;
    return pw;
  }

  return {
    isUpdating,
    isDeleting,
    isChangingPassword,
    passwordChange,
    passwordValidation,
    deleteUser,
    updateUser,
    changePassword,
    generatePassword,
  };
}
