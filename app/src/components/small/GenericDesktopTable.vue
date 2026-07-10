<!-- components/small/GenericDesktopTable.vue -->
<!--
  Desktop BTable responsibility extracted from GenericTable.vue (issue #346).
  Owns the full Bootstrap-Vue-Next table: every cell-slot forwarding block, the
  column-header (`#head`) and `filter-controls` (`#thead-top`) slots, busy/empty/
  table attributes, the details-toggle button, and server-side sort wiring via
  useGenericTableSorting. It forwards the raw BTable row-expansion scope up through
  its own `row-expansion` slot so the parent can supply the default detail card.
  Mobile rows, pagination, and toolbar chrome intentionally live in consumer SFCs.
-->
<template>
  <BTable
    :items="items"
    :fields="fields"
    :busy="isBusy"
    :sort-by="localSortBy"
    :stacked="stackedMode"
    :fixed="fixedLayout"
    head-variant="light"
    show-empty
    hover
    sort-icon-left
    no-local-sorting
    class="entities-table"
    tbody-tr-class="entity-row"
    @update:sort-by="handleSortByUpdate"
    @head-clicked="handleHeadClicked"
    @sorted="handleSorted"
  >
    <!-- Column header with optional tooltip support -->
    <template #head()="data">
      <slot name="column-header" :data="data" :fields="fields">
        {{ data.label }}
      </slot>
    </template>

    <!-- Filter fields row. Bootstrap-Vue-Next uses #thead-top instead of #top-row.
         role="presentation" removes the row from the table accessibility tree so
         axe/Lighthouse does not flag the filter <td> cells as lacking column headers
         (td-has-header). Filter inputs are independently labelled via aria-label. -->
    <template #thead-top>
      <tr v-if="$slots['filter-controls']" role="presentation">
        <slot name="filter-controls" />
      </tr>
    </template>

    <template #cell(id)="data">
      <slot name="cell-id" :row="data.item" :index="data.index">
        {{ data.item.id }}
      </slot>
    </template>
    <template #cell(entity_id)="data">
      <slot name="cell-entity_id" :row="data.item" :index="data.index">
        {{ data.item.entity_id }}
      </slot>
    </template>
    <template #cell(symbol)="data">
      <slot name="cell-symbol" :row="data.item" :index="data.index">
        {{ data.item.symbol }}
      </slot>
    </template>
    <template #cell(gene_symbol)="data">
      <slot name="cell-gene_symbol" :row="data.item" :index="data.index">
        {{ data.item.gene_symbol }}
      </slot>
    </template>
    <template #cell(hgnc_id)="data">
      <slot name="cell-hgnc_id" :row="data.item" :index="data.index">
        {{ data.item.hgnc_id }}
      </slot>
    </template>
    <template #cell(ndd_score)="data">
      <slot name="cell-ndd_score" :row="data.item" :index="data.index">
        {{ data.item.ndd_score }}
      </slot>
    </template>
    <template #cell(percentile)="data">
      <slot name="cell-percentile" :row="data.item" :index="data.index">
        {{ data.item.percentile }}
      </slot>
    </template>
    <template #cell(risk_tier)="data">
      <slot name="cell-risk_tier" :row="data.item" :index="data.index">
        {{ data.item.risk_tier }}
      </slot>
    </template>
    <template #cell(confidence_tier)="data">
      <slot name="cell-confidence_tier" :row="data.item" :index="data.index">
        {{ data.item.confidence_tier }}
      </slot>
    </template>
    <template #cell(known_sysndd_gene)="data">
      <slot name="cell-known_sysndd_gene" :row="data.item" :index="data.index">
        {{ data.item.known_sysndd_gene }}
      </slot>
    </template>
    <template #cell(model_split)="data">
      <slot name="cell-model_split" :row="data.item" :index="data.index">
        {{ data.item.model_split }}
      </slot>
    </template>
    <template #cell(top_inheritance_mode)="data">
      <slot name="cell-top_inheritance_mode" :row="data.item" :index="data.index">
        {{ data.item.top_inheritance_mode }}
      </slot>
    </template>
    <template #cell(top_hpo_predictions_json)="data">
      <slot name="cell-top_hpo_predictions_json" :row="data.item" :index="data.index">
        {{ data.item.top_hpo_predictions_json }}
      </slot>
    </template>
    <template #cell(disease_ontology_name)="data">
      <slot name="cell-disease_ontology_name" :row="data.item" :index="data.index">
        {{ data.item.disease_ontology_name }}
      </slot>
    </template>
    <template #cell(hpo_mode_of_inheritance_term_name)="data">
      <slot name="cell-hpo_mode_of_inheritance_term_name" :row="data.item" :index="data.index">
        {{ data.item.hpo_mode_of_inheritance_term_name }}
      </slot>
    </template>
    <template #cell(category)="data">
      <slot name="cell-category" :row="data.item" :index="data.index">
        {{ data.item.category }}
      </slot>
    </template>
    <template #cell(ndd_phenotype_word)="data">
      <slot name="cell-ndd_phenotype_word" :row="data.item" :index="data.index">
        {{ data.item.ndd_phenotype_word }}
      </slot>
    </template>
    <template #cell(actions)="data">
      <slot
        name="cell-actions"
        :row="data.item"
        :index="data.index"
        :toggle-expansion="data.toggleDetails || data.toggleExpansion"
        :expansion-showing="data.detailsShowing || data.expansionShowing"
      >
        {{ data.item.actions }}
      </slot>
    </template>
    <template #cell(synopsis)="data">
      <slot name="cell-synopsis" :row="data.item" :index="data.index">
        {{ data.item.synopsis }}
      </slot>
    </template>
    <template #cell(comment)="data">
      <slot name="cell-comment" :row="data.item" :index="data.index">
        {{ data.item.comment }}
      </slot>
    </template>
    <template #cell(review_date)="data">
      <slot name="cell-review_date" :row="data.item" :index="data.index">
        {{ data.item.review_date }}
      </slot>
    </template>
    <template #cell(review_user_name)="data">
      <slot name="cell-review_user_name" :row="data.item" :index="data.index">
        {{ data.item.review_user_name }}
      </slot>
    </template>
    <template #cell(status_date)="data">
      <slot name="cell-status_date" :row="data.item" :index="data.index">
        {{ data.item.status_date }}
      </slot>
    </template>
    <template #cell(status_user_name)="data">
      <slot name="cell-status_user_name" :row="data.item" :index="data.index">
        {{ data.item.status_user_name }}
      </slot>
    </template>
    <template #cell(problematic)="data">
      <slot name="cell-problematic" :row="data.item" :index="data.index">
        {{ data.item.problematic }}
      </slot>
    </template>
    <template #cell(agent)="data">
      <slot name="cell-agent" :row="data.item" :index="data.index">
        {{ data.item.agent }}
      </slot>
    </template>
    <template #cell(status)="data">
      <slot name="cell-status" :row="data.item" :index="data.index">
        {{ data.item.status }}
      </slot>
    </template>
    <template #cell(request_method)="data">
      <slot name="cell-request_method" :row="data.item" :index="data.index">
        {{ data.item.request_method }}
      </slot>
    </template>
    <template #cell(query)="data">
      <slot name="cell-query" :row="data.item" :index="data.index">
        {{ data.item.query }}
      </slot>
    </template>
    <template #cell(timestamp)="data">
      <slot name="cell-timestamp" :row="data.item" :index="data.index">
        {{ data.item.timestamp }}
      </slot>
    </template>
    <template #cell(modified)="data">
      <slot name="cell-modified" :row="data.item" :index="data.index">
        {{ data.item.modified }}
      </slot>
    </template>
    <template #cell(path)="data">
      <slot name="cell-path" :row="data.item" :index="data.index">
        {{ data.item.path }}
      </slot>
    </template>
    <template #cell(host)="data">
      <slot name="cell-host" :row="data.item" :index="data.index">
        {{ data.item.host }}
      </slot>
    </template>
    <template #cell(address)="data">
      <slot name="cell-address" :row="data.item" :index="data.index">
        {{ data.item.address }}
      </slot>
    </template>
    <template #cell(duration)="data">
      <slot name="cell-duration" :row="data.item" :index="data.index">
        {{ data.item.duration }}
      </slot>
    </template>
    <template #cell(file)="data">
      <slot name="cell-file" :row="data.item" :index="data.index">
        {{ data.item.file }}
      </slot>
    </template>
    <template #cell(post)="data">
      <slot name="cell-post" :row="data.item" :index="data.index">
        {{ data.item.post }}
      </slot>
    </template>
    <template #cell(approved)="data">
      <slot name="cell-approved" :row="data.item" :index="data.index">
        {{ data.item.approved }}
      </slot>
    </template>
    <template #cell(user_role)="data">
      <slot name="cell-user_role" :row="data.item" :index="data.index">
        {{ data.item.user_role }}
      </slot>
    </template>
    <template #cell(user_name)="data">
      <slot name="cell-user_name" :row="data.item" :index="data.index">
        {{ data.item.user_name }}
      </slot>
    </template>
    <template #cell(re_review_batch)="data">
      <slot name="cell-re_review_batch" :row="data.item" :index="data.index">
        {{ data.item.re_review_batch }}
      </slot>
    </template>
    <template #cell(re_review_review_saved)="data">
      <slot name="cell-re_review_review_saved" :row="data.item" :index="data.index">
        {{ data.item.re_review_review_saved }}
      </slot>
    </template>
    <template #cell(re_review_status_saved)="data">
      <slot name="cell-re_review_status_saved" :row="data.item" :index="data.index">
        {{ data.item.re_review_status_saved }}
      </slot>
    </template>
    <template #cell(re_review_submitted)="data">
      <slot name="cell-re_review_submitted" :row="data.item" :index="data.index">
        {{ data.item.re_review_submitted }}
      </slot>
    </template>
    <template #cell(re_review_approved)="data">
      <slot name="cell-re_review_approved" :row="data.item" :index="data.index">
        {{ data.item.re_review_approved }}
      </slot>
    </template>
    <template #cell(entity_count)="data">
      <slot name="cell-entity_count" :row="data.item" :index="data.index">
        {{ data.item.entity_count }}
      </slot>
    </template>
    <template #cell(cluster_num)="data">
      <slot name="cell-cluster_num" :row="data.item" :index="data.index">
        {{ data.item.cluster_num }}
      </slot>
    </template>
    <template #cell(SysNDD)="data">
      <slot name="cell-SysNDD" :row="data.item" :index="data.index">
        {{ data.item.SysNDD }}
      </slot>
    </template>
    <template #cell(radboudumc_ID)="data">
      <slot name="cell-radboudumc_ID" :row="data.item" :index="data.index">
        {{ data.item.radboudumc_ID }}
      </slot>
    </template>
    <template #cell(gene2phenotype)="data">
      <slot name="cell-gene2phenotype" :row="data.item" :index="data.index">
        {{ data.item.gene2phenotype }}
      </slot>
    </template>
    <template #cell(panelapp)="data">
      <slot name="cell-panelapp" :row="data.item" :index="data.index">
        {{ data.item.panelapp }}
      </slot>
    </template>
    <template #cell(sfari)="data">
      <slot name="cell-sfari" :row="data.item" :index="data.index">
        {{ data.item.sfari }}
      </slot>
    </template>
    <template #cell(ndd_genehub)="data">
      <slot name="cell-ndd_genehub" :row="data.item" :index="data.index">
        {{ data.item.ndd_genehub }}
      </slot>
    </template>
    <template #cell(omim_ndd)="data">
      <slot name="cell-omim_ndd" :row="data.item" :index="data.index">
        {{ data.item.omim_ndd }}
      </slot>
    </template>
    <template #cell(orphanet_id)="data">
      <slot name="cell-orphanet_id" :row="data.item" :index="data.index">
        {{ data.item.orphanet_id }}
      </slot>
    </template>
    <template #cell(publication_id)="data">
      <slot name="cell-publication_id" :row="data.item" :index="data.index">
        {{ data.item.publication_id }}
      </slot>
    </template>
    <template #cell(Title)="data">
      <slot name="cell-Title" :row="data.item" :index="data.index">
        {{ data.item.Title }}
      </slot>
    </template>
    <template #cell(Journal)="data">
      <slot name="cell-Journal" :row="data.item" :index="data.index">
        {{ data.item.Journal }}
      </slot>
    </template>
    <template #cell(Publication_date)="data">
      <slot name="cell-Publication_date" :row="data.item" :index="data.index">
        {{ data.item.Publication_date }}
      </slot>
    </template>
    <!-- Description column with truncation and tooltip -->
    <template #cell(description)="data">
      <slot name="cell-description" :row="data.item" :index="data.index">
        <span v-b-tooltip.hover.top class="description-text" :title="data.item.description">
          {{ data.item.description }}
        </span>
      </slot>
    </template>
    <template #cell(text_hl)="data">
      <slot name="cell-text_hl" :row="data.item" :index="data.index">
        {{ data.item.text_hl }}
      </slot>
    </template>
    <template #cell(title)="data">
      <slot name="cell-title" :row="data.item" :index="data.index">
        {{ data.item.title }}
      </slot>
    </template>
    <template #cell(doi)="data">
      <slot name="cell-doi" :row="data.item" :index="data.index">
        {{ data.item.doi }}
      </slot>
    </template>
    <template #cell(journal)="data">
      <slot name="cell-journal" :row="data.item" :index="data.index">
        {{ data.item.journal }}
      </slot>
    </template>
    <template #cell(date)="data">
      <slot name="cell-date" :row="data.item" :index="data.index">
        {{ data.item.date }}
      </slot>
    </template>
    <template #cell(score)="data">
      <slot name="cell-score" :row="data.item" :index="data.index">
        {{ data.item.score }}
      </slot>
    </template>
    <template #cell(gene_symbols)="data">
      <slot name="cell-gene_symbols" :row="data.item" :index="data.index">
        {{ data.item.gene_symbols }}
      </slot>
    </template>
    <template #cell(pmid)="data">
      <slot name="cell-pmid" :row="data.item" :index="data.index">
        {{ data.item.pmid }}
      </slot>
    </template>
    <template #cell(search_id)="data">
      <slot name="cell-search_id" :row="data.item" :index="data.index">
        {{ data.item.search_id }}
      </slot>
    </template>
    <!-- Details toggle button -->
    <template #cell(details)="row">
      <BButton class="btn-xs" variant="outline-primary" @click="row.toggleExpansion">
        {{ row.expansionShowing ? 'Hide' : 'Show' }}
      </BButton>
    </template>
    <!-- Row expansion - forwards the raw BTable scope so the parent can supply
         the default detail card (or a consumer override) via its own slot. -->
    <template #row-expansion="row">
      <slot name="row-expansion" v-bind="row" />
    </template>
  </BTable>
</template>

<script setup>
// Plain <script setup> (no lang="ts") deliberately mirrors the original
// GenericTable.vue JS component: row items are intentionally loosely typed so
// every consumer's cell/row-expansion slot keeps its original untyped contract.
// Sort logic is delegated to the typed useGenericTableSorting composable.
import { BTable, BButton } from 'bootstrap-vue-next';
import { useGenericTableSorting } from './useGenericTableSorting';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  fields: {
    type: Array,
    default: () => [],
  },
  isBusy: {
    type: Boolean,
    default: false,
  },
  sortBy: {
    // Accept both string (legacy) and array (Bootstrap-Vue-Next) formats
    type: [String, Array],
    default: () => [],
  },
  sortDesc: {
    type: Boolean,
    default: false,
  },
  stackedMode: {
    type: [String, Boolean],
    default: 'md',
  },
  fixedLayout: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['update-sort', 'update:sort-by']);

