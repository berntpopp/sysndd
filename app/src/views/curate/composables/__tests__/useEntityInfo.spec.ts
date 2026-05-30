import { describe, expect, test } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { useEntityInfo } from '../useEntityInfo';

// Lifecycle (listen / resetHandlers / close) is provided globally by
// vitest.setup.ts. This file only adds per-test handler overrides via
// `server.use(...)`.

describe('useEntityInfo', () => {
  test('loadEntity populates entity_info from listEntities response', async () => {
    server.use(
      http.get('*/api/entity/*', () =>
        HttpResponse.json({
          data: [{ entity_id: 7, symbol: 'GRIN2B', disease_ontology_name: 'NDD' }],
        })
      )
    );
    const e = useEntityInfo();
    await e.loadEntity(7);
    expect(e.entity_info.value.entity_id).toBe(7);
    expect(e.entity_info.value.symbol).toBe('GRIN2B');
  });

  test('loadEntity requests fields required by entity mutation endpoints', async () => {
    let requestedFields: string | null = null;
    server.use(
      http.get('*/api/entity/*', ({ request }) => {
        requestedFields = new URL(request.url).searchParams.get('fields');
        return HttpResponse.json({
          data: [
            {
              entity_id: 3367,
              symbol: 'FGF13',
              hgnc_id: 'HGNC:3670',
              hpo_mode_of_inheritance_term: 'HP:0001417',
              hpo_mode_of_inheritance_term_name: 'X-linked inheritance',
              disease_ontology_id_version: 'OMIM:300070',
              disease_ontology_name: 'developmental and epileptic encephalopathy',
              ndd_phenotype: 1,
              is_active: 1,
              replaced_by: null,
            },
          ],
        });
      })
    );

    const e = useEntityInfo();
    await e.loadEntity(3367);

    expect(requestedFields).toContain('hgnc_id');
    expect(requestedFields).toContain('hpo_mode_of_inheritance_term');
    expect(requestedFields).toContain('disease_ontology_id_version');
    expect(requestedFields).toContain('ndd_phenotype');
    expect(requestedFields).toContain('is_active');
    expect(requestedFields).toContain('replaced_by');
    expect(e.entity_info.value.hgnc_id).toBe('HGNC:3670');
  });

  test('loadEntity surfaces a not-found toast and clears entity_info', async () => {
    server.use(http.get('*/api/entity/*', () => HttpResponse.json({ data: [] })));
    const toasts: any[] = [];
    const e = useEntityInfo({ onToast: (...a) => toasts.push(a) });
    await e.loadEntity(99);
    expect(e.entity_info.value).toEqual({});
    expect(toasts.length).toBe(1);
  });

  test('loadReview snapshots reviewLoadedData for change detection', async () => {
    server.use(
      http.get('*/api/entity/7/review', () =>
        HttpResponse.json([{ synopsis: 'syn', comment: 'cm', review_id: 1, entity_id: 7 }])
      ),
      http.get('*/api/entity/7/phenotypes', () =>
        HttpResponse.json([{ phenotype_id: 'HP:1', modifier_id: 'present' }])
      ),
      http.get('*/api/entity/7/variation', () =>
        HttpResponse.json([{ vario_id: 'VARIO:1', modifier_id: 'present' }])
      ),
      http.get('*/api/entity/7/publications', () =>
        HttpResponse.json([
          { publication_id: 'PMID:1', publication_type: 'gene_review' },
          { publication_id: 'PMID:2', publication_type: 'additional_references' },
        ])
      )
    );
    const e = useEntityInfo();
    await e.loadReview(7);
    expect(e.reviewLoadedData.value).not.toBeNull();
    expect(e.select_phenotype.value).toEqual(['present-HP:1']);
    expect(e.select_gene_reviews.value).toEqual(['PMID:1']);
    expect(e.hasReviewChanges.value).toBe(false);
  });

  test('hasReviewChanges flips when a watched field diverges', async () => {
    server.use(
      http.get('*/api/entity/7/review', () =>
        HttpResponse.json([{ synopsis: 'a', comment: 'b', review_id: 1, entity_id: 7 }])
      ),
      http.get('*/api/entity/7/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/7/variation', () => HttpResponse.json([])),
      http.get('*/api/entity/7/publications', () => HttpResponse.json([]))
    );
    const e = useEntityInfo();
    await e.loadReview(7);
    expect(e.hasReviewChanges.value).toBe(false);
    e.review_info.value.synopsis = 'CHANGED';
    expect(e.hasReviewChanges.value).toBe(true);
  });

  test('loadStatus populates status_info', async () => {
    server.use(
      http.get('*/api/entity/7/status', () =>
        HttpResponse.json([
          { category_id: 'definitive', comment: 'c', problematic: 0, status_id: 1, entity_id: 7 },
        ])
      )
    );
    const e = useEntityInfo();
    await e.loadStatus(7);
    expect(e.status_info.value.category_id).toBe('definitive');
  });
});
