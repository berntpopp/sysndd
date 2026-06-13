<template>
  <section class="analysis-panel">
    <header v-if="title || description || $slots.actions" class="analysis-panel__header">
      <div class="analysis-panel__title-group">
        <h2 v-if="title" class="analysis-panel__title">{{ title }}</h2>
        <p v-if="description" class="analysis-panel__description">{{ description }}</p>
      </div>
      <div v-if="$slots.actions" class="analysis-panel__actions">
        <slot name="actions" />
      </div>
    </header>

    <div class="analysis-panel__body">
      <slot />
    </div>
  </section>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    title?: string;
    description?: string;
  }>(),
  {
    title: '',
    description: '',
  }
);
</script>

<style scoped>
.analysis-panel {
  overflow: visible;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
}

.analysis-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.75rem 0.85rem;
  border-bottom: 1px solid #e6ebf2;
  text-align: left;
}

.analysis-panel__title-group {
  min-width: 0;
}

.analysis-panel__title {
  margin: 0;
  color: #172033;
  font-size: 0.95rem;
  font-weight: 750;
  line-height: 1.25;
}

.analysis-panel__description {
  margin: 0.2rem 0 0;
  color: #526070;
  font-size: 0.82rem;
  line-height: 1.35;
}

.analysis-panel__actions {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 0.35rem;
}

.analysis-panel__body {
  padding: 0.75rem;
}

@media (max-width: 575.98px) {
  .analysis-panel__header {
    flex-direction: column;
    gap: 0.5rem;
    padding: 0.7rem;
  }

  .analysis-panel__actions {
    width: 100%;
    justify-content: flex-start;
  }

  .analysis-panel__body {
    padding: 0.65rem;
  }
}
</style>
