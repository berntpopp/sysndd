// app/src/api/client.spec.ts
/**
 * Phase E.E1 smoke tests for the typed api client wrapper.
 *
 * These tests exercise the public surface of `./client.ts`:
 *   - `apiClient.get/post/put/delete/patch` unwrap to `response.data` by default
 *   - `apiClient.raw` returns the full `AxiosResponse<T>` for headers/status
 *   - `isApiError` narrows AxiosError from arbitrary thrown values
 *   - `unwrapScalar` collapses R/Plumber's 1-element array JSON scalar shape
 *
 * The global MSW server in `vitest.setup.ts` already intercepts network calls
 * against the B1 handler table, so we hit a couple of known endpoints
 * (`POST /api/auth/authenticate`, `GET /api/user/table`) to prove the wrapper
 * actually reaches through the axios plugin and its 401 interceptor chain.
 */

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';
import { apiClient, isApiError, unwrapScalar } from './client';
import { ERROR_SENTINELS } from '@/test-utils/mocks/handlers';
import { server } from '@/test-utils/mocks/server';

describe('api/client — typed wrapper smoke tests', () => {
  // ---------------------------------------------------------------------------
  // GET / POST / PUT / DELETE unwrap to `data`
  // ---------------------------------------------------------------------------

  describe('http verb helpers', () => {
    it('apiClient.post returns response.data directly', async () => {
      const body = await apiClient.post<[string]>('/api/auth/authenticate', {
        user_name: 'test_user',
        password: 'hunter2!',
      });

      // MSW handler returns `authenticateTokenOk` which is `[token]`.
      expect(Array.isArray(body)).toBe(true);
      expect(body).toHaveLength(1);
      expect(body[0]).toMatch(/^eyJ/);
    });

    it('apiClient.get returns response.data directly', async () => {
      const body = await apiClient.get<{ data: unknown[] }>('/api/user/table');
      expect(body).toHaveProperty('data');
      expect(Array.isArray(body.data)).toBe(true);
    });

    it('apiClient.put returns response.data directly', async () => {
      const body = await apiClient.put<{ data?: unknown[] }>('/api/user/update', {
        user_id: 42,
        user_name: 'updated_user',
      });
      // Handler returns the OK shape; assert we resolved with the body, not
      // the full AxiosResponse.
      expect(body).not.toHaveProperty('status');
      expect(body).not.toHaveProperty('config');
    });

    it('apiClient.delete returns response.data directly', async () => {
      // The B1 handler table has no stable DELETE-verb route (`/api/user/delete`
      // is registered as `http.put(...)` — annotated spec bug). Install a
      // per-test override so we can exercise the DELETE code path end-to-end.
      // `afterEach` in vitest.setup.ts calls `server.resetHandlers()`, which
      // removes this override automatically — no cleanup needed here.
      server.use(
        http.delete('/api/test-only/delete-smoke/:id', ({ params }) => {
          return HttpResponse.json({ deleted_id: params.id, ok: true });
        }),
      );

      const body = await apiClient.delete<{ deleted_id: string; ok: boolean }>(
        '/api/test-only/delete-smoke/42',
      );
      expect(body).toEqual({ deleted_id: '42', ok: true });
    });
  });

  // ---------------------------------------------------------------------------
  // `raw` escape hatch
  // ---------------------------------------------------------------------------

  describe('raw escape hatch', () => {
    it('apiClient.raw.get returns the full AxiosResponse', async () => {
      const response = await apiClient.raw.get<{ data: unknown[] }>('/api/user/table');
      expect(response.status).toBe(200);
      expect(response).toHaveProperty('headers');
      expect(response).toHaveProperty('data');
      expect(response.data).toHaveProperty('data');
    });
  });

  // ---------------------------------------------------------------------------
  // isApiError type guard
  // ---------------------------------------------------------------------------

  describe('isApiError', () => {
    it('returns false for the tagged Error synthesised by the 401 interceptor', async () => {
      // The axios 401 interceptor in `plugins/axios.ts` swaps the original
      // AxiosError for a tagged plain Error (`__handled401: true`) to
      // coalesce concurrent login redirects. `isApiError` must return
      // `false` for that tagged error — by the time a call site sees a 401
      // rejection, the redirect is already in flight and there is no
      // AxiosError left to inspect. This assertion pins that contract.
      let caught: unknown;
      try {
        await apiClient.post('/api/auth/authenticate', {
          user_name: ERROR_SENTINELS.WRONG_USER,
          password: 'hunter2!',
        });
      } catch (err) {
        caught = err;
      }

      expect(caught).toBeDefined();
      expect(isApiError(caught)).toBe(false);
    });

    it('recognises an AxiosError thrown from a 400 body-validation response', async () => {
      let caught: unknown;
      try {
        // user_name too short → 400 per the handler.
        await apiClient.post('/api/auth/authenticate', {
          user_name: 'xx',
          password: 'yy',
        });
      } catch (err) {
        caught = err;
      }

      expect(caught).toBeDefined();
      expect(isApiError(caught)).toBe(true);
      if (isApiError(caught)) {
        expect(caught.response?.status).toBe(400);
      }
    });

    it('returns false for plain Error values', () => {
      expect(isApiError(new Error('boom'))).toBe(false);
      expect(isApiError('string')).toBe(false);
      expect(isApiError(null)).toBe(false);
      expect(isApiError(undefined)).toBe(false);
      expect(isApiError({ response: {} })).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // unwrapScalar helper
  // ---------------------------------------------------------------------------

  describe('unwrapScalar', () => {
    it('unwraps a 1-element array to its single element', () => {
      expect(unwrapScalar(['abc'])).toBe('abc');
      expect(unwrapScalar([42])).toBe(42);
    });

    it('returns a non-array value unchanged', () => {
      expect(unwrapScalar('abc')).toBe('abc');
      expect(unwrapScalar(42)).toBe(42);
    });

    it('returns a multi-element array unchanged (not a scalar wrapper)', () => {
      // Multi-element arrays are real arrays, not plumber scalar shims.
      const multi = ['a', 'b', 'c'];
      expect(unwrapScalar(multi as unknown as [string])).toEqual(multi);
    });
  });
});
