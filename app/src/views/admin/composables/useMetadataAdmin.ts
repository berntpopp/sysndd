// Composable backing the Admin "Manage Metadata" view (issue #32).
//
// Owns the vocabulary catalog, the active vocabulary's rows, and the create /
// update / soft-delete mutations. Every API call goes through the typed
// @/api/metadata client; errors are surfaced via extractApiErrorMessage so the
// in-use delete guard's 400 message reaches the user verbatim.
import { ref, computed } from 'vue';
import {
  fetchMetadataCatalog,
  fetchMetadataRows,
  createMetadataRow,
  updateMetadataRow,
  deleteMetadataRow,
  type MetadataVocabulary,
  type MetadataRow,
  type MetadataListMeta,
  type MetadataCellValue,
} from '@/api/metadata';
import { extractApiErrorMessage } from '@/utils/api-errors';
import type { ToastVariant } from '@/types/components';

type ToastFn = (
  message: unknown,
  title?: string | null,
  variant?: ToastVariant | null
) => void;

export interface UseMetadataAdminOptions {
  onToast: ToastFn;
}

export function useMetadataAdmin(options: UseMetadataAdminOptions) {
  const { onToast } = options;

  const catalog = ref<MetadataVocabulary[]>([]);
  const activeSlug = ref<string | null>(null);
  const rows = ref<MetadataRow[]>([]);
  const listMeta = ref<MetadataListMeta | null>(null);

  const loadingCatalog = ref(false);
  const loadingRows = ref(false);
  const saving = ref(false);
  const deleting = ref(false);
  const loadError = ref<string | null>(null);

  // Request ownership for row loads (#535 S5b). Switching vocabulary A→B while
  // A's rows are still in flight must not let A's late response populate the B
  // table — a subsequent edit would then send an A row id with activeSlug=B and
  // mutate the WRONG vocabulary. Capture slug + generation and apply only if both
  // are still current.
  let rowsGeneration = 0;

  const activeVocabulary = computed<MetadataVocabulary | null>(
    () => catalog.value.find((v) => v.slug === activeSlug.value) ?? null
  );

  /** Whether the active vocabulary supports create + delete (full CRUD). */
  const canCreate = computed(() => activeVocabulary.value?.editable === true);
  const canDelete = computed(() => activeVocabulary.value?.editable === true);
  /** Anchored vocabularies allow editing curated fields + activation only. */
  const isAnchored = computed(() => activeVocabulary.value?.editable === 'anchored');

  async function loadCatalog(): Promise<void> {
    loadingCatalog.value = true;
    loadError.value = null;
    try {
      catalog.value = await fetchMetadataCatalog();
      if (!activeSlug.value && catalog.value.length > 0) {
        await selectVocabulary(catalog.value[0].slug);
      }
    } catch (err) {
      loadError.value = extractApiErrorMessage(err, 'Failed to load metadata vocabularies.');
      onToast(loadError.value, 'Error', 'danger');
    } finally {
      loadingCatalog.value = false;
    }
  }

  async function loadRows(): Promise<void> {
    if (!activeSlug.value) return;
    const mySlug = activeSlug.value;
    const myGen = ++rowsGeneration;
    const stillCurrent = (): boolean =>
      myGen === rowsGeneration && mySlug === activeSlug.value;
    loadingRows.value = true;
    loadError.value = null;
    try {
      const response = await fetchMetadataRows(mySlug);
      if (!stillCurrent()) return; // a newer vocabulary/reload superseded this one
      rows.value = response.data ?? [];
      listMeta.value = response.meta ?? null;
    } catch (err) {
      if (!stillCurrent()) return;
      loadError.value = extractApiErrorMessage(err, 'Failed to load vocabulary entries.');
      onToast(loadError.value, 'Error', 'danger');
    } finally {
      if (stillCurrent()) loadingRows.value = false;
    }
  }

  async function selectVocabulary(slug: string): Promise<void> {
    if (activeSlug.value === slug) return;
    activeSlug.value = slug;
    rows.value = [];
    listMeta.value = null;
    await loadRows();
  }

  async function createRow(payload: Record<string, MetadataCellValue>): Promise<boolean> {
    if (!activeSlug.value) return false;
    saving.value = true;
    try {
      await createMetadataRow(activeSlug.value, payload);
      onToast('Entry created.', 'Success', 'success');
      await loadRows();
      return true;
    } catch (err) {
      onToast(extractApiErrorMessage(err, 'Failed to create entry.'), 'Error', 'danger');
      return false;
    } finally {
      saving.value = false;
    }
  }

  async function updateRow(
    id: string | number,
    payload: Record<string, MetadataCellValue>
  ): Promise<boolean> {
    if (!activeSlug.value) return false;
    saving.value = true;
    try {
      await updateMetadataRow(activeSlug.value, id, payload);
      onToast('Entry updated.', 'Success', 'success');
      await loadRows();
      return true;
    } catch (err) {
      onToast(extractApiErrorMessage(err, 'Failed to update entry.'), 'Error', 'danger');
      return false;
    } finally {
      saving.value = false;
    }
  }

  async function deleteRow(id: string | number): Promise<boolean> {
    if (!activeSlug.value) return false;
    deleting.value = true;
    try {
      await deleteMetadataRow(activeSlug.value, id);
      onToast('Entry deactivated.', 'Success', 'success');
      await loadRows();
      return true;
    } catch (err) {
      // The in-use guard returns a 400 with an explanatory message; surface it.
      onToast(extractApiErrorMessage(err, 'Failed to delete entry.'), 'Error', 'danger');
      return false;
    } finally {
      deleting.value = false;
    }
  }

  return {
    catalog,
    activeSlug,
    activeVocabulary,
    rows,
    listMeta,
    loadingCatalog,
    loadingRows,
    saving,
    deleting,
    loadError,
    canCreate,
    canDelete,
    isAnchored,
    loadCatalog,
    loadRows,
    selectVocabulary,
    createRow,
    updateRow,
    deleteRow,
  };
}

export default useMetadataAdmin;
