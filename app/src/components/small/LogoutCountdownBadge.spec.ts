import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import { afterEach, describe, expect, it, vi } from 'vitest';
import LogoutCountdownBadge from './LogoutCountdownBadge.vue';

const makeToast = vi.fn();
vi.mock('@/composables/useToast', () => ({ default: () => ({ makeToast }) }));

const NOW = 1_800_000_000;
vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    isAuthenticated: ref(true),
    user: ref({ exp: [NOW + 301] }),
    token: ref('t'),
    logout: vi.fn(),
    login: vi.fn(),
    refresh: vi.fn(),
  }),
}));

describe('LogoutCountdownBadge', () => {
  afterEach(() => vi.useRealTimers());

  it('warns with a toast when the session reaches a warning point', () => {
    vi.useFakeTimers();
    vi.setSystemTime(NOW * 1000);
    const wrapper = mount(LogoutCountdownBadge, { global: { stubs: { BBadge: true } } });

    vi.advanceTimersByTime(1000); // 300 s left

    expect(makeToast).toHaveBeenCalledWith(
      expect.stringContaining('5 min'),
      'Session ending soon',
      'warning'
    );
    wrapper.unmount();
  });
});
