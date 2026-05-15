import { describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { ref, computed } from 'vue';

import ManagePubtator from './ManagePubtator.vue';

vi.mock('@/composables/usePubtatorAdmin', () => ({
  usePubtatorAdmin: () => {
    const lastStatus = ref({
      query: 'neurodevelopmental disorder',
      cached: true,
      query_id: 12,
      pages_cached: 8,
      publications_cached: 214,
      total_pages_available: 20,
      total_results_available: 612,
      pages_remaining: 12,
      cache_date: '2026-05-01T12:00:00Z',
      estimated_fetch_time_minutes: 30,
      message: 'Cached',
    });

    return {
      error: ref(null),
      lastStatus,
      isCheckingStatus: ref(false),
      isClearing: ref(false),
      isBackfilling: ref(false),
      jobId: ref('job-123456789'),
      jobStatus: ref('running'),
      jobStep: ref('Fetching page 8 of 20'),
      jobProgress: ref({ current: 8, total: 20 }),
      jobError: ref(null),
      hasRealProgress: ref(true),
      progressPercent: ref(40),
      elapsedTimeDisplay: ref('00:04:12'),
      progressVariant: ref('info'),
      statusBadgeClass: ref('bg-info'),
      isJobLoading: ref(false),
      cacheProgress: computed(() => 40),
      getCacheStatus: vi.fn(),
      submitFetchJob: vi.fn(),
      clearCache: vi.fn(),
      backfillGeneSymbols: vi.fn(),
      stopPolling: vi.fn(),
      resetJob: vi.fn(),
    };
  },
}));

function mountView() {
  return mount(ManagePubtator, {
    global: {
      stubs: {
        AuthenticatedPageShell: {
          template: '<main data-testid="authenticated-page-shell"><slot /></main>',
        },
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BCard: { template: '<section><slot name="header" /><slot /></section>' },
        BFormGroup: {
          props: ['label'],
          template: '<label><span>{{ label }}</span><slot /></label>',
        },
        BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
        BInputGroupText: { template: '<span><slot /></span>' },
        BFormInput: {
          props: ['type', 'modelValue', 'placeholder'],
          template: '<input :type="type" :value="modelValue" :placeholder="placeholder" />',
        },
        BFormText: { template: '<small><slot /></small>' },
        BFormCheckbox: { template: '<label><input type="checkbox" /><slot /></label>' },
        BButton: { template: '<button><slot /></button>' },
        BButtonGroup: { template: '<div><slot /></div>' },
        BSpinner: { template: '<span />' },
        BBadge: { template: '<span><slot /></span>' },
        BAlert: { template: '<div><slot /></div>' },
        BProgress: { template: '<div><slot /></div>' },
        BProgressBar: { template: '<div><slot /></div>' },
        BModal: { template: '<div><slot /></div>' },
      },
    },
  });
}

describe('ManagePubtator visual structure', () => {
  it('groups query, fetch, and destructive actions into distinct work zones', () => {
    const wrapper = mountView();

    expect(wrapper.get('[data-testid="pubtator-query-workspace"]').text()).toContain(
      'PubTator query'
    );
    expect(wrapper.get('[data-testid="pubtator-status-metrics"]').text()).toContain('Cached');
    expect(wrapper.get('[data-testid="pubtator-fetch-workspace"]').text()).toContain(
      'Submit fetch job'
    );
    expect(wrapper.get('[data-testid="pubtator-danger-zone"]').text()).toContain('Clear all cache');
  });
});
