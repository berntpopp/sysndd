// app/src/views/curate/VariationSuggestions.spec.ts
//
// Shell-level spec for the #612 curation queue page.
//
// The rules live in `useVariationSuggestions` and are covered exhaustively by
// its own spec; what this file proves is that the page RENDERS them — that a
// served unconfirmed row offers Confirm and not Dismiss, an unserved suggestion
// offers the reverse, a row that permits neither offers only a way out to the
// entity, and a mixed selection offers no bulk action at all.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createRouter, createWebHistory } from 'vue-router';

import { bootstrapStubs } from '@/test-utils';
import VariationSuggestions from '@/views/curate/VariationSuggestions.vue';
import * as api from '@/api/curate_variation';

vi.mock('@/api/curate_variation');
// The page reports every batch outcome through a toast; bootstrap-vue-next's
// registry is not installed in a shallow mount.
vi.mock('@/composables/useToast', () => ({ default: () => ({ makeToast: vi.fn() }) }));

const row = (over: Partial<api.VariationSuggestionRow> = {}): api.VariationSuggestionRow => ({
  entity_id: 42,
  symbol: 'CHD8',
  disease_ontology_name: 'CHD8 disorder',
  vario_id: 'VariO:0015',
  vario_name: 'protein truncation',
  modifier_id: 1,
  state: 'active_unconfirmed',
  served: true,
  moved: false,
  max_strength: 2,
  evidence: [
    {
      source_type: 'external_database',
      source_key: 'clinvar',
      batch_id: 'clinvar-2026-02',
      strength: 2,
      summary: '10 ClinVar records, max 2 stars',
    },
  ],
  ...over,
});

const router = createRouter({
  history: createWebHistory(),
  routes: [{ path: '/:pathMatch(.*)*', component: { template: '<div />' } }],
});

const stubs = {
  ...bootstrapStubs,
  AuthenticatedPageShell: { template: '<div><slot /></div>' },
  TableShell: {
    template: '<div><slot name="actions" /><slot /><slot name="footer" /></div>',
  },
};

async function mountPage(rows: api.VariationSuggestionRow[]): Promise<VueWrapper> {
  vi.mocked(api.listVariationSuggestions).mockResolvedValue({
    meta: { page: 1, page_size: 25, total: rows.length },
    data: rows,
  });
  const wrapper = mount(VariationSuggestions, {
    global: { plugins: [router], stubs },
  });
  await flushPromises();
  return wrapper;
}

beforeEach(() => vi.resetAllMocks());

describe('row rendering', () => {
  it('shows the gene, term and its modifier', async () => {
    const w = await mountPage([row()]);
    const text = w.text();
    expect(text).toContain('CHD8');
    expect(text).toContain('protein truncation');
    expect(text).toContain('VariO:0015');
    w.unmount();
  });

  it('offers Confirm, and not Dismiss, for a served unconfirmed term', async () => {
    const w = await mountPage([row()]);
    expect(w.find('[data-testid="variation-suggestion-confirm-42:VariO:0015:1"]').exists()).toBe(
      true
    );
    expect(w.find('[data-testid="variation-suggestion-dismiss-42:VariO:0015:1"]').exists()).toBe(
      false
    );
    w.unmount();
  });

  it('offers Dismiss, and not Confirm, for an unserved suggestion', async () => {
    const w = await mountPage([row({ state: 'suggested', served: false })]);
    expect(w.find('[data-testid="variation-suggestion-dismiss-42:VariO:0015:1"]').exists()).toBe(
      true
    );
    expect(w.find('[data-testid="variation-suggestion-confirm-42:VariO:0015:1"]').exists()).toBe(
      false
    );
    w.unmount();
  });

  it('offers no action, only a way out to the entity, for a served suggestion', async () => {
    // Removing a SERVED term is a review write. Dismissing it here would make it
    // render as curator-authored, which is what this feature exists to prevent.
    const w = await mountPage([row({ state: 'suggested', served: true })]);
    expect(w.find('[data-testid="variation-suggestion-confirm-42:VariO:0015:1"]').exists()).toBe(
      false
    );
    expect(w.find('[data-testid="variation-suggestion-dismiss-42:VariO:0015:1"]').exists()).toBe(
      false
    );
    expect(w.find('[data-testid="variation-suggestion-open-42:VariO:0015:1"]').exists()).toBe(
      true
    );
    w.unmount();
  });

  it('shows the moved badge only for a superseded import', async () => {
    const plain = await mountPage([row()]);
    expect(plain.find('[data-testid="variation-suggestion-moved-42:VariO:0015:1"]').exists()).toBe(
      false
    );
    plain.unmount();

    const moved = await mountPage([row({ moved: true })]);
    expect(moved.find('[data-testid="variation-suggestion-moved-42:VariO:0015:1"]').exists()).toBe(
      true
    );
    moved.unmount();
  });

  it('renders an empty state rather than a bare table', async () => {
    const w = await mountPage([]);
    expect(w.find('[data-testid="variation-suggestions-empty"]').exists()).toBe(true);
    w.unmount();
  });
});

describe('bulk actions', () => {
  it('offers no bulk action until something is selected', async () => {
    const w = await mountPage([row()]);
    expect(w.find('[data-testid="variation-suggestions-bulk-confirm"]').exists()).toBe(false);
    w.unmount();
  });

  it('offers Confirm selected for a homogeneous selection', async () => {
    const w = await mountPage([row()]);
    await w.find('[data-testid="variation-suggestion-select-42:VariO:0015:1"]').trigger('change');
    await flushPromises();
    expect(w.find('[data-testid="variation-suggestions-bulk-confirm"]').exists()).toBe(true);
    w.unmount();
  });

  it('refuses to offer a bulk action for a mixed selection', async () => {
    const w = await mountPage([
      row(),
      row({ vario_id: 'VariO:0017', state: 'suggested', served: false }),
    ]);
    await w.find('[data-testid="variation-suggestion-select-42:VariO:0015:1"]').trigger('change');
    await w.find('[data-testid="variation-suggestion-select-42:VariO:0017:1"]').trigger('change');
    await flushPromises();

    expect(w.find('[data-testid="variation-suggestions-bulk-confirm"]').exists()).toBe(false);
    expect(w.find('[data-testid="variation-suggestions-bulk-dismiss"]').exists()).toBe(false);
    expect(w.find('[data-testid="variation-suggestions-bulk-mixed"]').exists()).toBe(true);
    w.unmount();
  });
});

describe('actions', () => {
  it('confirms exactly the row that was clicked', async () => {
    vi.mocked(api.confirmVariationSuggestions).mockResolvedValue({
      requested: 1,
      applied: 1,
      skipped: [],
    });
    const w = await mountPage([row()]);
    await w.find('[data-testid="variation-suggestion-confirm-42:VariO:0015:1"]').trigger('click');
    await flushPromises();

    expect(api.confirmVariationSuggestions).toHaveBeenCalledWith([
      { entity_id: 42, vario_id: 'VariO:0015', modifier_id: 1 },
    ]);
    w.unmount();
  });
});
