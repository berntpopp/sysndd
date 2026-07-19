<!-- src/views/analyses/DataReleases.vue -->
<!--
  Public, unauthenticated page for analysis-snapshot releases (#573 Slice B,
  Task B2): immutable, content-addressed exports of the derived-analysis
  public snapshots (functional clusters, phenotype clusters, phenotype-
  functional correlation). Composes:
    - AnalysisShell (title/subtitle chrome, matches every other analysis view)
    - a releases table (GenericTable, fields from dataReleaseTable.ts)
    - the selected release's manifest/provenance card (ReleaseManifestPanel)
    - download actions (bundle.tar.gz, manifest.json, per-file) and a
      factual "how to verify" disclosure.

  Data flow: `listReleases()` populates the table; `getLatestRelease()`
  populates the initial manifest panel; selecting a row re-fetches via
  `getRelease(release_id)`. `getLatestRelease()` 404s when no release has
  been published yet — that is NOT an error, it is the "no releases yet"
  empty state (SectionCard's `empty` prop collapses to nothing per its own
  contract, so the empty message is rendered from the default slot instead,
  via the existing `ui/EmptyState.vue`).
-->
<template>
  <AnalysisShell
    title="Analysis-snapshot releases"
    subtitle="Immutable, content-addressed exports of SysNDD's public derived analysis (functional clusters, phenotype clusters, and their correlation) — download and independently verify what you get."
  >
    <SectionCard
      title="Published releases"
      :loading="listLoading"
      :empty="false"
      :error="listError"
    >
      <GenericTable :items="releaseRows" :fields="RELEASE_TABLE_FIELDS">
        <template #cell-actions="{ row }">
          <BButton
            size="sm"
            variant="outline-primary"
            :aria-label="`View manifest for release ${row.release_id}`"
            @click="selectRelease(row.release_id)"
          >
            View manifest
          </BButton>
        </template>
      </GenericTable>
    </SectionCard>

    <SectionCard
      title="Release manifest & verification"
      class="data-releases__manifest-card"
      :loading="detailLoading"
      :empty="false"
      :error="detailError"
    >
      <template v-if="selectedRelease">
        <ReleaseManifestPanel :release="selectedRelease" />

        <section class="data-releases__downloads" aria-label="Downloads">
          <h3 class="data-releases__section-title">Downloads</h3>
          <div class="data-releases__download-buttons">
            <BButton
              size="sm"
              variant="primary"
              data-testid="download-bundle-button"
              @click="handleDownloadBundle"
            >
              <i class="bi bi-file-earmark-zip" aria-hidden="true" />
              Download bundle.tar.gz
            </BButton>
            <BButton
              size="sm"
              variant="outline-secondary"
              data-testid="download-manifest-button"
              @click="handleDownloadManifest"
            >
              <i class="bi bi-file-earmark-code" aria-hidden="true" />
              Download manifest.json
            </BButton>
          </div>

          <div v-if="selectedRelease.manifest.files.length" class="data-releases__files">
            <h4 class="data-releases__section-subtitle">Individual files</h4>
            <ul class="data-releases__file-list">
              <li v-for="file in selectedRelease.manifest.files" :key="file.path">
                <button
                  type="button"
                  class="data-releases__file-link"
                  @click="handleDownloadFile(file.path)"
                >
                  {{ file.path }}
                </button>
                <span class="data-releases__file-size">({{ formatReleaseBytes(file.bytes) }})</span>
              </li>
            </ul>
          </div>
        </section>

        <details class="data-releases__verify">
          <summary>How to verify a download</summary>
          <ul>
            <li>
              Recompute the SHA-256 of each downloaded file and compare it against
              <code>manifest.files[].sha256</code> (or the top-level <code>checksums.sha256</code>
              file in the bundle).
            </li>
            <li>
              For the functional and phenotype cluster layers,
              <code>sha256(reproducibility.json)</code> matches that layer's
              <code>reproducibility_hash</code> exactly — the phenotype-functional correlation
              layer has no reproducibility bundle (<code>reproducibility_hash</code> is
              <code>null</code>).
            </li>
            <li>
              <code>payload_hash</code>, <code>input_hash</code>, and <code>snapshot_id</code> are
              lineage anchors: cross-check them against the live <code>meta.snapshot</code> block
              on the matching <code>/api/analysis/*</code> endpoint. They are
              <strong>not</strong> a hash of this release's own <code>payload.json</code> — the
              values round-trip through <code>DECIMAL</code> database columns before the release
              freezes them, so a byte-for-byte match of the payload file is neither guaranteed nor
              attempted.
            </li>
          </ul>
        </details>
      </template>
      <EmptyState
        v-else-if="!detailLoading && !detailError"
        icon="archive"
        title="No releases published yet"
        message="Analysis-snapshot releases are published periodically once public snapshots are available. Check back soon."
      />
    </SectionCard>
  </AnalysisShell>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useHead } from '@unhead/vue';
import { BButton } from 'bootstrap-vue-next';
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';
import SectionCard from '@/components/ui/SectionCard.vue';
import EmptyState from '@/components/ui/EmptyState.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import ReleaseManifestPanel from '@/components/analyses/ReleaseManifestPanel.vue';
import {
  normalizeReleaseRows,
  formatReleaseBytes,
  RELEASE_TABLE_FIELDS,
  type ReleaseTableRow,
} from '@/components/analyses/dataReleaseTable';
import {
  listReleases,
  getLatestRelease,
  getRelease,
  downloadReleaseBundle,
  downloadReleaseManifest,
  downloadReleaseFile,
  type ReleaseDetail,
} from '@/api/analysis';
import { isApiError } from '@/api/client';
import { extractApiErrorMessage } from '@/utils/api-errors';
import useToast from '@/composables/useToast';

defineOptions({
  name: 'DataReleases',
});

useHead({
  title: 'Analysis-snapshot releases',
  meta: [
    {
      name: 'description',
      content:
        "Download and independently verify SysNDD's immutable, content-addressed analysis-snapshot releases: functional gene clusters, phenotype clusters, and their correlation.",
    },
  ],
});

const { makeToast } = useToast();

const releaseRows = ref<ReleaseTableRow[]>([]);
const listLoading = ref(true);
const listError = ref<string | null>(null);

const selectedRelease = ref<ReleaseDetail | null>(null);
const detailLoading = ref(true);
const detailError = ref<string | null>(null);

async function loadList(): Promise<void> {
  listLoading.value = true;
  listError.value = null;
  try {
    const response = await listReleases();
    releaseRows.value = normalizeReleaseRows(response.releases);
  } catch (err) {
    listError.value = extractApiErrorMessage(err, 'Failed to load analysis-snapshot releases.');
  } finally {
    listLoading.value = false;
  }
}

/**
 * Loads a release detail (head + manifest) via the given fetcher. A 404 is
 * the "no published release" empty state, not an error — see the file
 * header for why that renders through the default slot rather than
 * SectionCard's `empty` prop.
 */
