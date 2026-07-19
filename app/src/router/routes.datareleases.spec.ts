import { describe, expect, it, vi } from 'vitest';

vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    isAuthenticated: { value: true },
    isExpired: { value: false },
    hasRole: (role: string) => role === 'Administrator',
  }),
}));

import { routes } from './routes';
import {
  DROPDOWN_ITEMS_LEFT,
  DROPDOWN_ITEMS_RIGHT,
} from '@/assets/js/constants/main_nav_constants';

describe('Data releases navigation + routes', () => {
  it('adds a Data releases item to the public Analyses dropdown', () => {
    const analyses = DROPDOWN_ITEMS_LEFT.find((d) => d.id === 'analyses_dropdown');

    expect(
      analyses?.items.some((i) => i.text === 'Data releases' && i.path === '/DataReleases')
    ).toBe(true);
  });

  it('registers a public /DataReleases route', () => {
    const dataReleases = routes.find((r) => r.path === '/DataReleases');

    expect(dataReleases).toBeDefined();
    expect(dataReleases?.name).toBe('DataReleases');
    expect(dataReleases?.beforeEnter).toBeUndefined();
    expect(dataReleases?.component).toBeDefined();
    expect(dataReleases?.meta?.sitemap).toEqual({ priority: 0.7, changefreq: 'monthly' });
  });

  it('registers an Administrator-guarded /ManageAnalysisReleases route', () => {
    const manage = routes.find((r) => r.path === '/ManageAnalysisReleases');
    expect(manage).toBeDefined();
    expect(typeof manage?.beforeEnter).toBe('function');
  });

  it('adds a Manage releases item to the Administration dropdown', () => {
    const administration = DROPDOWN_ITEMS_RIGHT.find((d) => d.id === 'administration_dropdown');

    expect(
      administration?.items.some(
        (i) => i.text === 'Manage releases' && i.path === '/ManageAnalysisReleases'
      )
    ).toBe(true);
  });
});
