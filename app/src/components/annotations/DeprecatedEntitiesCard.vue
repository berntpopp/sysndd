<!-- components/annotations/DeprecatedEntitiesCard.vue -->
<template>
  <BCard
    header-tag="header"
    body-class="p-2"
    header-class="p-1"
    border-variant="dark"
    class="mb-3 text-start"
  >
    <template #header>
      <h5 class="mb-0 text-start font-weight-bold d-flex align-items-center">
        Deprecated OMIM Entities
        <span v-if="data.mim2gene_date" class="badge bg-secondary ms-2 fw-normal">
          mim2gene: {{ data.mim2gene_date }}
        </span>
        <span
          v-if="data.affected_entity_count > 0"
          class="badge bg-warning text-dark ms-2 fw-normal"
        >
          {{ data.affected_entity_count }} entities need review
        </span>
        <span
          v-else-if="!loading && data.deprecated_count !== null"
          class="badge bg-success ms-2 fw-normal"
        >
          No affected entities
        </span>
      </h5>
    </template>

    <div class="mb-3">
      <BButton variant="outline-secondary" size="sm" :disabled="loading" @click="$emit('check')">
        <BSpinner v-if="loading" small type="grow" class="me-1" />
        {{ loading ? 'Checking...' : 'Check for Deprecated Entities' }}
      </BButton>
      <small class="text-muted ms-2">
        Compares database entities against OMIM moved/removed entries
      </small>
    </div>

    <div v-if="data.message && !data.affected_entities?.length">
      <BAlert variant="info" show>{{ data.message }}</BAlert>
    </div>

    <div v-if="data.affected_entities?.length > 0">
      <p class="text-muted small mb-2">
        The following entities reference OMIM IDs that have been marked as moved/removed. MONDO
        mappings and replacement suggestions are fetched from the EBI OLS4 API.
      </p>
      <BTable
        :items="data.affected_entities"
        :fields="tableFields"
        striped
        hover
        small
        responsive
        class="mb-0"
      >
        <template #cell(entity_id)="row">
          <router-link
            :to="{ name: 'Entity', params: { entity_id: String(row.value) } }"
            class="text-decoration-none"
          >
            <span class="badge bg-primary">sysndd:{{ row.value }}</span>
          </router-link>
        </template>
        <template #cell(symbol)="row">
          <router-link
            :to="{ name: 'Gene', params: { symbol: String(row.value) } }"
            class="text-decoration-none fw-bold"
          >
            {{ row.value }}
          </router-link>
        </template>
        <template #cell(disease_ontology_id)="row">
          <div class="d-flex flex-column">
            <a
              :href="`https://omim.org/entry/${String(row.value).replace('OMIM:', '')}`"
              target="_blank"
              class="text-danger text-decoration-none"
            >
              {{ row.value }}
              <small class="text-muted">(deprecated)</small>
            </a>
            <small v-if="row.item.mondo_id" class="text-muted">
              <a
                :href="`https://monarchinitiative.org/disease/${row.item.mondo_id}`"
                target="_blank"
                class="text-decoration-none"
              >
                {{ row.item.mondo_id }}
              </a>
            </small>
          </div>
        </template>
        <template #cell(replacement_suggestion)="row">
          <div
            v-if="row.item.replacement_omim_id || row.item.replacement_mondo_id"
            class="d-flex flex-column"
          >
            <span v-if="row.item.replacement_omim_id" class="d-flex align-items-center">
              <span class="badge bg-success me-1">Suggested</span>
              <a
                :href="`https://omim.org/entry/${String(row.item.replacement_omim_id).replace('OMIM:', '')}`"
                target="_blank"
                class="text-decoration-none text-success fw-bold"
              >
                {{ row.item.replacement_omim_id }}
              </a>
            </span>
            <small v-if="row.item.replacement_mondo_id" class="text-muted">
              via
              <a
                :href="`https://monarchinitiative.org/disease/${row.item.replacement_mondo_id}`"
                target="_blank"
                class="text-decoration-none"
              >
                {{ row.item.replacement_mondo_id }}
              </a>
              <span v-if="row.item.replacement_mondo_label">
                ({{ truncateText(String(row.item.replacement_mondo_label), 30) }})
              </span>
            </small>
          </div>
          <span v-else-if="row.item.mondo_id" class="text-muted small"> No replacement found </span>
          <span v-else class="text-muted small">No MONDO mapping</span>
        </template>
        <template #cell(deprecation_reason)="row">
          <small v-if="row.value" class="text-muted deprecation-reason" :title="String(row.value)">
            {{ truncateText(String(row.value), 80) }}
          </small>
          <span v-else class="text-muted small">-</span>
        </template>
        <template #cell(category)="row">
          <span class="badge" :class="categoryBadgeClass(String(row.value))">
            {{ row.value }}
          </span>
        </template>
      </BTable>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import {
  truncateText,
  categoryBadgeClass,
} from '@/composables/annotations/useAnnotationFormatters';

export interface DeprecatedData {
  deprecated_count: number | null;
  affected_entity_count: number;
  affected_entities: Array<Record<string, unknown>>;
  mim2gene_date: string | null;
  message: string | null;
}

defineProps<{
  data: DeprecatedData;
  loading: boolean;
}>();

defineEmits<{
  (e: 'check'): void;
}>();

const tableFields = [
  { key: 'entity_id', label: 'Entity', sortable: true },
  { key: 'symbol', label: 'Gene', sortable: true },
  { key: 'disease_ontology_id', label: 'Deprecated OMIM', sortable: true },
  { key: 'replacement_suggestion', label: 'Replacement', sortable: false },
  { key: 'deprecation_reason', label: 'Reason', sortable: false },
  { key: 'category', label: 'Category', sortable: true },
];
</script>

<style scoped>
.deprecation-reason {
  display: block;
  max-width: 250px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  cursor: help;
}
</style>
