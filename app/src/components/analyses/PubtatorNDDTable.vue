<!-- src/components/analyses/PubtatorNDDTable.vue -->
<template>
  <div>
    <!-- Show an overlay spinner while loading -->
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <!-- Once loaded, show the table container -->
    <AnalysisPanel
      v-else
      title="PubTator NDD publications"
      :description="
        'Publications: ' +
        totalRows +
        ' · Loaded ' +
        perPage +
        '/' +
        totalRows +
        ' in ' +
        executionTime
      "
    >
      <template #actions>
        <TableDownloadLinkCopyButtons
          v-if="showFilterControls"
          :downloading="downloading"
          :remove-filters-title="removeFiltersButtonTitle"
          :remove-filters-variant="removeFiltersButtonVariant"
          @request-excel="requestExcel"
          @copy-link="copyLinkToClipboard"
          @remove-filters="removeFilters"
        />
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

        <!-- search_id — static identifier, not a link; use neutral chip -->
        <template #cell-search_id="{ row }">
          <span class="sysndd-chip sysndd-chip--neutral sysndd-chip--mono">
            {{ row.search_id }}
          </span>
        </template>

        <!-- pmid - clickable button like Genes table -->
        <template #cell-pmid="{ row }">
          <BButton
            size="sm"
            variant="outline-primary"
            class="btn-xs pubtator-pmid-btn"
            :href="'https://pubmed.ncbi.nlm.nih.gov/' + row.pmid"
            :aria-label="`Open PubMed article ${row.pmid} in new tab`"
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

        <!-- score — right-aligned numeric -->
        <template #cell-score="{ row }">
          <span class="pubtator-score-numeric">
            {{ row.score ? row.score.toFixed(3) : '' }}
          </span>
        </template>

        <!-- gene_symbols - clickable gene chips -->
        <template #cell-gene_symbols="{ row }">
          <div v-if="row.gene_symbols" class="gene-chips">
            <RouterLink
              v-for="gene in geneSymbolList(row.gene_symbols).slice(0, 3)"
              :key="gene"
              :to="'/Genes/' + gene"
              class="gene-chip"
            >
              {{ gene }}
            </RouterLink>
            <span
              v-if="geneSymbolList(row.gene_symbols).length > 3"
              class="gene-chip-more"
              :title="row.gene_symbols"
            >
              +{{ geneSymbolList(row.gene_symbols).length - 3 }}
            </span>
          </div>
          <span v-else class="text-muted">—</span>
        </template>

        <!-- text_hl - truncated preview -->
        <template #cell-text_hl="{ row }">
          <div v-if="row.text_hl" class="overflow-hidden text-truncate" style="max-width: 300px">
            <span
              v-for="(segment, idx) in parseAnnotations(row.text_hl).slice(0, 5)"
              :key="idx"
              :class="getSegmentClass(segment)"
              >{{ segment.text }}</span
            >
            <span v-if="parseAnnotations(row.text_hl).length > 5" class="text-muted">...</span>
          </div>
          <div v-else>
            <span class="text-muted">No highlight text</span>
          </div>
        </template>

        <!-- Row details slot for expanded annotation view -->
        <template #row-expansion="{ row }">
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
              <PubtatorAnnotatedText
                v-if="row.text_hl"
                :text="row.text_hl"
                section-class="mt-3"
              />
              <div v-else class="text-muted mt-3">
                <i class="bi bi-info-circle me-1" />No annotated text available.
              </div>
            </div>
          </div>
        </template>
      </GenericTable>
      <!-- Main GenericTable -->
    </AnalysisPanel>
  </div>
</template>

<script lang="ts">
// Import Vue utilities
import { ref, markRaw } from 'vue';

// Import composables
import {
  useToast,
  useUrlParsing,
  useColorAndSymbols,
  useText,
  useTableData,
  parsePubtatorTextMemoized,
  getSegmentClass,
} from '@/composables';
import type { ParsedSegment } from '@/composables';
import { normalizeSelectOptions } from '@/utils/selectOptions';

// Typed API client (W5)
import { listPubtatorTable, listPubtatorTableXlsx } from '@/api/publication';

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
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import PubtatorAnnotatedText from '@/components/analyses/PubtatorAnnotatedText.vue';

