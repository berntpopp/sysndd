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
              publication count, so popularity bias (e.g. heavily-studied genes) does not dominate
              the raw count.
            </li>
            <li>
              <em>FDR significance:</em> Benjamini-Hochberg adjusted Fisher exact test (* q&lt;0.05,
              ** q&lt;0.01, *** q&lt;0.001).
            </li>
            <li><em>NDD Pubs:</em> Raw co-occurrence count (still sortable).</li>
          </ul>
          <p class="small text-muted mb-0">
            Background (total) publication counts and enrichment metrics are refreshed periodically;
            genes show “—” until the first refresh.
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
        class="public-data-table"
        @update:sort-by="handleSortByUpdate"
      >
        <!-- Custom table header cell with tooltips -->
        <template #head()="columnData">
          <!-- Tooltip via directive VALUE (not :title) so counts update on filter; see AGENTS.md (bvn v-b-tooltip). -->
          <div
            v-b-tooltip.hover.top="
              getCompactTooltipText(
                fields.find((f) => f.label === columnData.label) || {
                  key: columnData.column,
                  label: columnData.label,
                }
              )
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
// Small reusable components
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import PubtatorPublicationDetail from '@/components/analyses/PubtatorPublicationDetail.vue';
import {
  formatCount,
  formatEnrichment,
  enrichmentVariant,
  enrichmentTooltip,
  fdrStars,
  fdrClass,
  fdrTooltip,
} from './pubtatorEnrichmentDisplay';
import { usePubtatorGenesTable, type PubtatorGeneItem as GeneItem } from './usePubtatorGenesTable';

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

// Table orchestration (filter/URL state, cursor-paginated load, enrichment
// notice, page/sort handlers, export, fspec merge) lives in the composable so
// this SFC stays a thin template shell.
const {
  items,
  totalRows,
  perPage,
  fields,
  loading,
  isBusy,
  downloading,
  pageOptions,
  removeFiltersButtonTitle,
  removeFiltersButtonVariant,
  sortByArray,
  enrichmentNotice,
  minPublications,
  pubCountOptions,
  dateRange,
  dateRangeOptions,
  anyFilterContent,
  getFilterContent,
  setFilterContent,
  applyPrioritizationFilters,
  handlePageChange,
  handlePerPageChange,
  handleSortByUpdate,
  filtered,
  removeFilters,
  removeSearch,
  isExporting,
  handleExcelExport,
  copyLinkToClipboard,
  handleRowExpand,
  isLoadingPublications,
  getPublications,
  parsePmids,
  truncateText,
  getCompactTooltipText,
} = usePubtatorGenesTable(props, emit);
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
