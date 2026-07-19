<!-- src/components/analyses/ReleaseManifestPanel.vue -->
<!--
  Provenance card for one analysis-snapshot release (#573 Slice B, Task B2):
  identity, integrity hashes (copy-to-clipboard), per-layer manifest detail,
  the correlation layer's dependency lineage, and Zenodo DOI links.

  Styled to mirror `nddscore/NddScoreModelCard.vue` (dl-grid provenance
  layout, `displayValue`/`doiUrl` local helpers, mono hash styling). The
  clipboard "Copy"/"Copied" idiom mirrors `small/GenericTableDetails.vue`
  (transient state + a reset timer, guarded for jsdom/no-Clipboard-API envs).
-->
<template>
  <section class="release-manifest-panel" aria-labelledby="release-manifest-panel-title">
    <header class="release-manifest-panel__header">
      <div>
        <h2 id="release-manifest-panel-title" class="release-manifest-panel__title">
          {{ displayTitle }}
        </h2>
        <p class="release-manifest-panel__subtitle">
          Immutable, content-addressed export. Verify a download against the hashes below.
        </p>
      </div>
      <BBadge variant="info" class="release-manifest-panel__badge">
        {{ release.release_id }}
      </BBadge>
    </header>

    <section aria-label="Identity">
      <h3 class="release-manifest-panel__section-title">Identity</h3>
      <dl class="release-manifest-panel__grid">
        <div>
          <dt>Release ID</dt>
          <dd class="release-manifest-panel__mono">{{ release.release_id }}</dd>
        </div>
        <div v-if="release.release_version">
          <dt>Version</dt>
          <dd>{{ release.release_version }}</dd>
        </div>
        <div>
          <dt>Title</dt>
          <dd>{{ displayTitle }}</dd>
        </div>
        <div>
          <dt>Status</dt>
          <dd>{{ release.status }}</dd>
        </div>
        <div>
          <dt>Source data version</dt>
          <dd>{{ release.source_data_version }}</dd>
        </div>
        <div>
          <dt>DB release version</dt>
          <dd>{{ displayValue(release.db_release_version) }}</dd>
        </div>
        <div>
          <dt>DB release commit</dt>
          <dd class="release-manifest-panel__mono">
            {{ displayValue(release.db_release_commit) }}
          </dd>
        </div>
        <div>
          <dt>Created</dt>
          <dd>{{ release.created_at }}</dd>
        </div>
        <div>
          <dt>Published</dt>
          <dd>{{ displayValue(release.published_at) }}</dd>
        </div>
      </dl>
    </section>

    <section aria-label="Integrity hashes">
      <h3 class="release-manifest-panel__section-title">Integrity hashes</h3>
      <dl class="release-manifest-panel__grid release-manifest-panel__grid--hashes">
        <div v-for="hash in integrityHashes" :key="hash.key">
          <dt>{{ hash.label }}</dt>
          <dd class="release-manifest-panel__hash-value">
            <span class="release-manifest-panel__mono">{{ hash.value }}</span>
            <button
              type="button"
              class="release-manifest-panel__copy-button"
              :aria-label="`Copy ${hash.label} to clipboard`"
              @click="copyValue(hash.key, hash.value)"
            >
              <i class="bi bi-clipboard" aria-hidden="true" />
              {{ copiedKey === hash.key ? 'Copied' : 'Copy' }}
            </button>
          </dd>
        </div>
      </dl>
    </section>

    <section aria-label="Layers">
      <h3 class="release-manifest-panel__section-title">Layers</h3>
      <div
        v-for="layer in release.manifest.layers"
        :key="layer.analysis_type"
        class="release-manifest-panel__layer"
      >
        <h4 class="release-manifest-panel__layer-title">{{ layer.analysis_type }}</h4>
        <dl class="release-manifest-panel__grid">
          <div>
            <dt>Snapshot ID</dt>
            <dd>{{ layer.snapshot_id }}</dd>
          </div>
          <div>
            <dt>Payload hash</dt>
            <dd class="release-manifest-panel__mono">{{ displayValue(layer.payload_hash) }}</dd>
          </div>
          <div>
            <dt>Input hash</dt>
            <dd class="release-manifest-panel__mono">{{ displayValue(layer.input_hash) }}</dd>
          </div>
          <div>
            <dt>Reproducibility hash</dt>
            <dd class="release-manifest-panel__mono">
              <span v-if="layer.reproducibility_hash">{{ layer.reproducibility_hash }}</span>
              <span v-else class="text-muted">n/a (not reproducible)</span>
            </dd>
          </div>
        </dl>
      </div>
    </section>

    <section v-if="dependencyLayer" aria-label="Dependency lineage">
      <h3 class="release-manifest-panel__section-title">Dependency lineage</h3>
      <p class="release-manifest-panel__hint">
        {{ dependencyLayer.analysis_type }} is derived from these pinned source-layer snapshots.
      </p>
      <dl class="release-manifest-panel__grid">
        <div v-if="dependencyLayer.dependencies?.functional_clusters">
          <dt>Functional clusters</dt>
          <dd>
            snapshot {{ dependencyLayer.dependencies.functional_clusters.snapshot_id }}
            &middot;
            <span class="release-manifest-panel__mono">{{
              dependencyLayer.dependencies.functional_clusters.payload_hash
            }}</span>
          </dd>
        </div>
        <div v-if="dependencyLayer.dependencies?.phenotype_clusters">
          <dt>Phenotype clusters</dt>
          <dd>
            snapshot {{ dependencyLayer.dependencies.phenotype_clusters.snapshot_id }}
            &middot;
            <span class="release-manifest-panel__mono">{{
              dependencyLayer.dependencies.phenotype_clusters.payload_hash
            }}</span>
          </dd>
        </div>
      </dl>
    </section>

    <section aria-label="DOI">
      <h3 class="release-manifest-panel__section-title">DOI</h3>
      <dl class="release-manifest-panel__grid">
        <div>
          <dt>Version DOI</dt>
          <dd>
            <a
              v-if="release.zenodo.version_doi"
              :href="doiUrl(release.zenodo.version_doi)"
              target="_blank"
              rel="noopener noreferrer"
            >
              {{ release.zenodo.version_doi }}
            </a>
            <span v-else class="text-muted">not yet assigned</span>
          </dd>
        </div>
        <div>
          <dt>Concept DOI</dt>
          <dd>
            <a
              v-if="release.zenodo.concept_doi"
              :href="doiUrl(release.zenodo.concept_doi)"
              target="_blank"
              rel="noopener noreferrer"
            >
              {{ release.zenodo.concept_doi }}
            </a>
            <span v-else class="text-muted">not yet assigned</span>
          </dd>
        </div>
        <div>
          <dt>Zenodo record</dt>
          <dd>
            <a
              v-if="release.zenodo.record_url"
              :href="release.zenodo.record_url"
              target="_blank"
              rel="noopener noreferrer"
            >
              Record
            </a>
            <span v-else class="text-muted">not yet assigned</span>
          </dd>
        </div>
      </dl>
    </section>
  </section>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue';
import { BBadge } from 'bootstrap-vue-next';
import type { ReleaseDetail, ReleaseManifestLayer } from '@/api/analysis';

defineOptions({
  name: 'ReleaseManifestPanel',
});

const props = defineProps<{
  release: ReleaseDetail;
}>();

function displayValue(value: string | number | null | undefined): string {
  return value === null || value === undefined || value === '' ? '—' : String(value);
}

/** `title`, falling back to `release_id` when the reserved `title` column is null. */
const displayTitle = computed(() => props.release.title || props.release.release_id);

function doiUrl(doi: string): string {
  return `https://doi.org/${doi}`;
}

const integrityHashes = computed(() => [
  { key: 'content_digest', label: 'Content digest', value: props.release.content_digest },
  { key: 'manifest_sha256', label: 'Manifest SHA-256', value: props.release.manifest_sha256 },
  { key: 'bundle_sha256', label: 'Bundle SHA-256', value: props.release.bundle_sha256 },
]);

/** The one manifest layer with pinned source-layer dependencies (the correlation layer), if any. */
const dependencyLayer = computed<ReleaseManifestLayer | null>(
  () => props.release.manifest.layers.find((layer) => layer.dependencies != null) ?? null
);

// --- Copy-to-clipboard: mirrors small/GenericTableDetails.vue's transient
// "Copy" -> "Copied" state + reset-timer lifecycle. ---
const copiedKey = ref<string | null>(null);
let copyResetTimer: ReturnType<typeof setTimeout> | null = null;

async function copyValue(key: string, value: string): Promise<void> {
  if (!value || !navigator.clipboard?.writeText) {
    return;
  }
  try {
    await navigator.clipboard.writeText(value);
    copiedKey.value = key;
    if (copyResetTimer) {
      clearTimeout(copyResetTimer);
    }
    copyResetTimer = setTimeout(() => {
      copiedKey.value = null;
      copyResetTimer = null;
    }, 1600);
  } catch {
    copiedKey.value = null;
  }
}

onBeforeUnmount(() => {
  if (copyResetTimer) {
    clearTimeout(copyResetTimer);
    copyResetTimer = null;
  }
});
</script>

<style scoped>
.release-manifest-panel {
  display: grid;
  gap: 1rem;
  padding: 1rem;
  border: 1px solid #d7dee8;
  border-radius: var(--radius-lg, 8px);
  background: #fff;
  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
}

.release-manifest-panel__header {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.release-manifest-panel__title {
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.release-manifest-panel__subtitle {
  margin: 0.15rem 0 0;
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
  line-height: 1.45;
}

.release-manifest-panel__badge {
  max-width: 100%;
  overflow-wrap: anywhere;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}

.release-manifest-panel__section-title {
  margin: 0 0 0.4rem;
  color: var(--neutral-700, #616161);
  font-size: 0.8125rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.release-manifest-panel__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 0.5rem 0.75rem;
  margin: 0;
}

.release-manifest-panel__grid div {
  min-width: 0;
}

.release-manifest-panel__grid dt {
  margin: 0;
  color: var(--neutral-700, #616161);
  font-size: 0.75rem;
  font-weight: 700;
}

.release-manifest-panel__grid dd {
  margin: 0.1rem 0 0;
  color: var(--neutral-900, #212121);
  font-size: 0.8125rem;
  overflow-wrap: anywhere;
}

.release-manifest-panel__grid a {
  color: var(--medical-blue-700, #0d47a1);
}

.release-manifest-panel__mono {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}

.release-manifest-panel__grid--hashes dd.release-manifest-panel__hash-value {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.release-manifest-panel__grid--hashes .release-manifest-panel__mono {
  word-break: break-all;
}

.release-manifest-panel__copy-button {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 0.25rem;
  padding: 0.08rem 0.4rem;
  border: 1px solid #0a58ca;
  border-radius: var(--radius-md, 6px);
  background: #fff;
  color: #0a58ca;
  font-size: 0.72rem;
  line-height: 1.6;
  white-space: nowrap;
}

.release-manifest-panel__copy-button:hover,
.release-manifest-panel__copy-button:focus {
  border-color: #084298;
  background-color: #0a58ca;
  color: #fff;
}

.release-manifest-panel__layer {
  padding: 0.5rem 0.65rem;
  border: 1px solid #e1e7ef;
  border-radius: var(--radius-md, 6px);
  background: #f8fafc;
}

.release-manifest-panel__layer + .release-manifest-panel__layer {
  margin-top: 0.5rem;
}

.release-manifest-panel__layer-title {
  margin: 0 0 0.35rem;
  color: var(--neutral-900, #212121);
  font-size: 0.875rem;
  font-weight: 700;
}

.release-manifest-panel__hint {
  margin: 0 0 0.5rem;
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
}
</style>
