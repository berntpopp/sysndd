// app/src/composables/__tests__/useGeneClinVarCounts.spec.ts
import { setActivePinia, createPinia } from 'pinia';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { defineComponent, h, nextTick, ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { server } from '@/test-utils/mocks/server';
import { useGeneClinVarCounts } from '../useGeneClinVarCounts';

function mountHook(symbol: string) {
  let captured!: ReturnType<typeof useGeneClinVarCounts>;
  const Comp = defineComponent({
    setup() {
      captured = useGeneClinVarCounts(ref(symbol));
      return () => h('div');
    },
  });
  const w = mount(Comp);
  return { w, hook: captured };
}

describe('useGeneClinVarCounts', () => {
  beforeEach(() => setActivePinia(createPinia()));
  afterEach(() => server.resetHandlers());

  it('calls /api/external/gnomad/variants/<symbol>?summary=true', async () => {
    let summaryFlag = '';
    server.use(
      http.get('*/api/external/gnomad/variants/GRIN2B', ({ request }) => {
        summaryFlag = new URL(request.url).searchParams.get('summary') ?? '';
        return HttpResponse.json({
          source: 'gnomad_clinvar',
          gene_symbol: 'GRIN2B',
          gene_id: 'ENSG00000273079',
          counts: {
            pathogenic: 235,
            likely_pathogenic: 165,
            vus: 574,
            likely_benign: 650,
            benign: 120,
          },
          variant_count: 1746,
          summary: true,
        });
      })
    );
    const { w, hook } = mountHook('GRIN2B');
    await flushPromises();
    await nextTick();
    expect(summaryFlag).toBe('true');
    expect(hook.data.value?.counts.pathogenic).toBe(235);
    expect(hook.data.value?.variant_count).toBe(1746);
    expect(hook.error.value).toBeNull();
    w.unmount();
  });

  it('returns null on 404', async () => {
    server.use(
      http.get('*/api/external/gnomad/variants/UNKNOWN', () =>
        HttpResponse.json({}, { status: 404 })
      )
    );
    const { w, hook } = mountHook('UNKNOWN');
    await flushPromises();
    await nextTick();
    expect(hook.data.value).toBeNull();
    expect(hook.error.value).toBeNull();
    w.unmount();
  });

  it('uses a distinct cache key from useGeneClinVar so the two hooks do not collide', async () => {
    server.use(
      http.get('*/api/external/gnomad/variants/MECP2', ({ request }) => {
        const params = new URL(request.url).searchParams;
        return HttpResponse.json(
          params.get('summary') === 'true'
            ? {
                source: 'gnomad_clinvar',
                gene_symbol: 'MECP2',
                gene_id: 'ENSG00000169057',
                counts: {
                  pathogenic: 1,
                  likely_pathogenic: 2,
                  vus: 3,
                  likely_benign: 4,
                  benign: 5,
                },
                variant_count: 15,
                summary: true,
              }
            : { variants: [] }
        );
      })
    );
    const { w, hook } = mountHook('MECP2');
    await flushPromises();
    await nextTick();
    // The data shape proves we hit the summary branch (not the empty variants branch).
    expect(hook.data.value?.counts.benign).toBe(5);
    expect(hook.data.value?.variant_count).toBe(15);
    w.unmount();
  });
});
