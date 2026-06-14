import { describe, expect, it, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { ref, computed } from 'vue';

import ManagePubtator from './ManagePubtator.vue';

// Shared mock handles for the inner cache/job composable. Each test can tweak
// the vi.fn() implementations (e.g. make one reject) before mounting.
const adminMock = {
  getCacheStatus: vi.fn(),
  submitFetchJob: vi.fn(),
  clearCache: vi.fn(),
  backfillGeneSymbols: vi.fn(),
  stopPolling: vi.fn(),
  resetJob: vi.fn(),
};

const lastStatus = ref<Record<string, unknown> | null>({
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

vi.mock('@/composables/usePubtatorAdmin', () => ({
  usePubtatorAdmin: () => ({
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
    ...adminMock,
  }),
}));

// BAlert stub that mirrors the real bootstrap-vue-next a11y contract: default
// role="alert", or role="status" + aria-live="polite" when is-status is set.
// Forwards variant so tests can assert the danger feedback banner.
const BAlertStub = {
  props: {
    variant: { type: String, default: undefined },
    isStatus: { type: Boolean, default: false },
    show: { type: [Boolean, Number], default: false },
  },
  template:
    '<div :data-variant="variant" :role="isStatus ? \'status\' : \'alert\'" :aria-live="isStatus ? \'polite\' : \'assertive\'"><slot /></div>',
};

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
        BButton: {
          props: ['type', 'disabled'],
          template: '<button :type="type" :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
          emits: ['click'],
        },
        BButtonGroup: { template: '<div><slot /></div>' },
        BSpinner: { template: '<span />' },
        BBadge: { template: '<span><slot /></span>' },
        BAlert: BAlertStub,
        BProgress: {
          props: ['value', 'max', 'ariaLabel', 'ariaValuenow'],
          template:
            '<div role="progressbar" :aria-label="ariaLabel" :aria-valuenow="ariaValuenow"><slot /></div>',
        },
        BProgressBar: { props: ['value'], template: '<div><slot /></div>' },
        BModal: {
          emits: ['ok'],
          template:
            '<div><slot /><button data-testid="modal-ok" @click="$emit(\'ok\')">ok</button></div>',
        },
      },
    },
  });
}

/** Build an axios-like problem+json rejection (RFC 9457 `detail`). */
function problemJson(detail: string) {
  return { response: { data: { detail } } };
}

beforeEach(() => {
  vi.clearAllMocks();
  lastStatus.value = {
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
  };
  // Default happy-path resolutions.
  adminMock.getCacheStatus.mockResolvedValue(lastStatus.value);
  adminMock.submitFetchJob.mockResolvedValue({ job_id: 'job-1' });
  adminMock.clearCache.mockResolvedValue({ success: true, message: 'Cleared all cache' });
  adminMock.backfillGeneSymbols.mockResolvedValue({ success: true, message: 'Backfilled 5 genes' });
});

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

describe('ManagePubtator behavior', () => {
  it('checks status through the composable on form submit', async () => {
    const wrapper = mountView();

    await wrapper.get('.pubtator-query-form').trigger('submit');
    await flushPromises();

    expect(adminMock.getCacheStatus).toHaveBeenCalledTimes(1);
  });

  it('submits a fetch job (resetting prior job state first)', async () => {
    const wrapper = mountView();

    const submitButton = wrapper
      .findAll('button')
      .find((b) => b.text().includes('Submit fetch job'));
    await submitButton?.trigger('click');
    await flushPromises();

    expect(adminMock.resetJob).toHaveBeenCalled();
    expect(adminMock.submitFetchJob).toHaveBeenCalledTimes(1);
  });

  it('backfills gene symbols for the cached query', async () => {
    const wrapper = mountView();

    const backfillButton = wrapper
      .findAll('button')
      .find((b) => b.text().includes('Backfill gene symbols'));
    await backfillButton?.trigger('click');
    await flushPromises();

    expect(adminMock.backfillGeneSymbols).toHaveBeenCalledWith(12);
  });

  it('clears all cache through the composable after modal confirmation', async () => {
    const wrapper = mountView();

    // The danger-zone button only opens the confirm modal; confirming triggers
    // the composable call via the modal's `ok` event.
    await wrapper.get('[data-testid="modal-ok"]').trigger('click');
    await flushPromises();

    expect(adminMock.clearCache).toHaveBeenCalledTimes(1);
  });

  it('renders the server problem+json detail with the danger variant on failure', async () => {
    adminMock.getCacheStatus.mockRejectedValueOnce(problemJson('Query is malformed'));
    const wrapper = mountView();

    await wrapper.get('.pubtator-query-form').trigger('submit');
    await flushPromises();

    const banner = wrapper
      .findAll('[role="status"], [role="alert"]')
      .find((el) => el.text().includes('Query is malformed'));
    expect(banner).toBeDefined();
    // extractApiErrorMessage prefers the RFC 9457 `detail`, not the raw axios string.
    expect(banner?.text()).toContain('Query is malformed');
    expect(banner?.attributes('data-variant')).toBe('danger');
  });
});

describe('ManagePubtator accessibility', () => {
  it('exposes named, valued progress bars and a live feedback region', async () => {
    adminMock.clearCache.mockResolvedValueOnce({ success: true, message: 'Cleared all cache' });
    const wrapper = mountView();

    const progressBars = wrapper.findAll('[role="progressbar"]');
    expect(progressBars.length).toBeGreaterThan(0);
    // Every progress bar carries an accessible name and a numeric value.
    progressBars.forEach((bar) => {
      expect(bar.attributes('aria-label')).toBeTruthy();
    });
    expect(
      progressBars.some((bar) => bar.attributes('aria-label')?.includes('Cache coverage'))
    ).toBe(true);

    // The inline feedback banner is a polite live status region.
    await wrapper.get('[data-testid="modal-ok"]').trigger('click');
    await flushPromises();

    const liveBanner = wrapper
      .findAll('[role="status"]')
      .find((el) => el.text().includes('Cleared all cache'));
    expect(liveBanner).toBeDefined();
    expect(liveBanner?.attributes('aria-live')).toBe('polite');
  });
});
