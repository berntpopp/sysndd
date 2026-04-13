<!-- components/review/ReviewRowExpansion.vue -->
<template>
  <BCard class="mb-2 border-0 shadow-sm" body-class="p-3">
    <div class="row g-3">
      <div class="col-md-4">
        <h6 class="text-muted small text-uppercase fw-semibold mb-2">
          <i class="bi bi-info-circle me-1" />
          Entity Details
        </h6>
        <div class="d-flex flex-column gap-2">
          <div class="d-flex align-items-center gap-2">
            <span class="text-muted small" style="min-width: 80px">Review ID:</span>
            <BBadge variant="secondary">{{ item.review_id }}</BBadge>
          </div>
          <div class="d-flex align-items-center gap-2">
            <span class="text-muted small" style="min-width: 80px">Ontology:</span>
            <code class="small">{{ item.disease_ontology_id_version }}</code>
          </div>
          <div class="d-flex align-items-center gap-2">
            <span class="text-muted small" style="min-width: 80px">Primary:</span>
            <BBadge :variant="item.is_primary ? 'success' : 'secondary'">
              {{ item.is_primary ? 'Yes' : 'No' }}
            </BBadge>
          </div>
        </div>
      </div>
      <div class="col-md-8">
        <h6 class="text-muted small text-uppercase fw-semibold mb-2">
          <i class="bi bi-file-text me-1" />
          Full Synopsis
        </h6>
        <div
          v-if="item.synopsis"
          class="bg-light rounded p-2 small"
          style="max-height: 120px; overflow-y: auto"
        >
          {{ item.synopsis }}
        </div>
        <span v-else class="text-muted small fst-italic">No synopsis available</span>
        <div v-if="item.comment" class="mt-3">
          <h6 class="text-muted small text-uppercase fw-semibold mb-2">
            <i class="bi bi-chat-left-text me-1" />
            Comment
          </h6>
          <div class="bg-warning-subtle rounded p-2 small">{{ item.comment }}</div>
        </div>
      </div>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import type { PropType } from 'vue';

export interface ReviewExpansionItem {
  review_id: number;
  disease_ontology_id_version?: string;
  is_primary?: number;
  synopsis?: string | null;
  comment?: string | null;
}

defineProps({
  item: { type: Object as PropType<ReviewExpansionItem>, required: true },
});
</script>
