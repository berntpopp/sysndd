// useBatchForm.spec.ts
/**
 * v11.0 closeout F2b — spec for `composables/useBatchForm.ts`.
 *
 * Pre-F2b, every authed call in this composable built its own
 * `Authorization: Bearer ${localStorage.getItem('token')}` header (8 raw
 * reads). The migration routes each request through `apiClient.raw.*`;
 * the shared request interceptor injects the Bearer from
 * `useAuth().token.value`. This spec pins:
 *
 *   - `searchEntities()`   GET /api/entity/
 *   - `loadOptions()`      GET /api/user/list + /api/list/status + /api/gene/
 *   - `handlePreview()`    POST /api/re_review/batch/preview
 *   - `handleSubmit()`     POST /api/re_review/batch/create
 *
 * All requests must carry `Authorization: Bearer <token>` when a session
 * is present.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';
import useBatchForm from './useBatchForm';

const makeToastSpy = vi.fn();
vi.mock('./useToast', () => ({
  default: () => ({ makeToast: makeToastSpy }),
}));

beforeEach(() => {
  makeToastSpy.mockClear();
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  useAuth().logout();
  vi.unstubAllEnvs();
});

describe('useBatchForm — v11.0 closeout F2b apiClient migration', () => {
  it('searchEntities issues GET /api/entity/ with the Bearer header', async () => {
    primeAuth('search-token');

    server.use(
      http.get('/api/entity/', ({ request }) => {
        expectBearerHeader(request, 'search-token');
        return HttpResponse.json({ data: [] });
      })
    );

    const form = useBatchForm();
    await form.searchEntities('BRCA');
    expect(form.entitySearchResults.value).toEqual([]);
  });

  it('loadOptions issues GET /api/user/list, /api/list/status, /api/gene/ all with the Bearer header', async () => {
    primeAuth('options-token');

    let userListAuth = false;
    let statusAuth = false;
    let genesAuth = false;

    server.use(
      http.get('/api/user/list', ({ request }) => {
        expectBearerHeader(request, 'options-token');
        userListAuth = true;
        return HttpResponse.json([
          { user_id: 1, user_name: 'alice' },
          { user_id: 2, user_name: 'bob' },
        ]);
      }),
      http.get('/api/list/status', ({ request }) => {
        expectBearerHeader(request, 'options-token');
        statusAuth = true;
        return HttpResponse.json({
          data: [
            { category_id: 1, category: 'Definitive' },
            { category_id: 2, category: 'Moderate' },
          ],
        });
      }),
      http.get('/api/gene/', ({ request }) => {
        expectBearerHeader(request, 'options-token');
        genesAuth = true;
        return HttpResponse.json({
          data: [
            { hgnc_id: 1100, symbol: 'BRCA1' },
            { hgnc_id: 1101, symbol: 'BRCA2' },
          ],
        });
      })
    );

    const form = useBatchForm();
    await form.loadOptions();

    expect(userListAuth).toBe(true);
    expect(statusAuth).toBe(true);
    expect(genesAuth).toBe(true);
    expect(form.userOptions.value).toHaveLength(2);
    expect(form.statusOptions.value).toHaveLength(2);
    expect(form.geneOptions.value).toHaveLength(2);
  });

  it('handlePreview issues POST /api/re_review/batch/preview with the Bearer header', async () => {
    primeAuth('preview-token');

    let sawBearer = false;
    server.use(
      http.post('/api/re_review/batch/preview', ({ request }) => {
        expectBearerHeader(request, 'preview-token');
        sawBearer = true;
        return HttpResponse.json({
          data: [
            {
              entity_id: 1,
              hgnc_id: 1100,
              gene_symbol: 'BRCA1',
              disease_ontology_name: 'BRCA',
              review_date: '2025-01-01',
            },
          ],
        });
      })
    );

    const form = useBatchForm();
    // A preview call requires at least one criterion; seed gene_list so
    // `isFormValid` passes without touching the UI-only entity selector.
    form.formData.gene_list = [1100];

    await form.handlePreview();
    expect(sawBearer).toBe(true);
    expect(form.previewEntities.value).toHaveLength(1);
  });

  it('handleSubmit issues POST /api/re_review/batch/create with the Bearer header', async () => {
    primeAuth('submit-token');

    let sawBearer = false;
    server.use(
      http.post('/api/re_review/batch/create', ({ request }) => {
        expectBearerHeader(request, 'submit-token');
        sawBearer = true;
        return HttpResponse.json({
          entry: { entity_count: 5 },
        });
      })
    );

    const form = useBatchForm();
    form.formData.gene_list = [1100];
    form.formData.batch_name = 'My Batch';

    const ok = await form.handleSubmit();
    expect(ok).toBe(true);
    expect(sawBearer).toBe(true);
  });
});
