// app/src/views/admin/composables/__tests__/useUserModals.spec.ts
/**
 * Unit tests for `useUserModals` — the modal state composable extracted
 * from `ManageUser.vue` during W1 of v11.2 monolith-cleanup.
 */

import { describe, expect, it } from 'vitest';
import { useUserModals } from '../useUserModals';

describe('useUserModals', () => {
  it('promptDelete sets target and opens delete modal', () => {
    const m = useUserModals();
    m.promptDelete({ user_id: 1, user_name: 'alice' } as any);
    expect(m.isDeleteOpen.value).toBe(true);
    expect(m.userToDelete.value.user_id).toBe(1);
  });

  it('editUser sets target with a clone (no aliasing) and opens update modal', () => {
    const m = useUserModals();
    const original = { user_id: 1, user_name: 'alice', orcid: '0000' } as any;
    m.editUser(original);
    expect(m.isUpdateOpen.value).toBe(true);
    expect(m.userToUpdate.value).not.toBe(original);
    expect(m.userToUpdate.value.user_id).toBe(1);
    m.userToUpdate.value.user_name = 'changed';
    expect(original.user_name).toBe('alice');
  });

  it('openBulkApprove rejects empty selection', () => {
    const m = useUserModals();
    expect(() => m.openBulkApprove([], [])).toThrow();
    expect(m.isBulkApproveOpen.value).toBe(false);
  });

  it('openBulkApprove with users opens modal and exposes usernames', () => {
    const m = useUserModals();
    m.openBulkApprove(
      [1, 2],
      [
        { user_id: 1, user_name: 'alice', user_role: 'Curator' } as any,
        { user_id: 2, user_name: 'bob', user_role: 'Reviewer' } as any,
      ]
    );
    expect(m.isBulkApproveOpen.value).toBe(true);
    expect(m.bulkApproveUsernames.value).toEqual(['alice', 'bob']);
  });

  it('openBulkDelete blocks if any selected user is Administrator', () => {
    const m = useUserModals();
    expect(() =>
      m.openBulkDelete([1], [{ user_id: 1, user_name: 'root', user_role: 'Administrator' } as any])
    ).toThrow();
    expect(m.isBulkDeleteOpen.value).toBe(false);
  });

  it('close resets every modal flag and target', () => {
    const m = useUserModals();
    m.promptDelete({ user_id: 1, user_name: 'alice' } as any);
    m.close();
    expect(m.isDeleteOpen.value).toBe(false);
    expect(m.userToDelete.value).toEqual({});
  });
});
