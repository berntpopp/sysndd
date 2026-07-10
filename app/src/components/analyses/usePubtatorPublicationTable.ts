// src/components/analyses/usePubtatorPublicationTable.ts
//
// Request/cache orchestration for the PubTator publication table
// (PubtatorNDDTable.vue): filter/sort state, cursor pagination (all four
// TablePaginationControls transitions), data loading, Excel export, and the
// copy-link method. Extracted so the SFC stays a thin template shell.
//
// Behavior is a straight move of the previous in-component logic (data(),
// watch, mounted, methods), plus one deliberate correctness addition:
// loadTableData tags each request with a monotonically increasing
// `loadSerial` and drops a response superseded by a newer load, mirroring the
// stale-response guard in AnalysesCurationComparisonsTable.vue (#467) — an
// earlier slow request can otherwise resolve after a newer one and clobber
// the table with out-of-date rows/meta.
//
// Parser logic is NOT duplicated here: `parseAnnotations` / `getSegmentClass`
// are the shared helpers from usePubtatorParser.ts (module-level bounded LRU
// cache), and `createLruCache` is reused for the gene-symbols split cache.

import { markRaw, nextTick, onMounted, ref, watch, type Ref } from 'vue';
import { useRoute } from 'vue-router';
import {
  useToast,
  useUrlParsing,
  useColorAndSymbols,
  useText,
  useTableData,
  parsePubtatorTextMemoized,
  getSegmentClass,
} from '@/composables';
import { normalizeSelectOptions } from '@/utils/selectOptions';
import { listPubtatorTable, listPubtatorTableXlsx } from '@/api/publication';
import { createLruCache } from '@/utils/lruCache';
import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';

/** Field definition with optional selection properties. */
export interface PubtatorTableField {
  key: string;
  label: string;
  sortable: boolean;
  sortDirection?: string;
  class: string;
  filterable?: boolean;
  selectable?: boolean;
  multi_selectable?: boolean;
}

/** Single column-filter entry (global "any" + per-column). */
export interface PubtatorFilterEntry {
  // Every field on this table uses the 'contains' operator (never 'any'/'all'
  // — see createEmptyPubtatorFilter below), so content is string-or-null in
  // practice. This also keeps it compatible with TableSearchInput's model
  // (string | null); the broader (string | string[] | null) shape from
  // useUrlParsing's generic FilterField is only used locally where this
  // component calls filterStrToObj.
  content: string | null;
  join_char: string | null;
  operator: string;
}

export type PubtatorFilter = Record<string, PubtatorFilterEntry>;

/**
 * Single source of truth for the empty PubTator-table filter shape, used by
 * both the initial `filter` ref and `removeFilters()` so the two can't drift.
 */
export function createEmptyPubtatorFilter(): PubtatorFilter {
  return {
    any: { content: null, join_char: null, operator: 'contains' },
    search_id: { content: null, join_char: null, operator: 'contains' },
    pmid: { content: null, join_char: null, operator: 'contains' },
    doi: { content: null, join_char: null, operator: 'contains' },
    title: { content: null, join_char: null, operator: 'contains' },
    journal: { content: null, join_char: null, operator: 'contains' },
    date: { content: null, join_char: null, operator: 'contains' },
    score: { content: null, join_char: null, operator: 'contains' },
    gene_symbols: { content: null, join_char: null, operator: 'contains' },
    text_hl: { content: null, join_char: null, operator: 'contains' },
    // Virtual field for row expansion.
    details: { content: null, join_char: null, operator: 'contains' },
  };
}

