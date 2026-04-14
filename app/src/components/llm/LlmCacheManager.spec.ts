// app/src/components/llm/LlmCacheManager.spec.ts
/**
 * v11.0 closeout F2a spec (plan §13.2): proves `LlmCacheManager.vue`'s
 * local `getToken()` helper has been removed and every call through the
 * `useLlmAdmin` composable now relies on the `apiClient` request
 * interceptor (`@/api/client`) for the `Authorization: Bearer <token>`
 * header.
 *
 * The component fetches cached summaries on mount via
 * `fetchCachedSummaries()`. We install an MSW handler for that endpoint
 * and assert the outbound request carries the Bearer header seeded by
 * `primeAuth`.
 */

import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { mount } from '@vue/test-utils';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';
import LlmCacheManager from './LlmCacheManager.vue';

afterEach(() => {
  useAuth().logout();
});

describe('LlmCacheManager — F2a Bearer-via-interceptor', () => {
  it('sends Bearer header when fetching cached summaries on mount', async () => {
    const { token } = primeAuth();
    let sawRequest = false;

    server.use(
      http.get('*/api/llm/cache/summaries', ({ request }) => {
        expectBearerHeader(request, token);
        sawRequest = true;
        return HttpResponse.json({ data: [], total: 0, page: 1, per_page: 20 });
      }),
    );

    mount(LlmCacheManager, {
      props: { stats: null },
      global: {
        stubs: {
          BRow: { template: '<div><slot /></div>' },
          BCol: { template: '<div><slot /></div>' },
          BCard: { template: '<div><slot name="header" /><slot /><slot name="footer" /></div>' },
          BButton: { template: '<button><slot /></button>' },
          BButtonGroup: { template: '<div><slot /></div>' },
          BBadge: { template: '<span><slot /></span>' },
          BTable: { template: '<table />' },
          BPagination: { template: '<nav />' },
          BFormSelect: { template: '<select />' },
          BModal: { template: '<div />' },
          'router-link': true,
        },
      },
    });

    // Wait one microtask tick for the onMounted → loadSummaries → MSW
    // resolver path to complete.
    await new Promise((r) => setTimeout(r, 0));
    expect(sawRequest).toBe(true);
  });
});
