import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import NddScorePredictionCard from './NddScorePredictionCard.vue';

describe('NddScorePredictionCard', () => {
  const props = {
    releaseId: 'nddscore_20260517_public',
    versionDoi: '10.5281/zenodo.20258027',
    testAucRoc: 0.8877,
    brierSkillScore: 0.4438,
  };

  it('renders the ML prediction indicator, not an AI label', () => {
    const wrapper = mount(NddScorePredictionCard, { props });
    expect(wrapper.text()).toContain('ML prediction');
    expect(wrapper.find('.bi-cpu').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('AI');
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
