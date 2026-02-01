<!-- src/components/analyses/PubtatorNDDGenes.vue -->
<template>
  <div class="container-fluid">
    <!-- Loading spinner -->
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <!-- Main container -->
    <BContainer v-else fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <!-- b-card with header controls -->
          <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
            <!-- Card Header -->
            <template #header>
              <BRow class="align-items-center">
                <BCol>
                  <h6 class="mb-1 text-start font-weight-bold">
                    Gene Prioritization
                    <mark
                      v-b-tooltip.hover.leftbottom
                      title="Genes from PubTator NDD literature search, prioritized for curation."
                    >
                      ({{ totalRows }} genes)
                    </mark>
                    <BBadge id="popover-badge-help-pubtator-genes" pill href="#" variant="info">
                      <i class="bi bi-question-circle-fill" />
                    </BBadge>
                    <BPopover
                      target="popover-badge-help-pubtator-genes"
                      variant="info"
                      triggers="focus"
                    >
                      <template #title>Gene Prioritization for Curation</template>
                      <p>
                        <strong>Literature Only</strong> genes (marked with
                        <BBadge variant="info" pill class="me-1">Literature Only</BBadge>) are genes
                        mentioned in NDD publications but not yet curated in SysNDD - potential
                        curation candidates.
                      </p>
                      <p><strong>Prioritization criteria:</strong></p>
                      <ul class="mb-2">
                        <li><em>Literature first:</em> Uncurated genes surface at the top</li>
                        <li><em>Oldest publication:</em> Long-overlooked genes prioritized</li>
                        <li><em>Publication count:</em> More mentions = more evidence</li>
                      </ul>
                      <p><strong>Filtering:</strong></p>
                      <ul class="mb-2">
                        <li><em>Min Publications:</em> Focus on well-cited genes (2+, 5+, 10+)</li>
                        <li><em>Date Range:</em> Filter by oldest publication date</li>
                      </ul>
                      <p class="mb-0">
                        <strong>Export:</strong> Download filtered list to Excel for offline review.
                      </p>
                    </BPopover>
                  </h6>
                </BCol>
                <BCol class="text-end">
                  <BButton
                    variant="outline-success"
                    size="sm"
                    :disabled="isExporting || items.length === 0"
                    @click="handleExcelExport"
                  >
                    <BSpinner v-if="isExporting" small class="me-1" />
                    <i v-else class="bi bi-file-earmark-excel me-1" />
                    Export
                  </BButton>
                  <TableDownloadLinkCopyButtons
                    v-if="showFilterControls"
                    :downloading="downloading"
                    :remove-filters-title="removeFiltersButtonTitle"
                    :remove-filters-variant="removeFiltersButtonVariant"
                    :show-download="false"
                    @copy-link="copyLinkToClipboard"
                    @remove-filters="removeFilters"
                  />
                </BCol>
              </BRow>
            </template>

            <!-- Prioritization Filters + Search + Pagination Controls -->
            <BRow class="p-2">
              <!-- Publication count filter -->
              <BCol class="my-1" sm="3">
                <BInputGroup prepend="Min Pubs" class="mb-1" size="sm">
                  <BFormSelect
                    v-model="minPublications"
                    :options="pubCountOptions"
                    size="sm"
                    @change="applyPrioritizationFilters"
                  />
                </BInputGroup>
              </BCol>

              <!-- Date range filter -->
              <BCol class="my-1" sm="3">
                <BInputGroup prepend="Date Range" class="mb-1" size="sm">
                  <BFormSelect
                    v-model="dateRange"
                    :options="dateRangeOptions"
                    size="sm"
                    @change="applyPrioritizationFilters"
                  />
                </BInputGroup>
              </BCol>

              <!-- Global "any" search -->
              <BCol class="my-1" sm="4">
                <TableSearchInput
                  v-model="anyFilterContent"
                  :placeholder="'Search any field...'"
                  :debounce-time="500"
                  @input="filtered"
                />
              </BCol>

              <!-- Pagination controls -->
              <BCol class="my-1" sm="2">
                <BContainer v-if="totalRows > perPage || showPaginationControls">
                  <TablePaginationControls
                    :total-rows="totalRows"
                    :initial-per-page="perPage"
                    :page-options="pageOptions"
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  />
                </BContainer>
              </BCol>
            </BRow>
            <!-- End Controls -->

            <!-- Main b-table -->
            <BTable
              :items="items"
              :fields="fields"
              :busy="isBusy"
              :sort-by="sortByArray"
              no-local-sorting
              head-variant="light"
              show-empty
              small
              fixed
              striped
              hover
              sort-icon-left
              stacked="md"
              @update:sort-by="handleSortByUpdate"
            >
              <!-- Custom table header cell with tooltips -->
              <template #head()="columnData">
                <div
                  v-b-tooltip.hover.top
                  :title="
                    columnData.label +
                    (fields.find((f) => f.label === columnData.label)?.count_filtered
                      ? ' (unique/total: ' +
                        fields.find((f) => f.label === columnData.label)?.count_filtered +
                        '/' +
                        fields.find((f) => f.label === columnData.label)?.count +
                        ')'
                      : '')
                  "
                >
                  {{ truncateText(columnData.label, 20) }}
                </div>
              </template>

              <!-- Per-column filters row -->
              <template #top-row>
                <td v-for="field in fields" :key="field.key">
                  <BFormInput
                    v-if="field.filterable"
                    :model-value="getFilterContent(field.key)"
                    :placeholder="'.. ' + truncateText(field.label, 12) + ' ..'"
                    debounce="500"
                    type="search"
                    autocomplete="off"
                    size="sm"
                    @click="removeSearch()"
                    @update:model-value="setFilterContent(field.key, String($event))"
                  />
                </td>
              </template>

              <!-- Gene symbol column - link to HGNC -->
              <template #cell(gene_symbol)="data">
                <strong>{{ (data.item as GeneItem).gene_symbol }}</strong>
              </template>

              <!-- Source badge column -->
              <template #cell(is_novel)="data">
                <BBadge v-if="(data.item as GeneItem).is_novel === 1" variant="info" pill>
                  <i class="bi bi-journal-text me-1" />
                  Literature Only
                </BBadge>
                <BBadge v-else variant="success" pill>
                  <i class="bi bi-check-circle me-1" />
                  Curated
                </BBadge>
              </template>

              <!-- PMIDs as clickable chips -->
              <template #cell(pmids)="data">
                <div class="d-flex flex-wrap gap-1">
                  <BButton
                    v-for="pmid in parsePmids((data.item as GeneItem).pmids).slice(0, 5)"
                    :key="pmid"
                    size="sm"
                    variant="outline-primary"
                    class="btn-xs"
                    :href="'https://pubmed.ncbi.nlm.nih.gov/' + pmid"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {{ pmid }}
                  </BButton>
                  <BBadge
                    v-if="parsePmids((data.item as GeneItem).pmids).length > 5"
                    variant="secondary"
                    pill
                    class="align-self-center"
                  >
                    +{{ parsePmids((data.item as GeneItem).pmids).length - 5 }}
                  </BBadge>
                </div>
              </template>

              <!-- Actions column with expand button -->
              <template #cell(actions)="data">
                <BButton
                  v-if="parsePmids((data.item as GeneItem).pmids).length > 0"
                  class="btn-xs"
                  variant="outline-primary"
                  @click="
                    handleRowExpand(data.item as GeneItem);
                    data.toggleDetails();
                  "
                >
                  {{ data.detailsShowing ? 'Hide' : 'Show' }}
                </BButton>
              </template>

              <!-- Row details - expanded view with actual publication data -->
              <template #row-details="data">
                <div class="publication-details">
                  <!-- Loading spinner -->
                  <div
                    v-if="isLoadingPublications((data.item as GeneItem).gene_symbol)"
                    class="text-center py-3"
                  >
                    <BSpinner small label="Loading publications..." />
                    <span class="ms-2 text-muted">Loading publication details...</span>
                  </div>

                  <!-- Publication list -->
                  <div v-else>
                    <div
                      v-for="pub in getPublications((data.item as GeneItem).gene_symbol)"
                      :key="pub.publication_id"
                      class="details-section"
                    >
                      <!-- Title -->
                      <div v-if="pub.Title" class="details-title">
                        {{ pub.Title }}
                      </div>

                      <div class="details-row">
                        <!-- PMID & Date -->
                        <div class="details-meta">
                          <a
                            :href="
                              'https://pubmed.ncbi.nlm.nih.gov/' +
                              pub.publication_id.replace('PMID:', '')
                            "
                            target="_blank"
                            rel="noopener noreferrer"
                            class="details-pmid"
                          >
                            <i class="bi bi-journal-medical me-1" />
                            {{ pub.publication_id }}
                            <i class="bi bi-box-arrow-up-right ms-1" />
                          </a>
                          <span v-if="pub.Publication_date" class="details-date">
                            <i class="bi bi-calendar3 me-1" />
                            {{ pub.Publication_date }}
                          </span>
                          <span v-if="pub.Journal" class="details-journal">
                            <i class="bi bi-book me-1" />
                            {{ pub.Journal }}
                          </span>
                        </div>
                      </div>

                      <!-- Abstract -->
                      <div v-if="pub.Abstract" class="details-abstract">
                        {{ truncateText(pub.Abstract, 400) }}
                      </div>
                    </div>

                    <!-- Fallback if no cached data -->
                    <div
                      v-if="getPublications((data.item as GeneItem).gene_symbol).length === 0"
                      class="details-section"
                    >
                      <h6 class="details-label">
                        <i class="bi bi-journal-text me-2" />Publications
                      </h6>
                      <div class="d-flex flex-wrap gap-2">
                        <a
                          v-for="pmid in parsePmids((data.item as GeneItem).pmids)"
                          :key="pmid"
                          :href="'https://pubmed.ncbi.nlm.nih.gov/' + pmid"
                          target="_blank"
                          rel="noopener noreferrer"
                          class="details-pmid"
                        >
                          <i class="bi bi-journal-medical me-1" />
                          PMID: {{ pmid }}
                          <i class="bi bi-box-arrow-up-right ms-1" />
                        </a>
                      </div>
                    </div>
                  </div>
                </div>
              </template>
            </BTable>
            <!-- End b-table -->
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, inject } from 'vue';
import type { AxiosInstance } from 'axios';

