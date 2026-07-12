// src/components/analyses/usePubtatorGenesTable.ts
//
// Table orchestration for the PubTator gene-prioritization table
// (PubtatorNDDGenes.vue): filter/URL state, cursor-paginated loading, the
// enrichment-freshness notice, page/sort handlers, Excel export, and the
// server fspec -> local fields merge (issue #346). Pure per-column display
// formatting stays in pubtatorEnrichmentDisplay.ts, filter-object helpers
// stay in pubtatorGeneFilters.ts, and the per-gene publication-detail cache
// stays in usePubtatorGenePublications.ts -- this composable orchestrates
// them, it does not fold their logic in.

import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { listPubtatorGenes } from '@/api/publication';
import { useColumnTooltip } from '@/composables/useColumnTooltip';
import useTableData from '@/composables/useTableData';
import useToast from '@/composables/useToast';
import useUrlParsing from '@/composables/useUrlParsing';
import { useExcelExport } from '@/composables/useExcelExport';
import { usePubtatorGenePublications } from '@/composables/usePubtatorGenePublications';
import { useUiStore } from '@/stores/ui';
import {
  applyPubtatorGenePrioritizationFilters,
  createDefaultPubtatorGeneFilter,
  type PubtatorGeneFilter,
} from './pubtatorGeneFilters';
import {
  createPubtatorGeneFields,
  type PubtatorGeneFieldDefinition as FieldDefinition,
} from './pubtatorEnrichmentDisplay';

/** One row of the gene-prioritization listing (mirrors GET /pubtator/genes). */
export interface PubtatorGeneItem {
  gene_symbol: string;
  gene_name: string;
  gene_normalized_id?: string;
  hgnc_id?: string;
  publication_count: number;
  oldest_pub_date?: string;
  is_novel: number;
  pmids?: string;
  // Normalized enrichment metrics (issue #175); null until first refresh.
  observed?: number | null;
  background_count?: number | null;
  enrichment_ratio?: number | null;
  npmi?: number | null;
  fisher_p?: number | null;
  fdr_bh?: number | null;
}

export interface PubtatorGenesTableProps {
  sortInput: string;
  filterInput: string | null;
  pageAfterInput: string;
  pageSizeInput: number;
  fspecInput: string;
}

export type PubtatorGenesTableEmit = (event: 'novel-count', count: number) => void;

interface PubtatorGenesResponseMeta {
  totalItems?: number;
  totalPages?: number;
  prevItemID?: number | null;
  currentItemID?: number;
  nextItemID?: number | null;
  lastItemID?: number | null;
  currentPage?: number;
  fspec?: FieldDefinition[];
  // Enrichment-freshness fields from /pubtator/genes meta (camelCase, like
  // executionTime/totalItems); absent on older API responses.
  enrichmentStatus?: string;
  enrichmentRefreshedAt?: string;
}

/**
 * Unwrap a Plumber response `meta`, always sent scalar-array-wrapped
 * (`[{...}]`) rather than as a bare object, into the plain object pagination
 * code can read. Returns null when the array is missing or empty, so callers
 * skip the pagination update entirely rather than mutating from a partial
 * shape.
 */
export function normalizePubtatorGenesMeta(meta: unknown): PubtatorGenesResponseMeta | null {
  if (Array.isArray(meta) && meta.length > 0) {
    return meta[0] as PubtatorGenesResponseMeta;
  }
  return null;
}

/**
 * Merge server fspec changes into the local fields, preserving each column's
 * locally-owned `filterable`/`class`, and append exactly one trailing
 * `actions` column (the expand-row control BTable renders; the server never
 * sends this frontend-only column). Any inbound `actions` entry is dropped
 * first so a stray server field can never produce a duplicate.
 */
export function mergePubtatorGeneFields(
  inboundFields: FieldDefinition[],
  currentFields: FieldDefinition[]
): FieldDefinition[] {
  const merged = inboundFields
    .filter((f) => f.key !== 'actions')
    .map((f) => {
      const existing = currentFields.find((x) => x.key === f.key);
      return {
        ...f,
        filterable: existing?.filterable ?? false,
        class: existing?.class ?? 'text-start',
      };
    });

  merged.push({
    key: 'actions',
    label: '',
    sortable: false,
    class: 'text-center',
    filterable: false,
  });

  return merged;
}

