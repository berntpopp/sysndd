import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import ReviewRowCells from './ReviewRowCells.vue';

const stubs = {
  BPopover: { props: ['target', 'triggers'], template: '<div class="popover-stub" />' },
};

describe('ReviewRowCells text-popover', () => {
  // CUR-11: the truncated synopsis was a plain div, so keyboard users could not open it.
  it('renders a clamped, keyboard-focusable trigger named by its column and text', () => {
    const wrapper = mount(ReviewRowCells, {
      props: {
        kind: 'text-popover',
        text: 'A long synopsis',
        title: 'Clinical Synopsis',
        targetId: 'syn-1',
      },
      global: { stubs },
    });
    const trigger = wrapper.get('#syn-1');
    expect(trigger.classes()).toContain('text-truncate-multiline');
    expect(trigger.attributes('tabindex')).toBe('0');
    expect(trigger.attributes('role')).toBe('button');
    expect(trigger.attributes('aria-label')).toBe('Clinical Synopsis: A long synopsis');
    expect(wrapper.getComponent(stubs.BPopover).props('triggers')).toContain('focus');
  });

  it.each(['', null, 'NA'])('shows a dash for a missing text (%s)', (text) => {
    const wrapper = mount(ReviewRowCells, {
      props: { kind: 'text-popover', text, title: 'Comment', targetId: 'c-1' },
      global: { stubs },
    });
    expect(wrapper.find('#c-1').exists()).toBe(false);
    expect(wrapper.text()).toBe('—');
  });
});
