import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { fetchCurrentRelease, fetchGeneDetail, fetchGenePredictions } from './nddscore';

describe('nddscore api client', () => {
  afterEach(() => server.resetHandlers());

  it('fetches the current release', async () => {
    server.use(
      http.get('/api/nddscore/release/current', () =>
        HttpResponse.json({ data: [{ release_id: ['ndd_fixture_release'], n_genes: [3] }] })
      )
    );
    const release = await fetchCurrentRelease();
    expect(release.release_id).toBe('ndd_fixture_release');
    expect(release.n_genes).toBe(3);
  });

  it('passes pagination + filter params to the genes endpoint', async () => {
    let seen: URL | null = null;
    server.use(
      http.get('/api/nddscore/genes', ({ request }) => {
        seen = new URL(request.url);
        return HttpResponse.json({ data: [], meta: { total: [42], page: [2], page_size: [10] } });
      })
    );
    const result = await fetchGenePredictions({ page: 2, pageSize: 10, riskTier: 'Low' });
    expect(seen!.searchParams.get('page')).toBe('2');
    expect(seen!.searchParams.get('page_size')).toBe('10');
    expect(seen!.searchParams.get('risk_tier')).toBe('Low');
    expect(result.total).toBe(42);
    expect(result.page).toBe(2);
    expect(result.page_size).toBe(10);
  });

  it('passes typed NDDScore gene table filters to the genes endpoint', async () => {
    let seen: URL | null = null;
    server.use(
      http.get('/api/nddscore/genes', ({ request }) => {
        seen = new URL(request.url);
        return HttpResponse.json({ data: [], meta: { total: [0], page: [1], page_size: [25] } });
      })
    );

    await fetchGenePredictions({
      nddScoreMin: 0.9,
      rankMax: 200,
      percentileMin: 95,
      topInheritanceMode: 'AD',
      hpoTerms: ['HP:0001249', 'HP:0001250'],
    });

    expect(seen!.searchParams.get('ndd_score_min')).toBe('0.9');
    expect(seen!.searchParams.get('rank_max')).toBe('200');
    expect(seen!.searchParams.get('percentile_min')).toBe('95');
    expect(seen!.searchParams.get('top_inheritance_mode')).toBe('AD');
    expect(seen!.searchParams.get('hpo_terms')).toBe('HP:0001249,HP:0001250');
  });

  it('normalizes the gene detail envelope into a renderable gene record', async () => {
    server.use(
      http.get('/api/nddscore/genes/HGNC%3A3230', () =>
        HttpResponse.json({
          meta: { notice: ['read only'] },
          data: {
            gene: [
              {
                hgnc_id: ['HGNC:3230'],
                gene_symbol: ['CELSR3'],
                ndd_score: [0.9751],
                rank: [157],
                risk_tier: ['Very High'],
                confidence_tier: ['High'],
                shap_expression: [0.82],
                shap_network: [-0.13],
              },
            ],
            hpo_predictions: [
              {
                phenotype_id: ['HP:0001249'],
                phenotype_name: ['Intellectual disability'],
                probability: [0.91],
              },
            ],
          },
        })
      )
    );

    const detail = await fetchGeneDetail('HGNC:3230');

    expect(detail.gene_symbol).toBe('CELSR3');
    expect(detail.hgnc_id).toBe('HGNC:3230');
    expect(detail.ndd_score).toBe(0.9751);
    expect(detail.hpo_predictions).toEqual([
      {
        phenotype_id: 'HP:0001249',
        phenotype_name: 'Intellectual disability',
        probability: 0.91,
      },
    ]);
    expect(detail.shap_group_contributions_json).toEqual({
      expression: 0.82,
      network: -0.13,
    });
  });
});
