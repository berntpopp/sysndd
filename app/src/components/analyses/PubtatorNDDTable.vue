<!-- src/components/analyses/PubtatorNDDTable.vue -->
<template>
  <div class="container-fluid">
    <!-- Show an overlay spinner while loading -->
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <!-- Once loaded, show the table container -->
    <BContainer v-else fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <!-- b-card wrapper for the table and controls -->
          <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
            <!-- Card Header -->
            <template #header>
              <BRow>
                <BCol>
                  <TableHeaderLabel
                    :label="headerLabel"
                    :subtitle="'Publications: ' + totalRows"
                    :tool-tip-title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
                  />
                </BCol>
                <BCol>
                  <h5 v-if="showFilterControls" class="mb-1 text-end font-weight-bold">
                    <TableDownloadLinkCopyButtons
                      :downloading="downloading"
                      :remove-filters-title="removeFiltersButtonTitle"
                      :remove-filters-variant="removeFiltersButtonVariant"
                      @request-excel="requestExcel"
                      @copy-link="copyLinkToClipboard"
                      @remove-filters="removeFilters"
                    />
                  </h5>
                </BCol>
              </BRow>
            </template>

            <!-- Controls (search + pagination) -->
            <BRow>
              <!-- Search box for "any" field -->
              <BCol class="my-1" sm="8">
                <TableSearchInput
                  v-model="filter.any.content"
                  :placeholder="'Search any field by typing here'"
                  :debounce-time="500"
                  @input="filtered"
                />
              </BCol>

              <!-- Pagination controls -->
              <BCol class="my-1" sm="4">
                <BContainer v-if="totalRows > perPage || showPaginationControls">
                  <!--
                    TablePaginationControls will emit:
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  -->
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
            <!-- Controls (search + pagination) -->

            <!-- Main GenericTable -->
            <GenericTable
              :items="items"
              :fields="fields"
              :field-details="fields_details"
              :sort-by="sortBy"
              :sort-desc="sortDesc"
              @update-sort="handleSortUpdate"
            >
              <!-- Filter row removed for cleaner UI - use search box instead -->

              <!-- search_id -->
              <template #cell-search_id="{ row }">
                <div>
                  <BBadge variant="primary" style="cursor: pointer">
                    {{ row.search_id }}
                  </BBadge>
                </div>
              </template>

              <!-- pmid - clickable button like Genes table -->
              <template #cell-pmid="{ row }">
                <BButton
                  size="sm"
                  variant="outline-primary"
                  class="btn-xs"
                  :href="'https://pubmed.ncbi.nlm.nih.gov/' + row.pmid"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ row.pmid }}
                </BButton>
              </template>

              <!-- doi -->
              <template #cell-doi="{ row }">
                <div class="text-truncate">
                  <a :href="`https://doi.org/${row.doi}`" target="_blank">
                    {{ row.doi }}
                  </a>
                </div>
              </template>

              <!-- title -->
              <template #cell-title="{ row }">
                <div
                  v-b-tooltip.hover
                  :title="row.title"
                  class="overflow-hidden text-truncate"
                  style="max-width: 300px"
                >
                  {{ truncate(row.title, 60) }}
                </div>
              </template>

              <!-- journal -->
              <template #cell-journal="{ row }">
                <div>
                  {{ row.journal }}
                </div>
              </template>

              <!-- date -->
              <template #cell-date="{ row }">
                <div>
                  {{ row.date }}
                </div>
              </template>

              <!-- score -->
              <template #cell-score="{ row }">
                <div>
                  {{ row.score ? row.score.toFixed(3) : '' }}
                </div>
              </template>

              <!-- gene_symbols - clickable gene chips -->
              <template #cell-gene_symbols="{ row }">
                <div v-if="row.gene_symbols" class="gene-chips">
                  <RouterLink
                    v-for="gene in row.gene_symbols.split(',').slice(0, 3)"
                    :key="gene"
                    :to="'/Genes/' + gene.trim()"
                    class="gene-chip"
                  >
                    {{ gene.trim() }}
                  </RouterLink>
                  <span
                    v-if="row.gene_symbols.split(',').length > 3"
                    class="gene-chip-more"
                    :title="row.gene_symbols"
                  >
                    +{{ row.gene_symbols.split(',').length - 3 }}
                  </span>
                </div>
                <span v-else class="text-muted">—</span>
              </template>

              <!-- text_hl - truncated preview -->
              <template #cell-text_hl="{ row }">
                <div
                  v-if="row.text_hl"
                  class="overflow-hidden text-truncate"
                  style="max-width: 300px"
                >
                  <span
                    v-for="(segment, idx) in parseAnnotations(row.text_hl).slice(0, 5)"
                    :key="idx"
                    :class="getSegmentClass(segment)"
                    >{{ segment.text }}</span
                  >
                  <span v-if="parseAnnotations(row.text_hl).length > 5" class="text-muted"
                    >...</span
                  >
                </div>
                <div v-else>
                  <span class="text-muted">No highlight text</span>
                </div>
              </template>

              <!-- Row details slot for expanded annotation view -->
              <template #row-details="{ row }">
                <div class="publication-details">
                  <div class="details-section">
                    <!-- Title -->
                    <div v-if="row.title" class="details-title">
                      {{ row.title }}
                    </div>

                    <div class="details-row">
                      <!-- PMID & Date & Journal -->
                      <div class="details-meta">
                        <a
                          :href="'https://pubmed.ncbi.nlm.nih.gov/' + row.pmid"
                          target="_blank"
                          rel="noopener noreferrer"
                          class="details-pmid"
                        >
                          <i class="bi bi-journal-medical me-1" />
                          PMID:{{ row.pmid }}
                          <i class="bi bi-box-arrow-up-right ms-1" />
                        </a>
                        <span v-if="row.date" class="details-date">
                          <i class="bi bi-calendar3 me-1" />
                          {{ row.date }}
                        </span>
                        <span v-if="row.journal" class="details-journal">
                          <i class="bi bi-book me-1" />
                          {{ row.journal }}
                        </span>
                      </div>
                    </div>

                    <!-- Annotated Text Section -->
                    <div v-if="row.text_hl" class="annotated-text-section mt-3">
                      <div class="annotated-text-label text-muted small mb-1">
                        <i class="bi bi-highlighter me-1" />Annotated Text:
                      </div>
                      <div class="annotated-text">
                        <span
                          v-for="(segment, idx) in parseAnnotations(row.text_hl)"
                          :key="idx"
                          :class="getSegmentClass(segment)"
                          :title="getSegmentTooltip(segment)"
                          >{{ segment.text }}</span
                        >
                      </div>
                      <div class="pubtator-legend d-flex flex-wrap gap-2 small mt-2">
                        <span><span class="pubtator-gene px-1">Gene</span></span>
                        <span><span class="pubtator-disease px-1">Disease</span></span>
                        <span><span class="pubtator-variant px-1">Variant</span></span>
                        <span><span class="pubtator-species px-1">Species</span></span>
                        <span><span class="pubtator-chemical px-1">Chemical</span></span>
                        <span><span class="pubtator-match px-1">Match</span></span>
                      </div>
                    </div>
                    <div v-else class="text-muted mt-3">
                      <i class="bi bi-info-circle me-1" />No annotated text available.
                    </div>
                  </div>
                </div>
              </template>
            </GenericTable>
            <!-- Main GenericTable -->
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script lang="ts">
// Import Vue utilities
import { ref, inject } from 'vue';
import type { AxiosInstance } from 'axios';

