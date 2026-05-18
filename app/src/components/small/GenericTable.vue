<!-- components/small/GenericTable.vue -->
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

    <!-- Slot for custom filter fields -->
    <!-- Bootstrap-Vue-Next uses #thead-top instead of #top-row -->
    <template #thead-top>
      <tr v-if="$slots['filter-controls']">
        <slot name="filter-controls" />
      </tr>
    </template>

    <!-- ID column (generic) -->
    <template #cell(id)="data">
      <slot name="cell-id" :row="data.item" :index="data.index">
        {{ data.item.id }}
      </slot>
    </template>

    <!-- Entity ID column -->
    <template #cell(entity_id)="data">
      <slot name="cell-entity_id" :row="data.item" :index="data.index">
        {{ data.item.entity_id }}
      </slot>
    </template>

    <!-- Symbol column -->
    <template #cell(symbol)="data">
      <slot name="cell-symbol" :row="data.item" :index="data.index">
        {{ data.item.symbol }}
      </slot>
    </template>

    <!-- Gene prediction columns -->
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

    <!-- Disease ontology name column -->
    <template #cell(disease_ontology_name)="data">
      <slot name="cell-disease_ontology_name" :row="data.item" :index="data.index">
        {{ data.item.disease_ontology_name }}
      </slot>
    </template>

    <!-- HPO mode of inheritance column -->
    <template #cell(hpo_mode_of_inheritance_term_name)="data">
      <slot name="cell-hpo_mode_of_inheritance_term_name" :row="data.item" :index="data.index">
        {{ data.item.hpo_mode_of_inheritance_term_name }}
      </slot>
    </template>

    <!-- Category column -->
    <template #cell(category)="data">
      <slot name="cell-category" :row="data.item" :index="data.index">
        {{ data.item.category }}
      </slot>
    </template>

    <!-- NDD phenotype column -->
    <template #cell(ndd_phenotype_word)="data">
      <slot name="cell-ndd_phenotype_word" :row="data.item" :index="data.index">
        {{ data.item.ndd_phenotype_word }}
      </slot>
    </template>

    <!-- Actions column -->
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

    <!-- Approval/review related columns -->
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

    <!-- Log-related columns -->
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

    <!-- Approved column -->
    <template #cell(approved)="data">
      <slot name="cell-approved" :row="data.item" :index="data.index">
        {{ data.item.approved }}
      </slot>
    </template>

    <!-- User role column -->
    <template #cell(user_role)="data">
      <slot name="cell-user_role" :row="data.item" :index="data.index">
        {{ data.item.user_role }}
      </slot>
    </template>

    <!-- Re-review management columns -->
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

    <!-- Cluster number column (for combined cluster data) -->
    <template #cell(cluster_num)="data">
      <slot name="cell-cluster_num" :row="data.item" :index="data.index">
        {{ data.item.cluster_num }}
      </slot>
    </template>

    <!-- Curation comparison columns -->
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

    <template #cell(geisinger_DBD)="data">
      <slot name="cell-geisinger_DBD" :row="data.item" :index="data.index">
        {{ data.item.geisinger_DBD }}
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

    <!-- Publication-related columns -->
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

    <!-- Text highlight column (for PubTator annotations) -->
    <template #cell(text_hl)="data">
      <slot name="cell-text_hl" :row="data.item" :index="data.index">
        {{ data.item.text_hl }}
      </slot>
    </template>

    <!-- Title column (lowercase - for PubTator table) -->
    <template #cell(title)="data">
      <slot name="cell-title" :row="data.item" :index="data.index">
        {{ data.item.title }}
      </slot>
    </template>

    <!-- DOI column -->
    <template #cell(doi)="data">
      <slot name="cell-doi" :row="data.item" :index="data.index">
        {{ data.item.doi }}
      </slot>
    </template>

    <!-- Journal column (lowercase) -->
    <template #cell(journal)="data">
      <slot name="cell-journal" :row="data.item" :index="data.index">
        {{ data.item.journal }}
      </slot>
    </template>

    <!-- Date column -->
    <template #cell(date)="data">
      <slot name="cell-date" :row="data.item" :index="data.index">
        {{ data.item.date }}
      </slot>
    </template>

    <!-- Score column -->
    <template #cell(score)="data">
      <slot name="cell-score" :row="data.item" :index="data.index">
        {{ data.item.score }}
      </slot>
    </template>

    <!-- Gene symbols column -->
    <template #cell(gene_symbols)="data">
      <slot name="cell-gene_symbols" :row="data.item" :index="data.index">
        {{ data.item.gene_symbols }}
      </slot>
    </template>

    <!-- PMID column -->
    <template #cell(pmid)="data">
      <slot name="cell-pmid" :row="data.item" :index="data.index">
        {{ data.item.pmid }}
      </slot>
    </template>

    <!-- Search ID column -->
    <template #cell(search_id)="data">
      <slot name="cell-search_id" :row="data.item" :index="data.index">
        {{ data.item.search_id }}
      </slot>
    </template>

    <!-- Details column -->
    <template #cell(details)="row">
      <BButton class="btn-xs" variant="outline-primary" @click="row.toggleExpansion">
        {{ row.expansionShowing ? 'Hide' : 'Show' }}
      </BButton>
    </template>

    <!-- Row expansion - allows custom slot override -->
    <template #row-expansion="row">
      <slot name="row-expansion" :row="row.item" :toggle="row.toggleExpansion">
        <BCard class="generic-table-detail-card">
          <dl class="generic-table-detail">
            <div
              v-for="field in fieldDetails"
              :key="field.key"
              class="generic-table-detail__row"
              :class="{ 'generic-table-detail__row--long-text': isLongDetailField(field.key) }"
            >
              <dt class="generic-table-detail__label">
                {{ field.label || field.key }}
              </dt>
              <dd class="generic-table-detail__value">
                <span>{{ detailValue(row.item, field.key) }}</span>
                <BButton
                  v-if="isCopyableDetailField(field.key, row.item)"
                  size="sm"
                  variant="outline-primary"
                  class="generic-table-detail__copy-button"
                  :aria-label="`Copy ${field.label || field.key}`"
                  @click.stop="copyDetailValue(row.item, field.key)"
                >
                  <i class="bi bi-clipboard" aria-hidden="true" />
                  {{ copiedDetailKey === detailCopyKey(row.item, field.key) ? 'Copied' : 'Copy' }}
                </BButton>
              </dd>
            </div>
          </dl>
        </BCard>
      </slot>
    </template>
  </BTable>
