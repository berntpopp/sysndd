import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import InlineHelpBadge from './InlineHelpBadge.vue';

describe('InlineHelpBadge', () => {
  it('renders a consistent accessible inline help trigger', () => {
    const wrapper = mount(InlineHelpBadge, {
      props: {
        id: 'help-target',
        'aria-label': 'Explain this view',
      },
      global: {
        stubs: {
          BBadge: {
            props: ['id', 'tag', 'type'],
            template:
              '<component :is="tag || \'span\'" :id="id" :type="type" class="inline-help-badge" v-bind="$attrs"><slot /></component>',
          },
        },
      },
    });

    const badge = wrapper.get('#help-target');
    expect(badge.attributes('aria-label')).toBe('Explain this view');
    expect(badge.classes()).toContain('inline-help-badge');
    expect(wrapper.get('i').classes()).toContain('bi-question-circle-fill');
  });

  it('forwards tooltip attributes without rendering navigational hrefs', () => {
    const wrapper = mount(InlineHelpBadge, {
      props: {
        id: 'tooltip-target',
        title: 'Explain UpSet plot',
      },
      global: {
        stubs: {
          BBadge: {
            props: ['id', 'tag', 'type'],
            template:
              '<component :is="tag || \'span\'" :id="id" :type="type" class="inline-help-badge" v-bind="$attrs"><slot /></component>',
          },
        },
      },
    });

    const badge = wrapper.get('#tooltip-target');
    expect(badge.element.tagName).toBe('BUTTON');
    expect(badge.attributes('type')).toBe('button');
    expect(badge.attributes('title')).toBe('Explain UpSet plot');
    expect(badge.attributes('href')).toBeUndefined();
  });
});
