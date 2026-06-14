// useBackupInventory.spec.ts
/**
 * Spec for `views/admin/composables/useBackupInventory.ts` after the typed
 * backup-client migration.
 *
 * The inventory data layer no longer hand-builds `${VITE_API_URL}/api/backup/...`
 * URLs through `apiClient.raw.*`; it now routes through the typed helpers in
 * `@/api/backup` (`listBackups`, `downloadBackup`). These tests pin the
 * typed-client boundary directly at the composable level:
 *
 *   - GET /api/backup/list  -> list mapping + meta + Bearer header
 *   - GET /api/backup/download/:filename -> Blob + percent-encoded path + Bearer
 *     header + extractApiErrorMessage on failure
 *
 * They sit alongside the view-level contract in `../ManageBackups.spec.ts`.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';
import { useBackupInventory, formatFileSize } from './useBackupInventory';

const makeToastSpy = vi.fn();

beforeEach(() => {
  makeToastSpy.mockClear();
  // Relative paths must resolve against the MSW handlers, so neutralise any
  // configured base URL (mirrors ManageBackups.spec.ts).
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  useAuth().logout();
  vi.unstubAllEnvs();
});

describe('useBackupInventory — typed-client migration', () => {
  it('fetchBackupList() GETs /api/backup/list with the Bearer header and maps the envelope', async () => {
    primeAuth('inventory-token');

    server.use(
      http.get('/api/backup/list', ({ request }) => {
        expectBearerHeader(request, 'inventory-token');
        return HttpResponse.json({
          data: [
            {
              filename: 'manual_2026-04-25.sql.gz',
              size_bytes: 2048,
              created_at: '2026-04-25T00:00:00Z',
              table_count: 12,
            },
          ],
          meta: { total_count: 1, total_size_bytes: 2048 },
        });
      })
    );

    const inv = useBackupInventory({ onToast: makeToastSpy });
    await inv.fetchBackupList();

    expect(inv.backups.value).toEqual([
      {
        filename: 'manual_2026-04-25.sql.gz',
        size_bytes: 2048,
        created_at: '2026-04-25T00:00:00Z',
        table_count: 12,
      },
    ]);
    expect(inv.meta.value).toEqual({ total_count: 1, total_size_bytes: 2048 });
    expect(inv.loading.value).toBe(false);
  });

  it('fetchBackupList() unwraps R/Plumber single-element scalar arrays', async () => {
    primeAuth('scalar-token');

    server.use(
      http.get('/api/backup/list', () =>
        HttpResponse.json({
          data: [
            {
              filename: ['manual_scalar.sql.gz'],
              size_bytes: [4096],
              created_at: ['2026-04-25T01:00:00Z'],
              table_count: [7],
            },
          ],
          meta: { total_count: [1], total_size_bytes: [4096] },
        })
      )
    );

    const inv = useBackupInventory({ onToast: makeToastSpy });
    await inv.fetchBackupList();

    expect(inv.backups.value).toEqual([
      {
        filename: 'manual_scalar.sql.gz',
        size_bytes: 4096,
        created_at: '2026-04-25T01:00:00Z',
        table_count: 7,
      },
    ]);
    expect(inv.meta.value).toEqual({ total_count: 1, total_size_bytes: 4096 });
  });

  it('fetchBackupList() toasts and clears the list on failure', async () => {
    primeAuth('inventory-fail-token');

    server.use(
      http.get('/api/backup/list', () =>
        HttpResponse.json({ message: 'read failure' }, { status: 500 })
      )
    );

    const inv = useBackupInventory({ onToast: makeToastSpy });
    await inv.fetchBackupList();

    expect(inv.backups.value).toEqual([]);
    expect(makeToastSpy).toHaveBeenCalledWith('Failed to load backup list', 'Error', 'danger');
    expect(inv.loading.value).toBe(false);
  });

  it('downloadBackup() GETs the percent-encoded path with the Bearer header', async () => {
    primeAuth('download-token');

    const filename = 'manual_2026-04-25T12:34:56.sql.gz';
    let requestedPath = '';
    server.use(
      http.get('/api/backup/download/:filename', ({ request }) => {
        expectBearerHeader(request, 'download-token');
        requestedPath = new URL(request.url).pathname;
        return new HttpResponse(new Blob(['ok']));
      })
    );

    const createSpy = vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock');
    const revokeSpy = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {});

    const inv = useBackupInventory({ onToast: makeToastSpy });
    await inv.downloadBackup(filename);

    createSpy.mockRestore();
    revokeSpy.mockRestore();

    expect(requestedPath).toBe(`/api/backup/download/${encodeURIComponent(filename)}`);
    // The colon from the timestamp must be escaped, not present raw.
    expect(requestedPath).not.toContain(filename);
    expect(makeToastSpy).not.toHaveBeenCalled();
  });

  it('downloadBackup() surfaces the extracted error via the toast on failure', async () => {
    primeAuth('download-fail-token');

    server.use(
      http.get('/api/backup/download/:filename', () =>
        HttpResponse.json({ message: 'Backup file not found' }, { status: 404 })
      )
    );

    const inv = useBackupInventory({ onToast: makeToastSpy });
    await inv.downloadBackup('missing.sql.gz');

    expect(makeToastSpy).toHaveBeenCalledTimes(1);
    const [message, title, variant] = makeToastSpy.mock.calls[0];
    expect(message).toMatch(/404/);
    expect(title).toBe('Error');
    expect(variant).toBe('danger');
  });
});

describe('useBackupInventory — formatters', () => {
  it('formatFileSize() renders human-readable sizes', () => {
    expect(formatFileSize(0)).toBe('0 B');
    expect(formatFileSize(2048)).toBe('2 KB');
  });
});
