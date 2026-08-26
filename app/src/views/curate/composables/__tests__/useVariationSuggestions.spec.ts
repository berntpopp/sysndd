// #612 Phase 6 — the curation queue's action rules.
//
// The two predicates asserted here are the whole safety design. Getting
// `canDismiss` wrong offers a curator an action that would make a SERVED term
// render as curator-authored, which is the fabrication this feature exists to
// prevent. The server refuses it either way, but a UI that offers a refused
// action is a UI that teaches curators to distrust it.
import { describe, it, expect, vi, beforeEach } from 'vitest';

import useVariationSuggestions, {
  canConfirmRow,
  canDismissRow,
  describeApplyResult,
  suggestionRowKey,
} from '../useVariationSuggestions';
import * as api from '@/api/curate_variation';

vi.mock('@/api/curate_variation');

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
  evidence: [],
  ...over,
});

const emptyPage = { meta: { page: 1, page_size: 25, total: 0 }, data: [] };

beforeEach(() => {
  vi.resetAllMocks();
  vi.mocked(api.listVariationSuggestions).mockResolvedValue(emptyPage);
});

describe('action eligibility', () => {
  it('offers Confirm only for a SERVED active_unconfirmed assertion', () => {
    expect(canConfirmRow(row())).toBe(true);
    expect(canConfirmRow(row({ served: false }))).toBe(false);
    expect(canConfirmRow(row({ state: 'suggested', served: false }))).toBe(false);
    expect(canConfirmRow(row({ state: 'suggested', served: true }))).toBe(false);
  });

  it('offers Dismiss only for a suggested assertion that is NOT served', () => {
    expect(canDismissRow(row({ state: 'suggested', served: false }))).toBe(true);
    expect(canDismissRow(row({ state: 'suggested', served: true }))).toBe(false);
    expect(canDismissRow(row())).toBe(false);
  });

  it('never offers both actions for the same row', () => {
    const combinations: api.VariationSuggestionRow[] = [
      row(),
      row({ served: false }),
      row({ state: 'suggested', served: true }),
      row({ state: 'suggested', served: false }),
    ];
    combinations.forEach((candidate) => {
      expect(canConfirmRow(candidate) && canDismissRow(candidate)).toBe(false);
    });
  });
});

describe('row identity', () => {
  it('always carries the modifier, so present and absent are distinct rows', () => {
    expect(suggestionRowKey(row())).not.toEqual(suggestionRowKey(row({ modifier_id: 5 })));
    expect(suggestionRowKey(row())).not.toEqual(suggestionRowKey(row({ entity_id: 43 })));
    expect(suggestionRowKey(row())).not.toEqual(
      suggestionRowKey(row({ vario_id: 'VariO:0017' }))
    );
  });
});

describe('bulk selection', () => {
  it('reports a mixed selection so neither bulk action is offered', () => {
    const queue = useVariationSuggestions();
    queue.rows.value = [row(), row({ vario_id: 'VariO:0017', state: 'suggested', served: false })];
    queue.selected.value = queue.rows.value.map(suggestionRowKey);
    expect(queue.selectionKind.value).toBe('mixed');
  });

  it('reports the single permitted action for a homogeneous selection', () => {
    const queue = useVariationSuggestions();
    queue.rows.value = [row(), row({ modifier_id: 5 })];
    queue.selected.value = queue.rows.value.map(suggestionRowKey);
    expect(queue.selectionKind.value).toBe('confirm');
  });

  it('reports none for an empty selection', () => {
    expect(useVariationSuggestions().selectionKind.value).toBe('none');
  });

  it('selects only the rows that permit the requested action', () => {
    const queue = useVariationSuggestions();
    queue.rows.value = [
      row(),
      row({ vario_id: 'VariO:0017', state: 'suggested', served: false }),
      row({ vario_id: 'VariO:0031', state: 'suggested', served: true }),
    ];
    queue.selectAllEligible('dismiss');
    expect(queue.selected.value).toEqual(['42:VariO:0017:1']);
  });
});