</template>

<script>
import { BTable, BButton, BCard } from 'bootstrap-vue-next';

export default {
  name: 'GenericTable',
  components: {
    BTable,
    BButton,
    BCard,
  },
  props: {
    items: {
      type: Array,
      default: () => [],
    },
    fields: {
      type: Array,
      default: () => [],
    },
    fieldDetails: {
      type: Array,
      default: () => [],
    },
    currentPage: {
      type: Number,
      default: null,
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
  },
  emits: ['update-sort', 'update:sort-by', 'head-clicked', 'sorted'],
  data() {
    return {
      copiedDetailKey: null,
      copyResetTimer: null,
    };
  },
  computed: {
    /**
     * Converts sortBy prop to Bootstrap-Vue-Next array format.
     * Handles both legacy string format and new array format.
     * @returns {Array} Array of { key, order } objects
     */
    localSortBy() {
      // If already an array, return as-is
      if (Array.isArray(this.sortBy)) {
        return this.sortBy;
      }
      // Convert string to array format for Bootstrap-Vue-Next
      if (typeof this.sortBy === 'string' && this.sortBy) {
        return [
          {
            key: this.sortBy,
            order: this.sortDesc ? 'desc' : 'asc',
          },
        ];
      }
      // Default to empty array
      return [];
    },
  },
  beforeUnmount() {
    if (this.copyResetTimer) {
      window.clearTimeout(this.copyResetTimer);
      this.copyResetTimer = null;
    }
  },
  methods: {
    detailValue(row, key) {
      const value = row?.[key];
      return value === null || value === undefined || value === '' ? '—' : value;
    },
    isLongDetailField(key) {
      return /synopsis|abstract|comment|description|summary|note/i.test(String(key || ''));
    },
    isCopyableDetailField(key, row) {
      return this.isLongDetailField(key) && this.detailValue(row, key) !== '—';
    },
    detailCopyKey(row, key) {
      const rowKey = row?.entity_id ?? row?.id ?? row?.symbol ?? '';
      return `${rowKey}:${String(key || '')}`;
    },
    async copyDetailValue(row, key) {
      const value = this.detailValue(row, key);
      if (value === '—' || !navigator?.clipboard?.writeText) {
        return;
      }

      try {
        await navigator.clipboard.writeText(String(value));
        this.copiedDetailKey = this.detailCopyKey(row, key);
        if (this.copyResetTimer) {
          window.clearTimeout(this.copyResetTimer);
        }
        this.copyResetTimer = window.setTimeout(() => {
          this.copiedDetailKey = null;
          this.copyResetTimer = null;
        }, 1600);
      } catch {
        this.copiedDetailKey = null;
      }
    },
    handleSortByUpdate(newSortBy) {
      this.$emit('update:sort-by', newSortBy);
      if (newSortBy && newSortBy.length > 0 && newSortBy[0].key) {
        const sortByStr = newSortBy[0].key;
        const sortDescBool = newSortBy[0].order === 'desc';
        this.$emit('update-sort', { sortBy: sortByStr, sortDesc: sortDescBool });
      }
    },
    /**
     * Handle column header click for server-side sorting.
     * Bootstrap-Vue-Next may not emit update:sort-by with no-local-sorting,
     * so we handle head-clicked directly to ensure sorting works.
     * @param {string} key - The field key that was clicked
     * @param {Object} field - The field definition object
     * @param {Event} _event - The click event (unused but required by event signature)
     */
    handleHeadClicked(key, field, _event) {
      // Only handle sortable columns
      if (!field || field.sortable === false) {
        return;
      }

      // Determine current sort state and toggle
      const currentSortKey = this.localSortBy.length > 0 ? this.localSortBy[0].key : null;
      const currentSortOrder = this.localSortBy.length > 0 ? this.localSortBy[0].order : 'asc';

      let newSortOrder = 'asc';
      if (currentSortKey === key) {
        // Same column - toggle order
        newSortOrder = currentSortOrder === 'asc' ? 'desc' : 'asc';
      }

      // Build and emit the new sort state
      const newSortBy = [{ key, order: newSortOrder }];
      this.$emit('update:sort-by', newSortBy);
      this.$emit('update-sort', { sortBy: key, sortDesc: newSortOrder === 'desc' });
    },
    /**
     * Handle sorted event from BTable (Bootstrap-Vue-Next).
     * This event fires when sorting changes.
     * @param {Object} ctx - Sort context with sortBy and sortDesc
     */
    handleSorted(ctx) {
      if (ctx && ctx.sortBy) {
        const sortKey =
          Array.isArray(ctx.sortBy) && ctx.sortBy.length > 0 ? ctx.sortBy[0].key : ctx.sortBy;
        const sortDesc =
          Array.isArray(ctx.sortBy) && ctx.sortBy.length > 0
            ? ctx.sortBy[0].order === 'desc'
            : ctx.sortDesc || false;
        this.$emit('update-sort', { sortBy: sortKey, sortDesc });
      }
    },
  },
};
</script>

<style scoped>
.generic-table-detail-card {
  margin: 0.5rem;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 0.5rem;
  box-shadow: none;
  text-align: left;
  white-space: normal;
}

:deep(.generic-table-detail-card .card-body) {
  white-space: normal;
}

.generic-table-detail {
  margin: 0;
  min-width: 0;
  white-space: normal;
}

.generic-table-detail__row {
  display: grid;
  grid-template-columns: minmax(10rem, max-content) minmax(0, 1fr);
  gap: 0.75rem;
  padding: 0.45rem 0;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  white-space: normal;
}

.generic-table-detail__row--long-text {
  grid-template-columns: 1fr;
  gap: 0.3rem;
  padding: 0.65rem 0;
}

.generic-table-detail__row:last-child {
  border-bottom: 0;
}

.generic-table-detail__label {
  margin: 0;
  color: #0f172a;
  font-weight: 700;
  text-align: left;
  white-space: nowrap;
}

.generic-table-detail__value {
  min-width: 0;
  margin: 0;
  color: #111827;
  text-align: left;
  overflow-wrap: anywhere;
  white-space: normal;
}

.generic-table-detail__row--long-text .generic-table-detail__value {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 0.5rem;
  align-items: start;
  padding: 0.65rem 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.375rem;
  background: #f8fafc;
  line-height: 1.45;
}

.generic-table-detail__copy-button {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  min-height: 1.45rem;
  padding: 0.08rem 0.4rem;
  border-color: #0a58ca;
  color: #0a58ca;
  font-size: 0.72rem;
  line-height: 1;
  white-space: nowrap;
}

.generic-table-detail__copy-button:hover,
.generic-table-detail__copy-button:focus {
  border-color: #084298;
  background-color: #0a58ca;
  color: #fff;
}

:deep(.entities-table td[colspan]) {
  overflow: visible;
  white-space: normal;
}

@media (max-width: 575.98px) {
  .generic-table-detail__row {
    grid-template-columns: 1fr;
    gap: 0.15rem;
  }

  .generic-table-detail__label {
    white-space: normal;
  }

  .generic-table-detail__row--long-text .generic-table-detail__value {
    grid-template-columns: 1fr;
  }

  .generic-table-detail__copy-button {
    justify-self: start;
  }
}
</style>

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

<!-- Unscoped: override Bootstrap-Vue-Next's overflow:hidden on sortable <th>
     so tooltips rendered inside column headers are not clipped -->
<style>
.entities-table th.b-table-sortable-column {
  overflow: visible !important;
}
</style>
