// useAuth.ts
// SPA-only context; localStorage is always available at module load (Vite SPA, no SSR).
/**
 * Single owner of auth / session state for the SPA (Phase E.E7).
 *
 * Before this composable landed, five call sites (`router/routes.ts`,
 * `components/AppNavbar.vue`, `components/small/LogoutCountdownBadge.vue`,
 * `views/LoginView.vue`, `views/UserView.vue`) each reached into
 * `localStorage.token` / `localStorage.user` by hand, parsed the JWT payload
 * inline, and duplicated the "Bearer ${localStorage.getItem('token')}" header
 * pattern. `useAuth()` consolidates all of that into one typed API with
 * reactive state, so the 401 interceptor in `@/plugins/axios` is the only
 * other code path that mutates these keys.
 *
 * State model (module-level singleton)
 * ------------------------------------
 * Because there is exactly one authenticated session per browser tab, the
 * reactive refs are declared at module scope. Every `useAuth()` call returns
 * references to the same underlying state, so a `logout()` from the navbar
 * is immediately visible to a route guard on the next `isAuthenticated`
 * read. On first import, state is hydrated from `localStorage` and the axios
 * default Authorization header is seeded if a token exists.
 *
 * Coordination with the axios 401 interceptor
 * -------------------------------------------
 * `@/plugins/axios` already owns the "saw a 401 → clear localStorage →
 * redirect to /Login" flow. That interceptor writes localStorage directly
 * (not through useAuth), so after an interceptor-triggered logout the
 * in-memory refs can drift. `handle401()` and `syncFromStorage()` re-read
 * localStorage so reactive state mirrors whatever the interceptor last
 * persisted. Callers that want to react to a 401 (for example, showing a
 * toast) can watch `isAuthenticated` or call `handle401()` from the
 * interceptor's catch path in a future refactor.
 *
 * Shape of the user payload
 * -------------------------
 * `/api/auth/signin` returns the R/Plumber scalar-array shape
 * (`user_role: ['Administrator']`, `exp: [1234567890]`, etc.). We preserve
 * the raw shape so every read site — route guards, badges, profile view —
 * sees the same structure they see today; only the reading mechanism
 * changes. `hasRole()` indexes into `user_role[0]` to hide this detail from
 * callers.
 *
 * Corrupted-payload resilience
 * ----------------------------
 * If a user manually corrupts `localStorage.user` (or a half-written key
 * survives a crash), `syncFromStorage()` catches `JSON.parse` failures and
 * treats the session as logged-out. Route guards therefore never throw
 * during navigation, which was the failure mode the P1 "auth state is
 * duplicated" review finding called out.
 */

import type { ComputedRef, Ref } from 'vue';
import { computed, ref } from 'vue';
import axios from 'axios';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Shape of the user payload stored in `localStorage.user` (post Phase A1).
 * Mirrors `GET /api/auth/signin` as documented in
 * `api/config/openapi/schemas/inferred/api_auth_signin_GET.json` — R/Plumber
 * wraps every scalar in a one-element array.
 *
 * The fields listed here are the ones the SPA actually reads; additional
 * fields returned by the API are tolerated (the composable does not strip
 * them).
 */
export interface UserPayload {
  user_id: number[];
  user_name: string[];
  email: string[];
  user_role: string[];
  user_created: string[];
  abbreviation: string[];
  orcid: Record<string, unknown> | string[];
  exp: number[];
  [key: string]: unknown;
}

/**
 * Return type of `useAuth()`. Keeping this exported makes it easy for
 * Options-API components to annotate their `setup()` return value.
 */
export interface UseAuthReturn {
  // State (reactive)
  token: Ref<string | null>;
  user: Ref<UserPayload | null>;

  // Derived (computed)
  isAuthenticated: ComputedRef<boolean>;
  isExpired: ComputedRef<boolean>;

  // Actions
  login: (token: string, user: UserPayload) => void;
  logout: () => void;
  refresh: () => Promise<string>;
  handle401: () => void;
  syncFromStorage: () => void;
  hasRole: (role: string) => boolean;
}

// ---------------------------------------------------------------------------
// Module-level singleton state
// ---------------------------------------------------------------------------

