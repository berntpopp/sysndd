<template>
  <section class="table-shell" :aria-busy="loading ? 'true' : 'false'">
    <header class="table-shell__header">
      <div class="table-shell__heading">
        <div class="table-shell__title-line">
          <component :is="`h${headingLevel}`" class="table-shell__title">{{ title }}</component>
          <slot name="title-actions" />
          <span v-if="meta" class="table-shell__meta">{{ meta }}</span>
        </div>
        <p v-if="description" class="table-shell__description">{{ description }}</p>
      </div>
      <div v-if="$slots.actions" class="table-shell__actions">
        <slot name="actions" />
      </div>
    </header>

    <div v-if="$slots.toolbar" class="table-shell__toolbar">
      <slot name="toolbar" />
    </div>

    <div class="table-shell__body">
      <slot v-if="loading" name="loading">
        <TableLoadingState />
      </slot>
      <slot v-else />
    </div>
  </section>
</template>

<script setup lang="ts">
import TableLoadingState from './TableLoadingState.vue';

withDefaults(
  defineProps<{
    title: string;
    description?: string;
    meta?: string;
    loading?: boolean;
    headingLevel?: 1 | 2 | 3;
  }>(),
  {
    // Default to h2: most TableShell usages are nested under a page/shell that
    // already owns the route <h1> (AnalysisShell, AuthenticatedPageShell, detail
    // pages). Standalone public table VIEWS opt into h1 via :heading-level="1".
    headingLevel: 2,
  }
);
</script>

<style scoped>
.table-shell {
  overflow: hidden;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: #fff;
  box-shadow: var(--shadow-sm);
}

.table-shell__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem 1.25rem;
}

.table-shell__heading {
  min-width: 0;
}

.table-shell__title-line {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.table-shell__title {
  margin: 0;
  color: var(--neutral-900);
  font-size: var(--font-size-lg);
  font-weight: var(--font-weight-semibold);
  line-height: 1.35;
}

.table-shell__meta {
  display: inline-flex;
  align-items: center;
  min-height: 1.5rem;
  padding: 0.125rem 0.5rem;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-full);
  background: var(--neutral-100);
  /* --neutral-700 (5.74:1 on neutral-100) — neutral-600 fails AA on the tinted pill */
  color: var(--neutral-700);
  font-size: 0.75rem;
  font-weight: var(--font-weight-semibold);
  line-height: 1.2;
  white-space: nowrap;
}

.table-shell__description {
  margin: 0.25rem 0 0;
  color: var(--neutral-600);
  font-size: 0.875rem;
  line-height: 1.45;
}

.table-shell__actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.5rem;
}

.table-shell__toolbar {
  padding: 0.75rem 1.25rem;
  border-top: 1px solid var(--border-subtle);
  background: var(--neutral-50);
}

.table-shell__body {
  padding: 1rem 1.25rem 1.25rem;
  border-top: 1px solid var(--border-subtle);
}

.table-shell__toolbar + .table-shell__body {
  border-top: 0;
}

@media (max-width: 767.98px) {
  .table-shell__header {
    flex-direction: column;
    align-items: stretch;
    gap: 0.75rem;
    padding: 0.875rem 1rem;
  }

  .table-shell__actions {
    justify-content: flex-start;
  }

  .table-shell__toolbar,
  .table-shell__body {
    padding-right: 1rem;
    padding-left: 1rem;
  }
}
</style>
