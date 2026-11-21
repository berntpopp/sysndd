import { describe, expect, it, vi } from 'vitest';

vi.mock('@unhead/vue', () => ({ useHead: vi.fn() }));
vi.mock('@/composables/useToast', () => ({ default: () => ({ makeToast: vi.fn() }) }));

import HomeView from './HomeView.vue';

type Options = {
  computed: { last_update: (this: unknown) => string };
  methods: { notifyDeniedAccess: (this: unknown) => void };
};
const opts = HomeView as unknown as Options;

describe('HomeView', () => {
  it('shows the last update in the long date format, not the browser locale', () => {
    const value = opts.computed.last_update.call({
      entity_statistics: { meta: [{ last_update: '2025-11-12 09:30:00' }] },
    });
    expect(value).toBe('November 12, 2025');
  });

  it('explains a role redirect from the route guard and clears the query', () => {
    const makeToast = vi.fn();
    const replace = vi.fn();
    opts.methods.notifyDeniedAccess.call({
      $route: { query: { denied: '/ApproveReview', role: 'Curator' } },
      $router: { replace },
      makeToast,
    });
    expect(makeToast).toHaveBeenCalledWith(
      'Opening /ApproveReview needs the Curator role.',
      'Access restricted',
      'warning'
    );
    expect(replace).toHaveBeenCalledWith({ query: {} });
  });

  it('ignores a crafted query that would put arbitrary text in the toast', () => {
    const makeToast = vi.fn();
    const replace = vi.fn();
    for (const query of [
      { denied: '/User', role: 'Owner. Call +1 555 0100 to unlock' },
      { denied: 'Your account is locked, call 555 0100', role: 'Curator' },
    ]) {
      opts.methods.notifyDeniedAccess.call({ $route: { query }, $router: { replace }, makeToast });
    }
    expect(makeToast).not.toHaveBeenCalled();
  });

  it('does nothing on a normal visit', () => {
    const makeToast = vi.fn();
    opts.methods.notifyDeniedAccess.call({ $route: { query: {} }, $router: {}, makeToast });
    expect(makeToast).not.toHaveBeenCalled();
  });
});