const TOKEN_KEY = 'token';
const USER_KEY = 'user';

const tokenRef = ref<string | null>(null);
const userRef = ref<UserPayload | null>(null);

/**
 * Parse a JSON string and return `null` on any failure. Shared by
 * `syncFromStorage()` and used to keep the parse site in one place.
 *
 * Shape validation
 * ----------------
 * A successful `JSON.parse` is necessary but not sufficient: the SPA reads
 * `user.exp[0]` (expiry check) and `user.user_role[0]` (role gating) on
 * every navigation. If `localStorage.user` is set to a valid-but-wrong JSON
 * value (for example `'[]'` from a dev-tools typo, or `'null'`, or an object
 * missing `exp`/`user_role`), those reads would silently return `undefined`
 * and the session would appear authenticated to `isAuthenticated` while
 * failing every role check and exp calculation. We defensively require the
 * minimal shape the call sites rely on:
 *   - non-null, non-array object
 *   - `exp` is a non-empty `number[]` (expiry computations)
 *   - `user_role` is a non-empty `string[]` (router guards, badges)
 * Any failure is treated the same as corrupt JSON: `null`, handled upstream
 * as a logged-out state.
 */
function safeParseUser(raw: string | null): UserPayload | null {
  if (!raw) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  // Reject null, primitives, and arrays (`typeof [] === 'object'`, so the
  // array guard is not redundant).
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return null;
  }
  const candidate = parsed as Record<string, unknown>;
  // `exp` must be a non-empty numeric array — `[0]` is what `isExpired`
  // reads. A missing or empty exp would make `isExpired` always false and
  // silently keep an expired session alive.
  const exp = candidate.exp;
  if (!Array.isArray(exp) || exp.length === 0 || typeof exp[0] !== 'number') {
    return null;
  }
  // `user_role` must be a non-empty string array — router guards resolve
  // `roles[0]`; an empty array would fail every guard anyway, so rejecting
  // here keeps `isAuthenticated` honest.
  const roles = candidate.user_role;
  if (!Array.isArray(roles) || roles.length === 0 || typeof roles[0] !== 'string') {
    return null;
  }
  return parsed as UserPayload;
}

/**
 * Re-read both keys from `localStorage` and mirror them into the module
 * refs. Called once at module load, on every `useAuth()` invocation (cheap —
 * just two `getItem` calls), and by `handle401()` after the axios
 * interceptor clears state.
 */
function syncFromStorage(): void {
  const rawToken = localStorage.getItem(TOKEN_KEY);
  const rawUser = localStorage.getItem(USER_KEY);

  tokenRef.value = rawToken;
  userRef.value = safeParseUser(rawUser);

  // A token without a (readable) user is treated as no session — the SPA
  // always pairs them, and a dangling token would fail every downstream
  // role check anyway. Clear localStorage too so the state matches on
  // every observer.
  if (tokenRef.value && !userRef.value) {
    localStorage.removeItem(TOKEN_KEY);
    tokenRef.value = null;
  }

  // Keep the axios default header in lockstep with the current token.
  if (tokenRef.value) {
    axios.defaults.headers.common.Authorization = `Bearer ${tokenRef.value}`;
  } else {
    delete axios.defaults.headers.common.Authorization;
  }
}

// Hydrate once at import time so the Bearer header is set before the first
// request fires. `@/plugins/axios` does the same seeding; running this here
// is redundant but harmless, and protects callers who import this module
// before `@/plugins/axios`.
syncFromStorage();

// ---------------------------------------------------------------------------
// Computed derivations
// ---------------------------------------------------------------------------

const isAuthenticated = computed<boolean>(
  () => tokenRef.value !== null && userRef.value !== null
);

const isExpired = computed<boolean>(() => {
  const exp = userRef.value?.exp?.[0];
  if (typeof exp !== 'number') return false;
  const nowSec = Math.floor(Date.now() / 1000);
  return nowSec >= exp;
});

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/**
 * Persist a fresh login: token + user payload → localStorage + reactive
 * state + axios default Authorization header.
 *
 * @param token - The raw JWT string. `LoginView.vue` reads the Plumber
 *                scalar-array at `response.data[0]`; callers are expected
 *                to unwrap before passing in. We do NOT re-unwrap here so
 *                the type contract stays a simple `string`.
 * @param user  - The parsed `/api/auth/signin` response body.
 */
