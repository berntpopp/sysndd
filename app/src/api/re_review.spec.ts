// app/src/api/re_review.spec.ts
//
// Vitest + MSW spec for the typed re_review helpers (W3.17).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  submitReReview,
  unsubmitReReview,
  approveReReview,
  getReReviewTable,
  applyForReReviewBatch,
  assignReReviewBatch,
  unassignReReviewBatch,
  getAssignmentTable,
  listAvailableReReviewEntities,
  createReReviewBatch,
  previewReReviewBatch,
  reassignReReviewBatch,
  archiveReReviewBatch,
  assignReReviewEntities,
  recalculateReReviewBatch,
  type AssignBatchResponse,
  type AssignmentRow,
  type BatchServiceResponse,
} from './re_review';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/re_review — submitReReview', () => {
  it('PUTs the submit_json body', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.put('/api/re_review/submit', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({});
      })
    );

    await submitReReview({ submit_json: { re_review_entity_id: 7, comment: 'ok' } });
    expect((receivedBody as { submit_json?: unknown }).submit_json).toBeDefined();
  });
});

describe('api/re_review — unsubmitReReview', () => {
  it('URL-encodes the re_review_id path param', async () => {
    let observedPath: string | null = null;
    server.use(
      http.put('/api/re_review/unsubmit/:id', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json({});
      })
    );

    await unsubmitReReview(7);
    expect(observedPath).toBe('/api/re_review/unsubmit/7');
  });
});

describe('api/re_review — approveReReview', () => {
  it('forwards status_ok / review_ok flags', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.put('/api/re_review/approve/:id', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ message: 'Re-review approved successfully' });
      })
    );

    await approveReReview(42, { status_ok: true, review_ok: false });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('status_ok')).toBe('true');
    expect(q.get('review_ok')).toBe('false');
  });

  it('throws AxiosError on 404 (record not found)', async () => {
    server.use(
      http.put('/api/re_review/approve/:id', () =>
        HttpResponse.json({ error: 'Re-review record not found' }, { status: 404 })
      )
    );

    let caught: unknown;
    try {
      await approveReReview(999);
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(404);
    }
  });
});

describe('api/re_review — getReReviewTable', () => {
  it('forwards filter + curate params', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/re_review/table', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json([]);
      })
    );

    await getReReviewTable({ filter: 'equals(re_review_approved,0)', curate: true });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('filter')).toBe('equals(re_review_approved,0)');
    expect(q.get('curate')).toBe('true');
  });
});

describe('api/re_review — applyForReReviewBatch', () => {
  it('returns the email transport result on 200', async () => {
    server.use(http.get('/api/re_review/batch/apply', () => HttpResponse.json({ ok: true })));
    const result = await applyForReReviewBatch();
    expect((result as { ok?: boolean }).ok).toBe(true);
  });
});

describe('api/re_review — assignReReviewBatch', () => {
  it('forwards user_id and returns assignment details', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: AssignBatchResponse = {
      message: 'Batch assigned successfully.',
      batch_number: 5,
      entity_count: 20,
    };
    server.use(
      http.put('/api/re_review/batch/assign', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await assignReReviewBatch({ user_id: 7 });
    expect((observedQuery as unknown as URLSearchParams).get('user_id')).toBe('7');
    expect(result.batch_number).toBe(5);
  });

  it('throws AxiosError on 409 (user does not exist)', async () => {
    server.use(
      http.put('/api/re_review/batch/assign', () =>
        HttpResponse.json({ error: 'User account does not exist.' }, { status: 409 })
      )
    );

    await expect(assignReReviewBatch({ user_id: 999 })).rejects.toThrow();
  });
});

describe('api/re_review — unassignReReviewBatch', () => {
  it('forwards re_review_batch query param', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.delete('/api/re_review/batch/unassign', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({});
      })
    );

    await unassignReReviewBatch({ re_review_batch: 5 });
    expect((observedQuery as unknown as URLSearchParams).get('re_review_batch')).toBe('5');
  });
});

describe('api/re_review — getAssignmentTable', () => {
  it('returns the assignment table on 200', async () => {
    const ok: AssignmentRow[] = [
      {
        assignment_id: 1,
        user_id: 7,
        user_name: 'pw_curator',
        re_review_batch: 5,
        re_review_review_saved: 0,
        re_review_status_saved: 0,
        re_review_submitted: 0,
        re_review_approved: 0,
        entity_count: 20,
      },
    ];
    server.use(http.get('/api/re_review/assignment_table', () => HttpResponse.json(ok)));

    const result = await getAssignmentTable();
    expect(result[0].user_name).toBe('pw_curator');
  });
});

