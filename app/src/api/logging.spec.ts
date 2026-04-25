// app/src/api/logging.spec.ts
//
// Vitest + MSW spec for the typed logging helpers (W3.12).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  listLogs,
  listLogsXlsx,
  deleteLogs,
  type LogListResponse,
  type DeleteLogsResponse,
} from './logging';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/logs — listLogs', () => {
  it('forwards format=json + sort/filter params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: LogListResponse = { links: {}, meta: {}, data: [] };
    server.use(
      http.get('/api/logs/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      }),
    );

    await listLogs({ sort: '-timestamp', filter: 'status==500' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('json');
    expect(q.get('sort')).toBe('-timestamp');
    expect(q.get('filter')).toBe('status==500');
  });

  it('throws AxiosError on 400 (invalid filter)', async () => {
    server.use(
      http.get('/api/logs/', () =>
        HttpResponse.json({ error: 'INVALID_FILTER' }, { status: 400 }),
      ),
    );

    let caught: unknown;
    try {
      await listLogs();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(400);
    }
  });
});

describe('api/logs — listLogsXlsx', () => {
  it('returns a Blob and forces format=xlsx', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/logs/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return new HttpResponse(new Uint8Array([0x50, 0x4b]), {
          status: 200,
          headers: {
            'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        });
      }),
    );

    const blob = await listLogsXlsx({ sort: 'id' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('xlsx');
    expect(q.get('sort')).toBe('id');
    expect(blob).toBeInstanceOf(Blob);
  });
});

describe('api/logs — deleteLogs', () => {
  it('forwards older_than_days and returns the deletion envelope', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: DeleteLogsResponse = {
      message: 'Logs older than 30 days deleted successfully.',
      deleted_count: 100,
      cutoff_date: '2026-03-26 00:00:00',
    };
    server.use(
      http.delete('/api/logs/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      }),
    );

    const result = await deleteLogs({ older_than_days: 30 });
    expect((observedQuery as unknown as URLSearchParams).get('older_than_days')).toBe('30');
    expect(result.deleted_count).toBe(100);
  });

  it('returns the wipe-all envelope when older_than_days is omitted', async () => {
    server.use(
      http.delete('/api/logs/', () =>
        HttpResponse.json({
          message: 'All logs deleted successfully.',
          deleted_count: 42,
        }),
      ),
    );

    const result = await deleteLogs();
    expect(result.deleted_count).toBe(42);
  });
});
