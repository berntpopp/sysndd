import { mount } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { createRouter, createWebHistory } from 'vue-router';
import { nextTick } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { signin } from '@/api/auth';
import { useAuth } from '@/composables/useAuth';
import AppNavbar from './AppNavbar.vue';

vi.mock('@/api/auth', () => ({
  signin: vi.fn(),
}));

const mountNavbar = async (initialPath = '/') => {
  const router = createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/', name: 'Home', component: { template: '<div />' } },
      { path: '/Genes/:symbol', name: 'GenesDetail', component: { template: '<div />' } },
    ],
  });

  await router.push(initialPath);
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
          template:
            '<button class="navbar-toggler-stub" :aria-controls="target" v-bind="$attrs" />',
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
  beforeEach(() => {
    useAuth().logout();
    localStorage.clear();
    vi.mocked(signin).mockReset();
  });

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
    expect(triggers).toEqual(['Tables', 'Analyses', 'NDDScore', 'Help']);
  });

  it('labels the collapsed navigation trigger for mobile and assistive tech', async () => {
    const wrapper = await mountNavbar();

    const toggle = wrapper.get('.navbar-toggler-stub');
    expect(toggle.attributes('aria-label')).toBe('Open navigation menu');
    expect(toggle.attributes('aria-expanded')).toBe('false');
  });

  it('shows navbar search on direct non-home route loads', async () => {
    const wrapper = await mountNavbar('/Genes/ARID1B');

    expect(wrapper.find('.app-navbar__search .search-combobox-stub').exists()).toBe(true);
    expect(wrapper.find('.app-navbar__mobile-search .search-combobox-stub').exists()).toBe(true);
  });

  it('shows admin menus from the persisted auth payload while JWT validation is still pending', async () => {
    localStorage.setItem('token', 'admin-token');
    localStorage.setItem(
      'user',
      JSON.stringify({
        user_id: [3],
        user_name: ['Christiane'],
        email: ['christiane.zweier@insel.ch'],
        user_role: ['Administrator'],
        user_created: ['2022-06-09'],
        abbreviation: ['CZ'],
        orcid: ['0000-0001-8002-2020'],
        exp: [Math.floor(Date.now() / 1000) + 3600],
      })
    );
    vi.mocked(signin).mockReturnValue(new Promise(() => {}));

    const wrapper = await mountNavbar();

    const triggers = wrapper.findAll('.chrome-nav-trigger').map((trigger) => trigger.text());
    expect(triggers).toContain('Administration');
    expect(triggers).toContain('Curation');
    expect(triggers).toContain('Review');
    expect(triggers).toContain('Christiane');
  });

  it('updates role-gated menus immediately after login without a route reload', async () => {
    vi.mocked(signin).mockReturnValue(new Promise(() => {}));
    const wrapper = await mountNavbar();

    expect(wrapper.findAll('.chrome-nav-trigger').map((trigger) => trigger.text())).not.toContain(
      'Administration'
    );

    useAuth().login('admin-token', {
      user_id: [3],
      user_name: ['Christiane'],
      email: ['christiane.zweier@insel.ch'],
      user_role: ['Administrator'],
      user_created: ['2022-06-09'],
      abbreviation: ['CZ'],
      orcid: ['0000-0001-8002-2020'],
      exp: [Math.floor(Date.now() / 1000) + 3600],
    });
    await nextTick();
    await nextTick();

    const triggers = wrapper.findAll('.chrome-nav-trigger').map((trigger) => trigger.text());
    expect(triggers).toContain('Administration');
    expect(triggers).toContain('Curation');
    expect(triggers).toContain('Review');
    expect(triggers).toContain('Christiane');
  });
});
