import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import AuthenticatedPageShell from './AuthenticatedPageShell.vue';

describe('AuthenticatedPageShell', () => {
  it('renders route heading, meta, actions, and content slots', () => {
    const wrapper = mount(AuthenticatedPageShell, {
      props: {
        title: 'Review queue',
        description: 'Assigned entities needing re-review.',
        meta: '27 entities',
      },
      slots: {
        actions: '<button class="test-action">Refresh</button>',
        default: '<div class="test-content">Queue table</div>',
      },
    });

    expect(wrapper.find('.authenticated-page').exists()).toBe(true);
    expect(wrapper.find('.authenticated-frame').exists()).toBe(true);
    expect(wrapper.get('h1').text()).toBe('Review queue');
    expect(wrapper.get('.authenticated-description').text()).toBe(
      'Assigned entities needing re-review.'
    );
    expect(wrapper.get('.authenticated-meta').text()).toBe('27 entities');
    expect(wrapper.get('.test-action').text()).toBe('Refresh');
    expect(wrapper.get('.test-content').text()).toBe('Queue table');
  });

  it('applies optional content class to the content area', () => {
    const wrapper = mount(AuthenticatedPageShell, {
      props: {
        title: 'Profile',
        contentClass: 'profile-layout',
      },
    });

    expect(wrapper.get('.authenticated-content').classes()).toContain('profile-layout');
  });
});