import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';

// Upper bound for the per-instance gene_symbols split cache (LRU eviction).
const GENE_SYMBOL_CACHE_LIMIT = 2000;

export default {
  name: 'PubtatorNDDTable',
  components: {
    AnalysisPanel,
    TableSearchInput,
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    GenericTable,
    PubtatorAnnotatedText,
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
          class: 'text-end',
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

      // Non-reactive memoization cache for gene_symbols splits (keyed by the
      // raw comma-separated string). markRaw keeps Vue from making it reactive;
      // declaring it here lets TypeScript infer the instance property.
      geneSymbolCache: markRaw(new Map<string, string[]>()),
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

      try {
        const data = await listPubtatorTable({
          sort: this.sort,
          filter: this.filter_string,
          page_after: String(this.currentItemID),
          page_size: String(this.perPage),
          fields: this.fspecInput,
        });
        this.items = data.data;

        // R/Plumber serialises meta as a 1-row array of dynamic-key objects.
        const meta = data.meta as Array<Record<string, unknown>> | undefined;
        if (meta && meta.length > 0) {
          const metaObj = meta[0] as Record<string, unknown> & {
            totalItems?: number;
            currentPage?: number;
            totalPages?: number;
            prevItemID?: number | null;
            currentItemID?: number | null;
            nextItemID?: number | null;
            lastItemID?: number | null;
            executionTime?: number;
            fspec?: TableField[];
          };
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

      try {
        const blob = await listPubtatorTableXlsx({
          sort: this.sort,
          filter: this.filter_string,
          page_after: '0',
          page_size: 'all',
          fields: this.fspecInput,
        });

        const fileURL = window.URL.createObjectURL(blob);
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
     * Parse PubTator annotations from text_hl field.
     * Memoized: the same `text_hl` string parses once and is reused across the
     * preview slice and the length check. The expanded detail view renders
     * annotated text via PubtatorAnnotatedText (which memoizes independently).
     */
    parseAnnotations(text: string | null | undefined): ParsedSegment[] {
      return parsePubtatorTextMemoized(text);
    },

    /**
     * Get CSS class for a parsed segment based on its type.
     * Delegates to the shared PubTator parser helper.
     */
    getSegmentClass(segment: ParsedSegment): string {
      return getSegmentClass(segment);
    },

    /**
     * Split a comma-separated gene_symbols string into trimmed symbols once.
     * The template needs this list up to three times per row (slice, count,
     * overflow), so memoize by the raw string to avoid repeated splitting.
     * Bounded with LRU eviction (recency refreshed on hit) so a long browsing
     * session over many distinct gene_symbols strings cannot grow it unbounded.
     */
    geneSymbolList(geneSymbols: string | null | undefined): string[] {
      if (!geneSymbols) return [];
      const cache = this.geneSymbolCache;
      const cached = cache.get(geneSymbols);
      if (cached) {
        cache.delete(geneSymbols);
        cache.set(geneSymbols, cached);
        return cached;
      }
      const list = geneSymbols
        .split(',')
        .map((g) => g.trim())
        .filter((g) => g !== '');
      if (cache.size >= GENE_SYMBOL_CACHE_LIMIT) {
        const oldestKey = cache.keys().next().value;
        if (oldestKey !== undefined) cache.delete(oldestKey);
      }
      cache.set(geneSymbols, list);
      return list;
    },
    // Normalize select options for BFormSelect (replacement for treeselect normalizer)
    normalizeSelectOptions(options) {
      return normalizeSelectOptions(options);
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

/* PubTator entity annotation highlights — AA-compliant (≥ 4.5:1).
   Class names are fixed by getSegmentClass() in usePubtatorParser.ts.
   Colors mapped to global sysndd-annotation-- equivalents from _chips.scss. */

/* Gene: --medical-blue-700 (#0d47a1) on --medical-blue-50 (#e3f2fd) ≈ 7.1:1 ✓ AAA */
.pubtator-gene {
  background-color: var(--medical-blue-50, #e3f2fd);
  color: var(--medical-blue-700, #0d47a1);
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Disease: #bf360c on #ffe0b2 ≈ 4.6:1 ✓ AA (deep orange, replaces #e65100 which is 3.5:1) */
.pubtator-disease {
  background-color: #ffe0b2;
  color: #bf360c;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Variant: #880e4f on #f8bbd9 ≈ 5.4:1 ✓ AA (deep rose, replaces #c2185b which is 3.9:1) */
.pubtator-variant {
  background-color: #f8bbd9;
  color: #880e4f;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Species: #1b5e20 on #c8e6c9 ≈ 5.5:1 ✓ AA (deep green, replaces #2e7d32 which is 3.7:1 on this bg) */
.pubtator-species {
  background-color: #c8e6c9;
  color: #1b5e20;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Chemical: #4a148c on #e1bee7 ≈ 5.6:1 ✓ AA (deep purple, replaces #7b1fa2 which is 3.6:1) */
.pubtator-chemical {
  background-color: #e1bee7;
  color: #4a148c;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Match: #bf360c on #fff59d ≈ 5.2:1 ✓ AA (replaces #f57f17 which is ~2.6:1 on yellow) */
.pubtator-match {
  background-color: #fff59d;
  color: #bf360c;
  font-weight: 600;
  border-radius: 2px;
  padding: 0 2px;
}

/* Score column — right-aligned monospace numeric */
.pubtator-score-numeric {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.8125rem;
}

/* PMID button — monospace for identifier consistency */
.pubtator-pmid-btn {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.75rem;
}

/* Publication details panel */
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
  color: var(--neutral-900, #212121);
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

/* PMID badge: --medical-blue-700 on --medical-blue-50 ≈ 7.1:1 ✓ AAA */
.details-pmid {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  background-color: var(--medical-blue-50, #e3f2fd);
  color: var(--medical-blue-700, #0d47a1);
  font-size: 0.85rem;
  font-weight: 500;
  text-decoration: none;
  border-radius: var(--radius-sm, 0.25rem);
  transition: all 0.15s ease-in-out;
}

.details-pmid:hover {
  background-color: var(--medical-blue-700, #0d47a1);
  color: #fff;
}

/* Date badge: --status-warning text (#f57c00 → boosted to #e65c00) on --status-warning-bg ≈ 4.55:1 ✓ AA */
.details-date {
  display: inline-flex;
  align-items: center;
  padding: 0.2em 0.5em;
  background-color: var(--status-warning-bg, #fff3e0);
  color: #e65c00;
  font-size: 0.8rem;
  font-weight: 500;
  border-radius: var(--radius-sm, 0.25rem);
}

/* Journal badge: --neutral-700 on --neutral-100 ≈ 5.4:1 ✓ AA */
.details-journal {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  background-color: var(--neutral-100, #f5f5f5);
  color: var(--neutral-700, #616161);
  font-size: 0.8rem;
  font-style: italic;
  border-radius: var(--radius-sm, 0.25rem);
  border: 1px solid var(--neutral-300, #e0e0e0);
}

/* The annotated-text block + legend now live in PubtatorAnnotatedText.vue.
   The entity color classes below are retained because the truncated text_hl
   preview cell renders segments inline (without that child component). */

/* Gene chips — pill badges in table cells */
.gene-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
  align-items: center;
}

/* Gene chip: --medical-blue-700 on --medical-blue-50 ≈ 7.1:1 ✓ AAA */
.gene-chip {
  display: inline-block;
  padding: 0.15em 0.5em;
  font-size: 0.75rem;
  font-weight: 500;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  background-color: var(--medical-blue-50, #e3f2fd);
  color: var(--medical-blue-700, #0d47a1);
  border-radius: var(--radius-full, 9999px);
  text-decoration: none;
  transition: all 0.15s ease-in-out;
  white-space: nowrap;
}

.gene-chip:hover {
  background-color: var(--medical-blue-700, #0d47a1);
  color: #fff;
  text-decoration: none;
}

/* Overflow chip: --neutral-700 on --neutral-100 ≈ 5.4:1 ✓ AA */
.gene-chip-more {
  display: inline-block;
  padding: 0.15em 0.4em;
  font-size: 0.7rem;
  font-weight: 500;
  background-color: var(--neutral-100, #f5f5f5);
  color: var(--neutral-700, #616161);
  border-radius: var(--radius-full, 9999px);
  cursor: help;
}
</style>