/** Default table columns (overridden by the server-supplied fspec on load). */
export function defaultPubtatorTableFields(): PubtatorTableField[] {
  return [
    { key: 'search_id', label: 'Search ID', sortable: true, sortDirection: 'asc', class: 'text-start', filterable: true },
    { key: 'pmid', label: 'PMID', sortable: true, class: 'text-start', filterable: true },
    { key: 'doi', label: 'DOI', sortable: true, class: 'text-start', filterable: true },
    { key: 'title', label: 'Title', sortable: true, class: 'text-start', filterable: true },
    { key: 'journal', label: 'Journal', sortable: true, class: 'text-start', filterable: true },
    { key: 'date', label: 'Date', sortable: true, class: 'text-start', filterable: true },
    { key: 'score', label: 'Score', sortable: true, class: 'text-end', filterable: true },
    { key: 'gene_symbols', label: 'Genes', sortable: true, class: 'text-start', filterable: true },
    { key: 'text_hl', label: 'Text HL', sortable: true, class: 'text-start', filterable: true },
    { key: 'details', label: 'Details', sortable: false, class: 'text-center' },
  ];
}

/** Literal download filename for the Excel export (regression-guarded). */
export const PUBTATOR_TABLE_XLSX_FILENAME = 'publications.xlsx';

/** Shape of one row of the R/Plumber `meta` array for this endpoint. */
interface PubtatorTableMeta {
  totalItems?: number;
  currentPage?: number;
  totalPages?: number;
  prevItemID?: number | null;
  currentItemID?: number | null;
  nextItemID?: number | null;
  lastItemID?: number | null;
  executionTime?: number;
  fspec?: PubtatorTableField[];
}

export interface UsePubtatorPublicationTableProps {
  sortInput?: string;
  filterInput?: string | null;
  pageAfterInput?: string;
  pageSizeInput?: number;
  fspecInput?: string;
}

