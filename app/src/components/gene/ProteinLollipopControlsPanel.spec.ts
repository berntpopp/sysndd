/**
 * ProteinLollipopControlsPanel contract tests.
 *
 * The panel is presentational: coloring mode, legends, and filter visibility
 * are read-only props, and every user interaction is surfaced as an event so
 * the parent (which owns LollipopFilterState) can react. These pin the
 * pathogenicity/effect/coloring emits and the domain legend display.
 */

import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import ProteinLollipopControlsPanel from './ProteinLollipopControlsPanel.vue';

const legendItems = [
  { key: 'pathogenic' as const, label: 'Pathogenic', color: '#d73027', visible: true, count: 3 },
  {
    key: 'likelyPathogenic' as const,
    label: 'Likely pathogenic',
    color: '#fc8d59',
    visible: true,
    count: 0,
  },
  { key: 'vus' as const, label: 'VUS', color: '#fee08b', visible: false, count: 5 },
];

const effectLegendItems = [
  { key: 'missense' as const, label: 'Missense', color: '#1f77b4', visible: true, count: 4 },
  { key: 'frameshift' as const, label: 'Frameshift', color: '#d62728', visible: false, count: 1 },
];

const domainLegendItems = [
  { type: 'DOMAIN', label: 'Domain', color: '#66c2a5' },
  { type: 'ZN_FING', label: 'Zinc finger', color: '#fc8d62' },
];

function mountPanel(props = {}) {
  return mount(ProteinLollipopControlsPanel, {
    props: {
      coloringMode: 'acmg',
      domainLegendItems,
      legendItems,
      effectLegendItems,
      ...props,
    },
  });
}

