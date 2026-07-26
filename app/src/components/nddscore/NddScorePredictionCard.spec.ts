import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import NddScorePredictionCard from './NddScorePredictionCard.vue';

const source = readFileSync(
  resolve(process.cwd(), 'src/components/nddscore/NddScorePredictionCard.vue'),
  'utf8'
);

describe('NddScorePredictionCard', () => {
  const props = {
    releaseId: 'nddscore_20260517_public',
    versionDoi: '10.5281/zenodo.20258027',
    testAucRoc: 0.8877,
    brierSkillScore: 0.4438,
  };

  it('renders a warning-toned ML prediction disclosure, not an AI label', () => {
    const wrapper = mount(NddScorePredictionCard, { props });
    expect(wrapper.text()).toContain('ML prediction');
    expect(wrapper.text()).toContain('Machine learning, not manual curation');
    expect(wrapper.find('.bi-stars').exists()).toBe(true);
    expect(wrapper.classes()).toContain('ndd-score-card--ml-disclosure');
    expect(wrapper.attributes('role')).toBe('note');
    expect(wrapper.attributes('aria-label')).toBe('Machine-learning prediction warning');
    expect(wrapper.text()).not.toContain('AI');
  });

  it('uses a bounded warning surface without a decorative side accent', () => {
    const warningRule =
      source.match(/\.ndd-score-card--ml-disclosure\s*\{([\s\S]*?)\}/)?.[1] ?? '';

    expect(warningRule).toContain('background-color: var(--surface-warning);');
    expect(warningRule).toContain('border-color: var(--border-subtle);');
    expect(warningRule).not.toMatch(/border-(?:left|right)\s*:|linear-gradient/i);
  });

  it('shows the mandated separation disclaimer', () => {
    const wrapper = mount(NddScorePredictionCard, { props });
    const text = wrapper.text();
    expect(text).toContain('model-derived prediction layer');
    expect(text).toContain('not curated SysNDD evidence');
    expect(text).toContain('not part of curated classification');
  });

  it('renders the performance strip and release identity', () => {
    const wrapper = mount(NddScorePredictionCard, { props });
    expect(wrapper.text()).toContain('nddscore_20260517_public');
    expect(wrapper.get('a').attributes('href')).toContain('10.5281/zenodo.20258027');
  });
});
