// app/src/composables/useLlmAdmin.spec.ts
/**
 * v11.0 closeout F2a spec (plan §13.2): covers the coordinated API change
 * on `useLlmAdmin` — every method dropped its `token: string` parameter
 * and now delegates to `apiClient`, which means the outbound request
 * picks up its `Authorization: Bearer <token>` header from the apiClient
 * request interceptor (`@/api/client`), which reads `useAuth().token.value`.
 *
 * The three methods explicitly called out in the plan dispatch brief are
 * `fetchConfig`, `fetchPrompts`, and `fetchCacheStats`. We intercept each
 * endpoint via MSW and assert the outbound Bearer header matches the token
 * seeded by `primeAuth`.
 */

import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';
import { useLlmAdmin } from './useLlmAdmin';

afterEach(() => {
  useAuth().logout();
});

describe('useLlmAdmin — F2a coordinated API change (token dropped)', () => {
  it('fetchConfig sends Bearer header seeded by useAuth', async () => {
    const { token } = primeAuth();
    server.use(
      http.get('*/api/llm/config', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({
          gemini_configured: [true],
          current_model: ['gemini-1.5-flash'],
        });
      })
    );

    const admin = useLlmAdmin();
    await admin.fetchConfig();

    // The response body is unwrapped by the plumber-array unwrapper inside
    // the composable; we assert on the `current_model` field to prove the
    // call actually completed against the MSW handler.
    expect(admin.config.value?.current_model).toBe('gemini-1.5-flash');
    expect(admin.error.value).toBeNull();
  });

  it('fetchPrompts sends Bearer header seeded by useAuth', async () => {
    const { token } = primeAuth('prompts-token');
    const promptsFixture = {
      functional_generation: {
        template_id: 1,
        prompt_type: 'functional_generation',
        version: '1.0.0',
        template_text: 'fn gen',
        description: null,
      },
      functional_judge: {
        template_id: 2,
        prompt_type: 'functional_judge',
        version: '1.0.0',
        template_text: 'fn judge',
        description: null,
      },
      phenotype_generation: {
        template_id: 3,
        prompt_type: 'phenotype_generation',
        version: '1.0.0',
        template_text: 'ph gen',
        description: null,
      },
      phenotype_judge: {
        template_id: 4,
        prompt_type: 'phenotype_judge',
        version: '1.0.0',
        template_text: 'ph judge',
        description: null,
      },
    };
    server.use(
      http.get('*/api/llm/prompts', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json(promptsFixture);
      })
    );

    const admin = useLlmAdmin();
    await admin.fetchPrompts();

    // Arbitrary field from the mocked payload to prove the composable
    // actually received the MSW response.
    expect(admin.prompts.value?.functional_generation?.template_text).toBe('fn gen');
    expect(admin.error.value).toBeNull();
  });

  it('fetchCacheStats sends Bearer header seeded by useAuth', async () => {
    const { token } = primeAuth('stats-token');
    server.use(
      http.get('*/api/llm/cache/stats', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({
          total_entries: 12,
          by_type: {},
          by_status: { pending: 4, validated: 7, rejected: 1 },
          estimated_cost_usd: 0.42,
        });
      })
    );

    const admin = useLlmAdmin();
    await admin.fetchCacheStats();

    expect(admin.cacheStats.value?.total_entries).toBe(12);
    expect(admin.error.value).toBeNull();
  });
});
