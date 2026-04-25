import axios from 'axios';

// Configure axios defaults
axios.defaults.baseURL = import.meta.env.VITE_BASE_URL || '';

// v11.0 closeout F1: the init-time `localStorage.getItem('token')` →
// `axios.defaults.headers.common.Authorization` seeding has been removed.
// The `apiClient` request interceptor (`@/api/client`) is now the single
// injection point for the Bearer header; it reads `useAuth().token.value`
// on every outbound call, so there is nothing to seed here.

// v11.1 W2 finish-hardening: this interceptor no longer mutates
// `localStorage` directly or imports `@/router`. `useAuth().handle401()`
// is now the single owner of logout cleanup (clears localStorage, clears
// reactive refs, dispatches navigation toward `/Login`). The
// `isLoggingOut` guard remains as a belt-and-braces concurrent-401
// coalescer; `handle401()` is itself idempotent, so the guard now
// primarily exists to suppress duplicate `__handled401` rejections to
// callers that wired distinct `.catch()` blocks per concurrent request.

// Guard flag to prevent duplicate 401 reject-tagging on concurrent failures
let isLoggingOut = false;

// Response interceptor: centralized 401 handling
axios.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401 && !isLoggingOut) {
      isLoggingOut = true;

      // Lazy import to avoid a module-load cycle: this plugin is imported
      // by `@/composables/useAuth` for its initialisation side effects, so
      // `useAuth` cannot be a top-level import here without re-entering
      // the cycle before module bindings are stable. By the time a 401
      // response arrives, every module is fully initialised, and the
      // dynamic import resolves the singleton synchronously from the
      // bundle cache.
      const { useAuth } = await import('@/composables/useAuth');
      useAuth().handle401();

      // Reset guard after a window to coalesce concurrent 401s
      setTimeout(() => {
        isLoggingOut = false;
      }, 2000);

      // Mark as handled so downstream .catch() can skip toast display,
      // while still rejecting so .finally() cleanup runs properly.
      // Preserves the existing `__handled401` contract that callers in
      // `@/api/client.ts` (see `isApiError()` doc comment) rely on.
      const handled = new Error('Redirecting to login');
      (handled as Error & { __handled401: boolean }).__handled401 = true;
      return Promise.reject(handled);
    }

    return Promise.reject(error);
  }
);

export default axios;
