import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { isApiError } from './client';
import { extractApiErrorMessage } from '@/utils/api-errors';
import {
  buildRelease,
  deleteDraftRelease,
  fetchSnapshotStatus,
  getAdminRelease,
  listAdminReleases,
  publishRelease,
  recordReleaseDoi,
  RELEASE_LAYER_TYPES,
  type AdminReleaseHead,
} from './admin_analysis_release';

function makeHead(overrides: Partial<AdminReleaseHead> = {}): AdminReleaseHead {
  return {
    release_id: 'asr_abc1234567890def',
    release_version: null,
    title: 'Analysis snapshot release',
    status: 'published',
    manifest_schema_version: '1.0',
    content_digest: 'a'.repeat(64),
    source_data_version: '2026-07-19',
    db_release_version: null,
    db_release_commit: null,
    manifest_sha256: 'b'.repeat(64),
    bundle_sha256: 'c'.repeat(64),
    license: 'CC-BY-4.0',
    file_count: 10,
    total_bytes: 1024,
    created_by_user_id: 1,
    created_at: '2026-07-19T00:00:00Z',
    published_at: '2026-07-19T00:00:00Z',
    updated_at: '2026-07-19T00:00:00Z',
    zenodo_record_id: null,
    zenodo_record_url: null,
    version_doi: null,
    concept_doi: null,
    last_error_message: null,
    ...overrides,
  };
}

