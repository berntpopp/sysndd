<!-- components/review/ReviewRowCells.vue -->
<!--
  Row-cell renderers for the review approval table. Rendered once per row
  via the slot mapping in `ApproveReview.vue`. Kept as a set of small
  templates so E.E6's generic `ApprovalTableView` can reuse them through
  slot injection.
-->
<template>
  <div>
    <!-- synopsis / comment popover-capable truncated text -->
    <template v-if="kind === 'text-popover'">
      <div
        v-if="text"
        :id="targetId"
        class="text-truncate-multiline small text-popover-trigger"
        :style="`max-width: ${maxWidth}px`"
      >
        {{ text }}
      </div>
      <BPopover
        v-if="text"
        :target="targetId"
        triggers="hover focus"
        placement="top"
        custom-class="wide-popover"
      >
        <template #title>
          <i :class="'bi ' + iconClass + ' me-1'" />
          {{ title }}
        </template>
        <div class="popover-text-content">{{ text }}</div>
      </BPopover>
      <span v-else class="text-muted small">—</span>
    </template>

    <!-- review date badge -->
    <template v-else-if="kind === 'review-date'">
      <div class="d-flex align-items-center gap-1">
        <span
          v-b-tooltip.hover.top
          :title="text || ''"
          class="d-inline-flex align-items-center justify-content-center rounded-circle bg-secondary-subtle text-secondary"
          style="width: 24px; height: 24px; font-size: 0.75rem"
        >
          <i class="bi bi-calendar3" />
        </span>
        <span class="small text-muted">{{ (text || '').substring(0, 10) }}</span>
      </div>
    </template>

    <!-- review-user-name with role badge -->
    <template v-else-if="kind === 'review-user'">
      <div class="d-flex align-items-center gap-1">
        <span
          v-b-tooltip.hover.top
          :title="roleKey"
          class="d-inline-flex align-items-center justify-content-center rounded-circle"
          :class="`bg-${userStyle[roleKey]}-subtle text-${userStyle[roleKey]}`"
          style="width: 24px; height: 24px; font-size: 0.75rem"
        >
          <i :class="'bi bi-' + userIcon[roleKey]" />
        </span>
        <span class="small">{{ text }}</span>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import type { PropType } from 'vue';

defineProps({
  kind: {
    type: String as PropType<'text-popover' | 'review-date' | 'review-user'>,
    required: true,
  },
  text: { type: String as PropType<string | null | undefined>, default: '' },
  title: { type: String, default: '' },
  iconClass: { type: String, default: '' },
  targetId: { type: String, default: '' },
  maxWidth: { type: Number, default: 200 },
  roleKey: { type: String, default: '' },
  userStyle: {
    type: Object as PropType<Record<string, string>>,
    default: () => ({}),
  },
  userIcon: {
    type: Object as PropType<Record<string, string>>,
    default: () => ({}),
  },
});
</script>
