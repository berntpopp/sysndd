// app/src/composables/useCmsContent.spec.ts
/**
 * v11.0 closeout F2a spec (plan §13.2): proves `useCmsContent` no longer
 * builds its own Authorization header from `localStorage.token`. The
 * `apiClient` request interceptor (`@/api/client`) injects the Bearer
 * header on every outbound axios call; `useCmsContent` reaches the shared
 * axios singleton, so the interceptor fires for it too.
 *
 * Coverage: one write-flow assertion per method (`loadDraft`,
 * `saveDraft`, `publish`) — each asserts `expectBearerHeader` inside the
 * MSW resolver. `loadPublished` is the one public helper that intentionally
 * does NOT require auth (it powers the anonymous /About page), so no
 * assertion is needed there.
 */

import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import '@/api/client'; // Ensure the request interceptor is installed.
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';
import { useCmsContent } from './useCmsContent';

afterEach(() => {
  useAuth().logout();
});

describe('useCmsContent — F2a Bearer-via-interceptor', () => {
  it('loadDraft sends Bearer on GET /api/about/draft', async () => {
    const { token } = primeAuth();
    server.use(
      http.get('*/api/about/draft', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({
          status: 'draft',
          version: 3,
          sections: [{ heading: 'Test', body: 'Body', sort_order: 0 }],
        });
      })
    );

    const cms = useCmsContent();
    const ok = await cms.loadDraft();
    expect(ok).toBe(true);
    expect(cms.sections.value).toHaveLength(1);
  });

  it('saveDraft sends Bearer on PUT /api/about/draft', async () => {
    const { token } = primeAuth('save-token');
    server.use(
      http.put('*/api/about/draft', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({ ok: true });
      })
    );

    const cms = useCmsContent();
    // saveDraft short-circuits on empty sections, so we must seed one row.
    cms.addSection({
      heading: 'Heading',
      body: 'Body',
    } as unknown as Parameters<typeof cms.addSection>[0]);
    const ok = await cms.saveDraft();
    expect(ok).toBe(true);
  });

  it('publish sends Bearer on POST /api/about/publish', async () => {
    const { token } = primeAuth('publish-token');
    server.use(
      http.post('*/api/about/publish', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({ message: 'published', version: 4 });
      })
    );

    const cms = useCmsContent();
    cms.addSection({
      heading: 'Heading',
      body: 'Body',
    } as unknown as Parameters<typeof cms.addSection>[0]);
    const ok = await cms.publish();
    expect(ok).toBe(true);
    expect(cms.currentVersion.value).toBe(4);
  });
});