describe('admin_analysis_release api client', () => {
  afterEach(() => server.resetHandlers());

  describe('buildRelease', () => {
    it('returns outcome:"created" on a 201 head', async () => {
      primeAuth();
      const head = makeHead({ status: 'published' });
      server.use(
        http.post('/api/admin/analysis/releases', () => HttpResponse.json(head, { status: 201 }))
      );

      const result = await buildRelease({});
      expect(result).toEqual({ outcome: 'created', release: head });
    });

    it('returns outcome:"exists" on a 200 head (content-identical idempotent dup)', async () => {
      primeAuth();
      const head = makeHead();
      server.use(
        http.post('/api/admin/analysis/releases', () => HttpResponse.json(head, { status: 200 }))
      );

      const result = await buildRelease({});
      expect(result).toEqual({ outcome: 'exists', release: head });
    });

    it('returns outcome:"locked" with retryAfter from the Retry-After header on a 503', async () => {
      primeAuth();
      server.use(
        http.post('/api/admin/analysis/releases', () =>
          HttpResponse.json(
            { error: 'release_lock_unavailable', message: 'sources are mid-refresh' },
            { status: 503, headers: { 'Retry-After': '5' } }
          )
        )
      );

      const result = await buildRelease({});
      expect(result).toEqual({
        outcome: 'locked',
        retryAfter: 5,
        message: 'sources are mid-refresh',
      });
    });

    it('rejects with an ApiError on a 400 gate failure, extractable via extractApiErrorMessage', async () => {
      primeAuth();
      // Faithful RFC 9457 problem+json shape, as actually emitted by the
      // real backend errorHandler (`make_problem_response()`,
      // api/core/filters.R) — the reason lives under `detail`, never a
      // top-level `message`.
      server.use(
        http.post('/api/admin/analysis/releases', () =>
          HttpResponse.json(
            {
              type: 'https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400',
              title: 'Bad Request',
              status: 400,
              detail: 'functional_clusters snapshot is not available',
            },
            { status: 400 }
          )
        )
      );

      await expect(buildRelease({})).rejects.toSatisfy((err: unknown) => {
        expect(isApiError(err)).toBe(true);
        expect(extractApiErrorMessage(err, 'fallback')).toBe(
          'functional_clusters snapshot is not available'
        );
        return true;
      });
    });

    it('sends the genuine nested JSON body (layers/title/scope_statement/license/publish)', async () => {
      primeAuth();
      let payload: unknown;
      server.use(
        http.post('/api/admin/analysis/releases', async ({ request }) => {
          payload = await request.json();
          return HttpResponse.json(makeHead(), { status: 201 });
        })
      );

      await buildRelease({
        layers: [{ analysis_type: 'functional_clusters' }],
        title: 'My release',
        scope_statement: 'scope',
        license: 'CC0-1.0',
        publish: false,
      });

      expect(payload).toEqual({
        layers: [{ analysis_type: 'functional_clusters' }],
        title: 'My release',
        scope_statement: 'scope',
        license: 'CC0-1.0',
        publish: false,
      });
    });
  });

  it('listAdminReleases returns {releases, pagination}', async () => {
    primeAuth();
    const head = makeHead();
    server.use(
      http.get('/api/admin/analysis/releases', () =>
        HttpResponse.json({ releases: [head], pagination: { limit: 50, offset: 0, count: 1 } })
      )
    );

    const result = await listAdminReleases();
    expect(result.releases).toEqual([head]);
    expect(result.pagination).toEqual({ limit: 50, offset: 0, count: 1 });
  });

  it('getAdminRelease returns the bare head', async () => {
    primeAuth();
    const head = makeHead({ status: 'draft' });
    server.use(
      http.get('/api/admin/analysis/releases/asr_abc1234567890def', () => HttpResponse.json(head))
    );

    const result = await getAdminRelease('asr_abc1234567890def');
    expect(result).toEqual(head);
  });

  it('publishRelease posts to /publish and returns the published head', async () => {
    primeAuth();
    const head = makeHead({ status: 'published' });
    server.use(
      http.post('/api/admin/analysis/releases/asr_abc1234567890def/publish', () =>
        HttpResponse.json(head)
      )
    );

    const result = await publishRelease('asr_abc1234567890def');
    expect(result).toEqual(head);
  });

  describe('recordReleaseDoi', () => {
    it('sends ONLY the supplied fields as query params', async () => {
      primeAuth();
      let requestUrl: URL | undefined;
      const head = makeHead({ version_doi: '10.5281/zenodo.123' });
      server.use(
        http.patch('/api/admin/analysis/releases/asr_abc1234567890def/doi', ({ request }) => {
          requestUrl = new URL(request.url);
          return HttpResponse.json(head);
        })
      );

      const result = await recordReleaseDoi('asr_abc1234567890def', {
        version_doi: '10.5281/zenodo.123',
      });

      expect(result).toEqual(head);
      expect(requestUrl?.searchParams.get('version_doi')).toBe('10.5281/zenodo.123');
      expect(requestUrl?.searchParams.has('zenodo_record_id')).toBe(false);
      expect(requestUrl?.searchParams.has('zenodo_record_url')).toBe(false);
      expect(requestUrl?.searchParams.has('concept_doi')).toBe(false);
    });
  });

  it('deleteDraftRelease issues a DELETE to the right URL', async () => {
    primeAuth();
    let called = false;
    server.use(
      http.delete('/api/admin/analysis/releases/asr_abc1234567890def', () => {
        called = true;
        return HttpResponse.json({ deleted: true });
      })
    );

    await deleteDraftRelease('asr_abc1234567890def');
    expect(called).toBe(true);
  });

  it('fetchSnapshotStatus returns {presets, summary}', async () => {
    primeAuth();
    server.use(
      http.get('/api/admin/analysis/snapshots/status', () =>
        HttpResponse.json({
          presets: [
            {
              analysis_type: 'functional_clusters',
              parameter_hash: 'ph1',
              state: 'available',
              generated_at: '2026-07-19T00:00:00Z',
              activated_at: '2026-07-19T00:00:00Z',
              stale_after: '2026-07-26T00:00:00Z',
              source_data_version: '2026-07-19',
              row_counts: { clusters: 5 },
            },
          ],
          summary: { total: 5, available: 3, missing: 1, stale: 1, mismatch: 0 },
        })
      )
    );

    const result = await fetchSnapshotStatus();
    expect(result.presets).toHaveLength(1);
    expect(result.presets[0].analysis_type).toBe('functional_clusters');
    expect(result.summary).toEqual({ total: 5, available: 3, missing: 1, stale: 1, mismatch: 0 });
  });

  it('exposes RELEASE_LAYER_TYPES as the single source of truth for release layers', () => {
    expect(RELEASE_LAYER_TYPES).toEqual([
      'functional_clusters',
      'phenotype_clusters',
      'phenotype_functional_correlations',
    ]);
  });
});
