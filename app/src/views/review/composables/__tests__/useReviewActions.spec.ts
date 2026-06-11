// app/src/views/review/composables/__tests__/useReviewActions.spec.ts
/**
 * Unit tests for `useReviewActions` — re-review mutation composable
 * extracted during W6 of v11.1 finish-hardening.
 *
 * The composable owns the four `/api/re_review/*` mutations:
 *   - submit (`PUT /api/re_review/submit`)
 *   - approve (`PUT /api/re_review/approve/:id`)
 *   - unsubmit (`PUT /api/re_review/unsubmit/:id`)
 *   - batch apply (`GET /api/re_review/batch/apply`)
 *
 * It does NOT own the wizard's form submissions (those stay in
 * `useReviewForm` / `useStatusForm`).
 *
 * Mock strategy: stub `axios` so the typed clients in `@/api/re_review`
 * resolve through it. Assert URLs, params, and the `mutating` toggle.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';

vi.mock('axios', () => {
  const axiosMock = {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', headers: { common: {} } },
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
    isAxiosError: (err: unknown): boolean =>
      typeof err === 'object' && err !== null && 'isAxiosError' in err,
  };
  return {
    default: axiosMock,
    ...axiosMock,
    AxiosHeaders: class {
      private store = new Map<string, string>();
      has(key: string): boolean {
        return this.store.has(key.toLowerCase());
      }
      get(key: string): string | null {
        return this.store.get(key.toLowerCase()) ?? null;
      }
      set(key: string, value: string): this {
        this.store.set(key.toLowerCase(), value);
        return this;
      }
    },
    AxiosError: Error,
  };
});

vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
    currentRoute: { value: { fullPath: '/Review' } },
  },
}));

import { useReviewActions } from '../useReviewActions';

interface AxiosMock {
  get: ReturnType<typeof vi.fn>;
  put: ReturnType<typeof vi.fn>;
}

async function getAxiosMock(): Promise<AxiosMock> {
  const axios = await import('axios');
  return axios.default as unknown as AxiosMock;
}

describe('useReviewActions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('submitReReviewEntity', () => {
    it('PUTs `/api/re_review/submit` with submit_json + toggles mutating', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValueOnce({ data: { message: 'ok' } });

      const a = useReviewActions();
      expect(a.mutating.value).toBe(false);

      const promise = a.submitReReviewEntity(701);
      expect(a.mutating.value).toBe(true);
      await promise;
      await flushPromises();

      expect(axios.put).toHaveBeenCalledWith(
        '/api/re_review/submit',
        {
          submit_json: {
            re_review_entity_id: 701,
            re_review_submitted: 1,
          },
        },
        undefined
      );
      expect(a.mutating.value).toBe(false);
    });

    it('captures errors via onError and resets mutating', async () => {
      const axios = await getAxiosMock();
      const err = new Error('500');
      axios.put.mockRejectedValueOnce(err);

      const onError = vi.fn();
      const a = useReviewActions({ onError });
      await a.submitReReviewEntity(701);
      await flushPromises();

      expect(onError).toHaveBeenCalledWith(err);
      expect(a.mutating.value).toBe(false);
    });
  });

  describe('approveEntity', () => {
    it('PUTs `/api/re_review/approve/:id` with status_ok + review_ok params', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValueOnce({ data: { message: 'ok' } });

      const a = useReviewActions();
      await a.approveEntity(701, { status_ok: true, review_ok: false });
      await flushPromises();

      const call = axios.put.mock.calls.find(
        (c) => (c[0] as string) === '/api/re_review/approve/701'
      );
      expect(call).toBeDefined();
      const config = (
        call as [string, unknown, { params?: { status_ok?: boolean; review_ok?: boolean } }]
      )[2];
      expect(config?.params?.status_ok).toBe(true);
      expect(config?.params?.review_ok).toBe(false);
    });
  });

  describe('unsubmitEntity', () => {
    it('PUTs `/api/re_review/unsubmit/:id`', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValueOnce({ data: { message: 'ok' } });

      const a = useReviewActions();
      await a.unsubmitEntity(701);
      await flushPromises();

      const call = axios.put.mock.calls.find(
        (c) => (c[0] as string) === '/api/re_review/unsubmit/701'
      );
      expect(call).toBeDefined();
    });
  });

  describe('refuseEntity', () => {
    it('PUTs `/api/re_review/refuse/:id` with a body reason and resolves true', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValueOnce({ data: { message: 'refused' } });

      const a = useReviewActions();
      const promise = a.refuseEntity(701, '  Too complex  ');
      expect(a.mutating.value).toBe(true);
      const result = await promise;
      await flushPromises();

      expect(result).toBe(true);
      expect(axios.put).toHaveBeenCalledWith(
        '/api/re_review/refuse/701',
        { reason: 'Too complex' },
        undefined
      );
      expect(a.mutating.value).toBe(false);
    });

    it('sends reason=null when blank/whitespace-only', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValueOnce({ data: { message: 'refused' } });

      const a = useReviewActions();
      await a.refuseEntity(701, '   ');
      await flushPromises();

      expect(axios.put).toHaveBeenCalledWith(
        '/api/re_review/refuse/701',
        { reason: null },
        undefined
      );
    });

    it('routes errors through onError and resolves false', async () => {
      const axios = await getAxiosMock();
      const err = new Error('409 already refused');
      axios.put.mockRejectedValueOnce(err);

      const onError = vi.fn();
      const a = useReviewActions({ onError });
      const result = await a.refuseEntity(701, 'x');
      await flushPromises();

      expect(onError).toHaveBeenCalledWith(err);
      expect(result).toBe(false);
      expect(a.mutating.value).toBe(false);
    });
  });

  describe('applyForBatch', () => {
    it('GETs `/api/re_review/batch/apply`', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({ data: {} });

      const a = useReviewActions();
      await a.applyForBatch();
      await flushPromises();

      expect(axios.get).toHaveBeenCalledWith('/api/re_review/batch/apply', undefined);
    });

    it('routes errors through onError', async () => {
      const axios = await getAxiosMock();
      const err = new Error('SMTP down');
      axios.get.mockRejectedValueOnce(err);

      const onError = vi.fn();
      const a = useReviewActions({ onError });
      await a.applyForBatch();
      await flushPromises();

      expect(onError).toHaveBeenCalledWith(err);
    });
  });
});
