// app/src/api/review.spec.ts
//
// Vitest + MSW spec for the typed review helpers (W3.18).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  listReviews,
  createReview,
  updateReview,
  getReviewById,
  getReviewPhenotypes,
  getReviewVariation,
  getReviewPublications,
  approveReview,
  type ReviewListRow,
  type ReviewByIdRow,
  type ReviewMutationResponse,
} from './review';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/review — listReviews', () => {
  it('forwards filter_review_approved param', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: ReviewListRow[] = [];
    server.use(
      http.get('/api/review/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await listReviews({ filter_review_approved: true });
    expect((observedQuery as unknown as URLSearchParams).get('filter_review_approved')).toBe(
      'true'
    );
  });
});

describe('api/review — createReview', () => {
  it('POSTs the review_json body and returns the success envelope', async () => {
    let receivedBody: unknown = null;
    const ok: ReviewMutationResponse = { status: 200, entry: { review_id: 7 } };
    server.use(
      http.post('/api/review/create', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(ok);
      })
    );

    const result = await createReview({
      review_json: { entity_id: 1, synopsis: 'sample' },
    });
    expect((receivedBody as { review_json?: unknown }).review_json).toBeDefined();
    expect(result.entry?.review_id).toBe(7);
  });

  it('throws AxiosError on 403 (not Reviewer)', async () => {
    server.use(
      http.post('/api/review/create', () =>
        HttpResponse.json({ status: 403, message: 'forbidden' }, { status: 403 })
      )
    );

    let caught: unknown;
    try {
      await createReview({ review_json: { entity_id: 1, synopsis: 'x' } });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(403);
    }
  });
});

describe('api/review — updateReview', () => {
  it('PUTs the review_json body', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.put('/api/review/update', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ status: 200 });
      })
    );

    await updateReview({ review_json: { entity_id: 1, synopsis: 'updated' } }, { re_review: true });
    expect((receivedBody as { review_json?: unknown }).review_json).toBeDefined();
  });
});

describe('api/review — getReviewById', () => {
  it('URL-encodes the review_id_requested path param', async () => {
    let observedPath: string | null = null;
    server.use(
      http.get('/api/review/:id', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json([]);
      })
    );

    await getReviewById('7,8');
    expect(observedPath).toBe('/api/review/7%2C8');
  });

  it('returns the review rows on 200', async () => {
    const ok: ReviewByIdRow[] = [
      {
        review_id: 7,
        entity_id: 1,
        synopsis: 'foo',
        is_primary: 1,
        review_date: '2026-01-01',
        review_user_name: 'pw_reviewer',
        review_user_role: 'Reviewer',
        review_approved: 0,
        approving_user_name: null,
        approving_user_role: null,
        comment: null,
      },
    ];
    server.use(http.get('/api/review/:id', () => HttpResponse.json(ok)));

    const result = await getReviewById(7);
    expect(result[0].review_id).toBe(7);
  });
});

describe('api/review — getReviewPhenotypes', () => {
  it('returns the phenotypes array on 200', async () => {
    server.use(
      http.get('/api/review/:id/phenotypes', () =>
        HttpResponse.json([
          {
            review_id: 7,
            entity_id: 1,
            phenotype_id: 'HP:0001249',
            HPO_term: 'ID',
            modifier_id: 1,
          },
        ])
      )
    );
    const rows = await getReviewPhenotypes(7);
    expect(rows[0].phenotype_id).toBe('HP:0001249');
  });
});

describe('api/review — getReviewVariation', () => {
  it('returns the variation array on 200', async () => {
    server.use(
      http.get('/api/review/:id/variation', () =>
        HttpResponse.json([
          {
            review_id: 7,
            entity_id: 1,
            vario_id: 'VariO:0001',
            vario_name: 'missense',
            modifier_id: 1,
          },
        ])
      )
    );
    const rows = await getReviewVariation(7);
    expect(rows[0].vario_id).toBe('VariO:0001');
  });
});

describe('api/review — getReviewPublications', () => {
  it('returns the publications array on 200', async () => {
    server.use(
      http.get('/api/review/:id/publications', () =>
        HttpResponse.json([{ review_id: 7, entity_id: 1, publication_id: 'PMID:12345' }])
      )
    );
    const rows = await getReviewPublications(7);
    expect(rows[0].publication_id).toBe('PMID:12345');
  });
});

describe('api/review — approveReview', () => {
  it('forwards review_ok query param', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.put('/api/review/approve/:id', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ status: 200 });
      })
    );

    await approveReview(7, { review_ok: true });
    expect((observedQuery as unknown as URLSearchParams).get('review_ok')).toBe('true');
  });
});