async function loadDetail(fetcher: () => Promise<ReleaseDetail>): Promise<void> {
  detailLoading.value = true;
  detailError.value = null;
  try {
    selectedRelease.value = await fetcher();
  } catch (err) {
    selectedRelease.value = null;
    if (!(isApiError(err) && err.response?.status === 404)) {
      detailError.value = extractApiErrorMessage(err, 'Failed to load the release manifest.');
    }
  } finally {
    detailLoading.value = false;
  }
}

function selectRelease(releaseId: string): void {
  void loadDetail(() => getRelease(releaseId));
}

/** Triggers a browser download for a Blob via a transient object-URL anchor. */
function triggerBlobDownload(blob: Blob, filename: string): void {
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.setAttribute('download', filename);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  window.URL.revokeObjectURL(url);
}

async function handleDownloadBundle(): Promise<void> {
  const release = selectedRelease.value;
  if (!release) return;
  try {
    const blob = await downloadReleaseBundle(release.release_id);
    triggerBlobDownload(blob, `${release.release_id}_bundle.tar.gz`);
  } catch (err) {
    makeToast(extractApiErrorMessage(err, 'Bundle download failed.'), 'Error', 'danger');
  }
}

async function handleDownloadManifest(): Promise<void> {
  const release = selectedRelease.value;
  if (!release) return;
  try {
    const blob = await downloadReleaseManifest(release.release_id);
    triggerBlobDownload(blob, `${release.release_id}_manifest.json`);
  } catch (err) {
    makeToast(extractApiErrorMessage(err, 'Manifest download failed.'), 'Error', 'danger');
  }
}

async function handleDownloadFile(path: string): Promise<void> {
  const release = selectedRelease.value;
  if (!release) return;
  try {
    const blob = await downloadReleaseFile(release.release_id, path);
    triggerBlobDownload(blob, path.split('/').pop() || path);
  } catch (err) {
    makeToast(extractApiErrorMessage(err, 'File download failed.'), 'Error', 'danger');
  }
}

onMounted(() => {
  void loadList();
  void loadDetail(() => getLatestRelease());
});
</script>

<style scoped>
.data-releases__manifest-card {
  margin-top: 1rem;
}

.data-releases__section-title {
  margin: 0 0 0.5rem;
  color: var(--neutral-700, #616161);
  font-size: 0.8125rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.data-releases__section-subtitle {
  margin: 0.75rem 0 0.35rem;
  color: var(--neutral-700, #616161);
  font-size: 0.8125rem;
  font-weight: 700;
}

.data-releases__downloads {
  margin-top: 0.85rem;
  padding-top: 0.85rem;
  border-top: 1px solid var(--border-subtle, #e1e7ef);
}

.data-releases__download-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.data-releases__file-list {
  margin: 0;
  padding-left: 1.1rem;
  font-size: 0.8125rem;
}

.data-releases__file-list li {
  margin-bottom: 0.2rem;
}

.data-releases__file-link {
  border: none;
  background: none;
  padding: 0;
  color: var(--medical-blue-700, #0d47a1);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  text-decoration: underline;
  cursor: pointer;
}

.data-releases__file-size {
  margin-left: 0.35rem;
  color: var(--neutral-600, #757575);
}

.data-releases__verify {
  margin-top: 0.85rem;
  padding-top: 0.85rem;
  border-top: 1px solid var(--border-subtle, #e1e7ef);
  font-size: 0.85rem;
  color: var(--neutral-700, #4b5563);
}

.data-releases__verify summary {
  cursor: pointer;
  font-weight: 700;
  color: var(--neutral-900, #212121);
}

.data-releases__verify ul {
  margin: 0.5rem 0 0;
  padding-left: 1.1rem;
}

.data-releases__verify li {
  margin-bottom: 0.4rem;
  line-height: 1.5;
}

.data-releases__verify code {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.8em;
}
</style>
