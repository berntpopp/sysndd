// src/components/analyses/useFunctionalClusterTable.ts
//
// Table-side state and behavior for the functional gene-clusters analysis
// (FunctionalClusterTablePanel.vue): table-type selection, column filters,
// sorting, pagination, cell formatting, and Excel export. Extracted so the
// panel component stays a thin template shell. Cluster selection, network sync,
// and the LLM summary live in the parent; this composable receives the selected
// cluster's rows through props and reports table events back through `emit`.

import { computed, reactive, ref, watch } from 'vue';
import useToast from '@/composables/useToast';
import { useWildcardSearch } from '@/composables/useWildcardSearch';
import { useExcelExport } from '@/composables/useExcelExport';
import { getClusterColor as getClusterColorUtil } from '@/utils/clusterColors';
import { filterFunctionalClusterRows, sortFunctionalClusterRows } from './functionalClusterTable';
import type { FunctionalClusterTableType } from './functionalClusterTable';
import {
  buildClusterTableFields,
  categoryChipClass,
  findCategoryText as findCategoryTextHelper,
  findCategoryLink as findCategoryLinkHelper,
  formatFdr as formatFdrHelper,
  buildClusterExportFilename,
  clusterExportSheetName,
  CLUSTER_EXPORT_HEADERS,
} from './geneClusterTableData';
import type { CategoryDescriptor } from './geneClusterTableData';

type Row = Record<string, unknown>;

/** Props consumed from FunctionalClusterTablePanel.vue. */
export interface FunctionalClusterTableProps {
  selectedCluster: Record<string, Row[]>;
  valueCategories: CategoryDescriptor[];
  geneSearchPattern: string;
  showAllClustersInTable: boolean;
  displayedClusters: number[];
  hoveredRowId: string | number | null;
}

type EmitFn = {
  (event: 'update:geneSearchPattern', value: string): void;
  (event: 'update:searchMatchCount', value: number): void;
  (event: 'row-hover', hgncId: string | number | null): void;
};

interface FilterEntry {
  content: string | null;
  operator: string;
}

