// app/src/components/llm/LlmLogViewer.spec.ts
/**
 * v11.0 closeout F2a spec (plan §13.2): proves `LlmLogViewer.vue`'s
 * local `getToken()` helper has been removed and every call through the
 * `useLlmAdmin.fetchLogs` composable now relies on the `apiClient`
 * request interceptor (`@/api/client`) for the `Authorization: Bearer
 * <token>` header.
 */

import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { mount } from '@vue/test-utils';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';
import LlmLogViewer from './LlmLogViewer.vue';

afterEach(() => {
  useAuth().logout();
});

describe('LlmLogViewer — F2a Bearer-via-interceptor', () => {
  it('sends Bearer header when fetching logs on mount', async () => {
    const { token } = primeAuth();
    let sawRequest = false;

    server.use(
      http.get('*/api/llm/logs', ({ request }) => {
        expectBearerHeader(request, token);
        sawRequest = true;
        return HttpResponse.json({ data: [], total: 0, page: 1, per_page: 50 });
      }),
    );

    mount(LlmLogViewer, {
      global: {
        stubs: {
          BCard: { template: '<div><slot name="header" /><slot /></div>' },
          BRow: { template: '<div><slot /></div>' },
          BCol: { template: '<div><slot /></div>' },
          BButton: { template: '<button><slot /></button>' },
          BBadge: { template: '<span><slot /></span>' },
          BAlert: { template: '<div><slot /></div>' },
          BTable: { template: '<table />' },
          BPagination: { template: '<nav />' },
          BFormSelect: { template: '<select />' },
          BFormInput: { template: '<input />' },
          BSpinner: { template: '<div role="status" />' },
          BModal: { template: '<div />' },
          'router-link': true,
        },
      },
    });

    await new Promise((r) => setTimeout(r, 0));
    expect(sawRequest).toBe(true);
  });
});