// Import composables
import { useToast, useUrlParsing, useTableData } from '@/composables';
import { useExcelExport } from '@/composables/useExcelExport';

// Small reusable components
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';

import { useUiStore } from '@/stores/ui';
import { useRoute } from 'vue-router';

// Types
interface GeneItem {
  gene_symbol: string;
  gene_name: string;
  gene_normalized_id?: string;
  hgnc_id?: string;
  publication_count: number;
  oldest_pub_date?: string;
  is_novel: number;
  pmids?: string;
  _showDetails?: boolean;
}

interface PublicationData {
  publication_id: string;
  Title?: string;
  Journal?: string;
  Publication_date?: string;
  Abstract?: string;
}

interface FilterField {
  content: string | string[] | null;
  operator: string;
  join_char: string | null;
}

interface FieldDefinition {
  key: string;
  label: string;
  sortable?: boolean;
  sortDirection?: string;
  class?: string;
  filterable?: boolean;
  count?: number;
  count_filtered?: number;
}

// Props
const props = withDefaults(
  defineProps<{
    showFilterControls?: boolean;
    showPaginationControls?: boolean;
    headerLabel?: string;
    sortInput?: string;
    filterInput?: string | null;
    fieldsInput?: string | null;
    pageAfterInput?: string;
    pageSizeInput?: number;
    fspecInput?: string;
  }>(),
  {
    showFilterControls: true,
    showPaginationControls: true,
    headerLabel: 'Pubtator Genes table',
    sortInput: '-is_novel,oldest_pub_date',
    filterInput: null,
    fieldsInput: null,
    pageAfterInput: '',
    pageSizeInput: 10,
    fspecInput:
      'gene_name,gene_symbol,gene_normalized_id,hgnc_id,publication_count,oldest_pub_date,is_novel,pmids',
  }
);