// Import composables
import {
  useToast,
  useUrlParsing,
  useColorAndSymbols,
  useText,
  useTableData,
  parsePubtatorText,
} from '@/composables';
import type { ParsedSegment } from '@/composables';

/** Field definition with optional selection properties */
interface TableField {
  key: string;
  label: string;
  sortable: boolean;
  sortDirection?: string;
  class: string;
  filterable?: boolean;
  selectable?: boolean;
  multi_selectable?: boolean;
}

// Small reusable components
import TableHeaderLabel from '@/components/small/TableHeaderLabel.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';

import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';

export default {
  name: 'PubtatorNDDTable',
  components: {
    TableHeaderLabel,
    TableSearchInput,
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    GenericTable,
  },
  props: {
    apiEndpoint: {
      type: String,
      default: 'publication/pubtator/table',
    },
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Pubtator Publications table' },
    sortInput: { type: String, default: '-search_id' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '0' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default: 'search_id,pmid,doi,title,journal,date,score,gene_symbols,text_hl',
    },
  },
  setup(props) {
    // Independent composables
    const { makeToast } = useToast();
    const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
    const colorAndSymbols = useColorAndSymbols();
    const text = useText();

    // Table state composable
    const tableData = useTableData({
      pageSizeInput: props.pageSizeInput,
      sortInput: props.sortInput,
      pageAfterInput: props.pageAfterInput,
    });

    // Component-specific filter
    const filter = ref({
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
      details: { content: null, join_char: null, operator: 'contains' }, // Virtual field for row expansion
    });

    // Inject axios with proper typing
    const axios = inject<AxiosInstance>('axios');

    // Return all needed properties (this component has its own method implementations)
    return {
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      ...colorAndSymbols,
      ...text,
      ...tableData,
      filter,
      axios,
    };
  },
  data() {
    return {
      // Table columns
      fields: [
        {
          key: 'search_id',
          label: 'Search ID',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'pmid',
          label: 'PMID',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'doi',
          label: 'DOI',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'title',
          label: 'Title',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'journal',
          label: 'Journal',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'date',
          label: 'Date',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'score',
          label: 'Score',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'gene_symbols',
          label: 'Genes',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'text_hl',
          label: 'Text HL',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'details',
          label: 'Details',
          sortable: false,
          class: 'text-center',
        },
      ],
      // Additional hidden or detail fields can go here:
      fields_details: [],

      // Note: Table state (items, totalRows, perPage, sortBy, sortDesc, loading, isBusy,
      // downloading, currentItemID, prevItemID, nextItemID, lastItemID, executionTime,
      // filter_string, sort, etc.) is provided by useTableData composable in setup()

      // Component-specific cursor pagination info (not in useTableData)
      totalPages: 0,
    };
  },
  watch: {
    // Re-run data load when filter changes
    filter: {
      handler() {
        this.filtered();
      },
      deep: true,
    },
    // Watch for sortBy changes (deep watch for array format)
    sortBy: {
      handler(newVal) {
        // Build new sort string from sortBy array
        const newSortColumn = newVal && newVal.length > 0 ? newVal[0].key : 'search_id';
        const newSortOrder = newVal && newVal.length > 0 ? newVal[0].order : 'asc';
        const newSortString = (newSortOrder === 'desc' ? '-' : '+') + newSortColumn;
        // Only trigger if sort actually changed
        if (newSortString !== this.sort) {
          this.handleSortByOrDescChange();
        }
      },
      deep: true,
    },
  },
  mounted() {
    // Initialize sorting - use sortBy array format for Bootstrap-Vue-Next
    const sortObject = this.sortStringToVariables(this.sortInput);
    this.sortBy = sortObject.sortBy;
    this.sortDesc = sortObject.sortDesc;

    // Initialize filters from input
    if (this.filterInput && this.filterInput !== 'null') {
      Object.assign(
        this.filter,
        this.filterStrToObj(
          this.filterInput,
          this.filter as Record<
            string,
            { content: string | string[] | null; operator: string; join_char: string | null }
          >
        )
      );
    }

    setTimeout(() => {
      this.loading = false;
    }, 500);

    // Load initial data
    this.loadTableData();
  },
  methods: {
    /**
     * loadTableData
     * Fetches data from the API using sort/filter/cursor pagination
     */
    async loadTableData() {
      this.isBusy = true;

      const urlParam =
        `sort=${this.sort}` +
        `&filter=${this.filter_string}` +
        `&page_after=${this.currentItemID}` +
        `&page_size=${this.perPage}` +
        `&fields=${this.fspecInput}`;

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/${this.apiEndpoint}?${urlParam}`;

      try {
        if (!this.axios) {
          throw new Error('Axios not available');
        }
        const response = await this.axios.get(apiUrl);
        this.items = response.data.data;

        if (response.data.meta && response.data.meta.length > 0) {
          const metaObj = response.data.meta[0];
          this.totalRows = metaObj.totalItems || 0;

          // Fix for b-pagination
          this.$nextTick(() => {
            this.currentPage = metaObj.currentPage;
          });
          this.totalPages = metaObj.totalPages;
          this.prevItemID = metaObj.prevItemID;
          this.currentItemID = metaObj.currentItemID;
          this.nextItemID = metaObj.nextItemID;
          this.lastItemID = metaObj.lastItemID;
          this.executionTime = metaObj.executionTime;

          if (metaObj.fspec && Array.isArray(metaObj.fspec)) {
            this.fields = this.mergeFields(metaObj.fspec);
          }
        }
        const uiStore = useUiStore();
        uiStore.requestScrollbarUpdate();
      } catch (error) {
        this.makeToast(error, 'Error', 'danger');
      } finally {
        this.isBusy = false;
      }
    },

    handlePageChange(value) {
      if (value === 1) {
        this.currentItemID = 0;
      } else if (value === this.totalPages) {
        this.currentItemID = this.lastItemID;
      } else if (value > this.currentPage) {
        this.currentItemID = this.nextItemID;
      } else if (value < this.currentPage) {
        this.currentItemID = this.prevItemID;
      }
      this.filtered();
    },

    handlePerPageChange(newSize) {
      this.perPage = parseInt(newSize, 10) || 10;
      this.currentItemID = 0;
      this.filtered();
    },

    filtered() {
      const filterStringLoc = this.filterObjToStr(this.filter);
      if (filterStringLoc !== this.filter_string) {
        this.filter_string = filterStringLoc;
      }
      this.loadTableData();
    },

    removeFilters() {
      // Reset every field's filter to null
      this.filter = {
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
        details: { content: null, join_char: null, operator: 'contains' },
      };
      this.currentItemID = 0;
      this.filtered();
    },

    removeSearch() {
      this.filter.any.content = null;
    },

    /**
     * Handle sort update from GenericTable.
     * ctx.sortBy is the column key string, ctx.sortDesc is boolean.
     * Convert to Bootstrap-Vue-Next array format for consistency.
     */
    handleSortUpdate(ctx) {
      this.sortBy = [{ key: ctx.sortBy, order: ctx.sortDesc ? 'desc' : 'asc' }];
    },

    /**
     * Handle sort changes - extract column and order from array-based sortBy
     * and trigger data reload with new sort parameter.
     */
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      // Extract sort column and order from array-based sortBy (Bootstrap-Vue-Next format)
      const sortColumn =
        Array.isArray(this.sortBy) && this.sortBy.length > 0 ? this.sortBy[0].key : 'search_id';
      const sortOrder =
        Array.isArray(this.sortBy) && this.sortBy.length > 0 ? this.sortBy[0].order : 'asc';
      const isDesc = sortOrder === 'desc';
      // Build sort string for API: +column for asc, -column for desc
      this.sort = (isDesc ? '-' : '+') + sortColumn;
      this.filtered();
    },

    async requestExcel() {
      this.downloading = true;
      const urlParam =
        `sort=${this.sort}` +
        `&filter=${this.filter_string}` +
        '&page_after=0' +
        '&page_size=all' +
        '&format=xlsx' +
        `&fields=${this.fspecInput}`;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/${this.apiEndpoint}?${urlParam}`;

      try {
        if (!this.axios) {
          throw new Error('Axios not available');
        }
        const response = await this.axios({
          url: apiUrl,
          method: 'GET',
          responseType: 'blob',
        });

        const fileURL = window.URL.createObjectURL(new Blob([response.data]));
        const fileLink = document.createElement('a');
        fileLink.href = fileURL;
        fileLink.setAttribute('download', 'publications.xlsx');
        document.body.appendChild(fileLink);
        fileLink.click();
      } catch (error) {
        this.makeToast(error, 'Error downloading Excel', 'danger');
      }
      this.downloading = false;
    },

    copyLinkToClipboard() {
      const urlParam =
        `sort=${this.sort}` +
        `&filter=${this.filter_string}` +
        `&page_after=${this.currentItemID}` +
        `&page_size=${this.perPage}`;
      const fullUrl = `${import.meta.env.VITE_URL + this.$route.path}?${urlParam}`;
      navigator.clipboard.writeText(fullUrl);
      this.makeToast('Link copied to clipboard', 'Info', 'info');
    },

    mergeFields(inboundFields: TableField[]) {
      const merged = inboundFields.map((f) => {
        const existing = (this.fields as TableField[]).find((x) => x.key === f.key);
        return {
          ...f,
          // If your inbound fspec sets filterable, keep it or override it
          // For now, we forcibly set filterable to true, but you can merge logic
          filterable: true,
          selectable: existing?.selectable ?? false,
          class: existing?.class ?? 'text-start',
          multi_selectable: existing?.multi_selectable ?? false,
        };
      });

      // Always append the 'details' field at the end for row expansion
      const detailsField = (this.fields as TableField[]).find((x) => x.key === 'details');
      if (detailsField) {
        merged.push({
          ...detailsField,
          filterable: detailsField.filterable ?? false,
          selectable: detailsField.selectable ?? false,
          multi_selectable: detailsField.multi_selectable ?? false,
        });
      }

      return merged;
    },

    truncate(str, n) {
      return Utils.truncate(str, n);
    },

    /**
     * Parse PubTator annotations from text_hl field
     */
    parseAnnotations(text: string | null | undefined): ParsedSegment[] {
      return parsePubtatorText(text);
    },

    /**
     * Get CSS class for a parsed segment based on its type
     */
    getSegmentClass(segment: ParsedSegment): string {
      switch (segment.type) {
        case 'gene':
          return 'pubtator-gene';
        case 'disease':
          return 'pubtator-disease';
        case 'variant':
          return 'pubtator-variant';
        case 'species':
          return 'pubtator-species';
        case 'chemical':
          return 'pubtator-chemical';
        case 'match':
          return 'pubtator-match';
        default:
          return '';
      }
    },

    /**
     * Get tooltip text for annotated segments
     */
    getSegmentTooltip(segment: ParsedSegment): string {
      if (segment.type === 'plain' || segment.type === 'match') {
        return '';
      }
      const typeLabel = segment.type.charAt(0).toUpperCase() + segment.type.slice(1);
      if (segment.entityId) {
        return `${typeLabel}: ${segment.text} (ID: ${segment.entityId})`;
      }
      return `${typeLabel}: ${segment.text}`;
    },
    // Normalize select options for BFormSelect (replacement for treeselect normalizer)
    normalizeSelectOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return options.map((opt) => {
        if (typeof opt === 'object' && opt !== null) {
          return { value: opt.id || opt.value, text: opt.label || opt.text || opt.id };
        }
        return { value: opt, text: opt };
      });
    },
  },
};
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

