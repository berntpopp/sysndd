// test-utils/mount-helpers.ts
/**
 * Mount helpers for consistent component testing.
 * Provides pre-configured mounting with common plugins and stubs.
 */

import { mount, type MountingOptions, type VueWrapper } from '@vue/test-utils';
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router';
import { createPinia } from 'pinia';
import type { DefineComponent } from 'vue';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyComponent = DefineComponent<any, any, any>;

/**
 * Default route for tests that need vue-router
 */
const defaultRoutes: RouteRecordRaw[] = [
  { path: '/', name: 'Home', component: { template: '<div>Home</div>' } },
  { path: '/test', name: 'Test', component: { template: '<div>Test</div>' } },
];

/**
 * Creates a router instance for testing
 */
export function createTestRouter(routes: RouteRecordRaw[] = defaultRoutes) {
  return createRouter({
    history: createWebHistory(),
    routes,
  });
}

/**
 * Mount a component with router plugin
 *
 * @example
 * const wrapper = await mountWithRouter(Navbar);
 * expect(wrapper.find('nav').exists()).toBe(true);
 */
export async function mountWithRouter(
  component: AnyComponent,
  options: MountingOptions<AnyComponent> = {}
): Promise<VueWrapper> {
  const router = createTestRouter();
  await router.push('/');
  await router.isReady();

  return mount(component, {
    global: {
      plugins: [router],
      ...options.global,
    },
    ...options,
  });
}

/**
 * Mount a component with Pinia store plugin
 *
 * @example
 * const wrapper = mountWithStore(MyComponent);
 */
export function mountWithStore(
  component: AnyComponent,
  options: MountingOptions<AnyComponent> = {}
): VueWrapper {
  const pinia = createPinia();

  return mount(component, {
    global: {
      plugins: [pinia],
      ...options.global,
    },
    ...options,
  });
}

/**
 * Mount a component with both router and store
 *
 * @example
 * const wrapper = await mountWithPlugins(MyComponent, {
 *   props: { foo: 'bar' }
 * });
 */
export async function mountWithPlugins(
  component: AnyComponent,
  options: MountingOptions<AnyComponent> = {}
): Promise<VueWrapper> {
  const router = createTestRouter();
  const pinia = createPinia();

  await router.push('/');
  await router.isReady();

  return mount(component, {
    global: {
      plugins: [router, pinia],
      ...options.global,
    },
    ...options,
  });
}

/**
 * Common stubs for Bootstrap-Vue-Next components
 * Use when you don't need actual Bootstrap component behavior
 */
export const bootstrapStubs = {
  BNavbar: { template: '<nav><slot /></nav>' },
  BNavbarBrand: { template: '<a><slot /></a>' },
  BNavbarToggle: { template: '<button />' },
  BNavbarNav: { template: '<ul><slot /></ul>' },
  BNavItem: { template: '<li><slot /></li>' },
  BCollapse: { template: '<div><slot /></div>' },
  BDropdown: { template: '<div class="dropdown"><slot /><slot name="button-content" /></div>' },
  BDropdownItem: { template: '<a><slot /></a>' },
  BButton: { template: '<button><slot /></button>' },
  BAlert: { template: '<div role="alert"><slot /></div>' },
  BContainer: { template: '<div><slot /></div>' },
  BRow: { template: '<div><slot /></div>' },
  BCol: { template: '<div><slot /></div>' },
  BLink: { template: '<a><slot /></a>' },
};

export default {
  withSetup: () => {
    throw new Error('Import withSetup from @/test-utils/with-setup');
  },
  createTestRouter,
  mountWithRouter,
  mountWithStore,
  mountWithPlugins,
  bootstrapStubs,
};
