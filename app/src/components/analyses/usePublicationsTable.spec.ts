// src/components/analyses/usePublicationsTable.spec.ts
//
// Contract tests for the request/state orchestration extracted from
// PublicationsNDDTable.vue. Exercises the composable directly (mounted in a
// bare Vue app so onMounted/useRoute work) rather than the SFC, mirroring the
// usePhenotypeClusterTable.spec.ts / useFunctionalClusterTable.spec.ts style
// for this refactor program (#346).
//
// Contract asserted here (task-3 brief):
//   1. URL-derived state (sort/filter/cursor) is applied before the single
//      initial network request fires.
//   2. Identical concurrent requests dedupe to one network call.
//   3. An older, now-stale in-flight response cannot overwrite state once a
//      newer request has superseded it.
//   4. first/last/next/previous cursor fields preserve string PMIDs (not
//      coerced to numbers), with the "null" sentinel normalized to 0.
//   5. Excel export calls listPublicationsXlsx with page_size:'all' and
//      downloads "publications.xlsx".
//   6. Response application keeps the four visible fspec columns and appends
//      one non-sortable "details" column.
//
// The request coordinator is module-level (survives Vue Router remounts by
// design — see the comment in usePublicationsTable.ts), so it persists across
// `it()` blocks in this file. Each test that fires a real request uses a
// distinct pageSizeInput so its cache-key params never collide with another
// test's.

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { createApp, type App } from 'vue';
import { createRouter, createMemoryHistory, type Router } from 'vue-router';
import { createPinia, setActivePinia } from 'pinia';
import type { PublicationListResponse, PublicationRecord } from '@/api/publication';

const makeToastSpy = vi.fn();

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return {
    ...actual,
    useToast: () => ({ makeToast: makeToastSpy }),
  };
});

const listPublicationsMock = vi.hoisted(() => vi.fn());
const listPublicationsXlsxMock = vi.hoisted(() => vi.fn());

vi.mock('@/api/publication', () => ({
  listPublications: listPublicationsMock,
  listPublicationsXlsx: listPublicationsXlsxMock,
}));

import { usePublicationsTable, type UsePublicationsTableProps } from './usePublicationsTable';

// ---------------------------------------------------------------------------
// Fixtures / harness
// ---------------------------------------------------------------------------

const DEFAULT_FSPEC = [
  { key: 'publication_id', label: 'Publication ID', sortable: true },
  { key: 'Title', label: 'Title', sortable: true },
  { key: 'Journal', label: 'Journal', sortable: true },
  { key: 'Publication_date', label: 'Publication date', sortable: true },
];

function makeListResponse(
  data: Array<Partial<PublicationRecord>>,
  metaOverrides: Record<string, unknown> = {},
  fspec: Array<Record<string, unknown>> = DEFAULT_FSPEC
): PublicationListResponse {
  return {
    data: data as PublicationRecord[],
    meta: [
      {
        totalItems: data.length,
        currentPage: 1,
        totalPages: 1,
        prevItemID: 0,
        currentItemID: 0,
        nextItemID: 0,
        lastItemID: 0,
        executionTime: 1,
        fspec,
        ...metaOverrides,
      },
    ],
  };
}

function baseProps(overrides: Partial<UsePublicationsTableProps> = {}): UsePublicationsTableProps {
  return {
    apiEndpoint: 'publication',
    showFilterControls: true,
    showPaginationControls: true,
    headerLabel: 'Publications table',
    sortInput: '+publication_id',
    filterInput: null,
    fieldsInput: null,
    pageAfterInput: '0',
    pageSizeInput: 10,
    fspecInput: 'publication_id,Title,Journal,Publication_date,Abstract,Lastname,Firstname,Keywords',
    ...overrides,
  };
}

const mountedApps: App[] = [];

async function mountPublicationsTable(props: UsePublicationsTableProps) {
  const router: Router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/Publications', component: { template: '<div />' } }],
  });
  await router.push('/Publications');
  await router.isReady();

  let result!: ReturnType<typeof usePublicationsTable>;
  const app = createApp({
    setup() {
      result = usePublicationsTable(props);
      // Empty render function — only the setup/lifecycle context is needed.
      return () => {};
    },
  });
  app.use(router);
  app.mount(document.createElement('div'));
  mountedApps.push(app);

  return { result, app };
}

/** Real 50ms internal loadData() debounce + a margin. */
const waitForDebounce = () => new Promise((resolve) => setTimeout(resolve, 80));

