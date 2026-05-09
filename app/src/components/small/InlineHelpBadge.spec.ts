import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import InlineHelpBadge from './InlineHelpBadge.vue';

describe('InlineHelpBadge', () => {
  it('renders a consistent accessible inline help trigger', () => {
    const wrapper = mount(InlineHelpBadge, {
      props: {
        id: 'help-target',
        ariaLabel: 'Explain this view',
      },
      global: {
        stubs: {
          BBadge: {
            props: ['id', 'ariaLabel'],
            template: '<a :id="id" :aria-label="ariaLabel" class="inline-help-badge"><slot /></a>',
          },
        },
      },
    });

    const badge = wrapper.get('#help-target');
    expect(badge.attributes('aria-label')).toBe('Explain this view');
    expect(badge.classes()).toContain('inline-help-badge');
    expect(wrapper.get('i').classes()).toContain('bi-question-circle-fill');
  });
});