describe('api/re_review — listAvailableReReviewEntities', () => {
  it('sends q/page/page_size params and returns available rows', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/re_review/entities/available', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({
          data: [{ entity_id: 11, symbol: 'ARID1B' }],
          meta: { total: 1 },
        });
      })
    );

    const result = await listAvailableReReviewEntities({ q: 'ARI', page: 2, page_size: 50 });

    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('q')).toBe('ARI');
    expect(q.get('page')).toBe('2');
    expect(q.get('page_size')).toBe('50');
    expect(result.data).toEqual([{ entity_id: 11, symbol: 'ARID1B' }]);
    expect(result.meta?.total).toBe(1);
  });
});

describe('api/re_review — createReReviewBatch', () => {
  it('POSTs the criteria body', async () => {
    let receivedBody: unknown = null;
    const ok: BatchServiceResponse = {
      status: 200,
      message: 'OK',
      entry: { batch_id: 5 },
    };
    server.use(
      http.post('/api/re_review/batch/create', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(ok);
      })
    );

    await createReReviewBatch({ batch_size: 10, gene_list: [1, 2, 3] });
    expect((receivedBody as { batch_size?: number }).batch_size).toBe(10);
  });
});

describe('api/re_review — previewReReviewBatch', () => {
  it('POSTs the criteria body', async () => {
    server.use(
      http.post('/api/re_review/batch/preview', () =>
        HttpResponse.json({ status: 200, entry: { entities: [] } })
      )
    );
    const result = await previewReReviewBatch({});
    expect(result.status).toBe(200);
  });
});

describe('api/re_review — reassignReReviewBatch', () => {
  it('forwards both query params', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.put('/api/re_review/batch/reassign', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ status: 200 });
      })
    );

    await reassignReReviewBatch({ re_review_batch: 5, user_id: 7 });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('re_review_batch')).toBe('5');
    expect(q.get('user_id')).toBe('7');
  });
});

describe('api/re_review — archiveReReviewBatch', () => {
  it('forwards re_review_batch query param', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.put('/api/re_review/batch/archive', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ status: 200 });
      })
    );

    await archiveReReviewBatch({ re_review_batch: 5 });
    expect((observedQuery as unknown as URLSearchParams).get('re_review_batch')).toBe('5');
  });
});

describe('api/re_review — assignReReviewEntities', () => {
  it('PUTs the body with entity_ids + user_id', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.put('/api/re_review/entities/assign', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ status: 200 });
      })
    );

    await assignReReviewEntities({ entity_ids: [1, 2], user_id: 7 });
    expect((receivedBody as { user_id?: number }).user_id).toBe(7);
  });

  it('returns the created batch entry', async () => {
    server.use(
      http.put('/api/re_review/entities/assign', async ({ request }) => {
        expect(await request.json()).toEqual({
          entity_ids: [11, 12],
          user_id: 7,
          batch_name: 'Manual ARID batch',
        });
        return HttpResponse.json({
          status: 200,
          entry: { batch_id: 4, entity_count: 2 },
        });
      })
    );

    const result = await assignReReviewEntities({
      entity_ids: [11, 12],
      user_id: 7,
      batch_name: 'Manual ARID batch',
    });

    expect(result.entry?.batch_id).toBe(4);
    expect(result.entry?.entity_count).toBe(2);
  });
});

describe('api/re_review — recalculateReReviewBatch', () => {
  it('PUTs the body with re_review_batch', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.put('/api/re_review/batch/recalculate', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ status: 200 });
      })
    );

    await recalculateReReviewBatch({ re_review_batch: 5, batch_size: 30 });
    expect((receivedBody as { re_review_batch?: number }).re_review_batch).toBe(5);
  });

  it('sends criteria body and returns entry', async () => {
    server.use(
      http.put('/api/re_review/batch/recalculate', async ({ request }) => {
        expect(await request.json()).toEqual({
          re_review_batch: 9,
          batch_size: 20,
          status_filter: 3,
        });
        return HttpResponse.json({
          status: 200,
          entry: { batch_id: 9, entity_count: 17 },
        });
      })
    );

    const result = await recalculateReReviewBatch({
      re_review_batch: 9,
      batch_size: 20,
      status_filter: 3,
    });

    expect(result.entry?.batch_id).toBe(9);
    expect(result.entry?.entity_count).toBe(17);
  });
});
