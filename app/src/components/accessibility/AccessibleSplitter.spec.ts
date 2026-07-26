import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import AccessibleSplitter from './AccessibleSplitter.vue';

function mountSplitter(size = 42) {
  return mount(AccessibleSplitter, {
    props: {
      size,
      min: 25,
      max: 75,
      orientation: 'vertical',
      label: 'Resize gene network and cluster table',
      'onUpdate:size': () => {},
    },
    slots: {
      first: '<div>Network</div>',
      second: '<div>Cluster table</div>',
    },
  });
}

describe('AccessibleSplitter', () => {
  it('exposes the current pane size through a named separator', () => {
    const wrapper = mountSplitter();
    const separator = wrapper.get('[role="separator"]');

    expect(separator.attributes()).toMatchObject({
      'aria-label': 'Resize gene network and cluster table',
      'aria-orientation': 'vertical',
      'aria-valuemin': '25',
      'aria-valuemax': '75',
      'aria-valuenow': '42',
      tabindex: '0',
    });
  });

  it('updates the pane size with Arrow, Home, and End keys', async () => {
    const wrapper = mountSplitter();
    const separator = wrapper.get('[role="separator"]');

    await separator.trigger('keydown', { key: 'ArrowRight' });
    await separator.trigger('keydown', { key: 'ArrowLeft' });
    await separator.trigger('keydown', { key: 'Home' });
    await separator.trigger('keydown', { key: 'End' });

    expect(wrapper.emitted('update:size')).toEqual([[44], [40], [25], [75]]);
  });
});
