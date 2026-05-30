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
import { flushPromises, mount } from '@vue/test-utils';
import type { RouteLocationRaw } from 'vue-router';

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
  window.sessionStorage.clear();
  vi.useRealTimers();
});

describe('ManageLLM — F2a Bearer-via-interceptor', () => {
  const routerLinkStub = {
    props: ['to'],
    template: '<a :href="href"><slot /></a>',
    computed: {
      href(this: { to: RouteLocationRaw }): string {
        const to = this.to as RouteLocationRaw;
        if (typeof to === 'string') {
          return to;
        }
        return `${to.path ?? ''}${to.hash ?? ''}`;
      },
    },
  };

  const mountManageLLM = () =>
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
          BAlert: { template: '<div><slot /></div>' },
          BTabs: { template: '<div><slot /></div>' },
          BTab: { template: '<div><slot /></div>' },
          BProgress: { template: '<div />' },
          BProgressBar: { template: '<div><slot /></div>' },
          BModal: { template: '<div />' },
          BFormGroup: { template: '<div><slot /></div>' },
          BFormRadioGroup: { template: '<div />' },
          BNav: { template: '<nav><slot /></nav>' },
          BNavItem: { template: '<span><slot /></span>' },
          LlmConfigPanel: { template: '<div />' },
          LlmPromptEditor: { template: '<div />' },
          LlmCacheManager: { template: '<div />' },
          LlmLogViewer: { template: '<div />' },
          RouterLink: routerLinkStub,
        },
      },
    });

  it('sends Bearer on every GET fired by refreshAll()', async () => {
    const { token } = primeAuth();
    const hits = { config: false, prompts: false, stats: false };

    server.use(
      http.get('*/api/llm/config', ({ request }) => {
        expectBearerHeader(request, token);
        hits.config = true;
        return HttpResponse.json({
          gemini_configured: [true],
          current_model: ['gemini-3.5-flash'],
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

    mountManageLLM();

    // Allow the onMounted → Promise.all(3) → MSW path to resolve.
    await new Promise((r) => setTimeout(r, 0));
    await new Promise((r) => setTimeout(r, 0));

    expect(hits.config).toBe(true);
    expect(hits.prompts).toBe(true);
    expect(hits.stats).toBe(true);
  });

  it('renders direct URLs for every management section', async () => {
    primeAuth();

    server.use(
      http.get('*/api/llm/config', () =>
        HttpResponse.json({
          gemini_configured: [true],
          current_model: ['gemini-3.5-flash'],
        })
      ),
      http.get('*/api/llm/prompts', () =>
        HttpResponse.json({
          functional: { template: '', version: '1', description: '' },
          phenotype: { template: '', version: '1', description: '' },
        })
      ),
      http.get('*/api/llm/cache/stats', () =>
        HttpResponse.json({
          total_entries: 0,
          by_type: {},
          by_status: {},
          estimated_cost_usd: 0,
        })
      )
    );

    const wrapper = mountManageLLM();

    expect(wrapper.get('a[href="/ManageLLM#overview"]').text()).toBe('Overview');
    expect(wrapper.get('a[href="/ManageLLM#configuration"]').text()).toBe('Configuration');
    expect(wrapper.get('a[href="/ManageLLM#prompts"]').text()).toBe('Prompts');
    expect(wrapper.get('a[href="/ManageLLM#cache"]').text()).toBe('Cache');
    expect(wrapper.get('a[href="/ManageLLM#logs"]').text()).toBe('Logs');
  });

  it('tracks the real child job returned by functional regeneration', async () => {
    const { token } = primeAuth();
    let polledChildJob = false;

    server.use(
      http.get('*/api/llm/config', () =>
        HttpResponse.json({
          gemini_configured: [true],
          current_model: ['gemini-3.5-flash'],
        })
      ),
      http.get('*/api/llm/prompts', () =>
        HttpResponse.json({
          functional: { template: '', version: '1', description: '' },
          phenotype: { template: '', version: '1', description: '' },
        })
      ),
      http.get('*/api/llm/cache/stats', () =>
        HttpResponse.json({
          total_entries: 0,
          by_type: {},
          by_status: {},
          estimated_cost_usd: 0,
        })
      ),
      http.post('*/api/llm/regenerate', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json(
          {
            job_id: 'parent-job',
            status: 'accepted',
            status_url: '/api/jobs/parent-job',
            cluster_types: ['functional'],
            results: {
              functional: {
                job_id: 'functional-child-job',
                status: 'accepted',
                status_url: '/api/jobs/functional-child-job/status',
              },
            },
          },
          { status: 202 }
        );
      }),
      http.get('*/api/jobs/functional-child-job/status', () => {
        polledChildJob = true;
        return HttpResponse.json({
          status: ['running'],
          step: ['Generating functional cluster summaries'],
          progress: { current: [1], total: [8] },
        });
      }),
      http.get('*/api/jobs/parent-job/status', () => {
        throw new Error('ManageLLM should not poll the synthetic parent job');
      })
    );

    vi.useFakeTimers();
    const wrapper = mountManageLLM();
    try {
      await vi.runOnlyPendingTimersAsync();
      await wrapper.get('button[data-testid="llm-regenerate-functional"]').trigger('click');
      await flushPromises();

      expect(wrapper.text()).toContain('Functional');
      expect(wrapper.text()).toContain('functional-child-job');

      await vi.advanceTimersByTimeAsync(3000);
      expect(polledChildJob).toBe(true);
    } finally {
      vi.useRealTimers();
    }
  });

  it('resumes a visible regeneration job after returning to the view', async () => {
    primeAuth();
    let polledChildJob = false;

    window.sessionStorage.setItem(
      'sysndd.llm.activeRegenerationJobs.v1',
      JSON.stringify({ functional: 'functional-child-job' })
    );

    server.use(
      http.get('*/api/llm/config', () =>
        HttpResponse.json({
          gemini_configured: [true],
          current_model: ['gemini-3.5-flash'],
        })
      ),
      http.get('*/api/llm/prompts', () =>
        HttpResponse.json({
          functional: { template: '', version: '1', description: '' },
          phenotype: { template: '', version: '1', description: '' },
        })
      ),
      http.get('*/api/llm/cache/stats', () =>
        HttpResponse.json({
          total_entries: 0,
          by_type: {},
          by_status: {},
          estimated_cost_usd: 0,
        })
      ),
      http.get('*/api/jobs/functional-child-job/status', () => {
        polledChildJob = true;
        return HttpResponse.json({
          status: ['running'],
          step: ['Generating functional cluster summaries'],
          progress: { current: [2], total: [8] },
        });
      })
    );

    vi.useFakeTimers();
    const wrapper = mountManageLLM();
    try {
      await flushPromises();

      expect(wrapper.get('[data-testid="llm-regeneration-job-functional"]').text()).toContain(
        'functional-child-job'
      );

      await vi.advanceTimersByTimeAsync(3000);
      expect(polledChildJob).toBe(true);
    } finally {
      vi.useRealTimers();
    }
  });
});