/* PubTator entity colors - matching official PubTator color scheme */
.pubtator-gene {
  background-color: #b4e3f9;
  color: #0d6efd;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

.pubtator-disease {
  background-color: #ffe0b2;
  color: #e65100;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

.pubtator-variant {
  background-color: #f8bbd9;
  color: #c2185b;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

.pubtator-species {
  background-color: #c8e6c9;
  color: #2e7d32;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

.pubtator-chemical {
  background-color: #e1bee7;
  color: #7b1fa2;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

.pubtator-match {
  background-color: #fff59d;
  color: #f57f17;
  font-weight: 600;
  border-radius: 2px;
  padding: 0 2px;
}

/* Publication details styling - matching PubtatorNDDGenes */
.publication-details {
  background-color: #f8f9fa;
  padding: 1rem;
  border-radius: 0.375rem;
  box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.04);
}

.details-section {
  margin-bottom: 1rem;
}

.details-section:last-child {
  margin-bottom: 0;
}

.details-title {
  font-weight: 600;
  font-size: 0.95rem;
  color: #212529;
  line-height: 1.4;
  margin-bottom: 0.75rem;
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
  background-color: #e7f1ff;
  color: #0d6efd;
  font-size: 0.85rem;
  font-weight: 500;
  text-decoration: none;
  border-radius: 0.25rem;
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
  background-color: #fff3cd;
  color: #856404;
  font-size: 0.8rem;
  font-weight: 500;
  border-radius: 0.25rem;
}

.details-journal {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  background-color: #f8f9fa;
  color: #495057;
  font-size: 0.8rem;
  font-style: italic;
  border-radius: 0.25rem;
  border: 1px solid #dee2e6;
}

.annotated-text-section {
  border-top: 1px solid #dee2e6;
  padding-top: 0.75rem;
}

.annotated-text-label {
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.annotated-text {
  text-align: left;
  line-height: 1.8;
  white-space: pre-wrap;
  word-wrap: break-word;
}

.pubtator-legend {
  color: #6c757d;
}

/* Gene chips styling */
.gene-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
  align-items: center;
}

.gene-chip {
  display: inline-block;
  padding: 0.15em 0.4em;
  font-size: 0.75rem;
  font-weight: 500;
  background-color: #b4e3f9;
  color: #0d6efd;
  border-radius: 0.25rem;
  text-decoration: none;
  transition: all 0.15s ease-in-out;
  white-space: nowrap;
}

.gene-chip:hover {
  background-color: #0d6efd;
  color: white;
  text-decoration: none;
}

.gene-chip-more {
  display: inline-block;
  padding: 0.15em 0.4em;
  font-size: 0.7rem;
  font-weight: 500;
  background-color: #e9ecef;
  color: #6c757d;
  border-radius: 0.25rem;
  cursor: help;
}
</style>
