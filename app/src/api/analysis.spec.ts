// app/src/api/analysis.spec.ts
//
// Vitest + MSW spec for the typed analysis helpers (W3.3).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getFunctionalClustering,
  getPhenotypeClustering,
  getPhenotypeFunctionalCorrelation,
  getNetworkEdges,
  getFunctionalClusterSummary,
  getPhenotypeClusterSummary,
  type FunctionalClusteringResponse,
  type PhenotypeCluster,
  type PhenotypeClusteringResponse,
  type CorrelationResponse,
  type NetworkEdgesResponse,
  type ClusterSummary,
} from './analysis';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/analysis — getFunctionalClustering', () => {
  it('forwards pagination + algorithm params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: FunctionalClusteringResponse = {
      categories: [],
      clusters: [],
      pagination: {
        page_size: 10,
        page_after: '',
        next_cursor: null,
        total_count: 0,
        has_more: false,
      },
      meta: {
        algorithm: 'leiden',
        elapsed_seconds: 0.1,
        gene_count: 0,
        cluster_count: 0,
      },
    };
    server.use(
      http.get('/api/analysis/functional_clustering', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await getFunctionalClustering({
      page_size: '25',
      algorithm: 'walktrap',
      page_after: 'abc',
    });

    expect(observedQuery).not.toBeNull();
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('page_size')).toBe('25');
    expect(q.get('algorithm')).toBe('walktrap');
    expect(q.get('page_after')).toBe('abc');
  });

  it('returns the cursor-paginated envelope on 200', async () => {
    server.use(
      http.get('/api/analysis/functional_clustering', () =>
        HttpResponse.json<FunctionalClusteringResponse>({
          categories: [{ value: 'KEGG', text: 'KEGG' }],
          clusters: [],
          pagination: {
            page_size: 10,
            page_after: '',
            next_cursor: null,
            total_count: 0,
            has_more: false,
          },
          meta: {
            algorithm: 'leiden',
            elapsed_seconds: 0.05,
            gene_count: 0,
            cluster_count: 0,
          },
        })
      )
    );
    const result = await getFunctionalClustering();
    expect(result.meta.algorithm).toBe('leiden');
  });
});

describe('api/analysis — getPhenotypeClustering', () => {
  it('returns the cluster envelope on 200', async () => {
    const clusters: PhenotypeCluster[] = [
      { cluster: 1, identifiers: [{ entity_id: 1, hgnc_id: 'HGNC:1', symbol: 'A1BG' }] },
    ];
    const response: PhenotypeClusteringResponse = {
      clusters,
      meta: {
        snapshot: {
          analysis_type: 'phenotype_clusters',
        },
      },
    };
    server.use(http.get('/api/analysis/phenotype_clustering', () => HttpResponse.json(response)));
    const result = await getPhenotypeClustering();
    expect(result.clusters).toHaveLength(1);
    expect(result.clusters[0].identifiers[0].symbol).toBe('A1BG');
    expect(result.meta.snapshot?.analysis_type).toBe('phenotype_clusters');
  });
});

describe('api/analysis — getPhenotypeFunctionalCorrelation', () => {
  it('returns the correlation envelope on 200', async () => {
    const ok: CorrelationResponse = {
      correlation_matrix: [
        [1.0, 0.2],
        [0.2, 1.0],
      ],
      correlation_melted: [{ x: 'pc_1', y: 'fc_1', value: 0.2 }],
    };
    server.use(
      http.get('/api/analysis/phenotype_functional_cluster_correlation', () =>
        HttpResponse.json(ok)
      )
    );
    const result = await getPhenotypeFunctionalCorrelation();
    expect(result.correlation_melted).toHaveLength(1);
  });
});

describe('api/analysis — getNetworkEdges', () => {
  it('forwards network params and returns display layout coordinates', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: NetworkEdgesResponse = {
      nodes: [{ hgnc_id: 'HGNC:1', symbol: 'AAA', cluster: 1, degree: 4, x: 10, y: 20 }],
      edges: [],
      metadata: {
        node_count: 1,
        edge_count: 0,
        cluster_count: 1,
        total_edges: 0,
        edges_filtered: false,
        elapsed_seconds: 0,
        display_layout_status: 'available',
        snapshot: {
          analysis_type: 'gene_network_edges',
        },
      },
    };
    server.use(
      http.get('/api/analysis/network_edges', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await getNetworkEdges({
      cluster_type: 'subclusters',
      min_confidence: '700',
      max_edges: '3000',
    });
    expect(observedQuery).not.toBeNull();
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('cluster_type')).toBe('subclusters');
    expect(q.get('min_confidence')).toBe('700');
    expect(q.get('max_edges')).toBe('3000');
    expect(result.nodes[0].x).toBe(10);
    expect(result.nodes[0].y).toBe(20);
    expect(result.metadata.snapshot?.analysis_type).toBe('gene_network_edges');
  });
});

describe('api/analysis — getFunctionalClusterSummary', () => {
  it('forwards cluster_hash + cluster_number params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: ClusterSummary = {
      cluster_hash: 'abc',
      cluster_number: 1,
      summary_json: { summary: 'A short summary.' },
    };
    server.use(
      http.get('/api/analysis/functional_cluster_summary', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await getFunctionalClusterSummary({ cluster_hash: 'abc', cluster_number: '1' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q?.get('cluster_hash')).toBe('abc');
    expect(q?.get('cluster_number')).toBe('1');
  });

  it('throws AxiosError on 503 (LLM not configured)', async () => {
    server.use(
      http.get('/api/analysis/functional_cluster_summary', () =>
        HttpResponse.json({ error: 'LLM not configured' }, { status: 503 })
      )
    );

    let caught: unknown;
    try {
      await getFunctionalClusterSummary({ cluster_hash: 'x', cluster_number: '1' });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(503);
    }
  });
});

describe('api/analysis — getPhenotypeClusterSummary', () => {
  it('returns the summary on 200', async () => {
    const ok: ClusterSummary = {
      cluster_hash: 'def',
      cluster_number: 2,
      summary_json: { themes: ['ID', 'epilepsy'] },
    };
    server.use(http.get('/api/analysis/phenotype_cluster_summary', () => HttpResponse.json(ok)));
    const result = await getPhenotypeClusterSummary({ cluster_hash: 'def', cluster_number: '2' });
    expect(result.cluster_hash).toBe('def');
  });
});
