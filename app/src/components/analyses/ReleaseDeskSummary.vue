<template>
  <section class="release-desk-summary" aria-labelledby="release-desk-summary-title">
    <header class="release-desk-summary__header">
      <div>
        <p class="release-desk-summary__eyebrow">{{ isLatest ? 'Current release' : 'Selected release' }}</p>
        <h2 id="release-desk-summary-title">
          {{ isLatest ? 'Latest published release' : 'Selected published release' }}
        </h2>
        <p class="release-desk-summary__release-id">{{ release.release_id }}</p>
      </div>
      <span class="release-desk-summary__status">Published</span>
    </header>

    <dl class="release-desk-summary__facts">
      <div>
        <dt>Published</dt>
        <dd>{{ release.published_at || release.created_at }}</dd>
      </div>
      <div>
        <dt>Contents</dt>
        <dd>{{ release.file_count }} {{ release.file_count === 1 ? 'file' : 'files' }}</dd>
      </div>
      <div>
        <dt>Download size</dt>
        <dd>{{ formatReleaseBytes(release.total_bytes) }}</dd>
      </div>
      <div>
        <dt>Licence</dt>
        <dd>{{ release.license }}</dd>
      </div>
    </dl>

    <div class="release-desk-summary__actions" aria-label="Release downloads">
      <BButton
        variant="primary"
        class="release-desk-summary__action"
        data-testid="download-bundle-button"
        @click="$emit('download-bundle')"
      >
        <i class="bi bi-download" aria-hidden="true" />
        Download complete bundle
      </BButton>
      <BButton
        variant="outline-secondary"
        class="release-desk-summary__action"
        data-testid="download-manifest-button"
        @click="$emit('download-manifest')"
      >
        <i class="bi bi-file-earmark-code" aria-hidden="true" />
        Download manifest
      </BButton>
    </div>

    <section v-if="release.manifest.files.length" class="release-desk-summary__files" aria-label="Individual release files">
      <h3>Need one file?</h3>
      <ul>
        <li v-for="file in release.manifest.files" :key="file.path">
          <button
            type="button"
            class="release-desk-summary__file-link"
            :data-testid="`download-file-${fileTestId(file.path)}`"
            @click="$emit('download-file', file.path)"
          >
            {{ file.path }}
          </button>
          <span>{{ formatReleaseBytes(file.bytes) }}</span>
        </li>
      </ul>
    </section>
  </section>
</template>

<script setup lang="ts">
import { BButton } from 'bootstrap-vue-next';
import type { ReleaseDetail } from '@/api/analysis';
import { formatReleaseBytes } from './dataReleaseTable';

defineOptions({ name: 'ReleaseDeskSummary' });

withDefaults(
  defineProps<{
    release: ReleaseDetail;
    isLatest?: boolean;
  }>(),
  { isLatest: true }
);

defineEmits<{
  'download-bundle': [];
  'download-manifest': [];
  'download-file': [path: string];
}>();

function fileTestId(path: string): string {
  return path.replaceAll(/[/.]+/g, '-').replace(/^-|-$/g, '');
}
</script>

<style scoped>
.release-desk-summary {
  display: grid;
  gap: 1rem;
  padding: 1rem;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: var(--surface-raised);
}

.release-desk-summary__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.release-desk-summary__eyebrow {
  margin: 0 0 0.15rem;
  color: var(--text-muted);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.release-desk-summary h2 {
  margin: 0;
  color: var(--text-primary);
  font-size: 1.0625rem;
  font-weight: 700;
}

.release-desk-summary__release-id {
  margin: 0.3rem 0 0;
  color: var(--text-secondary);
  font-family: var(--font-family-mono);
  font-size: 0.8125rem;
  overflow-wrap: anywhere;
}

.release-desk-summary__status {
  flex: 0 0 auto;
  padding: 0.2rem 0.45rem;
  border-radius: var(--radius-sm);
  background: var(--status-success-bg);
  color: var(--status-success);
  font-size: 0.75rem;
  font-weight: 700;
}

.release-desk-summary__facts {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.5rem;
  margin: 0;
  padding: 0.75rem 0;
  border-block: 1px solid var(--border-subtle);
}

.release-desk-summary__facts div { min-width: 0; }

.release-desk-summary__facts dt {
  color: var(--text-muted);
  font-size: 0.75rem;
  font-weight: 700;
}

.release-desk-summary__facts dd {
  margin: 0.15rem 0 0;
  color: var(--text-primary);
  font-size: 0.875rem;
  overflow-wrap: anywhere;
}

.release-desk-summary__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.release-desk-summary__action {
  min-height: 2.75rem;
}

.release-desk-summary__files h3 {
  margin: 0 0 0.35rem;
  color: var(--text-secondary);
  font-size: 0.8125rem;
  font-weight: 700;
}

.release-desk-summary__files ul {
  display: grid;
  gap: 0.35rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.release-desk-summary__files li {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  color: var(--text-muted);
  font-size: 0.8125rem;
}

.release-desk-summary__file-link {
  min-height: 2.75rem;
  padding: 0.25rem 0;
  border: 0;
  background: transparent;
  color: var(--medical-blue-700);
  font-family: var(--font-family-mono);
  text-align: left;
  text-decoration: underline;
  overflow-wrap: anywhere;
}

.release-desk-summary__file-link:focus-visible {
  outline: var(--focus-ring-width) solid var(--focus-ring-color);
  outline-offset: var(--focus-ring-offset);
}

@media (max-width: 767.98px) {
  .release-desk-summary__facts { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}

@media (max-width: 575.98px) {
  .release-desk-summary__actions > * { width: 100%; }
  .release-desk-summary__files li { align-items: flex-start; }
}
</style>
