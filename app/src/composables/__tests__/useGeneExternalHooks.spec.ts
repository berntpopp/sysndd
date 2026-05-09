import { setActivePinia, createPinia } from 'pinia';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { defineComponent, h, nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { server } from '@/test-utils/mocks/server';
import { useGeneClinVar } from '../useGeneClinVar';
import { useGeneAlphaFold } from '../useGeneAlphaFold';
import { useGeneUniProt } from '../useGeneUniProt';
import { useGeneMGI } from '../useGeneMGI';
import { useGeneRGD } from '../useGeneRGD';

function mountHook<T>(useHook: (s: string) => T, symbol: string) {
  const Comp = defineComponent({
    setup() {
      const r = useHook(symbol);
      return { r };
    },
    render() {
      return h('div');
    },
  });
  return mount(Comp);
}

describe('per-source gene external hooks', () => {
  beforeEach(() => setActivePinia(createPinia()));
  afterEach(() => server.resetHandlers());

  it('useGeneClinVar fetches ClinVar variants', async () => {
    server.use(
      http.get('*/api/external/gnomad/variants/GRIN2B', () =>
        HttpResponse.json({
          source: 'gnomad',
          gene_symbol: 'GRIN2B',
          variants: [{ id: 'V1' }],
          variant_count: 1,
        })
      )
    );
    const w = mountHook(useGeneClinVar, 'GRIN2B');
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toEqual([{ id: 'V1' }]);
  });

  it('useGeneClinVar treats 404 as no-data, not error', async () => {
    server.use(
      http.get('*/api/external/gnomad/variants/UNKNOWN', () =>
        HttpResponse.json({}, { status: 404 })
      )
    );
    const w = mountHook(useGeneClinVar, 'UNKNOWN');
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.error.value).toBeNull();
    expect((w.vm as any).r.data.value).toBeNull();
  });

  it('useGeneAlphaFold treats found:false as no-data', async () => {
    server.use(
      http.get('*/api/external/alphafold/structure/UNKNOWN', () =>
        HttpResponse.json({ found: false })
      )
    );
    const w = mountHook(useGeneAlphaFold, 'UNKNOWN');
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.error.value).toBeNull();
    expect((w.vm as any).r.data.value).toBeNull();
  });

  it('useGeneUniProt returns the domains payload on 200', async () => {
    server.use(
      http.get('*/api/external/uniprot/domains/GRIN2B', () =>
        HttpResponse.json({ domains: [{ name: 'D1', start: 1, end: 50 }] })
      )
    );
    const w = mountHook(useGeneUniProt, 'GRIN2B');
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value?.domains?.length).toBe(1);
  });

  it('useGeneMGI returns the phenotypes payload', async () => {
    server.use(
      http.get('*/api/external/mgi/phenotypes/GRIN2B', () =>
        HttpResponse.json({ source: 'mgi', phenotypes: [{ id: 'M1' }], counts: { high: 5 } })
      )
    );
    const w = mountHook(useGeneMGI, 'GRIN2B');
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toMatchObject({ phenotypes: [{ id: 'M1' }] });
  });

  it('useGeneRGD returns the phenotypes payload', async () => {
    server.use(
      http.get('*/api/external/rgd/phenotypes/GRIN2B', () =>
        HttpResponse.json({ source: 'rgd', phenotypes: [] })
      )
    );
    const w = mountHook(useGeneRGD, 'GRIN2B');
    await nextTick();
    await new Promise((r) => setTimeout(r, 10));
    expect((w.vm as any).r.data.value).toMatchObject({ phenotypes: [] });
  });
});
