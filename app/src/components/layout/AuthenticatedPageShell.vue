<template>
  <div class="authenticated-page">
    <section class="authenticated-frame">
      <header class="authenticated-header">
        <div class="authenticated-heading">
          <div class="authenticated-title-line">
            <h1 class="authenticated-title">{{ title }}</h1>
            <span v-if="meta" class="authenticated-meta">{{ meta }}</span>
          </div>
          <p v-if="description" class="authenticated-description">{{ description }}</p>
        </div>

        <div v-if="$slots.actions" class="authenticated-actions">
          <slot name="actions" />
        </div>
      </header>

      <main class="authenticated-content" :class="contentClass">
        <slot />
      </main>
    </section>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    title: string;
    description?: string;
    meta?: string;
    contentClass?: string;
  }>(),
  {
    description: '',
    meta: '',
    contentClass: '',
  }
);
</script>

<style scoped>
.authenticated-page {
  box-sizing: border-box;
  min-height: 100%;
  padding: 0.75rem 1rem 1.5rem;
  background: #f6f8fb;
}

.authenticated-frame {
  width: min(100%, 1480px);
  margin: 0 auto;
  overflow: hidden;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
}

.authenticated-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem 1rem 0.7rem;
  border-bottom: 1px solid #e6ebf2;
}

.authenticated-heading {
  min-width: 0;
  text-align: left;
}

.authenticated-title-line {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.authenticated-title {
  margin: 0;
  color: #172033;
  font-size: 1.05rem;
  font-weight: 700;
  line-height: 1.2;
}

.authenticated-description {
  max-width: 58rem;
  margin: 0.25rem 0 0;
  color: #526070;
  font-size: 0.875rem;
  line-height: 1.35;
}

.authenticated-meta {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  min-height: 1.55rem;
  padding: 0.2rem 0.55rem;
  border: 1px solid #bdc7d4;
  border-radius: 999px;
  background: #eef2f7;
  color: #223044;
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

.authenticated-actions {
  display: inline-flex;
  flex: 0 0 auto;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: 0.45rem;
}

.authenticated-content {
  padding: 1rem;
}

@media (max-width: 575.98px) {
  .authenticated-page {
    padding: 0.5rem 0.75rem 1rem;
  }

  .authenticated-header {
    flex-direction: column;
    align-items: stretch;
    gap: 0.55rem;
    padding: 0.75rem;
  }

  .authenticated-actions {
    justify-content: flex-start;
  }

  .authenticated-description {
    font-size: 0.8125rem;
  }

  .authenticated-content {
    padding: 0.75rem;
  }
}
</style>
