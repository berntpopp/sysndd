<template>
  <AuthenticatedPageShell
    title="Manage Metadata"
    description="Administer the SysNDD-managed curation controlled vocabularies. Ontology-derived sets (HPO phenotypes, disease ontology, gene nomenclature) are refreshed from source and are not editable here."
    content-class="authenticated-route-content"
    full-width
  >
    <BContainer fluid class="metadata-admin">
      <BAlert v-if="loadError" variant="danger" :model-value="true" class="mb-3">
        <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
        {{ loadError }}
      </BAlert>

      <div v-if="loadingCatalog" class="metadata-loading">
        <BSpinner small class="me-2" />
        Loading vocabularies...
      </div>

      <template v-else>
        <!-- Vocabulary selector (WAI-ARIA tablist) -->
        <div class="metadata-tabs" role="tablist" aria-label="Metadata vocabularies">
          <BButton
            v-for="vocab in catalog"
            :id="`metadata-tab-${vocab.slug}`"
            :key="vocab.slug"
            role="tab"
            :aria-selected="vocab.slug === activeSlug ? 'true' : 'false'"
            :aria-controls="`metadata-panel-${vocab.slug}`"
            :tabindex="vocab.slug === activeSlug ? 0 : -1"
            size="sm"
            :variant="vocab.slug === activeSlug ? 'primary' : 'outline-primary'"
            class="metadata-tab"
            :data-testid="`metadata-tab-${vocab.slug}`"
            @click="selectVocabulary(vocab.slug)"
            @keydown="onTabKeydown"
          >
            {{ vocab.label }}
          </BButton>
        </div>

        <div
          v-if="activeVocabulary"
          :id="`metadata-panel-${activeSlug}`"
          role="tabpanel"
          :aria-labelledby="`metadata-tab-${activeSlug}`"
          tabindex="0"
        >
          <AdminOperationPanel
            :title="activeVocabulary.label"
            :description="vocabularyDescription"
            icon="bi-list-check"
            :meta="vocabularyMeta"
          >
          <template #actions>
            <BButton
              v-if="canCreate"
              variant="primary"
              size="sm"
              data-testid="metadata-add-btn"
              @click="openCreate"
            >
              <i class="bi bi-plus-lg me-1" aria-hidden="true" />
              Add entry
            </BButton>
          </template>

          <BAlert v-if="isAnchored" variant="info" :model-value="true" class="mb-3">
            <i class="bi bi-info-circle me-1" aria-hidden="true" />
            This vocabulary is anchored to an external ontology. You can edit the curated display
            fields and toggle activation, but terms cannot be created or deleted here.
          </BAlert>

          <BTable
            class="metadata-table"
            :items="rows"
            :fields="tableFields"
            :busy="loadingRows"
            hover
            small
            responsive
          >
            <template #table-busy>
              <div class="text-center my-2">
                <BSpinner class="align-middle" />
                <strong class="ms-2">Loading entries...</strong>
              </div>
            </template>

            <template #cell(is_active)="data">
              <BBadge :variant="isRowActive(data.item) ? 'success' : 'secondary'">
                {{ isRowActive(data.item) ? 'Active' : 'Inactive' }}
              </BBadge>
            </template>

            <template #cell(allowed_phenotype)="data">
              <BBadge :variant="truthy(data.value) ? 'info' : 'light'">
                {{ truthy(data.value) ? 'Yes' : 'No' }}
              </BBadge>
            </template>

            <template #cell(allowed_variation)="data">
              <BBadge :variant="truthy(data.value) ? 'info' : 'light'">
                {{ truthy(data.value) ? 'Yes' : 'No' }}
              </BBadge>
            </template>

            <template #cell(actions)="data">
              <div class="d-flex justify-content-end">
                <BButton
                  size="sm"
                  variant="link"
                  class="me-1 p-1 text-primary"
                  title="Edit entry"
                  aria-label="Edit entry"
                  :data-testid="`metadata-edit-${rowPk(data.item)}`"
                  @click="openEdit(data.item)"
                >
                  <i class="bi bi-pencil" aria-hidden="true" />
                </BButton>
                <BButton
                  v-if="canDelete"
                  size="sm"
                  variant="link"
                  class="p-1 text-warning"
                  title="Deactivate entry"
                  aria-label="Deactivate entry"
                  :data-testid="`metadata-delete-${rowPk(data.item)}`"
                  @click="openDelete(data.item)"
                >
                  <i class="bi bi-archive" aria-hidden="true" />
                </BButton>
              </div>
            </template>
          </BTable>

          <p v-if="!loadingRows && rows.length === 0" class="text-muted small mb-0">
            No entries.
          </p>
          </AdminOperationPanel>
        </div>
      </template>

      <MetadataEntryModal
        v-model:visible="isEntryOpen"
        :mode="entryMode"
        :vocabulary="activeVocabulary"
        :row="selectedRow"
        :saving="saving"
        @submit="onEntrySubmit"
        @cancel="isEntryOpen = false"
      />

      <MetadataDeleteModal
        v-model:visible="isDeleteOpen"
        :label="deleteLabel"
        :deleting="deleting"
        @confirm="onDeleteConfirm"
        @cancel="isDeleteOpen = false"
      />
    </BContainer>
  </AuthenticatedPageShell>
