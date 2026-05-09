import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import GeneConstraintCard from './GeneConstraintCard.vue';

const constraintsJson = JSON.stringify({
  exp_syn: 100.2,
  obs_syn: 98,
  syn_z: 0.11,
  oe_syn: 0.98,
  oe_syn_lower: 0.82,
  oe_syn_upper: 1.17,
  exp_mis: 255.5,
  obs_mis: 140,
  mis_z: 4.75,
  oe_mis: 0.55,
  oe_mis_lower: 0.47,
  oe_mis_upper: 0.65,
  exp_lof: 32.2,
  obs_lof: 3,
  lof_z: 5.9,
  oe_lof: 0.09,
  oe_lof_lower: 0.03,
  oe_lof_upper: 0.25,
  pLI: 1,
});

function mountCard(props: { geneSymbol?: string; constraintsJson: string | null }) {
  return mount(GeneConstraintCard, {
    props: {
      geneSymbol: props.geneSymbol ?? 'NAA10',
      constraintsJson: props.constraintsJson,
    },
  });
}

describe('GeneConstraintCard', () => {
  it('keeps the no-data state and gnomAD link visible for null constraints', () => {
    const wrapper = mountCard({ constraintsJson: null });

    expect(wrapper.find('.constraint-empty-state').exists()).toBe(true);
    expect(wrapper.text()).toContain('No gnomAD constraint data available for this gene.');

    const link = wrapper.get('a[aria-label="View gene on gnomAD (opens in new tab)"]');
    expect(link.attributes('href')).toBe('https://gnomad.broadinstitute.org/gene/NAA10');
  });

  it('renders constraint metric labels and values for populated constraints', () => {
    const wrapper = mountCard({ constraintsJson });

    expect(wrapper.text()).toContain('Synonymous');
    expect(wrapper.text()).toContain('Missense');
    expect(wrapper.text()).toContain('pLoF');
    expect(wrapper.text()).toContain('Exp / Obs');
    expect(wrapper.text()).toContain('pLI');
    expect(wrapper.text()).toContain('100.2');
    expect(wrapper.text()).toContain('98');
    expect(wrapper.text()).toContain('255.5');
    expect(wrapper.text()).toContain('140');
    expect(wrapper.text()).toContain('32.2');
    expect(wrapper.text()).toContain('3');
    expect(wrapper.text()).toContain('1.00');
  });

  it('uses a compact constraint matrix instead of tall metric cards or a table', () => {
    const wrapper = mountCard({ constraintsJson });

    expect(wrapper.find('.constraint-matrix').exists()).toBe(true);
    expect(wrapper.findAll('.constraint-matrix-row')).toHaveLength(3);
    expect(wrapper.find('.constraint-metric-row').exists()).toBe(false);
    expect(wrapper.find('table').exists()).toBe(false);
    expect(wrapper.text()).toContain('Exp / Obs');
    expect(wrapper.text()).toContain('o/e (90% CI)');
  });

  it('renders incomplete constraint payloads without NaN SVG attributes', () => {
    const wrapper = mountCard({ constraintsJson: '{}' });

    expect(wrapper.findAll('.constraint-matrix-row')).toHaveLength(3);
    expect(wrapper.text()).toContain('N/A');
    expect(wrapper.html()).not.toContain('NaN');

    const svgs = wrapper.findAll('svg[role="img"]');
    expect(svgs).toHaveLength(3);
    svgs.forEach((svg) => {
      expect(svg.attributes('aria-label')).toContain('data unavailable');
      expect(svg.findAll('rect')).toHaveLength(1);
      expect(svg.find('circle').exists()).toBe(false);
    });
  });

  it('keeps populated constraint values in high-contrast compact cells', () => {
    const wrapper = mountCard({ constraintsJson });

    expect(wrapper.find('.constraint-card--compact').exists()).toBe(true);
    expect(wrapper.findAll('.constraint-value').length).toBeGreaterThan(0);
    expect(wrapper.findAll('.constraint-label').length).toBeGreaterThan(0);
    expect(wrapper.find('.text-muted').exists()).toBe(false);
  });

  it('labels CI SVGs on the parent image and hides raw shapes from assistive tech', () => {
    const wrapper = mountCard({ constraintsJson });

    const svgs = wrapper.findAll('svg[role="img"]');
    expect(svgs).toHaveLength(3);
    svgs.forEach((svg) => {
      expect(svg.attributes('aria-label')).toMatch(/observed\/expected ratio/i);
    });

    const rawShapes = wrapper.findAll('rect,circle');
    expect(rawShapes.length).toBeGreaterThan(0);
    rawShapes.forEach((shape) => {
      expect(shape.attributes('aria-label')).toBeUndefined();
      expect(shape.attributes('aria-hidden')).toBe('true');
    });
  });
});
