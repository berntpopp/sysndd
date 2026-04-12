// app/src/api/client.ts
/**
 * Typed wrapper over the central axios singleton at `@/plugins/axios`.
 *
 * Phase E.E1 (exit criterion #14, `.plans/v11.0/phase-e.md` §3) introduces a
 * cohesive `api/` module as the single surface for HTTP calls. This file is
 * that surface: call-sites in views/components/composables will migrate to
 * `apiClient.get(...)` over E3–E10 instead of reaching for `axios.get(...)`
 * directly.
 *
 * IMPORTANT: we do NOT instantiate a new axios instance here. The plugin in
 * `@/plugins/axios` configures the default instance (`baseURL`, the
 * `Authorization` header, and the 401 response interceptor). Creating a
 * separate `axios.create({...})` would skip that interceptor chain and
 * silently bypass the login-redirect behaviour. Every method below delegates
 * to the configured default instance so the wrapper inherits all of it.
 */

import axios, { AxiosError, type AxiosRequestConfig, type AxiosResponse } from 'axios';

// Re-export the configured singleton from the existing plugin so anyone who
// imports it via `@/api/client` ends up on the same instance as `@/plugins/
// axios` consumers.  Importing the plugin here ensures its initialisation
// side-effects (Authorization header, 401 interceptor) have run before any
// api/ call site fires.
import '@/plugins/axios';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Typed HTTP verb helpers that resolve with `response.data` instead of the
 * full `AxiosResponse`. Reach for `apiClient.raw.*` when a call site needs
 * the status code, headers, or config object.
 */
export interface ApiClient {
  get<T>(path: string, config?: AxiosRequestConfig): Promise<T>;
  post<T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig): Promise<T>;
  put<T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig): Promise<T>;
  patch<T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig): Promise<T>;
  delete<T>(path: string, config?: AxiosRequestConfig): Promise<T>;
  /**
   * Escape hatch: returns the full AxiosResponse<T> for call sites that need
   * status codes, response headers, or to detect 201 vs 200 differentiation.
   */
  raw: {
    get<T>(path: string, config?: AxiosRequestConfig): Promise<AxiosResponse<T>>;
    post<T, B = unknown>(
      path: string,
      body?: B,
      config?: AxiosRequestConfig,
    ): Promise<AxiosResponse<T>>;
    put<T, B = unknown>(
      path: string,
      body?: B,
      config?: AxiosRequestConfig,
    ): Promise<AxiosResponse<T>>;
    patch<T, B = unknown>(
      path: string,
      body?: B,
      config?: AxiosRequestConfig,
    ): Promise<AxiosResponse<T>>;
    delete<T>(path: string, config?: AxiosRequestConfig): Promise<AxiosResponse<T>>;
  };
}

export const apiClient: ApiClient = {
  get: async <T>(path: string, config?: AxiosRequestConfig): Promise<T> => {
    const response = await axios.get<T>(path, config);
    return response.data;
  },
  post: async <T, B = unknown>(
    path: string,
    body?: B,
    config?: AxiosRequestConfig,
  ): Promise<T> => {
    const response = await axios.post<T>(path, body, config);
    return response.data;
  },
  put: async <T, B = unknown>(
    path: string,
    body?: B,
    config?: AxiosRequestConfig,
  ): Promise<T> => {
    const response = await axios.put<T>(path, body, config);
    return response.data;
  },
  patch: async <T, B = unknown>(
    path: string,
    body?: B,
    config?: AxiosRequestConfig,
  ): Promise<T> => {
    const response = await axios.patch<T>(path, body, config);
    return response.data;
  },
  delete: async <T>(path: string, config?: AxiosRequestConfig): Promise<T> => {
    const response = await axios.delete<T>(path, config);
    return response.data;
  },
  raw: {
    get: <T>(path: string, config?: AxiosRequestConfig) => axios.get<T>(path, config),
    post: <T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig) =>
      axios.post<T>(path, body, config),
    put: <T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig) =>
      axios.put<T>(path, body, config),
    patch: <T, B = unknown>(path: string, body?: B, config?: AxiosRequestConfig) =>
      axios.patch<T>(path, body, config),
    delete: <T>(path: string, config?: AxiosRequestConfig) => axios.delete<T>(path, config),
  },
};

// ---------------------------------------------------------------------------
// Error helpers
// ---------------------------------------------------------------------------

/**
 * Type guard narrowing an unknown value to `AxiosError<T>`. Wraps
 * `axios.isAxiosError` so call sites don't have to import `axios` directly.
 *
 * Note: the 401 interceptor in `@/plugins/axios` replaces the original
 * AxiosError with a tagged plain Error (`__handled401: true`) to coalesce
 * concurrent login redirects. For 401s, this guard will correctly return
 * `false` — the call site should treat a 401-originated rejection as
 * already handled by the redirect and skip toasts.
 */
export function isApiError<T = unknown>(err: unknown): err is AxiosError<T> {
  return axios.isAxiosError(err);
}

export { AxiosError };

// ---------------------------------------------------------------------------
// R/Plumber scalar unwrapper
// ---------------------------------------------------------------------------

/**
 * R/Plumber serialises bare JSON scalars as 1-element arrays (see the gotcha
 * in the repo-root `CLAUDE.md`). This helper collapses `[x]` to `x` for call
 * sites that need the scalar shape; leaves everything else untouched.
 *
 * Multi-element arrays are real arrays, not scalar wrappers, so the helper
 * returns them unchanged.
 */
export function unwrapScalar<T>(value: T | [T]): T {
  if (Array.isArray(value) && value.length === 1) {
    return value[0] as T;
  }
  return value as T;
}

export default apiClient;