</template>

<script lang="ts">
import { computed, defineComponent, nextTick, onMounted, ref } from 'vue';
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import MetadataEntryModal from './components/MetadataEntryModal.vue';
import MetadataDeleteModal from './components/MetadataDeleteModal.vue';
import useToast from '@/composables/useToast';
import { useMetadataAdmin } from './composables/useMetadataAdmin';
import type { MetadataRow, MetadataCellValue } from '@/api/metadata';

interface BTableField {
  key: string;
  label: string;
  class?: string;
}

interface EntrySubmitPayload {
  mode: 'create' | 'edit';
  pk: MetadataCellValue | null;
  payload: Record<string, MetadataCellValue>;
}

const MANAGED_COPY: Record<string, string> = {
  sysndd: 'SysNDD-managed controlled vocabulary. Full create / edit / deactivate.',
  hpo: 'Inheritance terms anchored to the Human Phenotype Ontology.',
  vario: 'Variant types anchored to the Variation Ontology (VariO).',
};

function humanizeLabel(field: unknown): string {
  // Defensive String(): the metadata client normalises Plumber's array-wrapped
  // scalars, but coercing here keeps a non-string field from crashing the
  // column computed (was: "field.replace is not a function").
  return String(field ?? '')
    .replace(/_/g, ' ')
    .replace(/\bhpo\b/gi, 'HPO')
    .replace(/^\w/, (c) => c.toUpperCase());
}