// Emits
const emit = defineEmits<{
  'novel-count': [count: number];
}>();

// Composables
const { makeToast } = useToast();
const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
const tableData = useTableData({
  pageSizeInput: props.pageSizeInput,
  sortInput: props.sortInput,
  pageAfterInput: props.pageAfterInput,
});
const { isExporting, exportToExcel } = useExcelExport();

// Inject axios
const axios = inject<AxiosInstance>('axios');
const route = useRoute();

// Destructure tableData
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
  filter_string,
  pageOptions,
  removeFiltersButtonTitle,
  removeFiltersButtonVariant,
} = tableData;

// Table fields definition
const fields = ref<FieldDefinition[]>([
  {
    key: 'gene_symbol',
    label: 'Gene',
    sortable: true,
    class: 'text-start',
    filterable: true,
  },
  {
    key: 'gene_name',
    label: 'Name',
    sortable: true,
    class: 'text-start',
    filterable: true,
  },
  {
    key: 'publication_count',
    label: 'Pubs',
    sortable: true,
    class: 'text-center',
    filterable: false,
  },
  {
    key: 'oldest_pub_date',
    label: 'Oldest Pub',
    sortable: true,
    class: 'text-center',
    filterable: false,
  },
  {
    key: 'is_novel',
    label: 'Source',
    sortable: true,
    class: 'text-center',
    filterable: false,
  },
  {
    key: 'pmids',
    label: 'PMIDs',
    sortable: false,
    class: 'text-start',
    filterable: false,
  },
  {
    key: 'actions',
    label: '',
    sortable: false,
    class: 'text-center',
    filterable: false,
  },
]);

