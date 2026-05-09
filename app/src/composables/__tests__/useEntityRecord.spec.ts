import { setActivePinia, createPinia } from 'pinia';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { defineComponent, h, nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { server } from '@/test-utils/mocks/server';
import { useEntityRecord } from '../useEntityRecord';

describe('useEntityRecord', () => {
  beforeEach(() => setActivePinia(createPinia()));
  afterEach(() => server.resetHandlers());

  it('fetches one entity row by id', async () => {
    server.use(
      http.get('*/api/entity/', ({ request }) => {
        const url = new URL(request.url);
        expect(url.searchParams.get('filter')).toBe('equals(entity_id,304)');
        return HttpResponse.json({
          data: [{ entity_id: 304, symbol: 'MECP2' }],
          links: [],
          meta: [{}],
        });
      })
    );
    const Comp = defineComponent({
      setup() {
        const r = useEntityRecord(304);
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const w = mount(Comp);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toEqual({ entity_id: 304, symbol: 'MECP2' });
  });

  it('accepts string id input', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({ data: [{ entity_id: 400 }], links: [], meta: [{}] })
      )
    );
    const Comp = defineComponent({
      setup() {
        const r = useEntityRecord('400');
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const w = mount(Comp);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toEqual({ entity_id: 400 });
  });

  it('returns null when the row list is empty', async () => {
    server.use(
      http.get('*/api/entity/', () => HttpResponse.json({ data: [], links: [], meta: [{}] }))
    );
    const Comp = defineComponent({
      setup() {
        const r = useEntityRecord(999_999);
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const w = mount(Comp);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toBeNull();
  });
});