beforeEach(() => {
  setActivePinia(createPinia());
  makeToastSpy.mockClear();
  listPublicationsMock.mockReset();
  listPublicationsXlsxMock.mockReset();
});

afterEach(() => {
  mountedApps.splice(0).forEach((app) => app.unmount());
});

// ---------------------------------------------------------------------------
// 1. URL state applied before the single initial request
// ---------------------------------------------------------------------------

describe('initial load', () => {
  it('applies URL-derived filter, sort, and cursor state before firing the single initial request', async () => {
    listPublicationsMock.mockResolvedValue(makeListResponse([]));

    await mountPublicationsTable(
      baseProps({
        sortInput: '-Title',
        filterInput: 'contains(Title,epilepsy)',
        pageAfterInput: '55',
        pageSizeInput: 25,
        fspecInput: 'publication_id,Title,Journal,Publication_date',
      })
    );

    await waitForDebounce();
    await flushPromises();

    expect(listPublicationsMock).toHaveBeenCalledTimes(1);
    expect(listPublicationsMock).toHaveBeenCalledWith({
      sort: '-Title',
      filter: 'contains(Title,epilepsy)',
      page_after: '55',
      page_size: '25',
      fields: 'publication_id,Title,Journal,Publication_date',
    });
  });
});

// ---------------------------------------------------------------------------
// 2. Identical concurrent requests dedupe
// ---------------------------------------------------------------------------

describe('request coordinator — dedupe', () => {
  it('dedupes identical concurrent doLoadData() calls into a single network request', async () => {
    const resolvers: Array<(value: PublicationListResponse) => void> = [];
    listPublicationsMock.mockImplementation(
      () =>
        new Promise<PublicationListResponse>((resolve) => {
          resolvers.push(resolve);
        })
    );

    const { result } = await mountPublicationsTable(baseProps({ pageSizeInput: 12 }));
    await waitForDebounce();
    expect(listPublicationsMock).toHaveBeenCalledTimes(1); // mount's initial request, in flight

    // Two more concurrent calls with identical (unchanged) params must not
    // trigger new fetches — they share the in-flight request.
    const second = result.doLoadData();
    const third = result.doLoadData();

    resolvers[0](makeListResponse([{ publication_id: 'PMID:1' }]));
    await Promise.all([second, third]);

    expect(listPublicationsMock).toHaveBeenCalledTimes(1);
    expect(result.items.value).toHaveLength(1);
  });
});

// ---------------------------------------------------------------------------
// 3. An older, different response must NOT overwrite current state
// ---------------------------------------------------------------------------

describe('request coordinator — stale response guard', () => {
  it('discards an older in-flight response once a newer request has superseded it', async () => {
    const resolvers: Array<(value: PublicationListResponse) => void> = [];
    listPublicationsMock.mockImplementation(
      () =>
        new Promise<PublicationListResponse>((resolve) => {
          resolvers.push(resolve);
        })
    );

    const { result } = await mountPublicationsTable(baseProps({ pageSizeInput: 21 }));
    await waitForDebounce();
    expect(listPublicationsMock).toHaveBeenCalledTimes(1); // request A in flight

    // Move the state on to a different query, then fire request B directly
    // (bypassing the debounce) while A is still unresolved.
    result.sort.value = '-Title';
    const requestB = result.doLoadData();
    expect(listPublicationsMock).toHaveBeenCalledTimes(2);

    // Resolve the OLDER request A first: its data must be discarded because
    // the composable's isCurrent() check now reflects request B's params.
    resolvers[0](makeListResponse([{ publication_id: 'PMID:OLD' }]));
    await flushPromises();
    expect(result.items.value).toEqual([]);

    // Resolve the newer request B; its data must win.
    resolvers[1](makeListResponse([{ publication_id: 'PMID:NEW' }]));
    await requestB;
    expect(result.items.value).toEqual([{ publication_id: 'PMID:NEW' }]);
  });
});

// ---------------------------------------------------------------------------
// 4. Cursor fields preserve string PMIDs
// ---------------------------------------------------------------------------

