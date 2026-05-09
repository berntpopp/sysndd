<!-- components/review/ReviewRowActions.vue -->
<!--
  Row-action buttons for the review approval table. Factored out so that
  E.E6's generic `ApprovalTableView` can accept a pluggable "actions" slot
  by swapping this component for a status-actions variant.
-->
<template>
  <div>
    <BButton
      v-b-tooltip.hover.left
      size="sm"
      class="me-1 btn-xs"
      variant="outline-primary"
      title="Toggle details"
      :aria-label="`Toggle details for entity ${item.entity_id}`"
      @click="toggleExpansion"
    >
      <i :class="'bi bi-' + (expansionShowing ? 'eye-slash' : 'eye')" aria-hidden="true" />
    </BButton>
    <BButton
      v-b-tooltip.hover.left
      size="sm"
      class="me-1 btn-xs"
      variant="secondary"
      title="Edit review"
      :aria-label="`Edit review for entity ${item.entity_id}`"
      @click="$emit('edit-review', item)"
    >
      <i class="bi bi-pen" aria-hidden="true" />
    </BButton>
    <BButton
      v-b-tooltip.hover.top
      size="sm"
      class="me-1 btn-xs"
      :variant="
        (stoplightsStyle[item.active_category ?? ''] as
          | 'secondary'
          | 'primary'
          | 'success'
          | 'warning'
          | 'danger'
          | 'info') || 'secondary'
      "
      :title="item.status_change ? 'Edit new status' : 'Edit status'"
      :aria-label="`${item.status_change ? 'Edit new status' : 'Edit status'} for entity ${item.entity_id}`"
      @click="$emit('edit-status', item)"
    >
      <span class="position-relative d-inline-block" style="font-size: 0.9em">
        <i class="bi bi-stoplights" aria-hidden="true" />
        <i
          v-if="item.status_change"
          class="bi bi-exclamation-triangle-fill position-absolute"
          style="top: -0.3em; right: -0.5em; font-size: 0.7em"
          aria-hidden="true"
        />
      </span>
    </BButton>
    <BButton
      v-b-tooltip.hover.right
      size="sm"
      class="me-1 btn-xs"
      variant="danger"
      title="Approve review"
      :aria-label="`Approve review for entity ${item.entity_id}`"
      @click="$emit('approve', item)"
    >
      <i class="bi bi-check2-circle" aria-hidden="true" />
    </BButton>
    <BButton
      v-b-tooltip.hover.right
      size="sm"
      class="me-1 btn-xs"
      variant="outline-danger"
      title="Dismiss review"
      :aria-label="`Dismiss review for entity ${item.entity_id}`"
      @click="$emit('dismiss', item)"
    >
      <i class="bi bi-x-circle" aria-hidden="true" />
    </BButton>
    <BButton
      v-if="item.duplicate === 'yes'"
      v-b-tooltip.hover.right
      variant="warning"
      title="Multiple pending reviews for this entity"
      :aria-label="`Warning: Multiple pending reviews for entity ${item.entity_id}`"
      size="sm"
      class="me-1 btn-xs"
    >
      <i class="bi bi-exclamation-triangle-fill" aria-hidden="true" />
    </BButton>
  </div>
</template>

<script setup lang="ts">
import type { PropType } from 'vue';

export interface ReviewRowItem {
  entity_id: number;
  review_id: number;
  active_category?: string | number;
  status_change?: number;
  duplicate?: string;
  [key: string]: unknown;
}

defineProps({
  item: { type: Object as PropType<ReviewRowItem>, required: true },
  expansionShowing: { type: Boolean, default: false },
  toggleExpansion: { type: Function as PropType<() => void>, required: true },
  stoplightsStyle: {
    type: Object as PropType<Record<string | number, string>>,
    default: () => ({}),
  },
});

defineEmits<{
  (e: 'edit-review', item: ReviewRowItem): void;
  (e: 'edit-status', item: ReviewRowItem): void;
  (e: 'approve', item: ReviewRowItem): void;
  (e: 'dismiss', item: ReviewRowItem): void;
}>();
</script>
