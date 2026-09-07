// app/src/components/gene/ProteinLollipopSkeleton.spec.ts
import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import ProteinLollipopSkeleton from './ProteinLollipopSkeleton.vue';

describe('ProteinLollipopSkeleton', () => {
  it('renders with accessible loading attributes', () => {
    const wrapper = mount(ProteinLollipopSkeleton);
    const root = wrapper.find('[role="status"]');
    expect(root.exists()).toBe(true);
    expect(root.attributes('aria-label')).toBe('Loading protein domain and variant visualization');
    expect(wrapper.text()).toContain('Loading protein domain and variant visualization...');
  });

  it('renders backbone, stem, and controls placeholders', () => {
    const wrapper = mount(ProteinLollipopSkeleton);
    expect(wrapper.find('.skeleton-backbone').exists()).toBe(true);
    expect(wrapper.findAll('.skeleton-stem-wrapper').length).toBe(10);
    expect(wrapper.find('.skeleton-controls-strip').exists()).toBe(true);
  });
});
