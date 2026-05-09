// app/src/views/admin/ManageLLM.spec.ts
/**
 * v11.0 closeout F2a spec (plan §13.2): proves `ManageLLM.vue`'s local
 * `getToken()` helper (formerly at line 211) has been deleted and every
 * outbound request for the view's on-mount `refreshAll()` sequence now
 * picks up its `Authorization: Bearer <token>` header from the apiClient
 * request interceptor (`@/api/client`).
 *
 * On mount the view fires all three in parallel:
 *   - `fetchConfig()`     → GET /api/llm/config
 *   - `fetchPrompts()`    → GET /api/llm/prompts
 *   - `fetchCacheStats()` → GET /api/llm/cache/stats
 * Every resolver asserts the incoming Bearer via `expectBearerHeader`.
 */

import { afterEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';
import { mount } from '@vue/test-utils';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';

// Stub `useToast`: the real implementation wraps `useBootstrapToast` from
// bootstrap-vue-next, which requires a BApp provider that we don't mount
// here. We don't assert on toast behavior in this spec.
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

import ManageLLM from './ManageLLM.vue';

afterEach(() => {
  useAuth().logout();
});

describe('ManageLLM — F2a Bearer-via-interceptor', () => {
  it('sends Bearer on every GET fired by refreshAll()', async () => {
    const { token } = primeAuth();
    const hits = { config: false, prompts: false, stats: false };

    server.use(
      http.get('*/api/llm/config', ({ request }) => {
        expectBearerHeader(request, token);
        hits.config = true;
        return HttpResponse.json({
          gemini_configured: [true],
          current_model: ['gemini-1.5-flash'],
        });
      }),
      http.get('*/api/llm/prompts', ({ request }) => {
        expectBearerHeader(request, token);
        hits.prompts = true;
        return HttpResponse.json({
          functional: { template: '', version: '1', description: '' },
          phenotype: { template: '', version: '1', description: '' },
        });
      }),
      http.get('*/api/llm/cache/stats', ({ request }) => {
        expectBearerHeader(request, token);
        hits.stats = true;
        return HttpResponse.json({
          total_entries: 0,
          by_type: {},
          by_status: {},
          estimated_cost_usd: 0,
        });
      })
    );

    mount(ManageLLM, {
      global: {
        stubs: {
          BContainer: { template: '<div><slot /></div>' },
          BRow: { template: '<div><slot /></div>' },
          BCol: { template: '<div><slot /></div>' },
          BCard: { template: '<div><slot name="header" /><slot /></div>' },
          BButton: { template: '<button><slot /></button>' },
          BBadge: { template: '<span><slot /></span>' },
          BSpinner: { template: '<div role="status" />' },
          BTabs: { template: '<div><slot /></div>' },
          BTab: { template: '<div><slot /></div>' },
          BProgress: { template: '<div />' },
          BModal: { template: '<div />' },
          BFormGroup: { template: '<div><slot /></div>' },
          BFormRadioGroup: { template: '<div />' },
          LlmConfigPanel: { template: '<div />' },
          LlmPromptEditor: { template: '<div />' },
          LlmCacheManager: { template: '<div />' },
          LlmLogViewer: { template: '<div />' },
          'router-link': true,
        },
      },
    });

    // Allow the onMounted → Promise.all(3) → MSW path to resolve.
    await new Promise((r) => setTimeout(r, 0));
    await new Promise((r) => setTimeout(r, 0));

    expect(hits.config).toBe(true);
    expect(hits.prompts).toBe(true);
    expect(hits.stats).toBe(true);
  });
});
