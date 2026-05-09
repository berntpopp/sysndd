// app/src/composables/annotations/useAnnotationFormatters.spec.ts
/**
 * v11.0 closeout F2a spec (plan §13.2): proves the `authRequestConfig()`
 * helper no longer reads `localStorage.token` — the Authorization header
 * is injected by the `apiClient` request interceptor (`@/api/client`) that
 * reads `useAuth().token.value`. The helper now only contributes
 * `withCredentials: true`.
 *
 * Two assertions:
 *   1. `authRequestConfig()` returns the credential opt-in shape and does
 *      NOT carry a `headers` field (the F1 interceptor, not this helper,
 *      owns the Bearer header).
 *   2. A real GET issued via `apiClient.get` — using `authRequestConfig()`
 *      as the config argument — carries the Bearer header seeded via
 *      `primeAuth`, asserted inside the MSW resolver via
 *      `expectBearerHeader`.
 */

import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';

import { apiClient } from '@/api/client';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';
import { authRequestConfig } from './useAnnotationFormatters';

afterEach(() => {
  useAuth().logout();
});

describe('useAnnotationFormatters.authRequestConfig — F2a migration', () => {
  it('returns only a credential opt-in (no headers field)', () => {
    const config = authRequestConfig();
    expect(config).toEqual({ withCredentials: true });
    // Defensive — make sure the helper truly does not emit a `headers`
    // property that would shadow the interceptor's Bearer injection.
    expect(config).not.toHaveProperty('headers');
  });

  it('participates in an apiClient.get that carries the Bearer from useAuth', async () => {
    const { token } = primeAuth();
    server.use(
      http.get('*/api/admin/annotation_dates', ({ request }) => {
        expectBearerHeader(request, token);
        return HttpResponse.json({ dates: [] });
      })
    );

    const data = await apiClient.get<{ dates: unknown[] }>(
      '/api/admin/annotation_dates',
      authRequestConfig()
    );
    expect(data).toEqual({ dates: [] });
  });
});
