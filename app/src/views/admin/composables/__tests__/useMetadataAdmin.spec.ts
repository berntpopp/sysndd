// Unit tests for `useMetadataAdmin` request ownership (#535 S5b).
//
// The race: switching vocabulary A→B while A's rows are still in flight must not
// let A's late response populate the B table — otherwise a subsequent edit sends
// an A row id with activeSlug=B and mutates the WRONG vocabulary.

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';

const { rowsResolvers } = vi.hoisted(() => ({
  rowsResolvers: [] as Array<{ slug: string; resolve: (v: unknown) => void }>,
}));

vi.mock('@/api/metadata', () => ({
  fetchMetadataCatalog: vi.fn(async () => []),
  fetchMetadataRows: vi.fn(
    (slug: string) => new Promise((resolve) => rowsResolvers.push({ slug, resolve }))
  ),
  createMetadataRow: vi.fn(),
  updateMetadataRow: vi.fn(),
  deleteMetadataRow: vi.fn(),
}));

import { useMetadataAdmin } from '../useMetadataAdmin';

function metaResponse(rows: unknown[]) {
  return {
    data: rows,
    meta: { slug: 'x', pk: 'id', label: 'l', columns: [], editable: true, count: rows.length },
  };
}

describe('useMetadataAdmin — S5b request ownership', () => {
  beforeEach(() => {
    rowsResolvers.length = 0;
    vi.clearAllMocks();
  });

  it('a late vocabulary-A response does not populate the B table after switching A→B', async () => {
    const admin = useMetadataAdmin({ onToast: vi.fn() });

    const pA = admin.selectVocabulary('vocabA'); // loadRows(A) in flight
    const pB = admin.selectVocabulary('vocabB'); // loadRows(B) in flight; activeSlug=B
    expect(admin.activeSlug.value).toBe('vocabB');

    // Resolve B first, then the stale A response LAST.
    rowsResolvers.find((r) => r.slug === 'vocabB')!.resolve(metaResponse([{ id: 'b1' }]));
    await pB;
    await flushPromises();
    rowsResolvers.find((r) => r.slug === 'vocabA')!.resolve(metaResponse([{ id: 'a1' }]));
    await pA;
    await flushPromises();

    // The B table must reflect B's rows, never the late A rows.
    expect(admin.rows.value).toEqual([{ id: 'b1' }]);
    expect(admin.activeSlug.value).toBe('vocabB');
    expect(admin.loadingRows.value).toBe(false);
  });
});
