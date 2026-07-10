import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import GeneStructurePlotControls, {
  type PathogenicityLegendRow,
  type EffectLegendRow,
} from './GeneStructurePlotControls.vue';
import type { GeneStructureRenderData } from '@/types/ensembl';

const geneData: GeneStructureRenderData = {
  geneSymbol: 'CHD8',
  transcriptId: 'ENST00000318560',
  chromosome: '14',
  geneStart: 21_400_000,
  geneEnd: 21_450_000,
  strand: '+',
  exons: [],
  introns: [],
  exonCount: 0,
  geneLength: 50_000,
};

const pathogenicityItems: PathogenicityLegendRow[] = [
  {
    key: 'pathogenic',
    label: 'Pathogenic',
    color: '#d73027',
    visible: true,
    count: 5,
  },
  {
    key: 'likelyPathogenic',
    label: 'Likely pathogenic',
    color: '#fc8d59',
    visible: true,
    count: 0,
  },
  {
    key: 'vus',
    label: 'VUS',
    color: '#fee08b',
    visible: false,
    count: 2,
  },
  {
    key: 'likelyBenign',
    label: 'Likely benign',
    color: '#91cf60',
    visible: false,
    count: 0,
  },
  {
    key: 'benign',
    label: 'Benign',
    color: '#1a9850',
    visible: false,
    count: 0,
  },
];

const effectItems: EffectLegendRow[] = [
  {
    key: 'missense',
    label: 'Missense',
    color: '#1f77b4',
    visible: true,
    count: 3,
  },
  {
    key: 'frameshift',
    label: 'Frameshift',
    color: '#d62728',
    visible: true,
    count: 0,
  },
];

function mountControls(
  props: Partial<{
    coloringMode: 'acmg' | 'effect';
    zoomDomain: [number, number] | null;
    hasVariants: boolean;
  }> = {}
) {
  return mount(GeneStructurePlotControls, {
    props: {
      coloringMode: props.coloringMode ?? 'acmg',
      geneData,
      zoomDomain: props.zoomDomain ?? null,
      hasVariants: props.hasVariants ?? true,
      pathogenicityItems,
      effectItems,
    },
  });
}

describe('GeneStructurePlotControls', () => {
  it('renders the gene info summary from geneData', () => {
    const wrapper = mountControls();

    const info = wrapper.get('.gene-info');
    expect(info.text()).toContain('+ strand');
    expect(info.text()).toContain('chr14:21.40 Mb-21.45 Mb');
    expect(info.text()).toContain('ENST00000318560');
  });

  it('highlights the active coloring mode and emits set-coloring-mode on click', async () => {
    const wrapper = mountControls({ coloringMode: 'acmg' });
    const buttons = wrapper.findAll('.btn-group button');

    expect(buttons[0].classes()).toContain('btn-primary');
    expect(buttons[1].classes()).toContain('btn-outline-secondary');

    await buttons[1].trigger('click');

    expect(wrapper.emitted('set-coloring-mode')).toEqual([['effect']]);
  });

  it('does not render the reset-zoom button when zoomDomain is null', () => {
    const wrapper = mountControls({ zoomDomain: null });

    expect(wrapper.find('button[title^="Reset zoom"]').exists()).toBe(false);
  });

  it('emits reset-zoom (showing all variants again) when the reset-zoom button is clicked', async () => {
    const wrapper = mountControls({ zoomDomain: [1000, 2000] });

    const resetButton = wrapper.get('button[title^="Reset zoom"]');
    await resetButton.trigger('click');

    expect(wrapper.emitted('reset-zoom')).toHaveLength(1);
  });

  it('emits download-svg and download-png on the export buttons', async () => {
    const wrapper = mountControls();

    await wrapper.get('button[title="Download as SVG"]').trigger('click');
    await wrapper.get('button[title="Download as PNG"]').trigger('click');

    expect(wrapper.emitted('download-svg')).toHaveLength(1);
    expect(wrapper.emitted('download-png')).toHaveLength(1);
  });

  it('hides the filter rows entirely when hasVariants is false', () => {
    const wrapper = mountControls({ hasVariants: false });

    expect(wrapper.find('.filter-rows').exists()).toBe(false);
  });

  it('renders pathogenicity chip labels with counts, hiding zero counts', () => {
    const wrapper = mountControls();

    const chips = wrapper.findAll('.filter-row')[0].findAll('.filter-chip');
    expect(chips).toHaveLength(pathogenicityItems.length);

    const pathogenicChip = chips[0];
    expect(pathogenicChip.text()).toContain('Pathogenic');
    expect(pathogenicChip.find('.filter-count').text()).toBe('5');

    const likelyPathogenicChip = chips[1];
    expect(likelyPathogenicChip.find('.filter-count').exists()).toBe(false);
  });

  it('marks hidden pathogenicity categories with filter-chip--hidden and aria-pressed=false', () => {
    const wrapper = mountControls();

    const chips = wrapper.findAll('.filter-row')[0].findAll('.filter-chip');
    const vusChip = chips[2];

    expect(vusChip.classes()).toContain('filter-chip--hidden');
    expect(vusChip.attributes('aria-pressed')).toBe('false');
  });

  it('emits toggle-pathogenicity with the clicked chip key', async () => {
    const wrapper = mountControls();

    const chips = wrapper.findAll('.filter-row')[0].findAll('.filter-chip');
    await chips[2].trigger('click'); // vus

    expect(wrapper.emitted('toggle-pathogenicity')).toEqual([['vus']]);
  });

  it('emits select-only-pathogenicity and select-all-pathogenicity', async () => {
    const wrapper = mountControls();

    const pathogenicityRow = wrapper.findAll('.filter-row')[0];
    const onlyButtons = pathogenicityRow.findAll('.only-btn');
    await onlyButtons[1].trigger('click'); // likelyPathogenic

    expect(wrapper.emitted('select-only-pathogenicity')).toEqual([['likelyPathogenic']]);

    await pathogenicityRow.get('.all-btn').trigger('click');

    expect(wrapper.emitted('select-all-pathogenicity')).toHaveLength(1);
  });

  it('renders effect-type chips with counts and emits toggle-effect', async () => {
    const wrapper = mountControls();

    const effectRow = wrapper.findAll('.filter-row')[1];
    const chips = effectRow.findAll('.filter-chip');
    expect(chips).toHaveLength(effectItems.length);
    expect(chips[0].find('.filter-count').text()).toBe('3');
    expect(chips[1].find('.filter-count').exists()).toBe(false);

    await chips[1].trigger('click'); // frameshift

    expect(wrapper.emitted('toggle-effect')).toEqual([['frameshift']]);
  });

  it('emits select-only-effect and select-all-effects', async () => {
    const wrapper = mountControls();

    const effectRow = wrapper.findAll('.filter-row')[1];
    const onlyButtons = effectRow.findAll('.only-btn');
    await onlyButtons[0].trigger('click'); // missense

    expect(wrapper.emitted('select-only-effect')).toEqual([['missense']]);

    await effectRow.get('.all-btn').trigger('click');

    expect(wrapper.emitted('select-all-effects')).toHaveLength(1);
  });
});
