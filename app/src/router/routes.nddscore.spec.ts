import { describe, expect, it, vi } from 'vitest';

vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    isAuthenticated: { value: true },
    isExpired: { value: false },
    hasRole: (role: string) => role === 'Administrator',
  }),
}));

import { routes } from './routes';
import { DROPDOWN_ITEMS_LEFT } from '@/assets/js/constants/main_nav_constants';

describe('NDDScore navigation + routes', () => {
  it('adds a public NDDScore dropdown between Analyses and Help', () => {
    const ids = DROPDOWN_ITEMS_LEFT.map((d) => d.id);
    const idxScore = ids.indexOf('ndd_score_dropdown');
    expect(idxScore).toBeGreaterThan(ids.indexOf('analyses_dropdown'));
    expect(idxScore).toBeLessThan(ids.indexOf('help_dropdown'));
    const dd = DROPDOWN_ITEMS_LEFT[idxScore];
    expect(dd.required).toEqual(['']);
    expect(dd.items.some((i) => i.path === '/NDDScore')).toBe(true);
  });

  it('keeps MCP documentation in the public Help dropdown', () => {
    const help = DROPDOWN_ITEMS_LEFT.find((d) => d.id === 'help_dropdown');

    expect(help?.items.some((i) => i.text === 'MCP' && i.path === '/mcp')).toBe(true);
  });

  it('registers a public /NDDScore route with child routes', () => {
    const score = routes.find((r) => r.path === '/NDDScore');
    expect(score).toBeDefined();
    expect(score?.beforeEnter).toBeUndefined();
    expect(score?.component).toBeDefined();
    const childPaths = (score?.children ?? []).map((c) => c.path);
    expect(childPaths).toContain('');
    expect(childPaths).not.toContain('PhenotypePredictions');
    expect(childPaths).toContain('ModelCard');
    expect(childPaths).toContain('Gene/:hgncIdOrSymbol');
  });

  it('registers an Administrator-guarded /ManageNDDScore route', () => {
    const manage = routes.find((r) => r.path === '/ManageNDDScore');
    expect(manage).toBeDefined();
    expect(typeof manage?.beforeEnter).toBe('function');
  });
});
