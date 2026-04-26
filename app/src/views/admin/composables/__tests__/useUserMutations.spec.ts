// app/src/views/admin/composables/__tests__/useUserMutations.spec.ts
/**
 * Unit tests for `useUserMutations` — the single-user CRUD composable
 * extracted from `ManageUser.vue` during W1 of v11.2 monolith-cleanup.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';

vi.mock('axios', () => {
  const axiosMock = {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', headers: { common: {} } },
    interceptors: {
      request: { use: vi.fn(), _cb: null },
      response: { use: vi.fn() },
    },
    isAxiosError: (err: unknown): boolean =>
      typeof err === 'object' && err !== null && 'isAxiosError' in err,
  };
  return {
    default: axiosMock,
    ...axiosMock,
    AxiosHeaders: class {
      private store = new Map<string, string>();
      has(key: string): boolean { return this.store.has(key.toLowerCase()); }
      get(key: string): string | null { return this.store.get(key.toLowerCase()) ?? null; }
      set(key: string, value: string): this { this.store.set(key.toLowerCase(), value); return this; }
    },
    AxiosError: Error,
  };
});

vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
    currentRoute: { value: { fullPath: '/admin/manage-user' } },
  },
}));

import { useUserMutations } from '../useUserMutations';

interface AxiosMock {
  put: ReturnType<typeof vi.fn>;
  delete: ReturnType<typeof vi.fn>;
}
async function getAxiosMock(): Promise<AxiosMock> {
  const axios = await import('axios');
  return axios.default as unknown as AxiosMock;
}

describe('useUserMutations', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('deleteUser DELETE succeeds and invokes onSuccess', async () => {
    const axios = await getAxiosMock();
    axios.delete.mockResolvedValueOnce({ status: 200, data: { ok: true } });
    let succeeded = false;
    const m = useUserMutations({ onSuccess: () => { succeeded = true; } });
    await m.deleteUser({ user_id: 7 } as any);
    await flushPromises();
    expect(succeeded).toBe(true);
  });

  it('updateUser PUT sends only intended fields and surfaces success', async () => {
    const axios = await getAxiosMock();
    let received: any = null;
    axios.put.mockImplementationOnce((_url: string, data: any) => {
      received = data;
      return Promise.resolve({ status: 200, data: { ok: true } });
    });
    const m = useUserMutations();
    await m.updateUser({
      user_id: 7,
      user_name: 'alice',
      email: 'alice@example.org',
      abbreviation: 'AL',
      first_name: 'Alice',
      family_name: 'Liddell',
      user_role: 'Curator',
      approved: true,
      orcid: '',
      comment: '',
    } as any);
    await flushPromises();
    expect(received.user_details.user_id).toBe(7);
    expect(received.user_details.approved).toBe(1);
    // empty strings are omitted from the wire payload
    expect(received.user_details.orcid).toBeUndefined();
    expect(received.user_details.comment).toBeUndefined();
  });

  it('changePassword PUT toggles isChangingPassword', async () => {
    const axios = await getAxiosMock();
    axios.put.mockResolvedValueOnce({ status: 200, data: { ok: true } });
    const m = useUserMutations();
    expect(m.isChangingPassword.value).toBe(false);
    const promise = m.changePassword({ userId: 7, newPassword: 'Aa!1aaaaaaaaaaaa', confirmPassword: 'Aa!1aaaaaaaaaaaa' });
    expect(m.isChangingPassword.value).toBe(true);
    await promise;
    await flushPromises();
    expect(m.isChangingPassword.value).toBe(false);
  });

  it('changePassword rejects on mismatch without firing the request', async () => {
    const axios = await getAxiosMock();
    const m = useUserMutations();
    await expect(
      m.changePassword({ userId: 7, newPassword: 'Aa!1aaaaaaaaaaaa', confirmPassword: 'mismatch' }),
    ).rejects.toThrow();
    expect(axios.put).not.toHaveBeenCalled();
  });

  it('generatePassword returns a 16-char string with at least one of each required class', () => {
    const m = useUserMutations();
    const pw = m.generatePassword();
    expect(pw.length).toBe(16);
    expect(/[a-z]/.test(pw)).toBe(true);
    expect(/[A-Z]/.test(pw)).toBe(true);
    expect(/[0-9]/.test(pw)).toBe(true);
    expect(/[!@#$%^&*]/.test(pw)).toBe(true);
  });
});
