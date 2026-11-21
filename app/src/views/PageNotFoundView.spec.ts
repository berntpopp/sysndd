import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import PageNotFoundView from './PageNotFoundView.vue';

describe('PageNotFoundView', () => {
  it('names the problem and links back home', () => {
    const wrapper = mount(PageNotFoundView, {
      global: {
        stubs: {
          RouterLink: { props: ['to'], template: '<a :href="to"><slot /></a>' },
        },
      },
    });
    expect(wrapper.get('h1').text()).toBe('Page not found');
    const home = wrapper.findAll('a').find((a) => a.text() === 'Go to home');
    expect(home?.attributes('href')).toBe('/');
  });
});
