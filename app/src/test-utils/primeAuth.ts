// app/src/test-utils/primeAuth.ts
/**
 * Shared test helper for v11.0 closeout F2 worktrees.
 *
 * Seed the `useAuth` composable with a session for a single test. Call in
 * `beforeEach` or inline before an authed request. The spec's `afterEach`
 * should call `useAuth().logout()` (or rely on `vitest.setup.ts` clearing
 * `localStorage` between tests) to reset.
 *
 * NOT `localStorage.setItem` — research-aligned: use the abstraction seam,
 * not the storage backend. See
 * `.planning/superpowers/specs/2026-04-14-v11.0-closeout-design.md` §5.2.
 */

import { useAuth } from '@/composables/useAuth';
import type { UserPayload } from '@/composables/useAuth';

const DEFAULT_USER: UserPayload = {
  user_id: [1],
  user_name: ['test-admin'],
  email: ['test@sysndd.local'],
  user_role: ['Administrator'],
  user_created: ['2024-01-01'],
  abbreviation: ['TA'],
  orcid: [''],
  exp: [Math.floor(Date.now() / 1000) + 3600],
};

/**
 * Seed `useAuth` with a test session. Returns the seeded token + user so
 * the spec can assert against the exact values it planted.
 */
export function primeAuth(
  token: string = 'test-token',
  user: UserPayload = DEFAULT_USER
): { token: string; user: UserPayload } {
  useAuth().login(token, user);
  return { token, user };
}
