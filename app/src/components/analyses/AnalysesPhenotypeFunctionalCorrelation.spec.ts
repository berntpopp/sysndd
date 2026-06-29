import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { getPhenotypeFunctionalCorrelation } from '@/api/analysis';
import AnalysesPhenotypeFunctionalCorrelation from './AnalysesPhenotypeFunctionalCorrelation.vue';

const mocks = vi.hoisted(() => ({
  makeToast: vi.fn(),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: mocks.makeToast }),
}));

vi.mock('@/api/analysis', async () => {
  const actual = await vi.importActual<typeof import('@/api/analysis')>('@/api/analysis');
  return {
    ...actual, // keep the real isSnapshotPreparingError so the preparing-state test is realistic
    getPhenotypeFunctionalCorrelation: vi.fn(),
  };
});

const getCorrelationMock = vi.mocked(getPhenotypeFunctionalCorrelation);

const globalStubs = {
  AnalysisPanel: { template: '<section><slot name="actions" /><slot /></section>' },
  InlineHelpBadge: { template: '<button data-testid="help-badge" />' },
  BPopover: { template: '<div />' },
  BButton: { template: '<button @click="$emit(\'click\')"><slot /></button>' },
  BSpinner: { template: '<span />' },
};

function mountComponent() {
  return mount(AnalysesPhenotypeFunctionalCorrelation, {
    global: { stubs: globalStubs },
  });
}

describe('AnalysesPhenotypeFunctionalCorrelation', () => {
  beforeEach(() => {
    mocks.makeToast.mockReset();
    getCorrelationMock.mockReset();
    // Default: never resolves, so the mount-time fetch stays pending and each
    // test drives the behaviour it cares about explicitly.
    getCorrelationMock.mockImplementation(() => new Promise(() => {}));
  });

  // Regression (#440): a snapshot "being prepared" 503 is a transient, expected
  // state. The page must show the friendly panel + retry like its siblings
  // (GeneNetworks / PhenotypeClusters), NOT a raw "Request failed with status
  // code 503" danger toast.
  it('shows the "being prepared" state on a snapshot 503 instead of an error toast', async () => {
    getCorrelationMock.mockReset();
    // Real API shape: 503 with the RFC 9457 problem code as a 1-element array.
    getCorrelationMock.mockRejectedValue({
      response: { status: 503, data: { code: ['snapshot_stale'] } },
    });

    const wrapper = mountComponent();
    await wrapper.vm.loadCorrelationData();
    await flushPromises();

    expect(wrapper.vm.isPreparing).toBe(true);
    expect(wrapper.vm.error).toBeNull();
    expect(mocks.makeToast).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('This analysis is being prepared');
  });

  it('shows an error panel and a danger toast on a non-snapshot failure', async () => {
    getCorrelationMock.mockReset();
    getCorrelationMock.mockRejectedValue(new Error('Network Error'));

    const wrapper = mountComponent();
    await wrapper.vm.loadCorrelationData();
    await flushPromises();

    expect(wrapper.vm.isPreparing).toBe(false);
    expect(wrapper.vm.error).toBe('Network Error');
    expect(mocks.makeToast).toHaveBeenCalledWith(
      'Network Error',
      'Error fetching correlation data',
      'danger'
    );
    expect(wrapper.text()).toContain('Network Error');
  });

  it('clears the preparing state and renders the viz container on a successful retry', async () => {
    getCorrelationMock.mockReset();
    getCorrelationMock.mockRejectedValue({
      response: { status: 503, data: { code: ['snapshot_missing'] } },
    });

    const wrapper = mountComponent();
    await wrapper.vm.loadCorrelationData();
    await flushPromises();
    expect(wrapper.vm.isPreparing).toBe(true);
    expect(wrapper.find('#phenotypeFunctionalCorrelationViz').exists()).toBe(false);

    getCorrelationMock.mockResolvedValue({ correlation_matrix: [], correlation_melted: [] });
    await wrapper.vm.retryLoad();
    await flushPromises();

    expect(wrapper.vm.isPreparing).toBe(false);
    expect(wrapper.vm.error).toBeNull();
    expect(wrapper.find('#phenotypeFunctionalCorrelationViz').exists()).toBe(true);
  });
});