// Component-specific filter
const filter = ref<Record<string, FilterField>>({
  any: { content: null, join_char: null, operator: 'contains' },
  gene_name: { content: null, join_char: null, operator: 'contains' },
  gene_symbol: { content: null, join_char: null, operator: 'contains' },
  gene_normalized_id: { content: null, join_char: null, operator: 'contains' },
  hgnc_id: { content: null, join_char: null, operator: 'contains' },
  publication_count: { content: null, join_char: null, operator: 'greaterThanOrEqual' },
  oldest_pub_date: { content: null, join_char: null, operator: 'greaterThanOrEqual' },
  is_novel: { content: null, join_char: null, operator: 'equals' },
});

// Prioritization filter options
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

// Cursor pagination info
const totalPages = ref(0);

// Publication data cache (keyed by gene_symbol)
const publicationCache = ref<Record<string, PublicationData[]>>({});
const loadingPublications = ref<Record<string, boolean>>({});

// Computed: sortBy as properly typed array for BTable
const sortByArray = computed(() => sortBy.value);

// Computed: any filter content (string binding)
const anyFilterContent = computed({
  get: () => {
    const content = filter.value.any.content;
    return typeof content === 'string' ? content : '';
  },
  set: (value: string) => {
    filter.value.any.content = value || null;
  },
});

// Helpers for filter content binding
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

// Computed: Novel gene count
const novelCount = computed(
  () => (items.value as GeneItem[]).filter((g) => g.is_novel === 1).length
);

// Watch novel count and emit to parent
watch(
  novelCount,
  (count) => {
    emit('novel-count', count);
  },
  { immediate: true }
);

// Helper: Parse PMIDs string to array
const parsePmids = (pmids: string | undefined): string[] => {
  if (!pmids) return [];
  return pmids.split(',').filter((p) => p.trim() !== '');
};

// Helper: Truncate text
const truncateText = (str: string | undefined, n: number): string => {
  if (!str) return '';
  return str.length > n ? `${str.slice(0, n)}...` : str;
};

// Fetch publication data for a gene's PMIDs
const fetchPublicationData = async (geneSymbol: string, pmids: string[]) => {
  if (!axios || pmids.length === 0) return;
  if (publicationCache.value[geneSymbol]) return; // Already cached

  loadingPublications.value[geneSymbol] = true;

  try {
    // Fetch publications by PMID filter
    const pmidFilter = pmids.map((p) => `PMID:${p}`).join(';');
    const apiUrl = `${import.meta.env.VITE_API_URL}/api/publication?filter=publication_id:in:${pmidFilter}&fields=publication_id,Title,Journal,Publication_date,Abstract&page_size=${pmids.length}`;

    const response = await axios.get(apiUrl);
    publicationCache.value[geneSymbol] = response.data.data || [];
  } catch (error) {
    console.error('Failed to fetch publication data:', error);
    publicationCache.value[geneSymbol] = [];
  } finally {
    loadingPublications.value[geneSymbol] = false;
  }
};

// Handle row expansion - fetch publication data
const handleRowExpand = (item: GeneItem) => {
  const pmids = parsePmids(item.pmids);
  if (pmids.length > 0 && !publicationCache.value[item.gene_symbol]) {
    fetchPublicationData(item.gene_symbol, pmids);
  }
};

