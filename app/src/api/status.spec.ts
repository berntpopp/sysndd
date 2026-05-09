// app/src/api/status.spec.ts
//
// Vitest + MSW spec for the typed status helpers (W3.21).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  listStatus,
  getStatusById,
  listStatusCategories,
  createStatus,
  updateStatus,
  approveStatus,
  type StatusListRow,
  type StatusByIdRow,
  type StatusCategoriesResponse,
  type StatusMutationResponse,
} from './status';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/status — listStatus', () => {
  it('forwards filter_status_approved param', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: StatusListRow[] = [];
    server.use(
      http.get('/api/status/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await listStatus({ filter_status_approved: true });
    expect((observedQuery as unknown as URLSearchParams).get('filter_status_approved')).toBe(
      'true'
    );
  });
});

describe('api/status — getStatusById', () => {
  it('URL-encodes the status_id_requested path param', async () => {
    let observedPath: string | null = null;
    server.use(
      http.get('/api/status/:id', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json([]);
      })
    );

    await getStatusById('1,2');
    expect(observedPath).toBe('/api/status/1%2C2');
  });

  it('returns the status rows on 200', async () => {
    const ok: StatusByIdRow[] = [
      {
        status_id: 1,
        entity_id: 7,
        category: 'Definitive',
        category_id: 5,
        is_active: 1,
        status_date: '2026-01-01',
        status_user_name: 'pw_curator',
        status_user_role: 'Curator',
        status_approved: 0,
        approving_user_name: null,
        approving_user_role: null,
        comment: null,
        problematic: 0,
      },
    ];
    server.use(http.get('/api/status/:id', () => HttpResponse.json(ok)));

    const result = await getStatusById(1);
    expect(result[0].status_id).toBe(1);
  });
});

describe('api/status — listStatusCategories', () => {
  it('returns the paginated categories envelope', async () => {
    const ok: StatusCategoriesResponse = {
      links: {},
      meta: {},
      data: [{ category_id: 5, category: 'Definitive' }],
    };
    server.use(http.get('/api/status/_list', () => HttpResponse.json(ok)));

    const result = await listStatusCategories();
    expect(result.data[0].category).toBe('Definitive');
  });
});

describe('api/status — createStatus / updateStatus', () => {
  it('POSTs the status_json body for create', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.post('/api/status/create', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ status: 200, entry: { status_id: 1 } });
      })
    );

    await createStatus({ status_json: { entity_id: 7, category_id: 5 } });
    expect((receivedBody as { status_json?: unknown }).status_json).toBeDefined();
  });

  it('PUTs the status_json body for update', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.put('/api/status/update', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ status: 200 });
      })
    );

    await updateStatus({ status_json: { entity_id: 7, category_id: 5 } });
    expect((receivedBody as { status_json?: unknown }).status_json).toBeDefined();
  });

  it('throws AxiosError on 403', async () => {
    server.use(
      http.post('/api/status/create', () =>
        HttpResponse.json({ status: 403, message: 'forbidden' }, { status: 403 })
      )
    );

    let caught: unknown;
    try {
      await createStatus({ status_json: { entity_id: 7, category_id: 5 } });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(403);
    }
  });
});

describe('api/status — approveStatus', () => {
  it('forwards status_ok param', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: StatusMutationResponse = { status: 200 };
    server.use(
      http.put('/api/status/approve/:id', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await approveStatus(1, { status_ok: true });
    expect((observedQuery as unknown as URLSearchParams).get('status_ok')).toBe('true');
  });
});