describe('applying', () => {
  it('confirms exactly the selected identities and reloads', async () => {
    vi.mocked(api.confirmVariationSuggestions).mockResolvedValue({
      requested: 1,
      applied: 1,
      skipped: [],
    });
    const queue = useVariationSuggestions();
    queue.rows.value = [row()];
    queue.selected.value = [suggestionRowKey(row())];

    await queue.confirmSelected();

    expect(api.confirmVariationSuggestions).toHaveBeenCalledWith([
      { entity_id: 42, vario_id: 'VariO:0015', modifier_id: 1 },
    ]);
    // A confirmed row leaves the queue, so the page must be re-read.
    expect(api.listVariationSuggestions).toHaveBeenCalled();
  });

  it('does not call the API for an empty selection', async () => {
    const queue = useVariationSuggestions();
    expect(await queue.confirmSelected()).toBeNull();
    expect(api.confirmVariationSuggestions).not.toHaveBeenCalled();
  });

  it('reloads even when the batch fails, so no row is left showing stale state', async () => {
    const errors: string[] = [];
    vi.mocked(api.dismissVariationSuggestions).mockRejectedValue(new Error('boom'));
    const queue = useVariationSuggestions({ onError: (m) => errors.push(m) });
    queue.rows.value = [row({ state: 'suggested', served: false })];
    queue.selected.value = queue.rows.value.map(suggestionRowKey);

    expect(await queue.dismissSelected()).toBeNull();
    expect(errors).toEqual(['boom']);
    expect(api.listVariationSuggestions).toHaveBeenCalled();
    expect(queue.loading.value).toBe(false);
  });

  it('acts on a single row without consuming an unrelated selection', async () => {
    vi.mocked(api.confirmVariationSuggestions).mockResolvedValue({
      requested: 1,
      applied: 1,
      skipped: [],
    });
    const target = row({ modifier_id: 5 });
    const queue = useVariationSuggestions();
    queue.rows.value = [row(), target];
    queue.selected.value = [suggestionRowKey(row())];

    await queue.applyRow(target, 'confirm');

    expect(api.confirmVariationSuggestions).toHaveBeenCalledWith([
      { entity_id: 42, vario_id: 'VariO:0015', modifier_id: 5 },
    ]);
    expect(queue.selected.value).toEqual([suggestionRowKey(row())]);
  });
});

describe('loading', () => {
  it('sends only the filters that are set, and moved only when true', async () => {
    const queue = useVariationSuggestions();
    queue.filters.value.source_key = 'clinvar';
    await queue.load();

    const sent = vi.mocked(api.listVariationSuggestions).mock.calls[0][0];
    expect(sent?.source_key).toBe('clinvar');
    expect(sent?.state).toBeUndefined();
    expect(sent?.q).toBeUndefined();
    expect(sent?.moved).toBe(false);
  });

  it('drops the selection on reload so a bulk action cannot target invisible rows', async () => {
    const queue = useVariationSuggestions();
    queue.rows.value = [row()];
    queue.selected.value = [suggestionRowKey(row())];
    await queue.load();
    expect(queue.selected.value).toEqual([]);
  });

  it('resets to page 1 when filters change', async () => {
    const queue = useVariationSuggestions();
    queue.page.value = 4;
    await queue.applyFilters();
    expect(queue.page.value).toBe(1);
  });

  it('clamps paging to the available range', async () => {
    vi.mocked(api.listVariationSuggestions).mockResolvedValue({
      meta: { page: 1, page_size: 25, total: 30 },
      data: [],
    });
    const queue = useVariationSuggestions();
    await queue.load();
    expect(queue.totalPages.value).toBe(2);

    await queue.goToPage(99);
    expect(queue.page.value).toBe(2);
    await queue.goToPage(-3);
    expect(queue.page.value).toBe(1);
  });

  it('surfaces a load failure and empties the page rather than showing stale rows', async () => {
    const errors: string[] = [];
    vi.mocked(api.listVariationSuggestions).mockRejectedValue(new Error('nope'));
    const queue = useVariationSuggestions({ onError: (m) => errors.push(m) });
    queue.rows.value = [row()];
    await queue.load();
    expect(queue.rows.value).toEqual([]);
    expect(queue.total.value).toBe(0);
    expect(errors).toEqual(['nope']);
  });
});

describe('result reporting', () => {
  it('names every skip reason with its count', () => {
    // A silent partial success on a provenance surface is the failure mode this
    // feature exists to avoid.
    expect(
      describeApplyResult({
        requested: 12,
        applied: 10,
        skipped: [
          { entity_id: 1, vario_id: 'V:1', modifier_id: 1, reason: 'not_served' },
          { entity_id: 2, vario_id: 'V:2', modifier_id: 1, reason: 'not_served' },
        ],
      })
    ).toBe('10 of 12 applied — skipped: 2 not served.');
  });

  it('says so plainly when nothing was skipped', () => {
    expect(describeApplyResult({ requested: 3, applied: 3, skipped: [] })).toBe(
      '3 of 3 applied.'
    );
  });
});
