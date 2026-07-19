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
  isSnapshotPreparingError,
  listReleases,
  getLatestRelease,
  getRelease,
  downloadReleaseManifest,
  downloadReleaseFile,
  downloadReleaseBundle,
  type FunctionalClusteringResponse,
  type PhenotypeCluster,
  type PhenotypeClusteringResponse,
  type CorrelationResponse,
  type NetworkEdgesResponse,
  type ClusterSummary,
  type ReleaseHead,
  type ReleaseDetail,
} from './analysis';
import { isApiError } from './client';
import { extractApiErrorMessage } from '@/utils/api-errors';
import { server } from '@/test-utils/mocks/server';

describe('api/analysis — getFunctionalClustering', () => {
  it('forwards pagination params for the public Leiden preset', async () => {
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
      page_after: 'abc',
    });

    expect(observedQuery).not.toBeNull();
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('page_size')).toBe('25');
    expect(q.has('algorithm')).toBe(false);
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
      cluster_type: 'clusters',
      min_confidence: '400',
      max_edges: '10000',
    });
    expect(observedQuery).not.toBeNull();
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('cluster_type')).toBe('clusters');
    expect(q.get('min_confidence')).toBe('400');
    expect(q.get('max_edges')).toBe('10000');
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

describe('isSnapshotPreparingError', () => {
  it('is true for a 503 snapshot_missing problem', () => {
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'snapshot_missing' } } })).toBe(true);
  });
  it('is true when code is a 1-element array (R/Plumber scalar serialisation) (#440)', () => {
    // The real API serialises the problem code as ["snapshot_missing"], not a
    // bare string — the "being prepared" state must still trigger.
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: ['snapshot_missing'] } } })).toBe(true);
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: ['snapshot_stale'] } } })).toBe(true);
  });
  it('is true for snapshot_stale and source_version_mismatch', () => {
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'snapshot_stale' } } })).toBe(true);
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'source_version_mismatch' } } })).toBe(true);
  });
  it('is false for a non-503 error', () => {
    expect(isSnapshotPreparingError({ response: { status: 500, data: { code: 'snapshot_missing' } } })).toBe(false);
  });
  it('is false for a 503 with an unrelated code', () => {
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'CAPACITY_EXCEEDED' } } })).toBe(false);
  });
  it('is false for a plain error', () => {
    expect(isSnapshotPreparingError(new Error('boom'))).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Analysis-snapshot releases (#573 Slice B, Task B1)
// ---------------------------------------------------------------------------

function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
  return {
    release_id: 'asr_0123456789abcdef',
    release_version: null,
    title: 'SysNDD analysis-snapshot release',
    status: 'published',
    content_digest: 'a'.repeat(64),
    created_at: '2026-07-01T00:00:00Z',
    published_at: '2026-07-01T00:05:00Z',
    source_data_version: '2026-07-01',
    db_release_version: '11.4.0',
    db_release_commit: 'deadbeef',
    manifest_sha256: 'b'.repeat(64),
    bundle_sha256: 'c'.repeat(64),
    license: 'CC-BY-4.0',
    file_count: 10,
    total_bytes: 123456,
    zenodo: { record_url: null, version_doi: null, concept_doi: null },
    ...overrides,
  };
}

describe('api/analysis — listReleases', () => {
  it('returns the releases envelope on 200', async () => {
    server.use(
      http.get('/api/analysis/releases', () =>
        HttpResponse.json({
          releases: [makeReleaseHead()],
          pagination: { limit: 50, offset: 0, count: 1 },
        })
      )
    );
    const result = await listReleases();
    expect(result.releases).toHaveLength(1);
    expect(result.releases[0].release_id).toBe('asr_0123456789abcdef');
    expect(result.pagination.count).toBe(1);
    // Public head allowlist: admin-only fields must never be present.
    expect(result.releases[0]).not.toHaveProperty('created_by_user_id');
    expect(result.releases[0]).not.toHaveProperty('last_error_message');
  });

  it('forwards limit/offset query params', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/analysis/releases', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({
          releases: [],
          pagination: { limit: 10, offset: 5, count: 0 },
        });
      })
    );
    await listReleases({ limit: 10, offset: 5 });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('limit')).toBe('10');
    expect(q.get('offset')).toBe('5');
  });

  it('throws AxiosError on non-2xx', async () => {
    server.use(
      http.get('/api/analysis/releases', () =>
        HttpResponse.json({ message: 'boom' }, { status: 500 })
      )
    );
    let caught: unknown;
    try {
      await listReleases();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    expect(extractApiErrorMessage(caught, 'fallback')).toBe('boom');
  });
});

