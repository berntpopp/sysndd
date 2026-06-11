// AppVersionInfo.spec.ts
//
// Unit tests for the version-information panel (issue #22). Verifies it renders
// the app version (package.json), the API version + commit, and the database
// version + commit from the typed /api/version client, and that it degrades
// gracefully when the database block is missing or the call fails.

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';

import { getVersion } from '@/api/version';
import packageInfo from '../../package.json';
import AppVersionInfo from './AppVersionInfo.vue';

vi.mock('@/api/version', () => ({
  getVersion: vi.fn(),
}));

const bootstrapStubs = {
  BCard: { template: '<article><slot /></article>' },
  BListGroup: { template: '<ul><slot /></ul>' },
  BListGroupItem: { template: '<li><slot /></li>' },
  BBadge: { template: '<span class="badge"><slot /></span>' },
  BSpinner: { template: '<span role="status" />' },
};

function mountComponent() {
  return mount(AppVersionInfo, { global: { stubs: bootstrapStubs } });
}

describe('AppVersionInfo', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders the app version from package.json', async () => {
    vi.mocked(getVersion).mockResolvedValue({
      version: '0.20.18',
      commit: 'abcdef1',
      title: 'SysNDD API',
      description: 'desc',
    });

    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.text()).toContain(`v${packageInfo.version}`);
  });

  it('renders the API and database versions with their commits', async () => {
    vi.mocked(getVersion).mockResolvedValue({
      version: '0.20.18',
      commit: 'abcdef1',
      title: 'SysNDD API',
      description: 'desc',
      database: {
        version: '1.0.0',
        commit: '7532ab5',
        description: 'release note',
        updated_at: '2026-06-11 10:00:00',
        available: true,
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    const text = wrapper.text();
    expect(text).toContain('v0.20.18');
    expect(text).toContain('abcdef1');
    expect(text).toContain('v1.0.0');
    expect(text).toContain('7532ab5');
  });

  it('shows database as unavailable when the block is absent', async () => {
    vi.mocked(getVersion).mockResolvedValue({
      version: '0.20.18',
      commit: 'abcdef1',
      title: 'SysNDD API',
      description: 'desc',
    });

    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.text().toLowerCase()).toContain('unavailable');
  });

  it('shows database as unavailable when API marks it unavailable', async () => {
    vi.mocked(getVersion).mockResolvedValue({
      version: '0.20.18',
      commit: 'abcdef1',
      title: 'SysNDD API',
      description: 'desc',
      database: { version: 'unknown', commit: 'unknown', available: false },
    });

    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.text().toLowerCase()).toContain('unavailable');
  });

  it('degrades gracefully when the version call fails', async () => {
    vi.mocked(getVersion).mockRejectedValue(new Error('network down'));

    const wrapper = mountComponent();
    await flushPromises();

    // App version still shows; API/DB report unavailable, no thrown error.
    expect(wrapper.text()).toContain(`v${packageInfo.version}`);
    expect(wrapper.text().toLowerCase()).toContain('unavailable');
  });
});
