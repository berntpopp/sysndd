<template>
  <section class="release-archive-list" aria-labelledby="release-archive-list-title">
    <div class="release-archive-list__heading">
      <h2 id="release-archive-list-title">Choose a published release</h2>
      <span class="release-archive-list__count">{{ releases.length }} available</span>
    </div>

    <ul class="release-archive-list__items">
      <li v-for="release in releases" :key="release.release_id">
        <button
          type="button"
          class="release-archive-list__item"
          :class="{
            'release-archive-list__item--selected': release.release_id === selectedReleaseId,
          }"
          :aria-current="release.release_id === selectedReleaseId ? 'true' : undefined"
          @click="$emit('select', release.release_id)"
        >
          <span class="release-archive-list__item-main">
            <span class="release-archive-list__release-id">{{ release.release_id }}</span>
            <span class="release-archive-list__date" :title="release.published_at"
              >Published {{ formatLongDate(release.published_at) }}</span
            >
          </span>
          <span class="release-archive-list__facts">
            {{ release.file_count }} {{ release.file_count === 1 ? 'file' : 'files' }}
            <span aria-hidden="true">·</span>
            {{ release.total_bytes_display }}
          </span>
        </button>
      </li>
    </ul>
  </section>
</template>

<script setup lang="ts">
import type { ReleaseTableRow } from './dataReleaseTable';
import { formatLongDate } from '@/utils/dateUtils';

defineOptions({ name: 'ReleaseArchiveList' });

defineProps<{
  releases: ReleaseTableRow[];
  selectedReleaseId?: string;
}>();

defineEmits<{
  select: [releaseId: string];
}>();
</script>

<style scoped>
.release-archive-list {
  min-width: 0;
}

.release-archive-list__heading {
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.5rem;
}

.release-archive-list h2 {
  margin: 0;
  color: var(--text-primary);
  font-size: 1rem;
  font-weight: 700;
}

.release-archive-list__count {
  color: var(--text-muted);
  font-size: 0.8125rem;
  white-space: nowrap;
}

.release-archive-list__items {
  display: grid;
  gap: 0.5rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.release-archive-list__item {
  display: flex;
  width: 100%;
  min-height: 3.5rem;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  color: var(--text-primary);
  text-align: left;
}

.release-archive-list__item:hover {
  border-color: var(--medical-blue-500);
  background: var(--surface-subtle);
}

.release-archive-list__item:focus-visible {
  outline: var(--focus-ring-width) solid var(--focus-ring-color);
  outline-offset: var(--focus-ring-offset);
}

.release-archive-list__item--selected {
  border-color: var(--medical-blue-600);
  box-shadow: inset 3px 0 0 var(--medical-blue-600);
}

.release-archive-list__item-main {
  display: grid;
  min-width: 0;
  gap: 0.15rem;
}

.release-archive-list__release-id {
  overflow-wrap: anywhere;
  font-family: var(--font-family-mono);
  font-size: 0.8125rem;
  font-weight: 700;
}

.release-archive-list__date,
.release-archive-list__facts {
  color: var(--text-muted);
  font-size: 0.8125rem;
}

.release-archive-list__facts {
  flex: 0 0 auto;
  white-space: nowrap;
}

@media (max-width: 575.98px) {
  .release-archive-list__item {
    align-items: flex-start;
    flex-direction: column;
    gap: 0.25rem;
  }
}
</style>
