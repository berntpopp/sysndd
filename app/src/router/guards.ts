// src/router/guards.ts
//
// Route-guard factory and lazy-component helpers extracted from routes.ts to
// keep the route table under the 600-line code-quality ceiling. These are the
// cross-cutting routing helpers; the route records themselves live in routes.ts.

import type { RouteLocationNormalized, RouteComponent } from 'vue-router';
import { useAuth } from '@/composables/useAuth';

/**
 * Role-based route-guard factory (Phase E.E7).
 *
 * Replaces an 18x-duplicated pattern that hand-parsed `localStorage.token`
 * and `localStorage.user` inside every `beforeEnter` hook. The new flow
 * delegates every auth decision to the `useAuth()` composable:
 *
 *   - `isAuthenticated` covers the "have both token and user" check that
 *     the old guards wrote as `!localStorage.user`.
 *   - `isExpired` replaces the inline `timestamp > expires` comparison
 *     (and picks up the corrupt-payload handling in `useAuth` for free —
 *     a bad JSON blob now fails closed to logged-out instead of throwing
 *     inside navigation).
 *   - `hasRole(role)` unwraps the R/Plumber scalar-array (`user_role[0]`)
 *     that the old guards did inline.
 *
 * Each call site still supplies its own `allowed_roles` list; behaviour is
 * otherwise identical to the pre-refactor guards.
 */
export function createAuthGuard(allowed_roles: readonly string[]) {
  return (_to: RouteLocationNormalized, _from: RouteLocationNormalized) => {
    const { isAuthenticated, isExpired, hasRole } = useAuth();
    const isAllowed = allowed_roles.some((role) => hasRole(role));
    if (!isAuthenticated.value || isExpired.value || !isAllowed) {
      return { name: 'Login' as const };
    }
    return true;
  };
}

export const nddScoreComponents = import.meta.glob('../components/nddscore/*.vue');
export const adminViews = import.meta.glob('../views/admin/*.vue');

export const lazyRouteComponent = (
  modules: Record<string, () => Promise<unknown>>,
  path: string
): (() => Promise<RouteComponent>) => {
  const component = modules[path];
  if (!component) {
    throw new Error(`Route component not found: ${path}`);
  }
  return component as () => Promise<RouteComponent>;
};