describe('api/analysis — getLatestRelease', () => {
  it('returns the head + manifest on 200', async () => {
    const detail: ReleaseDetail = {
      ...makeReleaseHead(),
      manifest: {
        release_id: 'asr_0123456789abcdef',
        release_version: null,
        title: 'SysNDD analysis-snapshot release',
        created_at: '2026-07-01T00:00:00Z',
        license: 'CC-BY-4.0',
        scope_statement: 'Public derived analysis only.',
        generator: 'sysndd-api',
        source: 'sysndd',
        layers: [],
        files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
        content_digest: 'a'.repeat(64),
      },
    };
    server.use(http.get('/api/analysis/releases/latest', () => HttpResponse.json(detail)));
    const result = await getLatestRelease();
    expect(result.release_id).toBe('asr_0123456789abcdef');
    expect(result.manifest.files).toHaveLength(1);
  });

  it('throws AxiosError 404 when no published release exists', async () => {
    server.use(
      http.get('/api/analysis/releases/latest', () =>
        HttpResponse.json({ message: 'No published analysis-snapshot release exists yet' }, { status: 404 })
      )
    );
    let caught: unknown;
    try {
      await getLatestRelease();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(404);
    }
  });
});

describe('api/analysis — getRelease', () => {
  it('returns the head + manifest on 200 and encodes the release id', async () => {
    let observedPath = '';
    const detail: ReleaseDetail = {
      ...makeReleaseHead({ release_id: 'asr_abc123' }),
      manifest: {
        release_id: 'asr_abc123',
        release_version: null,
        title: 'SysNDD analysis-snapshot release',
        created_at: '2026-07-01T00:00:00Z',
        license: 'CC-BY-4.0',
        scope_statement: 'Public derived analysis only.',
        generator: 'sysndd-api',
        source: 'sysndd',
        layers: [],
        files: [],
        content_digest: 'a'.repeat(64),
      },
    };
    server.use(
      http.get('/api/analysis/releases/:releaseId', ({ request, params }) => {
        observedPath = new URL(request.url).pathname;
        expect(params.releaseId).toBe('asr_abc123');
        return HttpResponse.json(detail);
      })
    );
    const result = await getRelease('asr_abc123');
    expect(result.release_id).toBe('asr_abc123');
    expect(observedPath).toBe('/api/analysis/releases/asr_abc123');
  });

  it('throws AxiosError 404 for an unknown/draft release id', async () => {
    server.use(
      http.get('/api/analysis/releases/:releaseId', () =>
        HttpResponse.json({ message: 'not found' }, { status: 404 })
      )
    );
    let caught: unknown;
    try {
      await getRelease('asr_unknown');
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(404);
    }
  });
});

describe('api/analysis — downloadReleaseManifest', () => {
  it('returns the manifest.json bytes as a Blob', async () => {
    server.use(
      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
        HttpResponse.json({ release_id: 'asr_abc123' })
      )
    );
    const blob = await downloadReleaseManifest('asr_abc123');
    expect(blob).toBeInstanceOf(Blob);
  });

  it('throws AxiosError on non-2xx', async () => {
    server.use(
      http.get('/api/analysis/releases/:releaseId/manifest.json', () =>
        HttpResponse.json({ message: 'not found' }, { status: 404 })
      )
    );
    let caught: unknown;
    try {
      await downloadReleaseManifest('asr_unknown');
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
  });
});

describe('api/analysis — downloadReleaseFile', () => {
  it('forwards the file path as a query param and returns a Blob', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/analysis/releases/:releaseId/file', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ ok: true });
      })
    );
    const blob = await downloadReleaseFile('asr_abc123', 'functional_clusters/payload.json');
    expect(blob).toBeInstanceOf(Blob);
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('path')).toBe('functional_clusters/payload.json');
  });

  it('throws AxiosError on non-2xx (unknown file path)', async () => {
    server.use(
      http.get('/api/analysis/releases/:releaseId/file', () =>
        HttpResponse.json({ message: 'not found' }, { status: 404 })
      )
    );
    let caught: unknown;
    try {
      await downloadReleaseFile('asr_abc123', 'nope.json');
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(404);
    }
  });
});

describe('api/analysis — downloadReleaseBundle', () => {
  it('returns the bundle.tar.gz bytes as a Blob', async () => {
    server.use(
      http.get('/api/analysis/releases/:releaseId/bundle', () =>
        HttpResponse.json({ ok: true })
      )
    );
    const blob = await downloadReleaseBundle('asr_abc123');
    expect(blob).toBeInstanceOf(Blob);
  });

  it('throws AxiosError on non-2xx', async () => {
    server.use(
      http.get('/api/analysis/releases/:releaseId/bundle', () =>
        HttpResponse.json({ message: 'not found' }, { status: 404 })
      )
    );
    let caught: unknown;
    try {
      await downloadReleaseBundle('asr_unknown');
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
  });
});