export default defineComponent({
  name: 'ManageMetadata',
  components: {
    AuthenticatedPageShell,
    AdminOperationPanel,
    MetadataEntryModal,
    MetadataDeleteModal,
  },
  setup() {
    const { makeToast } = useToast();
    const admin = useMetadataAdmin({ onToast: makeToast });

    const isEntryOpen = ref(false);
    const isDeleteOpen = ref(false);
    const entryMode = ref<'create' | 'edit'>('create');
    const selectedRow = ref<MetadataRow | null>(null);

    onMounted(() => {
      admin.loadCatalog();
    });

    const truthy = (value: unknown): boolean =>
      value === 1 || value === '1' || value === true;

    const rowPk = (row: MetadataRow): string => {
      const pk = admin.activeVocabulary.value?.pk;
      return pk ? String(row[pk] ?? '') : '';
    };

    const isRowActive = (row: MetadataRow): boolean => truthy(row.is_active);

    // Build table columns from the descriptor fields + lifecycle + actions.
    const tableFields = computed<BTableField[]>(() => {
      const vocab = admin.activeVocabulary.value;
      if (!vocab) return [];
      const cols: BTableField[] = [{ key: vocab.pk, label: humanizeLabel(vocab.pk) }];
      for (const field of vocab.fields) {
        cols.push({ key: field, label: humanizeLabel(field) });
      }
      if (vocab.has_sort) cols.push({ key: 'sort', label: 'Sort' });
      if (vocab.has_is_active) cols.push({ key: 'is_active', label: 'Status' });
      cols.push({ key: 'actions', label: 'Actions', class: 'text-end' });
      return cols;
    });

    const vocabularyDescription = computed(() => {
      const vocab = admin.activeVocabulary.value;
      if (!vocab) return '';
      return MANAGED_COPY[vocab.managed] ?? '';
    });

    const vocabularyMeta = computed(() => {
      const count = admin.rows.value.length;
      return `${count} ${count === 1 ? 'entry' : 'entries'}`;
    });

    const deleteLabel = computed(() => {
      const vocab = admin.activeVocabulary.value;
      const row = selectedRow.value;
      if (!vocab || !row) return '';
      const display = vocab.fields[0] ? row[vocab.fields[0]] : row[vocab.pk];
      return String(display ?? row[vocab.pk] ?? '');
    });

    function openCreate() {
      entryMode.value = 'create';
      selectedRow.value = null;
      isEntryOpen.value = true;
    }

    function openEdit(row: MetadataRow) {
      entryMode.value = 'edit';
      selectedRow.value = row;
      isEntryOpen.value = true;
    }

    function openDelete(row: MetadataRow) {
      selectedRow.value = row;
      isDeleteOpen.value = true;
    }

    async function onEntrySubmit(payload: EntrySubmitPayload) {
      let ok = false;
      if (payload.mode === 'create') {
        ok = await admin.createRow(payload.payload);
      } else if (payload.pk !== null && payload.pk !== undefined) {
        ok = await admin.updateRow(payload.pk as string | number, payload.payload);
      }
      if (ok) isEntryOpen.value = false;
    }

    async function onDeleteConfirm() {
      const vocab = admin.activeVocabulary.value;
      const row = selectedRow.value;
      if (!vocab || !row) return;
      const pk = row[vocab.pk];
      if (pk === null || pk === undefined) return;
      const ok = await admin.deleteRow(pk as string | number);
      if (ok) isDeleteOpen.value = false;
    }

    // WAI-ARIA tablist keyboard navigation (Left/Right/Home/End with roving focus).
    function onTabKeydown(event: KeyboardEvent) {
      const keys = ['ArrowRight', 'ArrowLeft', 'Home', 'End'];
      if (!keys.includes(event.key)) return;
      event.preventDefault();
      const slugs = admin.catalog.value.map((v) => v.slug);
      if (slugs.length === 0) return;
      const current = slugs.indexOf(admin.activeSlug.value);
      let next = current;
      if (event.key === 'ArrowRight') next = (current + 1) % slugs.length;
      else if (event.key === 'ArrowLeft') next = (current - 1 + slugs.length) % slugs.length;
      else if (event.key === 'Home') next = 0;
      else if (event.key === 'End') next = slugs.length - 1;
      const nextSlug = slugs[next];
      admin.selectVocabulary(nextSlug);
      nextTick(() => {
        document.getElementById(`metadata-tab-${nextSlug}`)?.focus();
      });
    }

    return {
      onTabKeydown,
      // state from composable
      catalog: admin.catalog,
      activeSlug: admin.activeSlug,
      activeVocabulary: admin.activeVocabulary,
      rows: admin.rows,
      loadingCatalog: admin.loadingCatalog,
      loadingRows: admin.loadingRows,
      saving: admin.saving,
      deleting: admin.deleting,
      loadError: admin.loadError,
      canCreate: admin.canCreate,
      canDelete: admin.canDelete,
      isAnchored: admin.isAnchored,
      selectVocabulary: admin.selectVocabulary,
      // local state + handlers
      isEntryOpen,
      isDeleteOpen,
      entryMode,
      selectedRow,
      tableFields,
      vocabularyDescription,
      vocabularyMeta,
      deleteLabel,
      truthy,
      rowPk,
      isRowActive,
      openCreate,
      openEdit,
      openDelete,
      onEntrySubmit,
      onDeleteConfirm,
    };
  },
});
</script>

<style scoped>
.metadata-admin {
  padding-bottom: 1.5rem;
}

.metadata-loading {
  display: flex;
  align-items: center;
  padding: 1rem 0;
  color: #64748b;
}

.metadata-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.metadata-table {
  text-align: left;
}
</style>
