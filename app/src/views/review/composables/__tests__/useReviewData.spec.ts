// app/src/views/review/composables/__tests__/useReviewData.spec.ts
/**
 * Unit tests for `useReviewData` — the data-loading composable extracted
 * from `Review.vue` during W6 of v11.1 finish-hardening.
 *
 * The composable owns:
 *   - the re-review table fetch (`/api/re_review/table?curate=*`)
 *   - the three lookup-list fetches (phenotype / variation_ontology / status,
 *     all `?tree=true`) that feed dropdowns/treeselects in the modals
 *   - the entity-context lookup (`/api/entity/?filter=equals(entity_id,...)`)
 *
 * It does NOT own modal state, filter state, or mutations — those live in
 * the sibling composables. The contract here is therefore narrow: load,
 * expose reactive state, surface errors via the optional `onError` hook.
 *
 * Mock strategy: stub `axios` at the module level (the typed clients in
 * `@/api/*` resolve to `axios.get` under the hood), then assert on the
 * shape of the URL/params each helper hits and the resulting state.
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
      request: {
        use: vi.fn(),
        _cb: null,
      },
      response: {
        use: vi.fn(),
      },
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

import { useReviewData } from '../useReviewData';

interface AxiosMock {
  get: ReturnType<typeof vi.fn>;
}

async function getAxiosMock(): Promise<AxiosMock> {
  const axios = await import('axios');
  return axios.default as unknown as AxiosMock;
}

describe('useReviewData', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('loadReReviewData', () => {
    it('populates items + totalRows on success', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: {
          data: [
            { entity_id: 1, symbol: 'GRIN2B' },
            { entity_id: 2, symbol: 'GRIN1' },
          ],
        },
      });

      const data = useReviewData();
      expect(data.isBusy.value).toBe(false);
      expect(data.loading.value).toBe(true);

      await data.loadReReviewData(false);
      await flushPromises();

      expect(data.items.value).toHaveLength(2);
      expect(data.totalRows.value).toBe(2);
      expect(data.isBusy.value).toBe(false);
      expect(data.loading.value).toBe(false);
    });

    it('forwards `curate=true` as the query param', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({ data: { data: [] } });

      const data = useReviewData();
      await data.loadReReviewData(true);
      await flushPromises();

      expect(axios.get).toHaveBeenCalledWith(
        '/api/re_review/table',
        expect.objectContaining({
          params: expect.objectContaining({ curate: true }),
        })
      );
    });

    it('accepts a bare-array payload as a fallback shape', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({ data: [{ entity_id: 99 }] });

      const data = useReviewData();
      await data.loadReReviewData(false);
      await flushPromises();

      expect(data.items.value).toHaveLength(1);
      expect(data.totalRows.value).toBe(1);
    });

    it('invokes onError on rejection and clears the busy/loading flags', async () => {
      const axios = await getAxiosMock();
      const err = new Error('boom');
      axios.get.mockRejectedValueOnce(err);

      const onError = vi.fn();
      const data = useReviewData({ onError });
      await data.loadReReviewData(false);
      await flushPromises();

      expect(onError).toHaveBeenCalledWith(err);
      expect(data.isBusy.value).toBe(false);
      expect(data.loading.value).toBe(false);
      // items should remain at their default (empty array)
      expect(data.items.value).toEqual([]);
    });
  });

  describe('loadPhenotypesList', () => {
    it('runs the present-prefix transform on the tree response', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: [
          {
            id: '1-HP:0001999',
            label: 'present: Abnormal facial shape',
            children: [
              { id: '2-HP:0001999', label: 'uncertain: Abnormal facial shape' },
              { id: '3-HP:0001999', label: 'absent: Abnormal facial shape' },
            ],
          },
        ],
      });

      const data = useReviewData();
      await data.loadPhenotypesList();
      await flushPromises();

      expect(data.phenotypes_options.value).toHaveLength(1);
      const root = data.phenotypes_options.value[0];
      expect(root.label).toBe('Abnormal facial shape');
      // Original "present:" node becomes the first child; modifiers follow.
      expect(root.children).toHaveLength(3);
      expect(root.children?.[0].label).toBe('present: Abnormal facial shape');
    });

    it('falls back to [] on a non-array response', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({ data: { data: [] } });

      const data = useReviewData();
      await data.loadPhenotypesList();
      await flushPromises();

      expect(data.phenotypes_options.value).toEqual([]);
    });

    it('clears the list and calls onError on rejection', async () => {
      const axios = await getAxiosMock();
      const err = new Error('list-down');
      axios.get.mockRejectedValueOnce(err);

      const onError = vi.fn();
      const data = useReviewData({ onError });
      await data.loadPhenotypesList();
      await flushPromises();

      expect(onError).toHaveBeenCalledWith(err);
      expect(data.phenotypes_options.value).toEqual([]);
    });
  });

  describe('loadVariationOntologyList', () => {
    it('reuses the present-prefix transform', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: [
          {
            id: '10-VARIO:0001',
            label: 'present: Missense variant',
            children: [],
          },
        ],
      });

      const data = useReviewData();
      await data.loadVariationOntologyList();
      await flushPromises();

      expect(data.variation_ontology_options.value).toHaveLength(1);
      expect(data.variation_ontology_options.value[0].label).toBe('Missense variant');
    });
  });

  describe('loadStatusList', () => {
    it('stores the response verbatim (no transform)', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: [
          { id: 1, label: 'Definitive' },
          { id: 2, label: 'Moderate' },
        ],
      });

      const data = useReviewData();
      await data.loadStatusList();
      await flushPromises();

      expect(data.status_options.value).toHaveLength(2);
      expect(data.status_options.value[0].label).toBe('Definitive');
    });
  });

  describe('getEntity', () => {
    it('passes the filter as `config.params.filter` and assigns entity_info', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: { data: [{ entity_id: 501, symbol: 'TEST1' }] },
      });

      const data = useReviewData();
      await data.getEntity(501);
      await flushPromises();

      expect(axios.get).toHaveBeenCalledWith(
        '/api/entity/',
        expect.objectContaining({
          params: expect.objectContaining({ filter: 'equals(entity_id,501)' }),
        })
      );
      expect(data.entity_info.entity_id).toBe(501);
      expect(data.entity_info.symbol).toBe('TEST1');
    });
  });

  describe('loadReviewInfo', () => {
    it('hydrates review_info from the typed-client response', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: [
          {
            review_id: 42,
            entity_id: 501,
            review_user_name: 'alice',
            review_user_role: 'Reviewer',
            review_date: '2025-06-01 12:00:00',
          },
        ],
      });

      const data = useReviewData();
      await data.loadReviewInfo(42, 1);
      await flushPromises();

      expect(data.review_info.review_id).toBe(42);
      expect(data.review_info.entity_id).toBe(501);
      expect(data.review_info.review_user_name).toBe('alice');
      expect(data.review_info.re_review_review_saved).toBe(1);
    });
  });

  describe('resetEntityContext', () => {
    it('clears entity_info + review_info to a fresh shape', () => {
      const data = useReviewData();
      data.entity_info.entity_id = 99;
      data.entity_info.symbol = 'X';
      data.review_info.review_id = 5;

      data.resetEntityContext();

      expect(data.entity_info.entity_id).toBe(0);
      expect(data.entity_info.symbol).toBe('');
      expect(data.review_info.review_id).toBeNull();
    });
  });
});
