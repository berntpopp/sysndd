<template>
  <div class="analysis-page">
    <div class="analysis-frame">
      <header class="analysis-header">
        <div class="analysis-title-group">
          <h1 class="analysis-title">{{ title }}</h1>
          <p v-if="subtitle" class="analysis-subtitle">{{ subtitle }}</p>
        </div>

        <slot name="meta">
          <span v-if="meta" class="analysis-meta-badge">{{ meta }}</span>
        </slot>
      </header>

      <nav v-if="tabs.length" class="analysis-tabs" :aria-label="navLabel">
        <RouterLink
          v-for="tab in tabs"
          :key="tab.label"
          :to="tab.to"
          class="analysis-tab"
          exact-active-class="active"
        >
          {{ tab.label }}
          <span v-if="tab.badge" class="analysis-tab__badge">{{ tab.badge }}</span>
        </RouterLink>
      </nav>

      <main class="analysis-content">
        <slot />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router';

interface AnalysisShellTab {
  label: string;
  to: RouteLocationRaw;
  badge?: string | number | null;
}

withDefaults(
  defineProps<{
    title: string;
    subtitle?: string;
    meta?: string;
    navLabel?: string;
    tabs?: AnalysisShellTab[];
  }>(),
  {
    subtitle: '',
    meta: '',
    navLabel: 'Analysis views',
    tabs: () => [],
  }
);
</script>

<style scoped>
.analysis-page {
  box-sizing: border-box;
  min-height: 100%;
  padding: 0.75rem 1rem 1.5rem;
  background: #f6f8fb;
}

.analysis-frame {
  width: min(100%, 1480px);
  margin: 0 auto;
  overflow: hidden;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: #fff;
  box-shadow: var(--shadow-sm);
}

.analysis-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem 1rem 0.7rem;
  border-bottom: 1px solid var(--border-subtle);
}

.analysis-title-group {
  min-width: 0;
  text-align: left;
}

.analysis-title {
  margin: 0;
  color: var(--neutral-900);
  font-size: var(--font-size-lg);
  font-weight: var(--font-weight-semibold);
  line-height: 1.2;
}

.analysis-subtitle {
  max-width: 58rem;
  margin: 0.25rem 0 0;
  color: var(--neutral-600);
  font-size: 0.875rem;
  line-height: 1.35;
}

.analysis-meta-badge,
.analysis-tab__badge {
  display: inline-flex;
  align-items: center;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-full);
  background: var(--neutral-100);
  color: var(--neutral-700);
  font-weight: var(--font-weight-bold);
  white-space: nowrap;
}

.analysis-meta-badge {
  flex: 0 0 auto;
  min-height: 1.55rem;
  padding: 0.2rem 0.55rem;
  font-size: 0.75rem;
}

.analysis-tabs {
  display: flex;
  gap: 0.25rem;
  padding: 0 1rem;
  overflow-x: auto;
  border-bottom: 1px solid var(--border-subtle);
  background: var(--neutral-50);
}

.analysis-tab {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 2.45rem;
  padding: 0 0.75rem;
  border-bottom: 2px solid transparent;
  color: var(--medical-blue-700);
  font-size: 0.92rem;
  font-weight: var(--font-weight-bold);
  text-decoration: none;
  white-space: nowrap;
}

.analysis-tab:hover,
.analysis-tab:focus {
  color: var(--medical-blue-800);
  background: var(--medical-blue-50);
}

.analysis-tab.active {
  border-bottom-color: var(--medical-blue-700);
  color: var(--neutral-900);
  background: #fff;
}

.analysis-tab__badge {
  min-height: 1.15rem;
  padding: 0.05rem 0.35rem;
  font-size: 0.68rem;
}

.analysis-content {
  padding: 1rem;
}

@media (max-width: 575.98px) {
  .analysis-page {
    padding: 0.5rem 0.75rem 1rem;
  }

  .analysis-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.45rem;
    padding: 0.75rem;
  }

  .analysis-subtitle {
    font-size: 0.8125rem;
  }

  .analysis-tabs {
    padding: 0 0.4rem;
  }

  .analysis-tab {
    flex: 1 0 auto;
    justify-content: center;
    padding: 0 0.5rem;
  }

  .analysis-content {
    padding: 0.75rem;
  }
}
</style>
