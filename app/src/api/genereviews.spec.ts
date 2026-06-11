// app/src/api/genereviews.spec.ts
//
// Vitest + MSW spec for the typed GeneReviews helpers (issues #14, #46).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getGeneReviewAvailability,
  getGeneReviewsCoverage,
  exportGeneReviewsCoverageCsv,
  attachGeneReview,
  type GeneReviewAvailability,
  type GeneReviewCoverageResponse,
} from './genereviews';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/genereviews — getGeneReviewAvailability', () => {
  it('URL-encodes the symbol and returns the availability payload', async () => {
    let observedPath: string | null = null;
    const ok: GeneReviewAvailability = {
      source: 'genereviews',
      gene_symbol: 'GRIN2B',
      has_genereview: true,
      nbk_id: 'NBK1116',
      url: 'https://www.ncbi.nlm.nih.gov/books/NBK1116/',
      title: 'GRIN2B chapter',
      chapter_count: 1,
    };
    server.use(
      http.get('/api/genereviews/availability/:symbol', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json(ok);
      })
    );

    const result = await getGeneReviewAvailability('GRIN2B');
    expect(observedPath).toBe('/api/genereviews/availability/GRIN2B');
    expect(result.has_genereview).toBe(true);
    expect(result.nbk_id).toBe('NBK1116');
  });
});

describe('api/genereviews — getGeneReviewsCoverage', () => {
  it('forwards include_live and returns the coverage envelope', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: GeneReviewCoverageResponse = {
      meta: { include_live: true, total: 1, already_linked: 0, needs_attention: 1 },
      data: [
        {
          entity_id: 1,
          hgnc_id: 'HGNC:1',
          symbol: 'GRIN2B',
          disease_ontology_name: 'Disease A',
          already_linked: false,
          linked_pmid: null,
          linked_nbk_id: null,
          genereview_available: true,
          available_nbk_id: 'NBK1116',
          available_url: 'https://www.ncbi.nlm.nih.gov/books/NBK1116/',
          available_title: 'GRIN2B chapter',
          lookup_error: false,
          needs_attention: true,
        },
      ],
    };
    server.use(
      http.get('/api/genereviews/coverage', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await getGeneReviewsCoverage({ include_live: true });
    expect((observedQuery as unknown as URLSearchParams).get('include_live')).toBe('true');
    expect(result.data[0].needs_attention).toBe(true);
    expect(result.meta.needs_attention).toBe(1);
  });
});

describe('api/genereviews — exportGeneReviewsCoverageCsv', () => {
  it('requests a blob and returns CSV content', async () => {
    server.use(
      http.get('/api/genereviews/coverage/export', () =>
        HttpResponse.text('symbol,already_linked\nGRIN2B,false\n', {
          headers: { 'Content-Type': 'text/csv' },
        })
      )
    );

    const blob = await exportGeneReviewsCoverageCsv({ include_live: false });
    const text = await blob.text();
    expect(text).toContain('symbol');
    expect(text).toContain('GRIN2B');
  });
});

describe('api/genereviews — attachGeneReview', () => {
  it('POSTs the entity_id + pmid body and returns the success envelope', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.post('/api/genereviews/attach', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({
          status: 200,
          message: 'OK. GeneReviews reference attached to entity.',
          entity_id: 1,
          review_id: 5,
          publication_id: 'PMID:20301494',
        });
      })
    );

    const result = await attachGeneReview({ entity_id: 1, pmid: '20301494' });
    expect((receivedBody as { entity_id?: number }).entity_id).toBe(1);
    expect((receivedBody as { pmid?: string }).pmid).toBe('20301494');
    expect(result.publication_id).toBe('PMID:20301494');
  });

  it('throws AxiosError on 400 (not a GeneReviews chapter)', async () => {
    server.use(
      http.post('/api/genereviews/attach', () =>
        HttpResponse.json(
          { title: 'PMID does not correspond to a GeneReviews chapter.' },
          { status: 400 }
        )
      )
    );

    let caught: unknown;
    try {
      await attachGeneReview({ entity_id: 1, pmid: '999' });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(400);
    }
  });
});
