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
import { fetchMetadataCatalog } from '@/api/metadata';

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

  it('an older loadCatalog response does not overwrite a newer one', async () => {
    const catalogResolvers: Array<(v: unknown) => void> = [];
    vi.mocked(fetchMetadataCatalog).mockImplementation(
      () => new Promise((resolve) => catalogResolvers.push(resolve)) as ReturnType<
        typeof fetchMetadataCatalog
      >
    );
    const admin = useMetadataAdmin({ onToast: vi.fn() });
    // Pre-select a slug present in the newer catalog so the accepted catalog does not
    // reconcile/auto-select and fan out to loadRows — this isolates the generation guard.
    admin.activeSlug.value = 'newer';

    const p1 = admin.loadCatalog(); // catalog load #1 (older)
    const p2 = admin.loadCatalog(); // catalog load #2 (newer)
    // Resolve the newer load first, then the stale older one LAST.
    catalogResolvers[1]([{ slug: 'newer' }]);
    await p2;
    await flushPromises();
    catalogResolvers[0]([{ slug: 'older' }]);
    await p1;
    await flushPromises();

    expect(admin.catalog.value.map((v) => v.slug)).toEqual(['newer']); // stale load ignored
    expect(admin.loadingCatalog.value).toBe(false);
  });

  it('a catalog that no longer contains the active vocabulary reselects and supersedes its rows', async () => {
    // C1 selects A and starts loading A rows; a newer catalog then arrives WITHOUT A.
    // The accepted catalog must reconcile activeSlug (→ B) so the table can never show
    // A rows under a B-only catalog, and the in-flight A row load must be superseded.
    const catalogResolvers: Array<(v: unknown) => void> = [];
    vi.mocked(fetchMetadataCatalog).mockImplementation(
      () => new Promise((resolve) => catalogResolvers.push(resolve)) as ReturnType<
        typeof fetchMetadataCatalog
      >
    );
    const admin = useMetadataAdmin({ onToast: vi.fn() });

    const p1 = admin.loadCatalog(); // #1
    catalogResolvers[0]([{ slug: 'A' }]); // #1 → catalog [A], auto-selects A, loadRows(A) in flight
    await flushPromises();
    expect(admin.activeSlug.value).toBe('A');

    const p2 = admin.loadCatalog(); // #2
    catalogResolvers[1]([{ slug: 'B' }]); // #2 → catalog [B]; A is gone → reselect B, loadRows(B)
    await flushPromises();
    expect(admin.activeSlug.value).toBe('B');
    expect(admin.catalog.value.map((v) => v.slug)).toEqual(['B']);

    // Resolve the stale A rows FIRST (must be ignored), then B rows.
    rowsResolvers.find((r) => r.slug === 'A')!.resolve(metaResponse([{ id: 'a1' }]));
    rowsResolvers.find((r) => r.slug === 'B')!.resolve(metaResponse([{ id: 'b1' }]));
    await flushPromises();
    await p1;
    await p2;
    expect(admin.rows.value).toEqual([{ id: 'b1' }]); // B rows, never the stale A rows
  });

  it('an empty catalog supersedes an in-flight row load and does not leave loadingRows stuck', async () => {
    const catalogResolvers: Array<(v: unknown) => void> = [];
    vi.mocked(fetchMetadataCatalog).mockImplementation(
      () => new Promise((resolve) => catalogResolvers.push(resolve)) as ReturnType<
        typeof fetchMetadataCatalog
      >
    );
    const admin = useMetadataAdmin({ onToast: vi.fn() });

    const p1 = admin.loadCatalog(); // #1 → catalog [A], auto-selects A, loadRows(A) in flight
    catalogResolvers[0]([{ slug: 'A' }]);
    await flushPromises();
    expect(admin.activeSlug.value).toBe('A');
    expect(admin.loadingRows.value).toBe(true); // A rows still loading

    const p2 = admin.loadCatalog(); // #2 → EMPTY catalog
    catalogResolvers[1]([]);
    await flushPromises();
    expect(admin.activeSlug.value).toBeNull();
    expect(admin.rows.value).toEqual([]);
    expect(admin.loadingRows.value).toBe(false); // spinner cleared, not stuck

    // The stale A rows resolve LAST — must NOT repopulate or re-raise the spinner.
    rowsResolvers.find((r) => r.slug === 'A')!.resolve(metaResponse([{ id: 'a1' }]));
    await flushPromises();
    await p1;
    await p2;
    expect(admin.rows.value).toEqual([]);
    expect(admin.loadingRows.value).toBe(false);
  });
});
