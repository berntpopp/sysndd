<!-- src/components/analyses/PubtatorNDDGenes.vue -->
<template>
  <div>
    <!-- Loading spinner -->
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <AnalysisPanel
      v-else
      title="Gene prioritization"
      :description="'Genes from PubTator NDD literature search: ' + totalRows + ' genes'"
    >
      <template #actions>
        <InlineHelpBadge
          id="popover-badge-help-pubtator-genes"
          aria-label="Explain PubTator gene prioritization"
        />
        <BPopover target="popover-badge-help-pubtator-genes" variant="info" triggers="focus">
          <template #title>Gene Prioritization for Curation</template>
          <p>
            <strong>Literature Only</strong> genes are mentioned in NDD publications but not yet
            curated in SysNDD - potential curation candidates.
          </p>
          <p><strong>Prioritization criteria:</strong></p>
          <ul class="mb-2">
            <li>
              <em>Enrichment (default):</em> NDD co-mentions normalized by the gene's total
              publication count, so popularity bias (e.g. heavily-studied genes) does not
              dominate the raw count.
            </li>
            <li>
              <em>FDR significance:</em> Benjamini-Hochberg adjusted Fisher exact test
              (* q&lt;0.05, ** q&lt;0.01, *** q&lt;0.001).
            </li>
            <li><em>NDD Pubs:</em> Raw co-occurrence count (still sortable).</li>
          </ul>
          <p class="small text-muted mb-0">
            Background (total) publication counts and enrichment metrics are refreshed
            periodically; genes show “—” until the first refresh.
          </p>
        </BPopover>
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

      <!-- Enrichment freshness notice (defensive: only when the API reports
           a non-current ranking; absent fields render nothing). -->
      <BAlert
        v-if="enrichmentNotice"
        :model-value="true"
        variant="warning"
        class="mx-2 mb-2 py-2 px-3 small"
      >
        <i class="bi bi-info-circle me-1" />
        {{ enrichmentNotice }}
      </BAlert>

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
          <td v-for="field in fields" :key="field.key" role="presentation">
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

        <!-- Gene symbol column - clickable badge linking to gene page -->
        <template #cell(gene_symbol)="data">
          <GeneBadge
            :symbol="(data.item as GeneItem).gene_symbol"
            :hgnc-id="(data.item as GeneItem).hgnc_id"
            :link-to="
              (data.item as GeneItem).hgnc_id
                ? '/Genes/' + (data.item as GeneItem).hgnc_id
                : undefined
            "
            size="sm"
          />
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

        <!-- Background (total) publication count -->
        <template #cell(background_count)="data">
          <span v-if="(data.item as GeneItem).background_count != null">
            {{ formatCount((data.item as GeneItem).background_count) }}
          </span>
          <span v-else class="text-muted">—</span>
        </template>

        <!-- Enrichment ratio - color-coded, never color-alone (label + tooltip) -->
        <template #cell(enrichment_ratio)="data">
          <BBadge
            v-if="(data.item as GeneItem).enrichment_ratio != null"
            v-b-tooltip.hover.top
            :variant="enrichmentVariant((data.item as GeneItem).enrichment_ratio)"
            :title="enrichmentTooltip(data.item as GeneItem)"
            pill
          >
            {{ formatEnrichment((data.item as GeneItem).enrichment_ratio) }}×
          </BBadge>
          <span v-else class="text-muted">—</span>
        </template>

        <!-- FDR significance: stars + label, paired with tooltip (not color-alone) -->
        <template #cell(fdr_bh)="data">
          <span
            v-if="(data.item as GeneItem).fdr_bh != null"
            v-b-tooltip.hover.top
            :title="fdrTooltip((data.item as GeneItem).fdr_bh)"
          >
            <span :class="fdrClass((data.item as GeneItem).fdr_bh)">
              {{ fdrStars((data.item as GeneItem).fdr_bh) || 'ns' }}
            </span>
          </span>
          <span v-else class="text-muted">—</span>
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
              data.toggleExpansion();
            "
          >
            {{ data.expansionShowing ? 'Hide' : 'Show' }}
          </BButton>
        </template>

        <!-- Row details - expanded view with rich publication data -->
        <template #row-expansion="data">
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
              <PubtatorPublicationDetail
                v-for="pub in getPublications((data.item as GeneItem).gene_symbol)"
                :key="pub.pmid"
                :publication="pub"
              />

              <!-- Fallback if no cached data -->
              <div
                v-if="getPublications((data.item as GeneItem).gene_symbol).length === 0"
                class="details-section"
              >
                <h6 class="details-label"><i class="bi bi-journal-text me-2" />Publications</h6>
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
    </AnalysisPanel>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { listPubtatorGenes } from '@/api/publication';

// Import composables
import { useToast, useUrlParsing, useTableData } from '@/composables';
import { useExcelExport } from '@/composables/useExcelExport';
import { usePubtatorGenePublications } from '@/composables/usePubtatorGenePublications';

