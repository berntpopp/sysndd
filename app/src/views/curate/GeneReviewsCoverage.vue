<!-- views/curate/GeneReviewsCoverage.vue -->
<!--
  GeneReviewsCoverage.vue (issues #14, #46)

  Curator-facing GeneReviews integration:
  - Lists active entities with their gene and whether a GeneReviews reference is
    already linked (#46 coverage).
  - Optional "Check NCBI availability" pass flags genes that have a GeneReviews
    chapter upstream but no linked reference yet (needs_attention).
  - "Attach" links a GeneReviews chapter (by PMID) to the entity's primary
    review, reusing the existing publication model (#14).
  - "Export CSV" downloads the gene -> GeneReviews coverage table (#46).

  All HTTP goes through the typed client in @/api/genereviews (no raw axios).
-->
<template>
  <AuthenticatedPageShell
    title="GeneReviews coverage"
    content-class="authenticated-route-content"
    full-width
  >
    <BContainer fluid>
      <p class="genereviews-coverage__intro">
        Review which SysNDD entities already have a GeneReviews reference, check
        live GeneReviews availability per gene from NCBI, and attach a
        GeneReviews chapter to an entity.
      </p>

      <TableShell
        title="Entity GeneReviews coverage"
        :description="tableDescription"
        :meta="metaText"
        :loading="loading"
      >
        <template #actions>
          <BFormCheckbox v-model="includeLive" switch class="me-3" @change="reload">
            Check NCBI availability
          </BFormCheckbox>
          <BButton
            variant="outline-secondary"
            size="sm"
            :disabled="loading || downloading"
            @click="onExportCsv"
          >
            <i class="bi bi-download" aria-hidden="true" />
            Export CSV
          </BButton>
          <BButton
            variant="outline-secondary"
            size="sm"
            class="ms-2"
            :disabled="loading"
            @click="reload"
          >
            <i class="bi bi-arrow-clockwise" aria-hidden="true" />
            Refresh
          </BButton>
        </template>

        <template #toolbar>
          <BFormInput
            v-model="searchText"
            type="search"
            size="sm"
            placeholder="Filter by gene symbol or disease"
            class="genereviews-coverage__search"
            aria-label="Filter coverage rows"
          />
          <BFormSelect
            v-model="statusFilter"
            size="sm"
            :options="statusFilterOptions"
            class="genereviews-coverage__status-filter ms-2"
            aria-label="Filter by link status"
          />
        </template>

        <BTable
          :items="filteredRows"
          :fields="fields"
          :busy="loading"
          small
          hover
          responsive
          show-empty
          empty-text="No entities match the current filter."
          class="genereviews-coverage__table"
        >
          <template #cell(symbol)="data">
            <GeneBadge :symbol="data.item.symbol" :hgnc-id="data.item.hgnc_id" size="sm" />
          </template>

          <template #cell(entity_id)="data">
            <EntityBadge
              :entity-id="data.item.entity_id"
              :link-to="`/Entities/${data.item.entity_id}`"
              variant="primary"
              size="sm"
            />
          </template>

          <template #cell(already_linked)="data">
            <BBadge v-if="data.item.already_linked" variant="success">
              <i class="bi bi-check-circle" aria-hidden="true" /> Linked
            </BBadge>
            <BBadge v-else variant="secondary">Not linked</BBadge>
            <div v-if="data.item.linked_nbk_id" class="genereviews-coverage__linked-id">
              {{ data.item.linked_nbk_id }}
            </div>
          </template>

          <template #cell(genereview_available)="data">
            <template v-if="data.item.lookup_error">
              <BBadge variant="warning">
                <i class="bi bi-exclamation-triangle" aria-hidden="true" /> Lookup failed
              </BBadge>
            </template>
            <template v-else-if="data.item.genereview_available === null">
              <span class="genereviews-coverage__muted">Not checked</span>
            </template>
            <template v-else-if="data.item.genereview_available">
              <BBadge :variant="data.item.needs_attention ? 'danger' : 'info'">
                <i class="bi bi-journal-medical" aria-hidden="true" />
                {{ data.item.needs_attention ? 'Available, not linked' : 'Available' }}
              </BBadge>
              <BLink
                v-if="data.item.available_url"
                :href="data.item.available_url"
                target="_blank"
                rel="noopener"
                class="genereviews-coverage__nbk-link"
              >
                {{ data.item.available_nbk_id }}
              </BLink>
            </template>
            <template v-else>
              <span class="genereviews-coverage__muted">None found</span>
            </template>
          </template>

          <template #cell(actions)="data">
            <BButton
              variant="outline-primary"
              size="sm"
              :aria-label="`Attach GeneReviews reference to entity ${data.item.entity_id}`"
              @click="openAttach(data.item)"
            >
              <i class="bi bi-link-45deg" aria-hidden="true" />
              Attach
            </BButton>
          </template>
        </BTable>
      </TableShell>
    </BContainer>

    <BModal
      v-model="attachModalVisible"
      title="Attach GeneReviews reference"
      :ok-disabled="attaching || !attachPmid"
      :ok-title="attaching ? 'Attaching…' : 'Attach'"
      @ok.prevent="confirmAttach"
    >
      <p v-if="attachTarget">
        Attach a GeneReviews chapter to
        <strong>{{ attachTarget.symbol }}</strong>
        (entity sysndd:{{ attachTarget.entity_id }}).
      </p>
      <BLink
        v-if="attachTarget && attachTarget.available_url"
        :href="attachTarget.available_url"
        target="_blank"
        rel="noopener"
      >
        Open the candidate GeneReviews chapter ({{ attachTarget.available_nbk_id }})
      </BLink>
      <BFormGroup
        label="GeneReviews chapter PMID"
        label-for="genereviews-pmid-input"
        description="Enter the PubMed ID of the GeneReviews chapter (e.g. 20301494)."
        class="mt-3"
      >
        <BFormInput
          id="genereviews-pmid-input"
          v-model="attachPmid"
          type="text"
          placeholder="20301494"
          aria-label="GeneReviews chapter PMID"
        />
      </BFormGroup>
    </BModal>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';

import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import TableShell from '@/components/table/TableShell.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import useToast from '@/composables/useToast';
import { isApiError } from '@/api/client';
import { extractApiErrorMessage } from '@/utils/api-errors';
import {
  getGeneReviewsCoverage,
  exportGeneReviewsCoverageCsv,
  attachGeneReview,
  type GeneReviewCoverageRow,
} from '@/api/genereviews';

const { makeToast } = useToast();

const rows = ref<GeneReviewCoverageRow[]>([]);
const loading = ref(false);
const downloading = ref(false);
const includeLive = ref(false);
const searchText = ref('');
const statusFilter = ref<'all' | 'linked' | 'not_linked' | 'needs_attention'>('all');

const statusFilterOptions = [
  { value: 'all', text: 'All entities' },
  { value: 'linked', text: 'Already linked' },
  { value: 'not_linked', text: 'Not linked' },
  { value: 'needs_attention', text: 'Available, not linked' },
];

const fields = [
  { key: 'symbol', label: 'Gene', sortable: true },
  { key: 'entity_id', label: 'Entity' },
  { key: 'disease_ontology_name', label: 'Disease', sortable: true },
  { key: 'already_linked', label: 'Linked reference' },
  { key: 'genereview_available', label: 'NCBI availability' },
  { key: 'actions', label: 'Action' },
];

const metaText = computed(() => `${filteredRows.value.length} of ${rows.value.length} entities`);

const tableDescription = computed(() =>
  includeLive.value
    ? 'Includes live (cached) GeneReviews availability from NCBI. Rows marked "Available, not linked" have a GeneReviews chapter that is not yet attached.'
    : 'Showing already-linked GeneReviews references. Enable "Check NCBI availability" to flag genes with an unlinked GeneReviews chapter.'
);

const filteredRows = computed<GeneReviewCoverageRow[]>(() => {
  const term = searchText.value.trim().toLowerCase();
  return rows.value.filter((row) => {
    if (statusFilter.value === 'linked' && !row.already_linked) return false;
    if (statusFilter.value === 'not_linked' && row.already_linked) return false;
    if (statusFilter.value === 'needs_attention' && row.needs_attention !== true) return false;
    if (!term) return true;
    const haystack = `${row.symbol ?? ''} ${row.disease_ontology_name ?? ''}`.toLowerCase();
    return haystack.includes(term);
  });
});

async function reload(): Promise<void> {
  loading.value = true;
  try {
    const response = await getGeneReviewsCoverage({ include_live: includeLive.value });
    rows.value = response.data ?? [];
  } catch (err) {
    if (isApiError(err)) {
      makeToast(
        extractApiErrorMessage(err, 'Failed to load GeneReviews coverage'),
        'Failed to load GeneReviews coverage',
        'danger'
      );
    } else if (err) {
      makeToast(err, 'Failed to load GeneReviews coverage', 'danger');
    }
  } finally {
    loading.value = false;
  }
}

async function onExportCsv(): Promise<void> {
  downloading.value = true;
  try {
    const blob = await exportGeneReviewsCoverageCsv({ include_live: includeLive.value });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'sysndd_genereviews_coverage.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  } catch (err) {
    if (isApiError(err)) {
      makeToast(extractApiErrorMessage(err, 'CSV export failed'), 'CSV export failed', 'danger');
    } else if (err) {
      makeToast(err, 'CSV export failed', 'danger');
    }
  } finally {
    downloading.value = false;
  }
}

// --- Attach flow ---
const attachModalVisible = ref(false);
const attachTarget = ref<GeneReviewCoverageRow | null>(null);
const attachPmid = ref('');
const attaching = ref(false);

function openAttach(row: GeneReviewCoverageRow): void {
  attachTarget.value = row;
  attachPmid.value = '';
  attachModalVisible.value = true;
}

async function confirmAttach(): Promise<void> {
  if (!attachTarget.value || !attachPmid.value) {
    return;
  }
  attaching.value = true;
  try {
    const result = await attachGeneReview({
      entity_id: attachTarget.value.entity_id,
      pmid: attachPmid.value.trim(),
    });
    makeToast(result.message, 'GeneReviews reference attached', 'success');
    attachModalVisible.value = false;
    await reload();
  } catch (err) {
    if (isApiError(err)) {
      makeToast(extractApiErrorMessage(err, 'Attach failed'), 'Attach failed', 'danger');
    } else if (err) {
      makeToast(err, 'Attach failed', 'danger');
    }
  } finally {
    attaching.value = false;
  }
}

onMounted(reload);

defineExpose({
  rows,
  filteredRows,
  includeLive,
  statusFilter,
  searchText,
  attachPmid,
  reload,
  onExportCsv,
  confirmAttach,
  openAttach,
});
</script>

<style scoped>
.genereviews-coverage__intro {
  margin-bottom: 1rem;
  color: var(--text-secondary, #555);
}

.genereviews-coverage__search {
  max-width: 22rem;
}

.genereviews-coverage__status-filter {
  max-width: 16rem;
}

.genereviews-coverage__linked-id,
.genereviews-coverage__nbk-link {
  display: block;
  font-size: 0.8rem;
  font-family: var(--font-mono, monospace);
  margin-top: 0.25rem;
}

.genereviews-coverage__muted {
  color: var(--text-muted, #888);
  font-size: 0.85rem;
}
</style>