export function usePubtatorPublicationTable(props: UsePubtatorPublicationTableProps) {
  const { makeToast } = useToast();
  const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
  const colorAndSymbols = useColorAndSymbols();
  const text = useText();
  const route = useRoute();

  const tableData = useTableData({
    pageSizeInput: props.pageSizeInput,
    sortInput: props.sortInput,
    pageAfterInput: props.pageAfterInput,
  });
  const {
    items,
    totalRows,
    currentPage,
    currentItemID,
    prevItemID,
    nextItemID,
    lastItemID,
    executionTime,
    perPage,
    sortBy,
    sort,
    filter_string,
    downloading,
    loading,
    isBusy,
  } = tableData;

  const filter = ref<PubtatorFilter>(createEmptyPubtatorFilter());
  const fields = ref<PubtatorTableField[]>(defaultPubtatorTableFields());
  const fields_details = ref<unknown[]>([]);
  const totalPages = ref(0);

  // Non-reactive memoization cache for gene_symbols splits (keyed by the raw
  // comma-separated string). markRaw keeps Vue from making it reactive.
  const geneSymbolCache = markRaw(createLruCache<string, string[]>(2000));

  // Monotonic id of the latest load; a response whose id is stale is dropped
  // so an earlier request can't overwrite a newer filter/sort/page (#346).
  let loadSerial = 0;

  /**
   * Merge a server-supplied fspec into the current field list, forcing
   * `filterable` on every inbound field while preserving locally-known
   * `selectable`/`class`/`multi_selectable` overrides, and always keeping the
   * `details` row-expansion column pinned at the end.
   */
  function mergeFields(inboundFields: PubtatorTableField[]): PubtatorTableField[] {
    const merged = inboundFields.map((f) => {
      const existing = fields.value.find((x) => x.key === f.key);
      return {
        ...f,
        filterable: true,
        selectable: existing?.selectable ?? false,
        class: existing?.class ?? 'text-start',
        multi_selectable: existing?.multi_selectable ?? false,
      };
    });

    const detailsField = fields.value.find((x) => x.key === 'details');
    if (detailsField) {
      merged.push({
        ...detailsField,
        filterable: detailsField.filterable ?? false,
        selectable: detailsField.selectable ?? false,
        multi_selectable: detailsField.multi_selectable ?? false,
      });
    }

    return merged;
  }

  /** Fetches data from the API using sort/filter/cursor pagination. */
  async function loadTableData(): Promise<void> {
    const serial = (loadSerial += 1);
    isBusy.value = true;

    try {
      const data = await listPubtatorTable({
        sort: sort.value,
        filter: filter_string.value,
        page_after: String(currentItemID.value),
        page_size: String(perPage.value),
        fields: props.fspecInput,
      });
      // Drop a stale response superseded by a newer load.
      if (serial !== loadSerial) return;

      items.value = data.data;

      // R/Plumber serialises meta as a 1-row array of dynamic-key objects.
      const meta = data.meta as PubtatorTableMeta[] | undefined;
      if (meta && meta.length > 0) {
        const metaObj = meta[0];
        totalRows.value = metaObj.totalItems || 0;

        // Fix for b-pagination.
        void nextTick(() => {
          currentPage.value = metaObj.currentPage as number;
        });
        totalPages.value = metaObj.totalPages ?? 0;
        prevItemID.value = metaObj.prevItemID ?? null;
        currentItemID.value = metaObj.currentItemID ?? 0;
        nextItemID.value = metaObj.nextItemID ?? null;
        lastItemID.value = metaObj.lastItemID ?? null;
        executionTime.value = metaObj.executionTime ?? 0;

        if (metaObj.fspec && Array.isArray(metaObj.fspec)) {
          fields.value = mergeFields(metaObj.fspec);
        }
      }
      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();
    } catch (error) {
      if (serial === loadSerial) {
        makeToast(error, 'Error', 'danger');
      }
    } finally {
      if (serial === loadSerial) {
        isBusy.value = false;
      }
    }
  }

  /** Cursor pagination: the four TablePaginationControls transitions. */
  function handlePageChange(value: number): void {
    if (value === 1) {
      currentItemID.value = 0;
    } else if (value === totalPages.value) {
      currentItemID.value = lastItemID.value ?? 0;
    } else if (value > currentPage.value) {
      currentItemID.value = nextItemID.value ?? 0;
    } else if (value < currentPage.value) {
      currentItemID.value = prevItemID.value ?? 0;
    }
    filtered();
  }

  function handlePerPageChange(newSize: number | string): void {
    perPage.value = parseInt(String(newSize), 10) || 10;
    currentItemID.value = 0;
    filtered();
  }

  function filtered(): void {
    const filterStringLoc = filterObjToStr(filter.value);
    if (filterStringLoc !== filter_string.value) {
      filter_string.value = filterStringLoc;
    }
    loadTableData();
  }

  function removeFilters(): void {
    filter.value = createEmptyPubtatorFilter();
    currentItemID.value = 0;
    filtered();
  }

  function removeSearch(): void {
    filter.value.any.content = null;
  }

  /**
   * Handle sort update from GenericTable. ctx.sortBy is the column key
   * string, ctx.sortDesc is boolean. Convert to Bootstrap-Vue-Next array
   * format for consistency.
   */
  function handleSortUpdate(ctx: { sortBy: string; sortDesc: boolean }): void {
    sortBy.value = [{ key: ctx.sortBy, order: ctx.sortDesc ? 'desc' : 'asc' }];
  }

  /**
   * Handle sort changes - extract column and order from the array-based
   * sortBy and trigger a data reload with the new sort parameter.
   */
  function handleSortByOrDescChange(): void {
    currentItemID.value = 0;
    const sortColumn =
      Array.isArray(sortBy.value) && sortBy.value.length > 0 ? sortBy.value[0].key : 'search_id';
    const sortOrder =
      Array.isArray(sortBy.value) && sortBy.value.length > 0 ? sortBy.value[0].order : 'asc';
    const isDesc = sortOrder === 'desc';
    sort.value = (isDesc ? '-' : '+') + sortColumn;
    filtered();
  }

  async function requestExcel(): Promise<void> {
    downloading.value = true;

    try {
      const blob = await listPubtatorTableXlsx({
        sort: sort.value,
        filter: filter_string.value,
        page_after: '0',
        page_size: 'all',
        fields: props.fspecInput,
      });

      const fileURL = window.URL.createObjectURL(blob);
      const fileLink = document.createElement('a');
      fileLink.href = fileURL;
      fileLink.setAttribute('download', PUBTATOR_TABLE_XLSX_FILENAME);
      document.body.appendChild(fileLink);
      fileLink.click();
    } catch (error) {
      makeToast(error, 'Error downloading Excel', 'danger');
    }
    downloading.value = false;
  }

  function copyLinkToClipboard(): void {
    const urlParam =
      `sort=${sort.value}` +
      `&filter=${filter_string.value}` +
      `&page_after=${currentItemID.value}` +
      `&page_size=${perPage.value}`;
    const fullUrl = `${import.meta.env.VITE_URL + route.path}?${urlParam}`;
    navigator.clipboard.writeText(fullUrl);
    makeToast('Link copied to clipboard', 'Info', 'info');
  }

  function truncate(str: string, n: number): string {
    return Utils.truncate(str, n);
  }

  /**
   * Parse PubTator annotations. Delegates directly to the shared, memoized
   * parser (no re-implementation) so the preview-slice/length-check callers
   * in the SFC reuse the same bounded module-level cache as every other
   * PubTator consumer.
   */
  const parseAnnotations = parsePubtatorTextMemoized;

  /**
   * Split a comma-separated gene_symbols string into trimmed symbols once
   * (the template uses it ~3x/row). Memoized via a bounded LRU
   * (geneSymbolCache).
   */
  function geneSymbolList(geneSymbols: string | null | undefined): string[] {
    if (!geneSymbols) return [];
    const cached = geneSymbolCache.get(geneSymbols);
    if (cached) return cached;
    const list = geneSymbols
      .split(',')
      .map((g) => g.trim())
      .filter((g) => g !== '');
    geneSymbolCache.set(geneSymbols, list);
    return list;
  }

  // Re-run data load when filter changes.
  watch(
    filter,
    () => {
      filtered();
    },
    { deep: true }
  );

  // Watch for sortBy changes (deep watch for array format).
  watch(
    sortBy as Ref<Array<{ key: string; order: 'asc' | 'desc' }>>,
    (newVal) => {
      const newSortColumn = newVal && newVal.length > 0 ? newVal[0].key : 'search_id';
      const newSortOrder = newVal && newVal.length > 0 ? newVal[0].order : 'asc';
      const newSortString = (newSortOrder === 'desc' ? '-' : '+') + newSortColumn;
      // Only trigger if sort actually changed.
      if (newSortString !== sort.value) {
        handleSortByOrDescChange();
      }
    },
    { deep: true }
  );

  onMounted(() => {
    // Initialize sorting - use sortBy array format for Bootstrap-Vue-Next.
    // (sortDesc is a derived computed over sortBy — setting sortBy alone is
    // sufficient; useTableData exposes it as a read-only ComputedRef.)
    const sortObject = sortStringToVariables(props.sortInput || '-search_id');
    sortBy.value = sortObject.sortBy;

    // Initialize filters from input. filterStrToObj's declared signature is
    // the shared (string | string[] | null) FilterObject shape from
    // useUrlParsing; this component's own fields are string-or-null only
    // (all 'contains' operators), so the assignment target is cast to match
    // the call's parameter type without widening PubtatorFilterEntry itself.
    if (props.filterInput && props.filterInput !== 'null') {
      Object.assign(
        filter.value,
        filterStrToObj(
          props.filterInput,
          filter.value as unknown as Record<
            string,
            { content: string | string[] | null; operator: string; join_char: string | null }
          >
        )
      );
    }

    setTimeout(() => {
      loading.value = false;
    }, 500);

    // Load initial data.
    loadTableData();
  });

  return {
    // composable passthroughs (spread for template/vm access parity)
    ...colorAndSymbols,
    ...text,
    ...tableData,
    filterObjToStr,
    filterStrToObj,
    sortStringToVariables,
    makeToast,
    // local state
    filter,
    fields,
    fields_details,
    totalPages,
    geneSymbolCache,
    // methods
    loadTableData,
    handlePageChange,
    handlePerPageChange,
    filtered,
    removeFilters,
    removeSearch,
    handleSortUpdate,
    handleSortByOrDescChange,
    requestExcel,
    copyLinkToClipboard,
    mergeFields,
    truncate,
    parseAnnotations,
    getSegmentClass,
    geneSymbolList,
    normalizeSelectOptions,
  };
}

export default usePubtatorPublicationTable;
