import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import UserSecurityPanel from './UserSecurityPanel.vue';

describe('UserSecurityPanel', () => {
  // CUR-19: label and timer ran together as "Auto-logout in58m 46s".
  it('puts the countdown on its own line under a readable label', () => {
    const wrapper = mount(UserSecurityPanel, {
      props: { timeRemaining: '58m 46s', sessionTimerClass: '', passwordVisible: false },
      global: { stubs: { BButton: { template: '<button><slot /></button>' }, BCollapse: true } },
    });
    expect(wrapper.get('.session-label').text()).toBe('Signs out in');
    expect(wrapper.get('.session-timer').text()).toBe('58m 46s');
  });
});