export function useFunctionalClusterTable(props: FunctionalClusterTableProps, emit: EmitFn) {
  const { makeToast } = useToast();
  // Wildcard search for filtering the identifiers table.
  const wildcardSearch = useWildcardSearch();
  // Excel export functionality.
  const { isExporting, exportToExcel } = useExcelExport();

  const tableType = ref<FunctionalClusterTableType>('term_enrichment');
  const tableOptions = [
    { value: 'term_enrichment', text: 'Term enrichment' },
    { value: 'identifiers', text: 'Identifiers' },
  ];

  const filter = reactive<Record<string, FilterEntry>>({
    any: { content: null, operator: 'contains' },
    cluster_num: { content: null, operator: 'contains' },
    category: { content: null, operator: 'contains' },
    number_of_genes: { content: null, operator: 'contains' },
    fdr: { content: null, operator: 'contains' },
    description: { content: null, operator: 'contains' },
    symbol: { content: null, operator: 'contains' },
    STRING_id: { content: null, operator: 'contains' },
  });
  // Specialized filter values (separate from the text filter object).
  const categoryFilter = ref<string | null>(null); // GO, KEGG, MONDO, or null for all
  const fdrThreshold = ref<number | null>(null); // FDR threshold or custom value
  const sortBy = ref<string>('fdr');
  const sortDesc = ref(false);

  // Pagination
  const perPage = ref(10);
  const totalRows = ref(1);
  const currentPage = ref(1);

  /** Writable proxy for the shared gene search pattern (v-model on TermSearch). */
  const searchPattern = computed<string>({
    get: () => props.geneSearchPattern,
    set: (val) => emit('update:geneSearchPattern', val ?? ''),
  });

  /** Category options for the CategoryFilter dropdown, derived from the API. */
  const categoryOptions = computed(() => {
    if (!props.valueCategories || props.valueCategories.length === 0) {
      return [
        { value: 'GO', text: 'GO (Gene Ontology)' },
        { value: 'KEGG', text: 'KEGG (Pathways)' },
        { value: 'MONDO', text: 'MONDO (Disease)' },
      ];
    }
    return props.valueCategories.map((cat) => ({ value: cat.value, text: cat.text }));
  });

  /** Field array based on tableType (delegates to the pure field builder). */
  const fieldsComputed = computed(() => buildClusterTableFields(tableType.value));

  /** Label showing which cluster(s) data is displayed in the table. */
  const clusterDisplayLabel = computed(() => {
    if (props.showAllClustersInTable || props.displayedClusters.length === 0) {
      return 'All Clusters';
    }
    if (props.displayedClusters.length === 1) {
      return `Cluster ${props.displayedClusters[0]}`;
    }
    return `Clusters ${[...props.displayedClusters].sort((a, b) => a - b).join(', ')}`;
  });

  /** Sync the wildcard pattern and run all active table filters over `items`. */
  function applyFilters(items: Row[]): Row[] {
    const pattern = props.geneSearchPattern || '';
    if (pattern !== wildcardSearch.pattern.value) {
      wildcardSearch.pattern.value = pattern;
    }

    const columnFilters = Object.fromEntries(
      Object.entries(filter)
        .filter(([key]) => key !== 'any')
        .map(([key, entry]) => [key, entry.content])
    );

    return filterFunctionalClusterRows(items, {
      tableType: tableType.value,
      searchPattern: pattern,
      wildcardMatches: (symbol: string) => wildcardSearch.matches(symbol),
      categoryFilter: categoryFilter.value,
      fdrThreshold: fdrThreshold.value,
      anyText: filter.any.content,
      columnFilters,
    });
  }

  /** Filtered + sorted + paginated items for the current tableType. */
  const displayedItems = computed<Row[]>(() => {
    let dataArray = props.selectedCluster[tableType.value] || [];
    dataArray = applyFilters(dataArray);
    dataArray = sortFunctionalClusterRows(dataArray, sortBy.value, sortDesc.value);

    const start = (currentPage.value - 1) * perPage.value;
    const end = start + perPage.value;
    return dataArray.slice(start, end);
  });

  /**
   * Update totalRows based on filtered data. Called when the search pattern,
   * tableType, or a specialized filter changes.
   */
  function updateFilteredTotalRows(): void {
    const arr = props.selectedCluster[tableType.value] || [];
    const filtered = applyFilters(arr);
    totalRows.value = filtered.length;

    // Update the search match count for the identifiers table.
    if (tableType.value === 'identifiers' && props.geneSearchPattern) {
      emit('update:searchMatchCount', filtered.length);
    }
  }

  function onFilterChange(): void {
    currentPage.value = 1;
  }
  function handlePageChange(newPage: number): void {
    currentPage.value = newPage;
  }
  function handlePerPageChange(newPerPage: number): void {
    perPage.value = newPerPage;
    currentPage.value = 1;
  }
  function handleSortUpdate(payload: { sortBy: string; sortDesc: boolean }): void {
    sortBy.value = payload.sortBy;
    sortDesc.value = payload.sortDesc;
  }

  function findCategoryText(categoryVal: string): string {
    return findCategoryTextHelper(props.valueCategories, categoryVal);
  }
  function findCategoryLink(categoryVal: string, termVal: string): string {
    return findCategoryLinkHelper(props.valueCategories, categoryVal, termVal);
  }
  function getCategoryChipClass(category: string): string {
    return categoryChipClass(category);
  }
  function formatFdr(fdr: unknown): string {
    return formatFdrHelper(fdr);
  }
  function getClusterColor(clusterNum: number | string): string {
    return getClusterColorUtil(clusterNum);
  }

  /** Highlight a row when the network hovers its corresponding node (NAVL-05). */
  function isRowHighlighted(hgncId: string | number | null): boolean {
    return props.hoveredRowId === hgncId;
  }
  /** Forward a table row hover to the parent so it can highlight the node. */
  function handleTableRowHover(hgncId: string | number | null): void {
    emit('row-hover', hgncId);
  }

  /** Download all filtered data (not just the current page) as an Excel file. */
  function downloadExcel(): void {
    let dataArray = props.selectedCluster[tableType.value] || [];
    dataArray = applyFilters(dataArray);

    if (dataArray.length === 0) {
      makeToast('No data to export', 'Warning', 'warning');
      return;
    }

    const headers = CLUSTER_EXPORT_HEADERS[tableType.value];
    const filename = buildClusterExportFilename(
      tableType.value,
      props.showAllClustersInTable,
      props.displayedClusters
    );

    exportToExcel(dataArray, {
      filename,
      sheetName: clusterExportSheetName(tableType.value),
      headers,
    });
  }

  watch(
    () => props.selectedCluster,
    () => {
      // Cluster selection changed: reset to the unfiltered row count and page 1
      // (mirrors the parent's previous setActiveCluster/handleClustersChanged).
      const arr = props.selectedCluster[tableType.value] || [];
      totalRows.value = arr.length;
      currentPage.value = 1;
    }
  );
  watch(tableType, () => {
    updateFilteredTotalRows();
    currentPage.value = 1;
  });
  watch(
    () => props.geneSearchPattern,
    () => {
      updateFilteredTotalRows();
      currentPage.value = 1;
    }
  );
  watch(categoryFilter, () => {
    updateFilteredTotalRows();
    currentPage.value = 1;
  });
  watch(fdrThreshold, () => {
    updateFilteredTotalRows();
    currentPage.value = 1;
  });

  return {
    // state
    tableType,
    tableOptions,
    filter,
    categoryFilter,
    fdrThreshold,
    sortBy,
    sortDesc,
    perPage,
    totalRows,
    currentPage,
    isExporting,
    // computed
    searchPattern,
    categoryOptions,
    fieldsComputed,
    clusterDisplayLabel,
    displayedItems,
    // methods
    onFilterChange,
    handlePageChange,
    handlePerPageChange,
    handleSortUpdate,
    findCategoryText,
    findCategoryLink,
    getCategoryChipClass,
    formatFdr,
    getClusterColor,
    isRowHighlighted,
    handleTableRowHover,
    downloadExcel,
  };
}
