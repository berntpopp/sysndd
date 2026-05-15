<template>
  <section
    class="admin-operation-panel"
    :class="toneClass"
    data-testid="admin-operation-panel"
  >
    <header class="admin-operation-panel__header">
      <div class="admin-operation-panel__heading">
        <div class="admin-operation-panel__title-line">
          <component :is="headingTag" class="admin-operation-panel__title">
            <i v-if="icon" :class="['bi', icon, 'admin-operation-panel__icon']" aria-hidden="true" />
            {{ title }}
          </component>
          <span
            v-for="item in normalizedMeta"
            :key="item"
            class="admin-operation-panel__meta"
          >
            {{ item }}
          </span>
        </div>
        <p v-if="description" class="admin-operation-panel__description">
          {{ description }}
        </p>
      </div>
      <div v-if="$slots.actions" class="admin-operation-panel__actions">
        <slot name="actions" />
      </div>
    </header>

    <div class="admin-operation-panel__body">
      <slot />
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    title: string;
    description?: string;
    meta?: string | string[] | null;
    icon?: string;
    headingTag?: 'h2' | 'h3' | 'h4';
    tone?: 'default' | 'danger' | 'success' | 'warning';
  }>(),
  {
    description: undefined,
    meta: null,
    icon: undefined,
    headingTag: 'h2',
    tone: 'default',
  }
);

const normalizedMeta = computed(() => {
  if (!props.meta) return [];
  return Array.isArray(props.meta) ? props.meta.filter(Boolean) : [props.meta];
});

const toneClass = computed(() =>
  props.tone === 'default' ? undefined : `admin-operation-panel--${props.tone}`
);
</script>

<style scoped>
.admin-operation-panel {
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: var(--radius-lg, 0.5rem);
  background: #fff;
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.06);
  text-align: left;
}

.admin-operation-panel + .admin-operation-panel {
  margin-top: 1rem;
}

.admin-operation-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.admin-operation-panel__heading {
  min-width: 0;
}

.admin-operation-panel__title-line {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.admin-operation-panel__title {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.35;
}

.admin-operation-panel__icon {
  color: var(--medical-blue-700, #0d47a1);
  font-size: 0.95rem;
}

.admin-operation-panel__meta {
  display: inline-flex;
  align-items: center;
  min-height: 1.5rem;
  padding: 0.125rem 0.5rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: var(--radius-full, 9999px);
  background: #f8fafc;
  color: #475569;
  font-size: 0.75rem;
  font-weight: 600;
  line-height: 1.2;
  white-space: nowrap;
}

.admin-operation-panel__description {
  margin: 0.25rem 0 0;
  color: #64748b;
  font-size: 0.875rem;
  line-height: 1.45;
}

.admin-operation-panel__actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.5rem;
}

.admin-operation-panel__body {
  padding: 1rem 1.25rem 1.25rem;
  text-align: left;
}

.admin-operation-panel--danger {
  border-color: rgba(198, 40, 40, 0.28);
}

.admin-operation-panel--danger .admin-operation-panel__icon,
.admin-operation-panel--danger .admin-operation-panel__title {
  color: var(--status-danger, #c62828);
}

.admin-operation-panel--success {
  border-color: rgba(46, 125, 50, 0.28);
}

.admin-operation-panel--success .admin-operation-panel__icon {
  color: var(--status-success, #2e7d32);
}

.admin-operation-panel--warning {
  border-color: rgba(245, 124, 0, 0.32);
}

.admin-operation-panel--warning .admin-operation-panel__icon {
  color: var(--status-warning, #f57c00);
}

@media (max-width: 767.98px) {
  .admin-operation-panel__header {
    flex-direction: column;
    align-items: stretch;
    gap: 0.75rem;
    padding: 0.875rem 1rem;
  }

  .admin-operation-panel__actions {
    justify-content: flex-start;
  }

  .admin-operation-panel__body {
    padding: 0.875rem 1rem 1rem;
  }
}
</style>