describe('ProteinLollipopControlsPanel', () => {
  it('renders the domain legend items with their labels and colors', () => {
    const wrapper = mountPanel();
    const items = wrapper.findAll('.domain-legend-item');
    expect(items).toHaveLength(2);
    expect(items[0].text()).toContain('Domain');
    expect(items[1].text()).toContain('Zinc finger');
    expect(items[0].find('.domain-dot').attributes('style')).toContain('background-color: rgb(102, 194, 165)');
  });

  it('hides the domain legend entirely when there are no domains', () => {
    const wrapper = mountPanel({ domainLegendItems: [] });
    expect(wrapper.find('.domain-legend').exists()).toBe(false);
  });

  it('marks the active coloring-mode button and emits update:coloring-mode on click', async () => {
    const wrapper = mountPanel({ coloringMode: 'effect' });
    const buttons = wrapper.findAll('.btn-group button');
    expect(buttons[0].classes()).toContain('btn-outline-secondary');
    expect(buttons[1].classes()).toContain('btn-primary');

    await buttons[0].trigger('click');
    expect(wrapper.emitted('update:coloring-mode')).toEqual([['acmg']]);
  });

  it('emits toggle-pathogenicity / select-only-pathogenicity / select-all-pathogenicity', async () => {
    const wrapper = mountPanel();
    const vusGroup = wrapper.findAll('.filter-group')[2];

    await vusGroup.find('.filter-chip').trigger('click');
    expect(wrapper.emitted('toggle-pathogenicity')).toEqual([['vus']]);

    await vusGroup.find('.only-btn').trigger('click');
    expect(wrapper.emitted('select-only-pathogenicity')).toEqual([['vus']]);

    const pathogenicityRow = wrapper.findAll('.filter-row')[0];
    await pathogenicityRow.find('.all-btn').trigger('click');
    expect(wrapper.emitted('select-all-pathogenicity')).toHaveLength(1);
  });

  it('emits toggle-effect / select-only-effect / select-all-effects', async () => {
    const wrapper = mountPanel();
    const effectRow = wrapper.findAll('.filter-row')[1];
    const frameshiftGroup = effectRow.findAll('.filter-group')[1];

    await frameshiftGroup.find('.filter-chip').trigger('click');
    expect(wrapper.emitted('toggle-effect')).toEqual([['frameshift']]);

    await frameshiftGroup.find('.only-btn').trigger('click');
    expect(wrapper.emitted('select-only-effect')).toEqual([['frameshift']]);

    await effectRow.find('.all-btn').trigger('click');
    expect(wrapper.emitted('select-all-effects')).toHaveLength(1);
  });

  it('renders filter counts only when greater than zero, and shows hidden state', () => {
    const wrapper = mountPanel();
    const groups = wrapper.findAll('.filter-row')[0].findAll('.filter-group');
    // Pathogenic (count 3) shows a count badge.
    expect(groups[0].find('.filter-count').exists()).toBe(true);
    expect(groups[0].find('.filter-count').text()).toBe('3');
    // Likely pathogenic (count 0) does not.
    expect(groups[1].find('.filter-count').exists()).toBe(false);
    // VUS (visible: false) renders as a hidden chip.
    expect(groups[2].find('.filter-chip').classes()).toContain('filter-chip--hidden');
    expect(groups[2].find('.filter-chip').attributes('aria-pressed')).toBe('false');
  });

  it('emits download-svg and download-png when the export buttons are clicked', async () => {
    const wrapper = mountPanel();
    await wrapper.find('button[title="Download as SVG"]').trigger('click');
    expect(wrapper.emitted('download-svg')).toHaveLength(1);

    await wrapper.find('button[title="Download as PNG"]').trigger('click');
    expect(wrapper.emitted('download-png')).toHaveLength(1);
  });

  describe('condition filter chips', () => {
    const conditionLegendItems = [
      { condition: 'Noonan syndrome 1', visible: true, count: 12 },
      { condition: 'Metachondromatosis', visible: false, count: 5 },
      { condition: 'LEOPARD syndrome 1', visible: true, count: 3 },
    ];

    it('hides the condition filter row when conditionLegendItems is empty or omitted', () => {
      const wrapper = mountPanel();
      expect(wrapper.find('.condition-filter-row').exists()).toBe(false);

      const wrapperEmpty = mountPanel({ conditionLegendItems: [] });
      expect(wrapperEmpty.find('.condition-filter-row').exists()).toBe(false);
    });

    it('renders condition chips and emits toggle-condition, select-only-condition, select-all-conditions', async () => {
      const wrapper = mountPanel({ conditionLegendItems });
      const conditionRow = wrapper.find('.condition-filter-row');
      expect(conditionRow.exists()).toBe(true);

      const groups = conditionRow.findAll('.filter-group');
      expect(groups).toHaveLength(3);

      // First chip: Noonan syndrome 1 (count: 12, visible: true)
      expect(groups[0].text()).toContain('Noonan syndrome 1');
      expect(groups[0].find('.filter-count').text()).toBe('12');

      // Second chip: Metachondromatosis (visible: false)
      expect(groups[1].find('.filter-chip').classes()).toContain('filter-chip--hidden');

      // Click first chip -> toggle-condition
      await groups[0].find('.filter-chip').trigger('click');
      expect(wrapper.emitted('toggle-condition')).toEqual([['Noonan syndrome 1']]);

      // Click "only" button on second chip -> select-only-condition
      await groups[1].find('.only-btn').trigger('click');
      expect(wrapper.emitted('select-only-condition')).toEqual([['Metachondromatosis']]);

      // Click "all" button on condition row -> select-all-conditions
      await conditionRow.find('.all-btn').trigger('click');
      expect(wrapper.emitted('select-all-conditions')).toHaveLength(1);
    });

    it('shows more/fewer button when there are more than 8 conditions', async () => {
      const manyConditions = Array.from({ length: 12 }, (_, i) => ({
        condition: `Condition ${i + 1}`,
        visible: true,
        count: i + 1,
      }));

      const wrapper = mountPanel({ conditionLegendItems: manyConditions });
      const toggleBtn = wrapper.find('.toggle-all-conditions-btn');
      expect(toggleBtn.exists()).toBe(true);
      expect(toggleBtn.text()).toContain('+7 more');

      // Initially only 5 groups rendered (MAX_VISIBLE_CONDITIONS = 5)
      expect(wrapper.find('.condition-filter-row').findAll('.filter-group')).toHaveLength(5);

      // Click show all
      await toggleBtn.trigger('click');
      expect(wrapper.find('.condition-filter-row').findAll('.filter-group')).toHaveLength(12);
      expect(toggleBtn.text()).toContain('less');
    });
  });
});

