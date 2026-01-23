<template>
  <div
    class="skeleton-shimmer"
    :style="{
      width: width,
      height: height,
      borderRadius: rounded ? 'var(--radius-sm)' : '0'
    }"
    aria-label="Loading content"
    role="status"
  />
</template>

<script lang="ts">
import { defineComponent } from 'vue';

export default defineComponent({
  name: 'LoadingSkeleton',
  props: {
    width: {
      type: String,
      default: '100%'
    },
    height: {
      type: String,
      default: '1rem'
    },
    rounded: {
      type: Boolean,
      default: true
    }
  }
});
</script>
