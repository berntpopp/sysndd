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
});
