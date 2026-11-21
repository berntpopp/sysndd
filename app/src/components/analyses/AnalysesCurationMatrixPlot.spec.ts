import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import AnalysesCurationMatrixPlot from './AnalysesCurationMatrixPlot.vue';

vi.mock('@/composables/useToast', () => ({ default: () => ({ makeToast: vi.fn() }) }));

const keys = ['SysNDD', 'radboudumc_ID', 'gene2phenotype', 'orphanet_id'];
vi.mock('@/api/comparisons', () => ({
  getSimilarity: vi.fn().mockResolvedValue(
    ['SysNDD', 'radboudumc_ID', 'gene2phenotype', 'orphanet_id'].flatMap((x) =>
      ['SysNDD', 'radboudumc_ID', 'gene2phenotype', 'orphanet_id'].map((y) => ({
        x,
        y,
        value: x === y ? 1 : 0.4567,
      }))
    )
  ),
}));

describe('AnalysesCurationMatrixPlot', () => {
  it('labels the axes with curated source names and prints each cell value', async () => {
    const wrapper = mount(AnalysesCurationMatrixPlot, {
      attachTo: document.body,
      global: {
        stubs: {
          DownloadImageButtons: true,
          InlineHelpBadge: true,
          BPopover: true,
          ColorLegend: true,
          BSpinner: true,
        },
      },
    });
    await flushPromises();

    const svg = document.querySelector('#matrix-svg') as SVGElement;
    const ticks = [...svg.querySelectorAll('.x-axis .tick text')].map((t) => t.textContent);
    expect(ticks).toEqual(['SysNDD', 'Radboudumc', 'Gene2Phenotype', 'Orphanet']);
    const values = [...svg.querySelectorAll('.cell-value')].map((t) => t.textContent);
    expect(values).toHaveLength(keys.length * keys.length);
    expect(values).toContain('0.46');
    expect(values).toContain('1.00');
    wrapper.unmount();
  });
});
