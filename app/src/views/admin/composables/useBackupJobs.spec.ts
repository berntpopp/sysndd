// useBackupJobs.spec.ts
/**
 * Spec for `views/admin/composables/useBackupJobs.ts` after the typed
 * backup-client migration.
 *
 * Job orchestration no longer hand-builds `${VITE_API_URL}/api/backup/...`
 * URLs through `apiClient.raw.*`; it now routes through the typed helpers in
 * `@/api/backup` (`createBackup`, `restoreBackup`, `deleteBackup`). These
 * tests pin the typed-client boundary at the composable level:
 *
 *   - POST   /api/backup/create  -> job_id handoff + Bearer header
 *   - POST   /api/backup/restore -> filename body + job_id handoff + Bearer
 *   - DELETE /api/backup/delete/:filename -> confirm body + percent-encoded path
 *
 * The async-job polling state machine has dedicated coverage in
 * `useAsyncJob.spec.ts`; here it is stubbed so `startJob` is observable
 * without firing the poller.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';

const startJobSpy = vi.fn();
const resetSpy = vi.fn();

vi.mock('@/composables/useAsyncJob', () => ({
  useAsyncJob: () => ({
    status: { value: 'idle' },
    isLoading: { value: false },
    progress: { value: 0 },
    message: { value: '' },
    error: { value: null },
    jobId: { value: null },
    reset: resetSpy,
    startJob: startJobSpy,
  }),
}));

import { useBackupJobs } from './useBackupJobs';
import type { BackupItem } from './useBackupInventory';

const onRefresh = vi.fn();
const makeToastSpy = vi.fn();

function makeBackup(filename: string): BackupItem {
  return { filename, size_bytes: 1, created_at: '2026-04-25T00:00:00Z', table_count: null };
}

beforeEach(() => {
  startJobSpy.mockClear();
  resetSpy.mockClear();
  onRefresh.mockClear();
  makeToastSpy.mockClear();
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  useAuth().logout();
  vi.unstubAllEnvs();
});

describe('useBackupJobs — typed-client migration', () => {
  it('triggerBackup() POSTs /api/backup/create with the Bearer header and starts the job', async () => {
    primeAuth('create-token');

    server.use(
      http.post('/api/backup/create', ({ request }) => {
        expectBearerHeader(request, 'create-token');
        return HttpResponse.json({ job_id: 'backup-1' }, { status: 202 });
      })
    );

    const jobs = useBackupJobs({ onRefresh, onToast: makeToastSpy });
    await jobs.triggerBackup();

    expect(resetSpy).toHaveBeenCalled();
    expect(startJobSpy).toHaveBeenCalledWith('backup-1');
  });

  it('triggerBackup() toasts the extracted error on failure', async () => {
    primeAuth('create-fail-token');

    server.use(
      http.post('/api/backup/create', () =>
        HttpResponse.json({ message: 'A backup is already running' }, { status: 409 })
      )
    );

    const jobs = useBackupJobs({ onRefresh, onToast: makeToastSpy });
    await jobs.triggerBackup();

    expect(startJobSpy).not.toHaveBeenCalled();
    expect(makeToastSpy).toHaveBeenCalledWith('A backup is already running', 'Error', 'danger');
  });

  it('confirmRestore() POSTs the filename body with the Bearer header and starts the job', async () => {
    primeAuth('restore-token');

    let receivedBody: unknown = null;
    server.use(
      http.post('/api/backup/restore', async ({ request }) => {
        expectBearerHeader(request, 'restore-token');
        receivedBody = await request.json();
        return HttpResponse.json({ job_id: 'restore-1' }, { status: 202 });
      })
    );

    const jobs = useBackupJobs({ onRefresh, onToast: makeToastSpy });
    jobs.selectedBackup.value = makeBackup('manual_2026-04-25.sql.gz');
    jobs.restoreConfirmText.value = 'RESTORE';

    await jobs.confirmRestore();

    expect(receivedBody).toEqual({ filename: 'manual_2026-04-25.sql.gz' });
    expect(startJobSpy).toHaveBeenCalledWith('restore-1');
    expect(jobs.showRestoreModal.value).toBe(false);
  });

  it('confirmRestore() is a no-op when the confirm text is wrong', async () => {
    primeAuth('restore-guard-token');

    const jobs = useBackupJobs({ onRefresh, onToast: makeToastSpy });
    jobs.selectedBackup.value = makeBackup('manual_2026-04-25.sql.gz');
    jobs.restoreConfirmText.value = 'nope';

    await jobs.confirmRestore();

    expect(resetSpy).not.toHaveBeenCalled();
    expect(startJobSpy).not.toHaveBeenCalled();
  });

  it('confirmDelete() DELETEs the percent-encoded path with the confirm body and refreshes', async () => {
    primeAuth('delete-token');

    const filename = 'pre-restore_2026-04-25T12:34:56.sql.gz';
    let requestedPath = '';
    let receivedBody: unknown = null;
    server.use(
      http.delete('/api/backup/delete/:filename', async ({ request }) => {
        expectBearerHeader(request, 'delete-token');
        requestedPath = new URL(request.url).pathname;
        receivedBody = await request.json();
        return HttpResponse.json({ success: true, message: 'Deleted' });
      })
    );

    const jobs = useBackupJobs({ onRefresh, onToast: makeToastSpy });
    jobs.selectedBackup.value = makeBackup(filename);
    jobs.deleteConfirmText.value = 'DELETE';

    await jobs.confirmDelete();

    expect(requestedPath).toBe(`/api/backup/delete/${encodeURIComponent(filename)}`);
    expect(receivedBody).toEqual({ confirm: 'DELETE' });
    expect(makeToastSpy).toHaveBeenCalledWith(
      `Backup '${filename}' deleted successfully`,
      'Success',
      'success'
    );
    expect(onRefresh).toHaveBeenCalled();
  });

  it('confirmDelete() toasts the extracted error and skips refresh on failure', async () => {
    primeAuth('delete-fail-token');

    server.use(
      http.delete('/api/backup/delete/:filename', () =>
        HttpResponse.json({ message: 'A backup operation is already running' }, { status: 409 })
      )
    );

    const jobs = useBackupJobs({ onRefresh, onToast: makeToastSpy });
    jobs.selectedBackup.value = makeBackup('manual_2026-04-25.sql.gz');
    jobs.deleteConfirmText.value = 'DELETE';

    await jobs.confirmDelete();

    expect(makeToastSpy).toHaveBeenCalledWith(
      'A backup operation is already running',
      'Error',
      'danger'
    );
    expect(onRefresh).not.toHaveBeenCalled();
  });
});
