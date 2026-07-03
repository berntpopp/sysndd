// src/components/analyses/usePhenotypeClusterTable.ts
//
// Table-side state and behavior for the phenotype-clusters analysis
// (PhenotypeClusterVariableTable.vue): table-type selection, the global "any" +
// per-column filters, sorting, client-side pagination, and Excel export (all
// delegated to the pure helpers in ./phenotypeClusterTable). Extracted so the
// panel component stays a thin template shell. Cluster selection, the Cytoscape
// network, and the LLM summary card live in the parent
// (AnalysesPhenotypeClusters.vue), which threads the selected cluster's rows in
// as `selectedCluster`.
//
// Behavior is a straight move of the previous in-component logic: `totalRows`
// tracks the UNFILTERED row count of the current table type (filtering changes
// only the displayed slice, never the pagination total), the page resets to 1 on
// a table-type change but is preserved across a cluster change, exactly as the
// original component did.

import { computed, reactive, ref, watch } from 'vue';
import useToast from '@/composables/useToast';
import { useExcelExport } from '@/composables';
import {
  sortPhenotypeClusterRows,
  filterPhenotypeClusterRows,
  buildPhenotypeClusterExportFilename,
  phenotypeClusterExportSheetName,
  PHENOTYPE_CLUSTER_EXPORT_HEADERS,
} from './phenotypeClusterTable';
import type {
  PhenotypeClusterRow,
  PhenotypeClusterTableType,
  PhenotypeFilterEntry,
} from './phenotypeClusterTable';

/** Props consumed from PhenotypeClusterVariableTable.vue. */
export interface PhenotypeClusterTableProps {
  /** Rows keyed by table type ({ quali_inp_var, quali_sup_var, quanti_sup_var }). */
  selectedCluster: Record<string, PhenotypeClusterRow[]>;
  /** True while the parent is loading cluster data. */
  loading: boolean;
  /** Active cluster number (used for the Excel export filename). */
  activeCluster: string | number;
}

export function usePhenotypeClusterTable(props: PhenotypeClusterTableProps) {
  const { makeToast } = useToast();
  const { isExporting, exportToExcel } = useExcelExport();

  const fields = [
    {
      key: 'variable',
      label: 'Variable',
      class: 'text-start',
      sortable: true,
    },
    {
      // Flat key alias for the raw 'p.value' stat. BootstrapVueNext BTable
      // renders a blank cell for a dotted field key, so the column is fed a
      // de-dotted alias added by normalizePhenotypeClusterRows().
      key: 'p_value',
      label: 'p-value',
      class: 'text-start',
      sortable: true,
    },
    {
      key: 'v_test',
      label: 'v-test',
      class: 'text-start',
      sortable: true,
    },
  ];

  const tableOptions = [
    {
      value: 'quali_inp_var',
      text: 'Qualitative input variables (phenotypes)',
    },
    {
      value: 'quali_sup_var',
      text: 'Qualitative supplementary variables (inheritance)',
    },
    {
      value: 'quanti_sup_var',
      text: 'Quantitative supplementary variables (phenotype counts)',
    },
  ];
  const tableType = ref<PhenotypeClusterTableType>('quali_inp_var');

  const perPage = ref(10);
  const totalRows = ref(1);
  const currentPage = ref(1);
  const sortBy = ref('p_value');
  const sortDesc = ref(false);
  const filter = reactive<Record<string, PhenotypeFilterEntry>>({
    any: { content: null, join_char: null, operator: 'contains' },
    variable: { content: null, join_char: null, operator: 'contains' },
    p_value: { content: null, join_char: null, operator: 'contains' },
    v_test: { content: null, join_char: null, operator: 'contains' },
  });

  /** Delegates to the pure global "any" + per-column filter helper. */
  function applyFilters(items: PhenotypeClusterRow[]): PhenotypeClusterRow[] {
    return filterPhenotypeClusterRows(items, filter);
  }

  /** Filtered + sorted + paginated items for the current table type. */
  const displayedItems = computed<PhenotypeClusterRow[]>(() => {
    // 1. Start from the relevant cluster data
    let dataArray = props.selectedCluster[tableType.value] || [];
    // 2. Apply filtering
    dataArray = applyFilters(dataArray);
    // 3. Apply sorting (numeric / scientific-notation aware)
    dataArray = sortPhenotypeClusterRows(dataArray, sortBy.value, sortDesc.value);
    // 4. Paginate (client-side)
    const start = (currentPage.value - 1) * perPage.value;
    const end = start + perPage.value;
    return dataArray.slice(start, end);
  });

  function onFilterChange(): void {
    // Reset page to 1 to see the updated first page
    currentPage.value = 1;
  }
  function handlePageChange(newPage: number): void {
    currentPage.value = newPage;
  }
  function handlePerPageChange(newPerPage: number): void {
    perPage.value = newPerPage;
    currentPage.value = 1;
  }
  function handleSortUpdate(ctx: { sortBy: string; sortDesc: boolean }): void {
    sortBy.value = ctx.sortBy;
    sortDesc.value = ctx.sortDesc;
  }

  /**
   * Download the current table data as an Excel file.
   * Exports all filtered data (not just the current page).
   */
  function downloadExcel(): void {
    let dataArray = props.selectedCluster[tableType.value] || [];
    dataArray = applyFilters(dataArray);

    if (dataArray.length === 0) {
      makeToast('No data to export', 'Warning', 'warning');
      return;
    }

    const filename = buildPhenotypeClusterExportFilename(props.activeCluster, tableType.value);

    exportToExcel(dataArray, {
      filename,
      sheetName: phenotypeClusterExportSheetName(tableType.value),
      headers: PHENOTYPE_CLUSTER_EXPORT_HEADERS,
    });
  }

  // Cluster selection changed: refresh the unfiltered row count (mirrors the
  // parent's previous setActiveCluster). The page is intentionally NOT reset
  // here — the original component only reset the page on a table-type change.
  watch(
    () => props.selectedCluster,
    () => {
      const arr = props.selectedCluster[tableType.value] || [];
      totalRows.value = arr.length;
    }
  );
  // Table type changed: refresh the unfiltered row count and reset to page 1.
  watch(tableType, () => {
    const arr = props.selectedCluster[tableType.value] || [];
    totalRows.value = arr.length;
    currentPage.value = 1;
  });

  return {
    // state
    fields,
    tableOptions,
    tableType,
    perPage,
    totalRows,
    currentPage,
    sortBy,
    sortDesc,
    filter,
    isExporting,
    // computed
    displayedItems,
    // methods
    onFilterChange,
    handlePageChange,
    handlePerPageChange,
    handleSortUpdate,
    downloadExcel,
  };
}
