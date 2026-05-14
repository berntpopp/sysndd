// app/src/views/admin/AdminStatistics.spec.ts
/**
 * v11.0 closeout F2a spec (plan §13.2): proves `AdminStatistics.vue`'s
 * `getAuthHeaders()` helper no longer reads `localStorage.token`. The
 * helper now returns an empty `{}` — the `apiClient` request interceptor
 * (`@/api/client`) reads `useAuth().token.value` and injects the
 * `Authorization: Bearer <token>` header on every outbound call against
 * the shared axios singleton.
 *
 * The view calls its sub-composables (`useAdminTrendData`,
 * `useLeaderboardData`, `useKPIStats`) through an injected `axios` — we
 * provide the shared singleton so the F1 request interceptor participates.
 * The on-mount `fetchStatistics()` fans out to several endpoints; any one
 * of them hitting MSW with the Bearer present is a sufficient assertion
 * that the migration succeeded. We pick the trend endpoint because it is
 * the simplest on-mount fire.
 */

import { afterEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';
import { mount } from '@vue/test-utils';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';

// Mock useToast before importing the view — bootstrap-vue-next's toast
// wrapper requires a BApp provider otherwise.
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

import '@/plugins/axios';
import '@/api/client'; // Ensure the request interceptor is installed.
import axios from 'axios';
import AdminStatistics from './AdminStatistics.vue';

afterEach(() => {
  useAuth().logout();
});

describe('AdminStatistics — F2a Bearer-via-interceptor', () => {
  function stubStatisticsEndpoints() {
    server.use(
      http.get('*/api/statistics/entities_over_time', () => HttpResponse.json({ data: [] })),
      http.get('*/api/statistics/leaderboard', () => HttpResponse.json({ data: [] })),
      http.get('*/api/statistics/rereview_leaderboard', () => HttpResponse.json({ data: [] })),
      http.get('*/api/statistics/updates', () => HttpResponse.json({})),
      http.get('*/api/statistics/rereview', () => HttpResponse.json({})),
      http.get('*/api/statistics/updated_reviews', () => HttpResponse.json({})),
      http.get('*/api/statistics/updated_statuses', () => HttpResponse.json({}))
    );
  }

  function mountView() {
    return mount(AdminStatistics, {
      global: {
        provide: {
          axios,
        },
        stubs: {
          BContainer: { template: '<div><slot /></div>' },
          BRow: { template: '<div><slot /></div>' },
          BCol: { template: '<div><slot /></div>' },
          BCard: { template: '<div><slot name="header" /><slot /></div>' },
          BButton: { template: '<button><slot /></button>' },
          BForm: { template: '<form><slot /></form>' },
          BFormGroup: {
            props: ['label'],
            template: '<label><span>{{ label }}</span><slot /></label>',
          },
          BFormInput: {
            props: ['type', 'modelValue'],
            template: '<input :type="type" :value="modelValue" />',
          },
          BFormRadioGroup: { template: '<div />' },
          BFormCheckboxGroup: { template: '<div />' },
          EntityTrendChart: { template: '<div />' },
          ContributorBarChart: { template: '<div />' },
          ReReviewBarChart: { template: '<div />' },
          StatCard: { template: '<div />' },
          'router-link': true,
        },
      },
    });
  }

  it('sends Bearer on GET /api/statistics/entities_over_time', async () => {
    const { token } = primeAuth();
    let sawRequest = false;

    server.use(
      http.get('*/api/statistics/entities_over_time', ({ request }) => {
        expectBearerHeader(request, token);
        sawRequest = true;
        return HttpResponse.json({ data: [] });
      }),
      // Short-circuit the rest of the on-mount fan-out so
      // `onUnhandledRequest: 'error'` does not fail the test on unrelated
      // endpoints the view also fires.
      http.get('*/api/statistics/leaderboard', () => HttpResponse.json({ data: [] })),
      http.get('*/api/statistics/rereview_leaderboard', () => HttpResponse.json({ data: [] })),
      http.get('*/api/statistics/updates', () => HttpResponse.json({})),
      http.get('*/api/statistics/rereview', () => HttpResponse.json({})),
      http.get('*/api/statistics/updated_reviews', () => HttpResponse.json({})),
      http.get('*/api/statistics/updated_statuses', () => HttpResponse.json({}))
    );

    mountView();

    // Allow the mount → fetchStatistics → axios → MSW path to complete.
    await new Promise((r) => setTimeout(r, 0));
    await new Promise((r) => setTimeout(r, 0));

    expect(sawRequest).toBe(true);
  });

  it('renders a compact date range control panel', () => {
    stubStatisticsEndpoints();

    const wrapper = mountView();

    const controlPanel = wrapper.get('[data-testid="admin-statistics-controls"]');
    expect(controlPanel.text()).toContain('Reporting window');
    expect(controlPanel.findAll('input[type="date"]')).toHaveLength(2);
    expect(controlPanel.find('button').text()).toContain('Apply');
  });
});
