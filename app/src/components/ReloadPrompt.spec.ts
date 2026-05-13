import { mount } from '@vue/test-utils';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { ref } from 'vue';
import { createRouter, createWebHistory } from 'vue-router';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import ReloadPrompt from './ReloadPrompt.vue';

const registerServiceWorker = vi.fn();
const checkForUpdate = vi.fn();
const stop = vi.fn();
const updateServiceWorker = vi.fn();
const needRefresh = ref(false);
const offlineReady = ref(false);

let registerOptions:
  | {
      onRegisteredSW?: (swUrl: string, registration: ServiceWorkerRegistration | undefined) => void;
    }
  | undefined;

vi.mock('@/composables/usePwaUpdateChecks', () => ({
  usePwaUpdateChecks: () => ({
    registerServiceWorker,
    checkForUpdate,
    stop,
  }),
}));

vi.mock('virtual:pwa-register/vue', () => ({
  useRegisterSW: vi.fn((options) => {
    registerOptions = options;
    return {
      needRefresh,
      offlineReady,
      updateServiceWorker,
    };
  }),
}));

async function mountPrompt() {
  const router = createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/Genes/:symbol', component: { template: '<div />' } },
    ],
  });

  await router.push('/');
  await router.isReady();

  const wrapper = mount(ReloadPrompt, {
    global: {
      plugins: [router],
    },
  });

  return { router, wrapper };
}

describe('ReloadPrompt', () => {
  beforeEach(() => {
    registerServiceWorker.mockReset();
    checkForUpdate.mockReset();
    stop.mockReset();
    updateServiceWorker.mockReset();
    needRefresh.value = false;
    offlineReady.value = false;
    registerOptions = undefined;
  });

  it('registers dense update checks when the service worker is registered', async () => {
    await mountPrompt();
    const registration = { update: vi.fn() } as unknown as ServiceWorkerRegistration;

    registerOptions?.onRegisteredSW?.('/sw.js', registration);

    expect(registerServiceWorker).toHaveBeenCalledWith('/sw.js', registration);
  });

  it('checks for updates on route changes after registration', async () => {
    const { router } = await mountPrompt();
    registerOptions?.onRegisteredSW?.('/sw.js', {
      update: vi.fn(),
    } as unknown as ServiceWorkerRegistration);

    await router.push('/Genes/ARID1B');

    expect(checkForUpdate).toHaveBeenCalledWith('route');
  });

  it('renders an accessible compact update prompt', async () => {
    needRefresh.value = true;
    const { wrapper } = await mountPrompt();

    expect(wrapper.get('[role="status"]').text()).toContain('New SysNDD version available');
    expect(wrapper.get('button.btn-primary').text()).toBe('Update');
  });

  it('offsets the fixed prompt above the fixed footer', () => {
    const source = readFileSync(fileURLToPath(import.meta.url).replace(/\.spec\.ts$/, '.vue'), {
      encoding: 'utf8',
    });

    expect(source).toContain('--app-footer-height');
    expect(source).toMatch(/bottom:\s*calc\(var\(--app-footer-height,\s*48px\)\s*\+\s*1rem/);
  });
});
