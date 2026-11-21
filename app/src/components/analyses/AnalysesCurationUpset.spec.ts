import { mount, flushPromises } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { renderMock } = vi.hoisted(() => ({
  renderMock: vi.fn(),
}));

// Real set/combination math; only the DOM render is captured.
vi.mock('@upsetjs/bundle', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@upsetjs/bundle')>()),
  render: renderMock,
}));

vi.mock('@/api/comparisons', () => ({
  getComparisonsOptions: vi.fn().mockResolvedValue({
    list: [{ list: 'SysNDD' }, { list: 'panelapp' }, { list: 'gene2phenotype' }],
  }),
  getUpsetData: vi.fn().mockResolvedValue([
    { name: 'A2M', sets: ['SysNDD', 'panelapp'] },
    { name: 'ARID1B', sets: ['SysNDD', 'panelapp', 'gene2phenotype'] },
  ]),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

import { generateCombinations } from '@upsetjs/bundle';
import AnalysesCurationUpset from './AnalysesCurationUpset.vue';

const upsetStubs = {
  BBadge: { template: '<span><slot /></span>' },
  BButton: { template: '<button><slot /></button>' },
  BDropdown: { template: '<div><slot name="button-content" /><slot /></div>' },
  BFormCheckbox: { template: '<label><input type="checkbox" /><slot /></label>' },
  BFormTag: { template: '<span><slot /></span>' },
  BPopover: { template: '<div><slot name="title" /><slot /></div>' },
  DownloadImageButtons: { template: '<div data-testid="download-buttons" />' },
  TransitionGroup: { template: '<div><slot /></div>' },
};

async function renderedOptions() {
  renderMock.mockClear();
  const wrapper = mount(AnalysesCurationUpset, {
    attachTo: document.body,
    global: { stubs: upsetStubs },
  });
  await flushPromises();
  await new Promise((resolve) => setTimeout(resolve, 0));
  wrapper.vm.renderUpset();
  return { wrapper, options: renderMock.mock.calls.at(-1)?.[1] };
}

describe('AnalysesCurationUpset counting and labels', () => {
  it('draws inclusive bars: each single-source bar equals that source size', async () => {
    const { wrapper, options } = await renderedOptions();
    // Combinations exactly as upsetjs builds them from the render options.
    const combos = generateCombinations(options.sets, options.combinations);
    for (const set of options.sets) {
      const single = combos.find((c) => c.degree === 1 && c.sets.has(set));
      expect(single?.cardinality).toBe(set.cardinality);
    }
    expect(options.combinationName).toBe('Genes in all marked sources');
    // the copy describes inclusive bars, not exclusive ones
    expect(wrapper.text()).not.toContain('unique to that intersection');
    expect(wrapper.text()).toContain('every source marked with a dot');
    wrapper.unmount();
  });

  it('keeps the source toolbar in place while the plot reloads (no layout jump)', async () => {
    const { wrapper } = await renderedOptions();
    const api = await import('@/api/comparisons');
    vi.mocked(api.getUpsetData).mockImplementationOnce(() => new Promise(() => {}));
    wrapper.vm.loadComparisonsUpsetData();
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.loadingUpset).toBe(true);
    expect(wrapper.find('.source-toolbar').exists()).toBe(true);
    wrapper.unmount();
  });

  it('labels sets with curated source names', async () => {
    const { wrapper, options } = await renderedOptions();
    expect(options.sets.map((s: { name: string }) => s.name).sort()).toEqual([
      'Gene2Phenotype',
      'PanelApp',
      'SysNDD',
    ]);
    expect(Object.keys(options.setColors).sort()).toEqual(['Gene2Phenotype', 'PanelApp', 'SysNDD']);
    wrapper.unmount();
  });
});

describe('AnalysesCurationUpset responsive plot', () => {
  beforeEach(() => {
    renderMock.mockClear();
  });

  it('renders the UpSet chart to the available container width without duplicate export controls', async () => {
    const wrapper = mount(AnalysesCurationUpset, {
      attachTo: document.body,
      global: {
        stubs: {
          BCard: { template: '<section class="card"><slot name="header" /><slot /></section>' },
          BBadge: { template: '<span><slot /></span>' },
          BButton: { template: '<button><slot /></button>' },
          BDropdown: { template: '<div><slot name="button-content" /><slot /></div>' },
          BFormCheckbox: { template: '<label><input type="checkbox" /><slot /></label>' },
          BFormTag: { template: '<span><slot /></span>' },
          BPopover: { template: '<div><slot name="title" /><slot /></div>' },
          BSpinner: { template: '<div role="status" />' },
          DownloadImageButtons: { template: '<div data-testid="download-buttons" />' },
          TransitionGroup: { template: '<div><slot /></div>' },
        },
      },
    });

    await flushPromises();
    await new Promise((resolve) => setTimeout(resolve, 0));

    const plot = wrapper.get('[data-testid="comparisons-upset-plot"]');
    Object.defineProperty(plot.element, 'clientWidth', { configurable: true, value: 760 });

    await wrapper.vm.$nextTick();
    wrapper.vm.renderUpset();

    const renderOptions = renderMock.mock.calls.at(-1)?.[1];
    expect(renderOptions).toMatchObject({
      width: 760,
      exportButtons: false,
    });
    expect(renderOptions.height).toBeLessThan(600);

    const help = wrapper.get('#popover-badge-help-upset');
    expect(help.attributes('aria-label')).toBe('Explain UpSet plot');

    wrapper.unmount();
  });

  it('renders the evidence-tier mapping help inside the Overlap heading', () => {
    const wrapper = mount(AnalysesCurationUpset, {
      global: {
        stubs: {
          InlineHelpBadge: true,
          BPopover: true,
          EvidenceTierMappingHelp: {
            name: 'EvidenceTierMappingHelp',
            template: '<span class="etmh-stub"/>',
          },
          DownloadImageButtons: true,
        },
      },
    });
    const heading = wrapper.get('h2.panel-title');
    // placement: the help affordance is within the Overlap <h2>, after its label
    expect(heading.find('.etmh-stub').exists()).toBe(true);
    expect(heading.text()).toContain('Overlap');
    wrapper.unmount();
  });
});