// Get cached publications for a gene
const getPublications = (geneSymbol: string): PublicationData[] => {
  return publicationCache.value[geneSymbol] || [];
};

// Check if publications are loading for a gene
const isLoadingPublications = (geneSymbol: string): boolean => {
  return loadingPublications.value[geneSymbol] || false;
};

// Apply prioritization filters
const applyPrioritizationFilters = () => {
  // Publication count filter
  if (minPublications.value === 'all') {
    filter.value.publication_count.content = null;
  } else {
    filter.value.publication_count.content = minPublications.value;
  }

  // Date range filter (calculate date from current date)
  if (dateRange.value === 'all') {
    filter.value.oldest_pub_date.content = null;
  } else {
    const yearsAgo = parseInt(dateRange.value, 10);
    const cutoffDate = new Date();
    cutoffDate.setFullYear(cutoffDate.getFullYear() - yearsAgo);
    filter.value.oldest_pub_date.content = cutoffDate.toISOString().split('T')[0];
  }

  currentItemID.value = 0;
  filtered();
};

// Load data from API
const loadData = async () => {
  if (!axios) {
    makeToast('Axios not available', 'Error', 'danger');
    return;
  }

  isBusy.value = true;

  const urlParam =
    `sort=${sort.value}` +
    `&filter=${filter_string.value}` +
    `&page_after=${currentItemID.value}` +
    `&page_size=${perPage.value}` +
    `&fields=${props.fspecInput}`;

  const apiUrl = `${import.meta.env.VITE_API_URL}/api/publication/pubtator/genes?${urlParam}`;

  try {
    const response = await axios.get(apiUrl);
    items.value = response.data.data || [];

    if (response.data.meta && response.data.meta.length > 0) {
      const metaObj = response.data.meta[0];
      totalRows.value = metaObj.totalItems || 0;
      totalPages.value = metaObj.totalPages || 1;
      prevItemID.value = metaObj.prevItemID || null;
      currentItemID.value = metaObj.currentItemID || 0;
      nextItemID.value = metaObj.nextItemID || null;
      lastItemID.value = metaObj.lastItemID || null;

      // Update currentPage from meta
      currentPage.value = metaObj.currentPage || 1;

      // Optionally merge any fspec changes into fields
      if (metaObj.fspec && Array.isArray(metaObj.fspec)) {
        fields.value = mergeFields(metaObj.fspec);
      }
    }

    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
  } catch (error) {
    makeToast(error, 'Error', 'danger');
  } finally {
    isBusy.value = false;
  }
};

// Handle page change
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

// Handle per page change
const handlePerPageChange = (newSize: number | string) => {
  perPage.value = parseInt(String(newSize), 10) || 10;
  currentItemID.value = 0;
  filtered();
};

// Rebuild filter string, reload data
const filtered = () => {
  const filterStringLoc = filterObjToStr(filter.value);
  if (filterStringLoc !== filter_string.value) {
    filter_string.value = filterStringLoc;
  }
  loadData();
};

// Clear all filters
const removeFilters = () => {
  filter.value = {
    any: { content: null, join_char: null, operator: 'contains' },
    gene_name: { content: null, join_char: null, operator: 'contains' },
    gene_symbol: { content: null, join_char: null, operator: 'contains' },
    gene_normalized_id: { content: null, join_char: null, operator: 'contains' },
    hgnc_id: { content: null, join_char: null, operator: 'contains' },
    publication_count: { content: null, join_char: null, operator: 'greaterThanOrEqual' },
    oldest_pub_date: { content: null, join_char: null, operator: 'greaterThanOrEqual' },
    is_novel: { content: null, join_char: null, operator: 'equals' },
  };
  minPublications.value = 'all';
  dateRange.value = 'all';
  currentItemID.value = 0;
  filtered();
};

// Clear the global "any" filter
const removeSearch = () => {
  filter.value.any.content = null;
};

// Handle sortBy updates from BTable
const handleSortByUpdate = (newSortBy: Array<{ key: string; order: 'asc' | 'desc' }>) => {
  sortBy.value = newSortBy;
  currentItemID.value = 0;
  // Extract sort string from array format for API
  if (newSortBy && newSortBy.length > 0) {
    const sortKey = newSortBy[0].key;
    const sortDesc = newSortBy[0].order === 'desc';
    sort.value = (sortDesc ? '-' : '+') + sortKey;
  }
  filtered();
};

