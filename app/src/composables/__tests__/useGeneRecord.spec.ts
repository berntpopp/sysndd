import { setActivePinia, createPinia } from 'pinia';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { defineComponent, h, ref, nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { server } from '@/test-utils/mocks/server';
import { useGeneRecord } from '../useGeneRecord';

describe('useGeneRecord', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });
  afterEach(() => {
    server.resetHandlers();
  });

  it('hits ?input_type=symbol when input is a symbol', async () => {
    let captured = '';
    server.use(
      http.get('*/api/gene/GRIN2B', ({ request }) => {
        captured = new URL(request.url).searchParams.get('input_type') ?? '';
        return HttpResponse.json([
          {
            symbol: ['GRIN2B'],
            hgnc_id: ['HGNC:4586'],
            name: ['glutamate ionotropic receptor NMDA type subunit 2B'],
          },
        ]);
      })
    );
    const Comp = defineComponent({
      setup() {
        const r = useGeneRecord('GRIN2B');
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect(captured).toBe('symbol');
    expect((wrapper.vm as any).r.data.value).not.toBeNull();
  });

  it('hits ?input_type=hgnc when input matches HGNC:NNNN', async () => {
    let captured = '';
    server.use(
      // axios encodes the colon: getGene uses encodeURIComponent("HGNC:4586") -> HGNC%3A4586
      http.get('*/api/gene/HGNC%3A4586', ({ request }) => {
        captured = new URL(request.url).searchParams.get('input_type') ?? '';
        return HttpResponse.json([{ symbol: ['GRIN2B'] }]);
      })
    );
    const Comp = defineComponent({
      setup() {
        const r = useGeneRecord('HGNC:4586');
        return { r };
      },
      render() {
        return h('div');
      },
    });
    mount(Comp);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect(captured).toBe('hgnc');
  });

  it('also accepts the bare numeric form HGNC4586', async () => {
    // The regex accepts /^HGNC:?\d+$/i — covers both "HGNC:4586" and "HGNC4586".
    let captured = '';
    server.use(
      http.get('*/api/gene/HGNC4586', ({ request }) => {
        captured = new URL(request.url).searchParams.get('input_type') ?? '';
        return HttpResponse.json([{ symbol: ['GRIN2B'] }]);
      })
    );
    const Comp = defineComponent({
      setup() {
        const r = useGeneRecord('HGNC4586');
        return { r };
      },
      render() {
        return h('div');
      },
    });
    mount(Comp);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect(captured).toBe('hgnc');
  });

  it('reacts to a ref input', async () => {
    server.use(
      http.get('*/api/gene/GRIN2B', () => HttpResponse.json([{ symbol: ['GRIN2B'] }])),
      http.get('*/api/gene/MECP2', () => HttpResponse.json([{ symbol: ['MECP2'] }]))
    );
    const symbol = ref('GRIN2B');
    const Comp = defineComponent({
      setup() {
        const r = useGeneRecord(symbol);
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((wrapper.vm as any).r.data.value?.symbol?.[0]).toBe('GRIN2B');
    symbol.value = 'MECP2';
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((wrapper.vm as any).r.data.value?.symbol?.[0]).toBe('MECP2');
  });
});