function login(token: string, user: UserPayload): void {
  tokenRef.value = token;
  userRef.value = user;
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
  axios.defaults.headers.common.Authorization = `Bearer ${token}`;
}

/**
 * Clear the session: both localStorage keys, both refs, and the axios
 * default header. Does NOT navigate — call sites that want a redirect
 * handle `$router.push(...)` themselves so this composable stays router-
 * agnostic and testable without mounting a router.
 */
function logout(): void {
  tokenRef.value = null;
  userRef.value = null;
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
  delete axios.defaults.headers.common.Authorization;
}

/**
 * Call `GET /api/auth/refresh` with the current Bearer token and store the
 * returned JWT. The API returns a R/Plumber scalar-array, matching the
 * authenticate endpoint shape.
 *
 * Errors bubble so callers can decide whether to toast, logout, or retry.
 * The axios 401 interceptor already handles unauthorized refresh responses
 * by clearing localStorage and redirecting — we do not duplicate that
 * behaviour here.
 *
 * @returns The new token string.
 */
async function refresh(): Promise<string> {
  const apiUrl = `${import.meta.env.VITE_API_URL ?? ''}/api/auth/refresh`;
  const response = await axios.get(apiUrl);
  // Plumber returns `["..."]`; tolerate either shape so this keeps working
  // if the API ever un-wraps scalars.
  const raw: unknown = response.data;
  const nextToken = Array.isArray(raw) ? String(raw[0]) : String(raw);

  // Guard against malformed 200 responses (null, {}, [null], non-coercible
  // payloads). Without this check, `String(undefined)` persists the literal
  // string "undefined" as the new token, which would masquerade as a valid
  // session until the next request fires a 401.
  if (!nextToken || nextToken === 'undefined' || nextToken === 'null') {
    throw new Error('Refresh returned invalid token');
  }

  tokenRef.value = nextToken;
  localStorage.setItem(TOKEN_KEY, nextToken);
  axios.defaults.headers.common.Authorization = `Bearer ${nextToken}`;
  return nextToken;
}

/**
 * Called (explicitly or implicitly) when a 401 is observed — re-reads
 * `localStorage` to mirror whatever the axios interceptor wrote, then
 * clears the axios default header so in-flight or queued requests stop
 * sending the stale Bearer. Safe to call multiple times; if the
 * interceptor hasn't cleared localStorage yet, we still fall through to
 * the "cleared" state via `logout()` semantics on re-sync.
 */
function handle401(): void {
  // The interceptor removes the keys directly; re-reading puts refs back
  // in sync. If for some reason localStorage still has values (e.g. this
  // is called defensively without an interceptor trigger), treat it as a
  // hard logout to be safe.
  const rawToken = localStorage.getItem(TOKEN_KEY);
  const rawUser = localStorage.getItem(USER_KEY);
  if (rawToken === null && rawUser === null) {
    // Interceptor-cleared path: just sync.
    tokenRef.value = null;
    userRef.value = null;
    delete axios.defaults.headers.common.Authorization;
    return;
  }
  // Defensive path: caller invoked handle401() without the interceptor
  // having run. Force a full logout.
  logout();
}

// ---------------------------------------------------------------------------
// Public composable
// ---------------------------------------------------------------------------

/**
 * Single entry point. Returns the shared reactive auth state plus typed
 * actions. The refs are stable across calls (module-level singleton); use
 * `useAuth()` freely inside components, guards, or other composables
 * without worrying about duplicate subscriptions.
 */
export function useAuth(): UseAuthReturn {
  // Re-sync on every call so module state can't drift from localStorage
  // after the axios interceptor path. Cheap: two `getItem` + optional
  // `JSON.parse`.
  syncFromStorage();

  return {
    token: tokenRef,
    user: userRef,
    isAuthenticated,
    isExpired,
    login,
    logout,
    refresh,
    handle401,
    syncFromStorage,
    hasRole: (role: string): boolean => {
      const roles = userRef.value?.user_role;
      if (!Array.isArray(roles)) return false;
      return roles[0] === role;
    },
  };
}

export default useAuth;
