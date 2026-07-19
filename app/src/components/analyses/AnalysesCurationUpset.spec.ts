import { mount, flushPromises } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { renderMock } = vi.hoisted(() => ({
  renderMock: vi.fn(),
}));

vi.mock('@upsetjs/bundle', () => ({
  extractSets: vi.fn((elems: Array<{ sets?: string[] }>) =>
    Array.from(new Set(elems.flatMap((elem) => elem.sets ?? []))).map((name) => ({ name }))
  ),
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

import AnalysesCurationUpset from './AnalysesCurationUpset.vue';

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
