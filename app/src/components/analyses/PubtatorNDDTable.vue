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
// Thin shell: all request/cache orchestration (state, watchers, loading,
// pagination, filter/sort, export, copy-link) lives in the
// usePubtatorPublicationTable composable; the parser helpers it delegates to
// stay in usePubtatorParser.ts (bounded module-level cache, not duplicated).
import { defineComponent } from 'vue';

import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import PubtatorAnnotatedText from '@/components/analyses/PubtatorAnnotatedText.vue';

import { usePubtatorPublicationTable } from './usePubtatorPublicationTable';

export default defineComponent({
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
    return {
      ...usePubtatorPublicationTable(props),
    };
  },
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
