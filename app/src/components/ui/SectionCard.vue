<!-- app/src/components/ui/SectionCard.vue -->
<!--
  Skeleton/empty/error wrapper used by Genes and Entities detail pages (v11.3 W2).
  Spec: §4.3 of 2026-04-26-v11.3-genes-entities-perf-ux-design.md.

  States:
    - loading=true                                 -> skeleton stripes at minHeight
    - loading=false, error!=null                   -> error variant card
    - loading=false, empty=true                    -> renders NOTHING (collapses)
    - loading=false, empty=false, error=null       -> default content slot

  `frameless=true`: skip the BCard wrapper around the resolved slot — used when
  the inner content already provides its own card frame (avoids double-borders).
  Skeleton/error states still render a frame so the slot has a visible shape
  while data is loading.
-->
<template>
  <!-- Loading: skeleton stripes inside a min-height div (frameless) or BCard (framed) -->
  <div
    v-if="loading && frameless"
    data-testid="section-card-skeleton"
    class="section-skeleton"
    :style="{ minHeight }"
  >
    <div class="skeleton-line skeleton-w-60 mb-2" />
    <div class="skeleton-line skeleton-w-90 mb-2" />
    <div class="skeleton-line skeleton-w-80 mb-2" />
    <div class="skeleton-line skeleton-w-70" />
  </div>
  <BCard
    v-else-if="loading"
    data-testid="section-card-skeleton"
    :style="{ minHeight }"
    body-class="p-0"
    header-class="p-1"
    border-variant="dark"
  >
    <template #header>
      <slot name="header">
        <h6 class="m-0 text-muted">
          {{ title }}
        </h6>
      </slot>
    </template>
    <div class="p-3">
      <div class="skeleton-line skeleton-w-60 mb-2" />
      <div class="skeleton-line skeleton-w-90 mb-2" />
      <div class="skeleton-line skeleton-w-80 mb-2" />
      <div class="skeleton-line skeleton-w-70" />
    </div>
  </BCard>
  <!-- Error: small alert-like block (frameless) or full BCard (framed) -->
  <div
    v-else-if="error && frameless"
    data-testid="section-card-error"
    class="section-error"
  >
    <p class="m-0 small text-danger">
      {{ error }}
    </p>
    <slot name="actions" />
  </div>
  <BCard
    v-else-if="error"
    data-testid="section-card-error"
    body-class="p-2"
    header-class="p-1"
    border-variant="danger"
  >
    <template #header>
      <slot name="header">
        <h6 class="m-0 text-danger">
          {{ title }}
        </h6>
      </slot>
    </template>
    <p class="m-0 small text-danger">
      {{ error }}
    </p>
    <slot name="actions" />
  </BCard>
  <!-- Resolved: frameless renders the slot directly; framed wraps in BCard -->
  <template v-else-if="!empty && frameless">
    <slot />
  </template>
  <BCard
    v-else-if="!empty"
    data-testid="section-card-content"
    body-class="p-0"
    header-class="p-1"
    border-variant="dark"
  >
    <template #header>
      <slot name="header">
        <h6 class="m-0">
          {{ title }}
        </h6>
      </slot>
    </template>
    <slot />
  </BCard>
  <!-- empty: render nothing -->
</template>

<script setup lang="ts">
import { BCard } from 'bootstrap-vue-next';

withDefaults(
  defineProps<{
    loading: boolean;
    empty: boolean;
    error: string | null;
    title: string;
    minHeight?: string;
    frameless?: boolean;
  }>(),
  { minHeight: '8rem', frameless: false },
);
</script>

<style scoped>
.skeleton-line {
  height: 0.75rem;
  border-radius: 4px;
  background: linear-gradient(90deg, #eee 25%, #f5f5f5 37%, #eee 63%);
  background-size: 400% 100%;
  animation: shimmer 1.4s ease infinite;
}
.skeleton-w-60 { width: 60%; }
.skeleton-w-70 { width: 70%; }
.skeleton-w-80 { width: 80%; }
.skeleton-w-90 { width: 90%; }
@keyframes shimmer {
  0% { background-position: 100% 50%; }
  100% { background-position: 0 50%; }
}
@media (prefers-reduced-motion: reduce) {
  .skeleton-line { animation: none; }
}
</style>