/**
 * Build a non-blocking notice string from the optional enrichment-freshness
 * meta. Returns null when the ranking is current or the fields are absent
 * (defensive: never throw on a shape the API may not yet send).
 */
export function deriveEnrichmentNotice(
  status: string | undefined,
  refreshedAt: string | undefined
): string | null {
  if (!status || status === 'current') return null;
  if (status === 'missing') {
    return 'Gene ranking not yet computed. Showing raw co-occurrence ordering until the first refresh.';
  }
  if (status === 'stale') {
    const when = refreshedAt ? ` (last refreshed ${formatRefreshedAt(refreshedAt)})` : '';
    return `Gene ranking may be out of date${when}.`;
  }
  return null;
}

/** Best-effort human-friendly date for the freshness notice. */
function formatRefreshedAt(value: string): string {
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleDateString();
}

export function usePubtatorGenesTable(props: PubtatorGenesTableProps, emit: PubtatorGenesTableEmit) {
  const { makeToast } = useToast();
  const { getCompactTooltipText } = useColumnTooltip();
  const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
  const tableData = useTableData({
    pageSizeInput: props.pageSizeInput,
    sortInput: props.sortInput,
    pageAfterInput: props.pageAfterInput,
  });
  const { isExporting, exportToExcel } = useExcelExport();
  const route = useRoute();

  const {
    items,
    totalRows,
    perPage,
    currentPage,
    sortBy,
    sort,
    loading,
    isBusy,
    downloading,
    currentItemID,
    prevItemID,
    nextItemID,
    lastItemID,
    filter_string: filterString,
    pageOptions,
    removeFiltersButtonTitle,
    removeFiltersButtonVariant,
  } = tableData;

  // Table fields (includes issue #175 enrichment columns) and the
  // component-specific filter object.
  const fields = ref<FieldDefinition[]>(createPubtatorGeneFields());
  const filter = ref<PubtatorGeneFilter>(createDefaultPubtatorGeneFilter());

  // Prioritization filter options.
  const minPublications = ref<string>('all');
  const pubCountOptions = [
    { value: 'all', text: 'All' },
    { value: '2', text: '2+' },
    { value: '5', text: '5+' },
    { value: '10', text: '10+' },
  ];

  const dateRange = ref<string>('all');
  const dateRangeOptions = [
    { value: 'all', text: 'All time' },
    { value: '1', text: 'Last 1 year' },
    { value: '2', text: 'Last 2 years' },
    { value: '5', text: 'Last 5 years' },
  ];

  // Cursor pagination info, and the non-blocking notice shown when the genes
  // API reports the gene ranking is not yet computed / is stale.
  const totalPages = ref(0);
  const enrichmentNotice = ref<string | null>(null);

  // Per-gene publication-detail cache (extracted composable). Scoped to the
  // current filter/sort: resetCache() runs on every reload so an expanded row
  // never shows publications fetched under a previous query.
  const {
    fetchPublications,
    getPublications,
    isLoading: isLoadingPublications,
    isCached,
    resetCache: resetPublicationCache,
    cancelAll: cancelAllPublicationFetches,
  } = usePubtatorGenePublications({ makeToast });

  // sortBy as a properly typed array for BTable; "any" filter string binding.
  const sortByArray = computed(() => sortBy.value);
  const anyFilterContent = computed({
    get: () => {
      const content = filter.value.any.content;
      return typeof content === 'string' ? content : '';
    },
    set: (value: string) => {
      filter.value.any.content = value || null;
    },
  });

  // Helpers for filter content binding.
  const getFilterContent = (key: string): string => {
    const content = filter.value[key]?.content;
    return typeof content === 'string' ? content : '';
  };

  const setFilterContent = (key: string, value: string) => {
    if (filter.value[key]) {
      filter.value[key].content = value || null;
      filtered();
    }
  };

  // Novel gene count, emitted to the parent whenever it changes.
  const novelCount = computed(
    () => (items.value as PubtatorGeneItem[]).filter((g) => g.is_novel === 1).length
  );
  watch(
    novelCount,
    (count) => {
      emit('novel-count', count);
    },
    { immediate: true }
  );

  const parsePmids = (pmids: string | undefined): string[] => {
    if (!pmids) return [];
    return pmids.split(',').filter((p) => p.trim() !== '');
  };

  const truncateText = (str: string | undefined, n: number): string => {
    if (!str) return '';
    return str.length > n ? `${str.slice(0, n)}...` : str;
  };

  // Fetch publication data lazily via the cache composable on row expansion.
  const handleRowExpand = (item: PubtatorGeneItem) => {
    const pmids = parsePmids(item.pmids);
    if (pmids.length > 0 && !isCached(item.gene_symbol)) {
      fetchPublications(item.gene_symbol, pmids);
    }
  };

  const applyPrioritizationFilters = () => {
    filter.value = applyPubtatorGenePrioritizationFilters(filter.value, {
      minPublications: minPublications.value,
      dateRangeYears: dateRange.value,
    });
    currentItemID.value = 0;
    filtered();
  };

  // Monotonic request id: only the newest in-flight load may commit its
  // result, so an overlapping filter/sort/page change can never have a slow,
  // stale response replace a newer response that already landed.
  let latestRequestId = 0;

  const loadData = async () => {
    isBusy.value = true;

    // The gene set is about to change (filter / sort / page). Drop the per-gene
    // publication cache so an expanded row cannot show publications fetched under
    // the previous query (correctness fix).
    resetPublicationCache();

    const requestId = ++latestRequestId;

    try {
      const response = await listPubtatorGenes({
        sort: sort.value,
        filter: filterString.value,
        page_after: currentItemID.value,
        page_size: String(perPage.value),
        fields: props.fspecInput,
      });

      // A newer load already started (and may have already landed); this
      // response is stale and must not overwrite the newer state.
      if (requestId !== latestRequestId) return;

      items.value = response.data || [];

      const metaObj = normalizePubtatorGenesMeta(response.meta);
      if (metaObj) {
        totalRows.value = metaObj.totalItems || 0;
        totalPages.value = metaObj.totalPages || 1;
        prevItemID.value = metaObj.prevItemID || null;
        currentItemID.value = metaObj.currentItemID || 0;
        nextItemID.value = metaObj.nextItemID || null;
        lastItemID.value = metaObj.lastItemID || null;

        currentPage.value = metaObj.currentPage || 1;

        if (metaObj.fspec && Array.isArray(metaObj.fspec)) {
          fields.value = mergePubtatorGeneFields(metaObj.fspec, fields.value);
        }

        enrichmentNotice.value = deriveEnrichmentNotice(
          metaObj.enrichmentStatus,
          metaObj.enrichmentRefreshedAt
        );
      }

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();
    } catch (error) {
      if (requestId !== latestRequestId) return;
      makeToast(error, 'Error', 'danger');
    } finally {
      if (requestId === latestRequestId) {
        isBusy.value = false;
      }
    }
  };

  const handlePageChange = (value: number) => {
    if (value === 1) {
      currentItemID.value = 0;
    } else if (value === totalPages.value) {
      currentItemID.value = lastItemID.value || 0;
    } else if (value > currentPage.value) {
      currentItemID.value = nextItemID.value || 0;
    } else if (value < currentPage.value) {
      currentItemID.value = prevItemID.value || 0;
    }
    filtered();
  };

  const handlePerPageChange = (newSize: number | string) => {
    perPage.value = parseInt(String(newSize), 10) || 10;
    currentItemID.value = 0;
    filtered();
  };

  // Rebuild the filter string and reload.
  const filtered = () => {
    const filterStringLoc = filterObjToStr(filter.value);
    if (filterStringLoc !== filterString.value) {
      filterString.value = filterStringLoc;
    }
    loadData();
  };

  const removeFilters = () => {
    filter.value = createDefaultPubtatorGeneFilter();
    minPublications.value = 'all';
    dateRange.value = 'all';
    currentItemID.value = 0;
    filtered();
  };

  const removeSearch = () => {
    filter.value.any.content = null;
  };

  const handleSortByUpdate = (newSortBy: Array<{ key: string; order: 'asc' | 'desc' }>) => {
    sortBy.value = newSortBy;
    currentItemID.value = 0;
    if (newSortBy && newSortBy.length > 0) {
      const sortKey = newSortBy[0].key;
      const sortDesc = newSortBy[0].order === 'desc';
      sort.value = (sortDesc ? '-' : '+') + sortKey;
    }
    filtered();
  };

  const copyLinkToClipboard = () => {
    const urlParam =
      `sort=${sort.value}` +
      `&filter=${filterString.value}` +
      `&page_after=${currentItemID.value}` +
      `&page_size=${perPage.value}`;
    const fullUrl = `${import.meta.env.VITE_URL}${route.path}?${urlParam}`;
    navigator.clipboard.writeText(fullUrl);
    makeToast('Link copied to clipboard', 'Info', 'info');
  };

  const handleExcelExport = async () => {
    if ((items.value as PubtatorGeneItem[]).length === 0) {
      makeToast('No data to export', 'Warning', 'warning');
      return;
    }

    const exportData = (items.value as PubtatorGeneItem[]).map((gene) => ({
      gene_symbol: gene.gene_symbol,
      gene_name: gene.gene_name,
      publication_count: gene.publication_count,
      background_count: gene.background_count ?? '',
      enrichment_ratio: gene.enrichment_ratio ?? '',
      npmi: gene.npmi ?? '',
      fisher_p: gene.fisher_p ?? '',
      fdr_bh: gene.fdr_bh ?? '',
      oldest_pub_date: gene.oldest_pub_date || '',
      source: gene.is_novel === 1 ? 'Literature Only' : 'Curated',
      pmids: gene.pmids || '',
    }));

    try {
      await exportToExcel(exportData, {
        filename: `pubtator_genes_${new Date().toISOString().split('T')[0]}`,
        sheetName: 'Gene Prioritization',
        headers: {
          gene_symbol: 'Gene Symbol',
          gene_name: 'Gene Name',
          publication_count: 'NDD Publication Count',
          background_count: 'Background (Total) Publications',
          enrichment_ratio: 'Enrichment Ratio',
          npmi: 'NPMI',
          fisher_p: 'Fisher p-value',
          fdr_bh: 'FDR (BH q-value)',
          oldest_pub_date: 'Oldest Publication',
          source: 'Source',
          pmids: 'PMIDs',
        },
      });
      makeToast('Excel file downloaded', 'Success', 'success');
    } catch (_error) {
      makeToast('Export failed', 'Error', 'danger');
    }
  };

  // Abort all in-flight publication requests on unmount.
  onUnmounted(() => {
    cancelAllPublicationFetches();
  });

  onMounted(() => {
    const sortObject = sortStringToVariables(props.sortInput);
    sortBy.value = sortObject.sortBy;
    sort.value = props.sortInput;

    if (props.filterInput && props.filterInput !== 'null' && props.filterInput !== '') {
      filter.value = filterStrToObj(props.filterInput, filter.value);
    }

    // Slight delay, then show the table.
    setTimeout(() => {
      loading.value = false;
    }, 300);

    loadData();
  });

  return {
    // table state
    items,
    totalRows,
    perPage,
    fields,
    filter,
    loading,
    isBusy,
    downloading,
    pageOptions,
    removeFiltersButtonTitle,
    removeFiltersButtonVariant,
    sortByArray,
    enrichmentNotice,
    // prioritization filters
    minPublications,
    pubCountOptions,
    dateRange,
    dateRangeOptions,
    anyFilterContent,
    getFilterContent,
    setFilterContent,
    applyPrioritizationFilters,
    // pagination / sort / filter handlers
    handlePageChange,
    handlePerPageChange,
    handleSortByUpdate,
    filtered,
    removeFilters,
    removeSearch,
    // export
    isExporting,
    handleExcelExport,
    // link
    copyLinkToClipboard,
    // publications (per-gene detail cache passthrough)
    handleRowExpand,
    isLoadingPublications,
    getPublications,
    cancelAllPublicationFetches,
    // helpers
    parsePmids,
    truncateText,
    getCompactTooltipText,
  };
}

export default usePubtatorGenesTable;
