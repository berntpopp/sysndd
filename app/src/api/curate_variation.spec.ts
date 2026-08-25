// app/src/api/curate_variation.spec.ts
//
// #612: the curation queue's wire contract.
//
// The API is R/Plumber and does not auto-unbox, so every scalar of a
// `list(...)`-built response arrives as a length-1 array. This queue's entire UI
// turns on three strict-equality reads of such fields — `state`, `served`,
// `moved` — which decide whether a curator is offered Confirm or Dismiss. Left
// unnormalized, all three read wrong and the picker offers the action the server
// is going to refuse.
import { describe, it, expect, vi, beforeEach } from 'vitest';

import { apiClient } from './client';
import {
  confirmVariationSuggestions,
  dismissVariationSuggestions,
  listVariationSuggestions,
} from './curate_variation';
import { normalizeSuggestionPage, normalizeApplyResult } from './curate-variation-wire';

vi.mock('./client', () => ({
  apiClient: { get: vi.fn(), post: vi.fn() },
}));

const wireRow = (over: Record<string, unknown> = {}) => ({
  entity_id: [42],
  symbol: ['CHD8'],
  disease_ontology_name: ['CHD8 disorder'],
  vario_id: ['VariO:0015'],
  vario_name: ['protein truncation'],
  modifier_id: [1],
  state: ['active_unconfirmed'],
  served: [true],
  moved: [false],
  max_strength: [2],
  evidence: [
    {
      source_type: ['external_database'],
      source_key: ['clinvar'],
      batch_id: ['clinvar-2026-02'],
      strength: [2],
      summary: ['10 ClinVar records, max 2 stars'],
    },
  ],
  ...over,
});

beforeEach(() => vi.resetAllMocks());

describe('wire normalization', () => {
  it('unwraps every documented scalar so strict equality is sound', () => {
    const page = normalizeSuggestionPage({
      meta: { page: [1], page_size: [25], total: [8083] },
      data: [wireRow()],
    });

    expect(page.meta).toEqual({ page: 1, page_size: 25, total: 8083 });
    const [row] = page.data;
    expect(row.state).toBe('active_unconfirmed');
    expect(row.served).toBe(true);
    expect(row.moved).toBe(false);
    expect(row.entity_id).toBe(42);
    expect(row.modifier_id).toBe(1);
    expect(row.max_strength).toBe(2);
    expect(row.symbol).toBe('CHD8');
    expect(row.evidence[0].source_key).toBe('clinvar');
    expect(row.evidence[0].strength).toBe(2);
  });

  it('keeps an unrecorded strength null rather than coercing it to zero', () => {
    const page = normalizeSuggestionPage({
      meta: { page: [1], page_size: [25], total: [1] },
      data: [wireRow({ max_strength: null, evidence: [] })],
    });
    expect(page.data[0].max_strength).toBeNull();
    expect(page.data[0].evidence).toEqual([]);
  });

  it('treats an unreadable served flag as NOT served', () => {
    // "We could not determine that this term is served" must never become "it is
    // served" — that would offer Confirm on something the server will refuse,
    // and hide Dismiss on something it would accept.
    const page = normalizeSuggestionPage({
      meta: { page: [1], page_size: [25], total: [1] },
      data: [wireRow({ served: null, moved: undefined })],
    });
    expect(page.data[0].served).toBe(false);
    expect(page.data[0].moved).toBe(false);
  });

  it('tolerates a missing data array and a missing meta block', () => {
    expect(normalizeSuggestionPage({ meta: { page: [1] } }).data).toEqual([]);
    expect(normalizeSuggestionPage({}).meta).toEqual({ page: 1, page_size: 25, total: 0 });
    expect(normalizeSuggestionPage(null).data).toEqual([]);
  });

  it('normalizes a batch result and every skip reason', () => {
    const result = normalizeApplyResult({
      requested: [3],
      applied: [1],
      skipped: [
        { entity_id: [42], vario_id: ['VariO:0017'], modifier_id: [5], reason: ['not_served'] },
      ],
    });
    expect(result).toEqual({
      requested: 3,
      applied: 1,
      skipped: [{ entity_id: 42, vario_id: 'VariO:0017', modifier_id: 5, reason: 'not_served' }],
    });
  });

  it('never loses a skip to a missing array', () => {
    expect(normalizeApplyResult({ requested: [1], applied: [1] }).skipped).toEqual([]);
  });
});

describe('listVariationSuggestions', () => {
  it('omits filters that are not set', () => {
    vi.mocked(apiClient.get).mockResolvedValue({ meta: {}, data: [] });
    return listVariationSuggestions({ source_key: 'clinvar' }).then(() => {
      const [path, config] = vi.mocked(apiClient.get).mock.calls[0];
      expect(path).toBe('/api/curate/variation/suggestions');
      expect(config?.params).toEqual({ source_key: 'clinvar' });
    });
  });

  it('sends every filter that is set, and only sends moved when true', async () => {
    vi.mocked(apiClient.get).mockResolvedValue({ meta: {}, data: [] });
    await listVariationSuggestions({
      state: 'suggested',
      source_key: 'synopsis',
      max_strength: 0,
      moved: false,
      q: 'CHD8',
      sort: 'strength_asc',
      page: 2,
      page_size: 50,
    });
    const [, config] = vi.mocked(apiClient.get).mock.calls[0];
    expect(config?.params).toEqual({
      state: 'suggested',
      source_key: 'synopsis',
      max_strength: 0,
      q: 'CHD8',
      sort: 'strength_asc',
      page: 2,
      page_size: 50,
    });

    await listVariationSuggestions({ moved: true });
    const [, second] = vi.mocked(apiClient.get).mock.calls[1];
    expect(second?.params).toEqual({ moved: 'true' });
  });
});

describe('batch actions', () => {
  const items = [{ entity_id: 42, vario_id: 'VariO:0015', modifier_id: 1 }];

  it('posts confirm to its own route with the items in the body', async () => {
    vi.mocked(apiClient.post).mockResolvedValue({ requested: [1], applied: [1], skipped: [] });
    const result = await confirmVariationSuggestions(items);
    const [path, body] = vi.mocked(apiClient.post).mock.calls[0];
    expect(path).toBe('/api/curate/variation/suggestions/confirm');
    expect(body).toEqual({ items });
    expect(result.applied).toBe(1);
  });

  it('posts dismiss to its own route', async () => {
    vi.mocked(apiClient.post).mockResolvedValue({ requested: [1], applied: [0], skipped: [] });
    await dismissVariationSuggestions(items);
    expect(vi.mocked(apiClient.post).mock.calls[0][0]).toBe(
      '/api/curate/variation/suggestions/dismiss'
    );
  });
});
