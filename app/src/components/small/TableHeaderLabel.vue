<!-- TableHeaderLabel.vue -->
<template>
  <div>
    <h4 class="mb-1 text-start font-weight-bold">
      {{ label }}
      <BBadge v-b-tooltip.hover.bottom variant="primary" :title="toolTipTitle">
        {{ subtitle }}
      </BBadge>
    </h4>
  </div>
</template>

<script>
export default {
  name: 'TableHeaderLabel',
  props: {
    label: {
      type: String,
      required: true,
    },
    subtitle: {
      type: String,
      default: '',
    },
    toolTipTitle: {
      type: String,
      default: '',
    },
  },
};
</script>
