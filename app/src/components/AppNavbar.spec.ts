import { mount } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { createRouter, createWebHistory } from 'vue-router';
import { describe, expect, it, vi } from 'vitest';
import AppNavbar from './AppNavbar.vue';

vi.mock('@/api/auth', () => ({
  signin: vi.fn(),
}));

const mountNavbar = async () => {
  const router = createRouter({
    history: createWebHistory(),
    routes: [{ path: '/', name: 'Home', component: { template: '<div />' } }],
  });

  await router.push('/');
  await router.isReady();

  return mount(AppNavbar, {
    global: {
      plugins: [router, createPinia()],
      stubs: {
        BNavbar: {
          props: ['toggleable', 'type', 'variant', 'fixed'],
          template: '<nav class="navbar-stub" v-bind="$attrs"><slot /></nav>',
        },
        BNavbarBrand: {
          props: ['to'],
          template: '<a class="navbar-brand-stub"><slot /></a>',
        },
        BNavbarToggle: {
          props: ['target'],
          template: '<button class="navbar-toggler-stub" :aria-controls="target" />',
        },
        BCollapse: {
          props: ['id', 'modelValue', 'isNav'],
          template: '<div :id="id" class="collapse-stub"><slot /></div>',
        },
        BNavbarNav: {
          template: '<ul class="navbar-nav-stub"><slot /></ul>',
        },
        BNavItem: {
          props: ['to'],
          template: '<li><a class="nav-link-stub"><slot /></a></li>',
        },
        IconPairDropdownMenu: {
          props: ['title'],
          template:
            '<li class="chrome-nav-menu"><button class="chrome-nav-trigger">{{ title }}</button></li>',
        },
        SearchCombobox: {
          template: '<div class="search-combobox-stub" />',
        },
      },
    },
  });
};

describe('AppNavbar', () => {
  it('keeps the SysNDD logo while using compact modern app chrome classes', async () => {
    const wrapper = await mountNavbar();

    const logo = wrapper.get('img.app-logo');
    expect(logo.attributes('src')).toBe('/SysNDD_brain-dna-magnifying-glass_dall-e_logo.webp');
    expect(wrapper.find('.app-navbar').exists()).toBe(true);
    expect(wrapper.get('.brand-container').classes()).toContain('brand-container--compact');
    expect(wrapper.get('.app-name').text()).toBe('SysNDD');
  });

  it('exposes main navigation as modern chrome triggers', async () => {
    const wrapper = await mountNavbar();

    const triggers = wrapper.findAll('.chrome-nav-trigger').map((trigger) => trigger.text());
    expect(triggers).toEqual(['Tables', 'Analyses', 'Help']);
  });
});