// Copy link to clipboard
const copyLinkToClipboard = () => {
  const urlParam =
    `sort=${sort.value}` +
    `&filter=${filter_string.value}` +
    `&page_after=${currentItemID.value}` +
    `&page_size=${perPage.value}`;
  const fullUrl = `${import.meta.env.VITE_URL}${route.path}?${urlParam}`;
  navigator.clipboard.writeText(fullUrl);
  makeToast('Link copied to clipboard', 'Info', 'info');
};

// Excel export handler
const handleExcelExport = async () => {
  if ((items.value as GeneItem[]).length === 0) {
    makeToast('No data to export', 'Warning', 'warning');
    return;
  }

  const exportData = (items.value as GeneItem[]).map((gene) => ({
    gene_symbol: gene.gene_symbol,
    gene_name: gene.gene_name,
    publication_count: gene.publication_count,
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
        publication_count: 'Publication Count',
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

// Merge server fspec changes into local fields - preserve actions column
const mergeFields = (inboundFields: FieldDefinition[]): FieldDefinition[] => {
  const merged = inboundFields.map((f) => {
    const existing = fields.value.find((x) => x.key === f.key);
    return {
      ...f,
      filterable: existing?.filterable ?? false,
      class: existing?.class ?? 'text-start',
    };
  });

  // Always add actions column at the end for expand functionality
  merged.push({
    key: 'actions',
    label: '',
    sortable: false,
    class: 'text-center',
    filterable: false,
  });

  return merged;
};

// Lifecycle
onMounted(() => {
  // Transform sort string into sortBy and sortDesc
  const sortObject = sortStringToVariables(props.sortInput);
  sortBy.value = sortObject.sortBy;
  sort.value = props.sortInput;

  // If we have a pre-loaded filter string, parse it
  if (props.filterInput && props.filterInput !== 'null' && props.filterInput !== '') {
    filter.value = filterStrToObj(props.filterInput, filter.value);
  }

  // Slight delay, then show table
  setTimeout(() => {
    loading.value = false;
  }, 300);

  // Load initial data
  loadData();
});
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

.input-group > .input-group-prepend {
  flex: 0 0 35%;
}
.input-group .input-group-text {
  width: 100%;
}

mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}

/* Publication details styling - matches PublicationsNDD */
.publication-details {
  padding: 1.25rem 1.5rem;
  background: #fafbfc;
  border-radius: 0.5rem;
  margin: 0.75rem 1rem;
  border: 1px solid #e9ecef;
  box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.04);
}

.details-section {
  margin-bottom: 1rem;
}

.details-section:last-child {
  margin-bottom: 0;
}

.details-label {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: #6c757d;
  margin-bottom: 0.6rem;
  padding-bottom: 0.35rem;
  border-bottom: 1px solid #e9ecef;
  display: flex;
  align-items: center;
}

.details-label i {
  color: #0d6efd;
  opacity: 0.7;
}

.details-title {
  font-weight: 600;
  font-size: 0.95rem;
  color: #212529;
  margin-bottom: 0.5rem;
  line-height: 1.4;
  text-align: left;
}

.details-row {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  margin-bottom: 0.75rem;
}

.details-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 1rem;
}

.details-pmid {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  font-size: 0.8em;
  font-weight: 500;
  background-color: #e7f1ff;
  color: #0d6efd;
  border-radius: 0.3rem;
  text-decoration: none;
  transition: all 0.15s ease-in-out;
}

.details-pmid:hover {
  background-color: #0d6efd;
  color: white;
}

.details-date {
  display: inline-flex;
  align-items: center;
  padding: 0.2em 0.5em;
  font-size: 0.8em;
  background-color: #e8f5e9;
  color: #2e7d32;
  border-radius: 0.25rem;
}

.details-journal {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  font-size: 0.8em;
  background-color: #f8f9fa;
  color: #495057;
  border-radius: 0.25rem;
  border: 1px solid #dee2e6;
}

.details-abstract {
  font-size: 0.875rem;
  line-height: 1.7;
  color: #333;
  text-align: justify;
  padding: 0.5rem 0;
}
</style>