describe('applyApiResponse — cursor pagination', () => {
  it('preserves string PMIDs in first/last/next/previous cursor fields', async () => {
    listPublicationsMock.mockResolvedValue(makeListResponse([]));
    const { result } = await mountPublicationsTable(baseProps({ pageSizeInput: 44 }));
    await waitForDebounce();
    await flushPromises();

    result.applyApiResponse(
      makeListResponse([{ publication_id: 'PMID:200' }], {
        prevItemID: 'PMID:100',
        currentItemID: 'PMID:200',
        nextItemID: 'PMID:300',
        lastItemID: 'PMID:999',
      })
    );

    expect(result.prevItemID.value).toBe('PMID:100');
    expect(result.currentItemID.value).toBe('PMID:200');
    expect(result.nextItemID.value).toBe('PMID:300');
    expect(result.lastItemID.value).toBe('PMID:999');
  });

  it('normalizes the "null" cursor sentinel to 0 without stringifying it', async () => {
    listPublicationsMock.mockResolvedValue(makeListResponse([]));
    const { result } = await mountPublicationsTable(baseProps({ pageSizeInput: 45 }));
    await waitForDebounce();
    await flushPromises();

    result.applyApiResponse(
      makeListResponse([], {
        prevItemID: 'null',
        currentItemID: 'null',
        nextItemID: 'null',
        lastItemID: 'null',
      })
    );

    expect(result.prevItemID.value).toBe(0);
    expect(result.currentItemID.value).toBe(0);
    expect(result.nextItemID.value).toBe(0);
    expect(result.lastItemID.value).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// 5. Excel export
// ---------------------------------------------------------------------------

describe('requestExcel', () => {
  it('calls listPublicationsXlsx with page_size "all" and downloads publications.xlsx', async () => {
    listPublicationsMock.mockResolvedValue(makeListResponse([]));
    const blob = new Blob(['x'], { type: 'application/octet-stream' });
    listPublicationsXlsxMock.mockResolvedValue(blob);
    const createObjectURL = vi.fn().mockReturnValue('blob:mock-publications');
    window.URL.createObjectURL = createObjectURL;
    const appendChildSpy = vi.spyOn(document.body, 'appendChild');

    const { result } = await mountPublicationsTable(
      baseProps({ pageSizeInput: 46, fspecInput: 'publication_id,Title,Journal,Publication_date' })
    );
    await waitForDebounce();
    await flushPromises();

    await result.requestExcel();

    expect(listPublicationsXlsxMock).toHaveBeenCalledTimes(1);
    expect(listPublicationsXlsxMock).toHaveBeenCalledWith({
      sort: '+publication_id',
      filter: '',
      page_after: '0',
      page_size: 'all',
      fields: 'publication_id,Title,Journal,Publication_date',
    });
    expect(createObjectURL).toHaveBeenCalledWith(blob);

    const anchorCall = appendChildSpy.mock.calls.find(
      ([node]) => (node as HTMLElement).tagName === 'A'
    );
    expect(anchorCall).toBeDefined();
    const anchor = anchorCall![0] as HTMLAnchorElement;
    expect(anchor.getAttribute('download')).toBe('publications.xlsx');
    expect(result.downloading.value).toBe(false);

    appendChildSpy.mockRestore();
  });
});

// ---------------------------------------------------------------------------
// 6. fspec column merge
// ---------------------------------------------------------------------------

describe('applyApiResponse — fspec columns', () => {
  it('keeps the four visible fspec columns and appends a non-sortable details column', async () => {
    listPublicationsMock.mockResolvedValue(makeListResponse([]));
    const { result } = await mountPublicationsTable(baseProps({ pageSizeInput: 47 }));
    await waitForDebounce();
    await flushPromises();

    result.applyApiResponse(
      makeListResponse([], undefined, [
        { key: 'publication_id', label: 'Publication ID', sortable: true },
        { key: 'Title', label: 'Title', sortable: true },
        { key: 'Journal', label: 'Journal', sortable: true },
        { key: 'Publication_date', label: 'Publication date', sortable: true },
        { key: 'Abstract', label: 'Abstract', sortable: true },
        { key: 'Lastname', label: 'Lastname', sortable: true },
        { key: 'Firstname', label: 'Firstname', sortable: true },
        { key: 'Keywords', label: 'Keywords', sortable: true },
      ])
    );

    const keys = result.fields.value.map((f: { key: string }) => f.key);
    expect(keys).toContain('publication_id');
    expect(keys).toContain('Title');
    expect(keys).toContain('Journal');
    expect(keys).toContain('Publication_date');
    expect(keys).not.toContain('Abstract');
    expect(keys).not.toContain('Lastname');
    expect(keys).not.toContain('Firstname');
    expect(keys).not.toContain('Keywords');
    expect(keys[keys.length - 1]).toBe('details');
    expect(keys).toHaveLength(5);

    const details = result.fields.value.find((f: { key: string }) => f.key === 'details');
    expect(details).toMatchObject({ key: 'details', class: 'text-center', sortable: false });
  });
});
