// app/src/views/curate/components/RefusedReReviewPanel.spec.ts
//
// Component spec for the curator "refused / needs specialist" surface
// (issue #54). Verifies it loads refused items via the typed re_review client
// (GET /api/re_review/table?refused=true) and clears a refusal via
// PUT /api/re_review/refuse/clear/:id.

import { describe, it, expect, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { http, HttpResponse } from 'msw';

// The panel calls useToast() in setup(); stub the composables barrel so the
// component mounts without a BApp/registry provider.
vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: vi.fn() }),
}));

import RefusedReReviewPanel from './RefusedReReviewPanel.vue';
import { server } from '@/test-utils/mocks/server';

const refusedRow = {
  re_review_entity_id: 701,
  entity_id: 501,
  symbol: 'ARID1B',
  disease_ontology_name: 'ARID1B-related disorder',
  re_review_refused: 1,
  re_review_refusal_comment: 'Complex inheritance; needs specialist',
  re_review_refused_user_name: 'reviewer_b',
  re_review_refused_date: '2026-06-11 10:00:00',
};

function mountPanel() {
  return mount(RefusedReReviewPanel, {
    global: {
      directives: { 'b-tooltip': {} },
      stubs: {
        TableShell: { template: '<section><slot name="actions" /><slot /></section>' },
        GenericTable: {
          name: 'GenericTable',
          props: ['items', 'fields'],
          template: `
            <table><tbody>
              <tr v-for="item in items" :key="item.re_review_entity_id">
                <td><slot name="cell-entity_id" :row="item" /></td>
                <td><slot name="cell-re_review_refusal_comment" :row="item" /></td>
                <td><slot name="cell-re_review_refused_user_name" :row="item" /></td>
                <td><slot name="cell-re_review_refused_date" :row="item" /></td>
                <td><slot name="cell-actions" :row="item" /></td>
              </tr>
            </tbody></table>`,
        },
        BButton: { template: '<button><slot /></button>' },
        BBadge: { template: '<span><slot /></span>' },
        BSpinner: { template: '<span role="status" />' },
      },
    },
  });
}

describe('RefusedReReviewPanel (issue #54)', () => {
  it('loads refused items via GET /api/re_review/table?refused=true', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/re_review/table', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ data: [refusedRow] });
      })
    );

    const wrapper = mountPanel();
    await flushPromises();

    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('refused')).toBe('true');
    expect(q.get('curate')).toBe('true');
    expect(wrapper.text()).toContain('Complex inheritance; needs specialist');
    expect(wrapper.text()).toContain('reviewer_b');
  });

  it('clears a refusal via PUT /api/re_review/refuse/clear/:id and emits "cleared"', async () => {
    let clearedPath: string | null = null;
    server.use(
      http.get('/api/re_review/table', () => HttpResponse.json({ data: [refusedRow] })),
      http.put('/api/re_review/refuse/clear/:id', ({ request }) => {
        clearedPath = new URL(request.url).pathname;
        return HttpResponse.json({ message: 'cleared' });
      })
    );

    const wrapper = mountPanel();
    await flushPromises();

    await wrapper.find('button[aria-label="Clear refusal for sysndd:501"]').trigger('click');
    await flushPromises();

    expect(clearedPath).toBe('/api/re_review/refuse/clear/701');
    expect(wrapper.emitted('cleared')).toBeTruthy();
  });
});
