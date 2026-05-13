import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import LogMobileRows from './LogMobileRows.vue';

describe('LogMobileRows', () => {
  it('renders log request details and emits view for the selected entry', async () => {
    const item = {
      id: 42,
      timestamp: '2026-05-01T10:30:00Z',
      request_method: 'POST',
      status: 500,
      path: '/api/entity',
      query: '?id=1',
      duration: 1250,
      address: '127.0.0.1',
      agent: 'Vitest agent',
    };

    const wrapper = mount(LogMobileRows, {
      props: { items: [item] },
    });

    expect(wrapper.text()).toContain('#42');
    expect(wrapper.text()).toContain('POST');
    expect(wrapper.text()).toContain('500');
    expect(wrapper.text()).toContain('/api/entity');
    expect(wrapper.text()).toContain('1.25s');

    await wrapper.get('button[aria-label="View log 42 details"]').trigger('click');

    expect(wrapper.emitted('view')).toEqual([[item]]);
  });
});
