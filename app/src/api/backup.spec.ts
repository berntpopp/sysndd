// app/src/api/backup.spec.ts
//
// Vitest + MSW spec for the typed backup helpers (W3.4).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  listBackups,
  createBackup,
  restoreBackup,
  downloadBackup,
  deleteBackup,
  type BackupListResponse,
  type AsyncBackupJobAccepted,
  type DeleteBackupResponse,
} from './backup';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/backup — listBackups', () => {
  it('forwards pagination + sort params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: BackupListResponse = {
      data: [],
      total: 0,
      page: 1,
      page_size: 20,
      limit: 20,
      offset: 0,
      links: { next: null },
      meta: { total_count: 0, total_size_bytes: 0 },
    };
    server.use(
      http.get('/api/backup/list', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      }),
    );

    await listBackups({ limit: 50, offset: 100, sort: 'oldest' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('limit')).toBe('50');
    expect(q.get('offset')).toBe('100');
    expect(q.get('sort')).toBe('oldest');
  });

  it('returns the paginated envelope on 200', async () => {
    server.use(
      http.get('/api/backup/list', () =>
        HttpResponse.json<BackupListResponse>({
          data: [
            { filename: 'manual_2026-04-25.sql.gz', size_bytes: 1234, created_at: '2026-04-25T00:00:00Z' },
          ],
          total: 1,
          page: 1,
          page_size: 20,
          limit: 20,
          offset: 0,
          links: { next: null },
          meta: { total_count: 1, total_size_bytes: 1234 },
        }),
      ),
    );
    const result = await listBackups();
    expect(result.data).toHaveLength(1);
    expect(result.total).toBe(1);
  });
});

describe('api/backup — createBackup', () => {
  it('returns the AsyncBackupJobAccepted envelope on 202', async () => {
    const expected: AsyncBackupJobAccepted = {
      job_id: 'b-1',
      status: 'accepted',
      estimated_seconds: 120,
      status_url: '/api/jobs/b-1/status',
    };
    server.use(
      http.post('/api/backup/create', () => HttpResponse.json(expected, { status: 202 })),
    );
    const result = await createBackup();
    expect(result.job_id).toBe('b-1');
  });

  it('throws AxiosError on 409 (backup already running)', async () => {
    server.use(
      http.post('/api/backup/create', () =>
        HttpResponse.json({ error: 'BACKUP_IN_PROGRESS' }, { status: 409 }),
      ),
    );

    let caught: unknown;
    try {
      await createBackup();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(409);
    }
  });
});

describe('api/backup — restoreBackup', () => {
  it('POSTs the filename and returns the job envelope', async () => {
    let receivedBody: unknown = null;
    const expected: AsyncBackupJobAccepted = {
      job_id: 'r-1',
      status: 'accepted',
      estimated_seconds: 120,
      status_url: '/api/jobs/r-1/status',
    };
    server.use(
      http.post('/api/backup/restore', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(expected, { status: 202 });
      }),
    );

    const result = await restoreBackup({ filename: 'manual_2026-04-25.sql.gz' });
    expect(receivedBody).toEqual({ filename: 'manual_2026-04-25.sql.gz' });
    expect(result.job_id).toBe('r-1');
  });

  it('throws AxiosError on 404 (backup file not found)', async () => {
    server.use(
      http.post('/api/backup/restore', () =>
        HttpResponse.json({ error: 'BACKUP_NOT_FOUND' }, { status: 404 }),
      ),
    );
    await expect(restoreBackup({ filename: 'missing.sql' })).rejects.toThrow();
  });
});

describe('api/backup — downloadBackup', () => {
  it('URL-encodes the filename and returns a Blob', async () => {
    let observedPath: string | null = null;
    const blobBytes = new Uint8Array([0x1f, 0x8b, 0x08]);
    server.use(
      http.get('/api/backup/download/:filename', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return new HttpResponse(blobBytes, {
          status: 200,
          headers: { 'Content-Type': 'application/gzip' },
        });
      }),
    );

    const blob = await downloadBackup('manual 2026-04-25.sql.gz');
    expect(observedPath).toBe('/api/backup/download/manual%202026-04-25.sql.gz');
    expect(blob).toBeInstanceOf(Blob);
  });

  it('throws AxiosError on 404', async () => {
    server.use(
      http.get('/api/backup/download/:filename', () =>
        HttpResponse.json({ error: 'BACKUP_NOT_FOUND' }, { status: 404 }),
      ),
    );
    await expect(downloadBackup('missing.sql')).rejects.toThrow();
  });
});

describe('api/backup — deleteBackup', () => {
  it('DELETEs with confirmation in body', async () => {
    let receivedBody: unknown = null;
    let observedPath: string | null = null;
    const expected: DeleteBackupResponse = {
      success: true,
      message: 'Backup file deleted',
      deleted_file: 'old.sql.gz',
      deleted_size_bytes: 100,
    };
    server.use(
      http.delete('/api/backup/delete/:filename', async ({ request }) => {
        observedPath = new URL(request.url).pathname;
        receivedBody = await request.json();
        return HttpResponse.json(expected);
      }),
    );

    const result = await deleteBackup('old.sql.gz');
    expect(observedPath).toBe('/api/backup/delete/old.sql.gz');
    expect(receivedBody).toEqual({ confirm: 'DELETE' });
    expect(result.success).toBe(true);
  });

  it('throws AxiosError on 400 (missing confirmation)', async () => {
    server.use(
      http.delete('/api/backup/delete/:filename', () =>
        HttpResponse.json({ error: 'CONFIRMATION_REQUIRED' }, { status: 400 }),
      ),
    );
    await expect(deleteBackup('x.sql', { confirm: 'no' })).rejects.toThrow();
  });
});