const { localSortBy, handleSortByUpdate, handleHeadClicked, handleSorted } = useGenericTableSorting(
  props,
  emit
);
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

/* Mobile: modest touch-target bump for details button */
@media (max-width: 767px) {
  .btn-xs {
    padding: 0.3rem 0.6rem;
    font-size: 0.8125rem;
    line-height: 1.2;
  }
}

/* Modern table styling */
.entities-table {
  border-collapse: separate;
  border-spacing: 0;
}

:deep(.entities-table td[colspan]) {
  overflow: visible;
  white-space: normal;
}

/* Row styling - subtle separator and better spacing */
:deep(.entities-table tbody tr) {
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  transition: background-color 0.15s ease;
}

:deep(.entities-table tbody tr:last-child) {
  border-bottom: none;
}

/* Alternating row backgrounds - very subtle */
:deep(.entities-table tbody tr:nth-child(even)) {
  background-color: rgba(0, 0, 0, 0.015);
}

/* Enhanced hover effect */
:deep(.entities-table tbody tr:hover) {
  background-color: rgba(13, 110, 253, 0.04);
}

/* Cell padding and alignment */
:deep(.entities-table td) {
  padding: 0.65rem 0.5rem;
  vertical-align: middle;
  border-top: none;
}

:deep(.entities-table th) {
  padding: 0.6rem 0.5rem;
  font-weight: 600;
  font-size: 0.8125rem;
  text-transform: uppercase;
  letter-spacing: 0;
  color: #495057;
  background-color: #f8f9fa;
  border-bottom: 2px solid #dee2e6;
}

/* Filter row styling */
:deep(.entities-table thead tr:first-child td) {
  padding: 0.4rem 0.25rem;
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
}

/* Stacked mode improvements for mobile */
@media (max-width: 767px) {
  :deep(.entities-table.b-table-stacked-md > tbody > tr) {
    padding: 0.75rem;
    margin-bottom: 0.5rem;
    border: 1px solid rgba(0, 0, 0, 0.08);
    border-radius: 0.5rem;
    background-color: #fff;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
  }

  :deep(.entities-table.b-table-stacked-md > tbody > tr:hover) {
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.08);
  }

  :deep(.entities-table.b-table-stacked-md > tbody > tr > td) {
    padding: 0.35rem 0;
    border: none;
  }
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  :deep(.entities-table tbody tr) {
    transition: none;
  }
}
</style>

<!-- The override that keeps column-header tooltips from being clipped by the
     sortable <th>'s overflow:hidden now lives once in
     `assets/scss/components/_tables.scss`, shared by `.entities-table` and
     `.public-data-table` surfaces. Kept there to avoid duplicating it per table. -->
