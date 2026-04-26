import { setActivePinia, createPinia } from 'pinia';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { defineComponent, h, nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { server } from '@/test-utils/mocks/server';
import { useEntityStatus } from '../useEntityStatus';
import { useEntityReview } from '../useEntityReview';
import { useEntityPublications } from '../useEntityPublications';
import { useEntityPhenotypes } from '../useEntityPhenotypes';
import { useEntityVariation } from '../useEntityVariation';

function mountHook<T>(hook: (id: number) => T, id: number) {
  const Comp = defineComponent({
    setup() {
      const r = hook(id);
      return { r };
    },
    render() {
      return h('div');
    },
  });
  return mount(Comp);
}

describe('per-source entity sub-resource hooks', () => {
  beforeEach(() => setActivePinia(createPinia()));
  afterEach(() => server.resetHandlers());

  it('useEntityStatus returns the status payload', async () => {
    server.use(
      http.get('*/api/entity/304/status', () => HttpResponse.json({ status: 'approved' })),
    );
    const w = mountHook(useEntityStatus, 304);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toMatchObject({ status: 'approved' });
  });

  it('useEntityReview returns the review payload', async () => {
    server.use(
      http.get('*/api/entity/304/review', () =>
        HttpResponse.json({ synopsis: 'Lorem ipsum.', comment: '' }),
      ),
    );
    const w = mountHook(useEntityReview, 304);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toMatchObject({ synopsis: 'Lorem ipsum.' });
  });

  it('useEntityPublications returns publications array (filterable client-side)', async () => {
    server.use(
      http.get('*/api/entity/304/publications', () =>
        HttpResponse.json([
          { publication_type: 'additional_references', pmid: '1' },
          { publication_type: 'gene_review', pmid: '2' },
        ]),
      ),
    );
    const w = mountHook(useEntityPublications, 304);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toHaveLength(2);
  });

  it('useEntityPhenotypes returns phenotypes array', async () => {
    server.use(
      http.get('*/api/entity/304/phenotypes', () =>
        HttpResponse.json([{ id: 'HP:0001' }]),
      ),
    );
    const w = mountHook(useEntityPhenotypes, 304);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toEqual([{ id: 'HP:0001' }]);
  });

  it('useEntityVariation returns variation array', async () => {
    server.use(
      http.get('*/api/entity/304/variation', () =>
        HttpResponse.json([{ id: 'VAR:1' }]),
      ),
    );
    const w = mountHook(useEntityVariation, 304);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toEqual([{ id: 'VAR:1' }]);
  });
});