// Small reusable components
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import PubtatorPublicationDetail from '@/components/analyses/PubtatorPublicationDetail.vue';
import {
  applyPubtatorGenePrioritizationFilters,
  createDefaultPubtatorGeneFilter,
  type PubtatorGeneFilter,
} from './pubtatorGeneFilters';
import {
  formatCount,
  formatEnrichment,
  enrichmentVariant,
  enrichmentTooltip,
  fdrStars,
  fdrClass,
  fdrTooltip,
  createPubtatorGeneFields,
  type PubtatorGeneFieldDefinition as FieldDefinition,
} from './pubtatorEnrichmentDisplay';

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
  // Normalized enrichment metrics (issue #175); null until first refresh.
  observed?: number | null;
  background_count?: number | null;
  enrichment_ratio?: number | null;
  npmi?: number | null;
  fisher_p?: number | null;
  fdr_bh?: number | null;
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
    // Default rank by enrichment (issue #175): normalize for popularity bias.
    sortInput: '-enrichment_ratio,-npmi,publication_count',
    filterInput: null,
    fieldsInput: null,
    pageAfterInput: '',
    pageSizeInput: 10,
    fspecInput:
      'gene_name,gene_symbol,gene_normalized_id,hgnc_id,publication_count,background_count,enrichment_ratio,npmi,fdr_bh,oldest_pub_date,is_novel,pmids',
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

// Table fields definition (includes issue #175 enrichment columns)
const fields = ref<FieldDefinition[]>(createPubtatorGeneFields());

// Component-specific filter
const filter = ref<PubtatorGeneFilter>(createDefaultPubtatorGeneFilter());

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

// Enrichment freshness notice (issue: surface a non-blocking notice when the
// genes API reports the gene ranking is not yet computed / is stale). Defensive
// — the meta fields may be absent (older API), in which case this stays null.
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

// Handle row expansion - fetch publication data lazily via the cache composable
const handleRowExpand = (item: GeneItem) => {
  const pmids = parsePmids(item.pmids);
  if (pmids.length > 0 && !isCached(item.gene_symbol)) {
    fetchPublications(item.gene_symbol, pmids);
  }
};

// Apply prioritization filters
const applyPrioritizationFilters = () => {
  filter.value = applyPubtatorGenePrioritizationFilters(filter.value, {
    minPublications: minPublications.value,
    dateRangeYears: dateRange.value,
  });
  currentItemID.value = 0;
  filtered();
};

const loadData = async () => {
  isBusy.value = true;

  // The gene set is about to change (filter / sort / page). Drop the per-gene
  // publication cache so an expanded row cannot show publications fetched under
  // the previous query (correctness fix).
  resetPublicationCache();

  try {
    const response = await listPubtatorGenes({
      sort: sort.value,
      filter: filter_string.value,
      page_after: currentItemID.value,
      page_size: String(perPage.value),
      fields: props.fspecInput,
    });

    items.value = response.data || [];

    if (response.meta && Array.isArray(response.meta) && response.meta.length > 0) {
      const metaObj = response.meta[0] as {
        totalItems?: number;
        totalPages?: number;
        prevItemID?: number | null;
        currentItemID?: number;
        nextItemID?: number | null;
        lastItemID?: number | null;
        currentPage?: number;
        fspec?: FieldDefinition[];
        // Optional enrichment-freshness fields from /pubtator/genes meta
        // (camelCase, matching executionTime/totalItems); absent on older API
        // responses, so both are optional and handled defensively.
        enrichmentStatus?: string;
        enrichmentRefreshedAt?: string;
      };
      totalRows.value = metaObj.totalItems || 0;
      totalPages.value = metaObj.totalPages || 1;
      prevItemID.value = metaObj.prevItemID || null;
      currentItemID.value = metaObj.currentItemID || 0;
      nextItemID.value = metaObj.nextItemID || null;
      lastItemID.value = metaObj.lastItemID || null;

      currentPage.value = metaObj.currentPage || 1;

      if (metaObj.fspec && Array.isArray(metaObj.fspec)) {
        fields.value = mergeFields(metaObj.fspec);
      }

      enrichmentNotice.value = deriveEnrichmentNotice(
        metaObj.enrichmentStatus,
        metaObj.enrichmentRefreshedAt
      );
    }

    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
  } catch (error) {
    makeToast(error, 'Error', 'danger');
  } finally {
    isBusy.value = false;
  }
};

/**
 * Build a non-blocking notice string from the optional enrichment-freshness
 * meta. Returns null when the ranking is current or the fields are absent
 * (defensive: never throw on a shape the API may not yet send).
 */
const deriveEnrichmentNotice = (
  status: string | undefined,
  refreshedAt: string | undefined
): string | null => {
  if (!status || status === 'current') return null;
  if (status === 'missing') {
    return 'Gene ranking not yet computed. Showing raw co-occurrence ordering until the first refresh.';
  }
  if (status === 'stale') {
    const when = refreshedAt ? ` (last refreshed ${formatRefreshedAt(refreshedAt)})` : '';
    return `Gene ranking may be out of date${when}.`;
  }
  return null;
};

/** Best-effort human-friendly date for the freshness notice. */
const formatRefreshedAt = (value: string): string => {
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleDateString();
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
  filter.value = createDefaultPubtatorGeneFilter();
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

// Cleanup: abort all in-flight publication requests on unmount
onUnmounted(() => {
  cancelAllPublicationFetches();
});

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

/* The per-publication detail card (title/meta/annotated text/gene chips) now
   lives in PubtatorPublicationDetail.vue and PubtatorAnnotatedText.vue. The
   styles retained here cover the panel wrapper, the loading state, and the
   no-cache PMID fallback that this component still renders directly. */
</style>
