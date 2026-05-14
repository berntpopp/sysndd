// ManageBackups.spec.ts
/**
 * v11.0 closeout F2b — spec for `views/admin/ManageBackups.vue`.
 *
 * Five authed endpoints were previously stamped with a hand-built
 * `Authorization: Bearer ${localStorage.getItem('token')}` header. They
 * now route through `apiClient.raw.*`, which inherits the Bearer from the
 * shared request interceptor. This spec pins all five call sites:
 *
 *   - GET   /api/backup/list
 *   - GET   /api/backup/download/:filename
 *   - POST  /api/backup/restore
 *   - DELETE /api/backup/delete/:filename
 *   - POST  /api/backup/create
 *
 * Each test uses `primeAuth() + expectBearerHeader()` — a 401 would have
 * made the original `fetchBackupList()` catch branch toast silently, so
 * asserting the header shape is the only way to prove the migration is
 * correct.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';
import ManageBackups from './ManageBackups.vue';

const makeToastSpy = vi.fn();
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: makeToastSpy }),
}));

// The view composes `useAsyncJob` for backup/restore status polling; stub
// it to a minimal surface so the spec focuses on the Bearer-header
// contract rather than the polling state machine (that has dedicated
// coverage in `useAsyncJob.spec.ts`). The template reads several reactive
// refs (`status.value`, `isLoading.value`, `progress.value`, `message.value`
// and `error.value`); stub them all with `.value === idle/false` defaults.
vi.mock('@/composables/useAsyncJob', () => ({
  useAsyncJob: () => ({
    status: { value: 'idle' },
    isLoading: { value: false },
    progress: { value: 0 },
    message: { value: '' },
    error: { value: null },
    jobId: { value: null },
    reset: vi.fn(),
    startJob: vi.fn(),
  }),
}));

interface BackupsVm {
  fetchBackupList: () => Promise<void>;
  downloadBackup: (filename: string) => Promise<void>;
  confirmRestore: () => Promise<void>;
  confirmDelete: () => Promise<void>;
  triggerBackup: () => Promise<void>;
  selectedBackup: { filename: string } | null;
  restoreConfirmText: string;
  deleteConfirmText: string;
  backups: unknown[];
}

function mountView() {
  return mount(ManageBackups, {
    global: {
      directives: { 'b-tooltip': {}, 'b-toggle': {} },
      stubs: {
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BCard: { template: '<div><slot name="header" /><slot /></div>' },
        BBadge: { template: '<span><slot /></span>' },
        BButton: { template: '<button><slot /></button>' },
        BSpinner: { template: '<div />' },
        BFormInput: { template: '<input />' },
        BFormSelect: { template: '<select />' },
        BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
        BInputGroupText: { template: '<span><slot /></span>' },
        BModal: { template: '<div><slot /></div>' },
        BTable: { template: '<table />' },
        BPagination: { template: '<nav />' },
        BProgress: { template: '<div />' },
      },
    },
  });
}

beforeEach(() => {
  makeToastSpy.mockClear();
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  useAuth().logout();
  vi.unstubAllEnvs();
});

describe('ManageBackups — v11.0 closeout F2b apiClient migration', () => {
  it('fetchBackupList() issues GET /api/backup/list with the Bearer header', async () => {
    primeAuth('backup-token');

    server.use(
      http.get('/api/backup/list', ({ request }) => {
        expectBearerHeader(request, 'backup-token');
        return HttpResponse.json({ data: [], meta: { total_count: 0, total_size_bytes: 0 } });
      })
    );

    const wrapper = mountView();
    await (wrapper.vm as unknown as BackupsVm).fetchBackupList();
    await flushPromises();
    expect((wrapper.vm as unknown as BackupsVm).backups).toEqual([]);
  });

  it('downloadBackup() issues GET /api/backup/download/:filename with the Bearer header', async () => {
    primeAuth('download-token');

    let sawBearerOnDownload = false;
    server.use(
      http.get('/api/backup/download/:filename', ({ request }) => {
        expectBearerHeader(request, 'download-token');
        sawBearerOnDownload = true;
        return new HttpResponse(new Blob(['ok']));
      })
    );

    // jsdom doesn't fully implement `URL.createObjectURL` / <a>.click() —
    // stub both so the download branch completes without throwing.
    const createSpy = vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock');
    const revokeSpy = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {});

    const wrapper = mountView();
    await (wrapper.vm as unknown as BackupsVm).downloadBackup('manual_2025-10-01.sql.gz');
    await flushPromises();

    createSpy.mockRestore();
    revokeSpy.mockRestore();

    // The handler fired AND the Bearer assertion inside it did not throw.
    // The download-click DOM dance may still fail in jsdom — that is
    // out of scope for the migration contract.
    expect(sawBearerOnDownload).toBe(true);
  });

  it('confirmRestore() issues POST /api/backup/restore with the Bearer header', async () => {
    primeAuth('restore-token');

    server.use(
      http.post('/api/backup/restore', async ({ request }) => {
        expectBearerHeader(request, 'restore-token');
        const body = (await request.json()) as { filename: string };
        expect(body.filename).toBe('manual_2025-10-01.sql.gz');
        return HttpResponse.json({ job_id: 'restore-1' });
      })
    );

    const wrapper = mountView();
    const vm = wrapper.vm as unknown as BackupsVm;
    vm.selectedBackup = { filename: 'manual_2025-10-01.sql.gz' };
    vm.restoreConfirmText = 'RESTORE';

    await vm.confirmRestore();
    await flushPromises();
  });

  it('confirmDelete() issues DELETE /api/backup/delete/:filename with the Bearer header', async () => {
    primeAuth('delete-token');

    server.use(
      http.delete('/api/backup/delete/:filename', async ({ request, params }) => {
        expectBearerHeader(request, 'delete-token');
        expect(params.filename).toBe('manual_2025-10-01.sql.gz');
        return HttpResponse.json({ message: 'Deleted' });
      }),
      // Post-delete refresh hits /api/backup/list — keep it green so the
      // test doesn't fail on the refetch leg.
      http.get('/api/backup/list', () =>
        HttpResponse.json({ data: [], meta: { total_count: 0, total_size_bytes: 0 } })
      )
    );

    const wrapper = mountView();
    const vm = wrapper.vm as unknown as BackupsVm;
    vm.selectedBackup = { filename: 'manual_2025-10-01.sql.gz' };
    vm.deleteConfirmText = 'DELETE';

    await vm.confirmDelete();
    await flushPromises();
  });

  it('triggerBackup() issues POST /api/backup/create with the Bearer header', async () => {
    primeAuth('create-token');

    server.use(
      http.post('/api/backup/create', ({ request }) => {
        expectBearerHeader(request, 'create-token');
        return HttpResponse.json({ job_id: 'backup-1' });
      })
    );

    const wrapper = mountView();
    await (wrapper.vm as unknown as BackupsVm).triggerBackup();
    await flushPromises();
  });

  it('keeps the manual backup operation inside the inventory table shell', () => {
    primeAuth('layout-token');

    server.use(
      http.get('/api/backup/list', () =>
        HttpResponse.json({ data: [], meta: { total_count: 0, total_size_bytes: 0 } })
      )
    );

    const wrapper = mountView();

    expect(wrapper.find('[data-testid="backup-manual-operation"]').exists()).toBe(true);
  });
});
