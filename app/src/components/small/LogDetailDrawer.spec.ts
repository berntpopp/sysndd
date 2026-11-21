import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import LogDetailDrawer from './LogDetailDrawer.vue';

const stubs = {
  BModal: { template: '<div><slot name="header" /><slot /><slot name="footer" /></div>' },
  BBadge: { template: '<span><slot /></span>' },
  BButton: { template: '<button><slot /></button>' },
  BCollapse: { template: '<div><slot /></div>' },
};

describe('LogDetailDrawer', () => {
  it('shows the logged seconds as milliseconds and the time in UTC (ADM-03 / ADM-06)', () => {
    const wrapper = mount(LogDetailDrawer, {
      props: {
        modelValue: true,
        log: { id: 9, duration: 0.039, timestamp: '2026-11-21 13:19:00', status: 200 },
      },
      global: { stubs, directives: { bTooltip: {} } },
    });

    expect(wrapper.text()).toContain('39 ms');
    expect(wrapper.text()).not.toContain('0.039ms');
    expect(wrapper.text()).toContain('Nov 21, 2026, 13:19:00 UTC');
  });
});
