/**
 * Composable for managing re-review batch creation form
 *
 * Handles form state, validation, preview, and submission for dynamic batch creation.
 * Follows single-form interface pattern from CONTEXT.md decisions.
 */
import { ref, reactive, computed } from 'vue';
// v11.0 closeout F2b: route authed calls through the apiClient — the
// request interceptor injects the Bearer from `useAuth().token.value`,
// so this composable no longer reads the session token from storage.
// `isApiError` is re-exported from `@/api/client` for the error branches
// that previously relied on `axios.isAxiosError`.
import { apiClient, isApiError } from '@/api/client';
import useToast from './useToast';

// Types for batch criteria
interface DateRange {
  start: string | null; // YYYY-MM-DD format
  end: string | null;
}

interface SelectedEntity {
  entity_id: number;
  symbol: string;
  disease_ontology_name: string;
}

interface BatchFormData {
  batch_name: string;
  date_range: DateRange;
  entity_list: SelectedEntity[]; // Selected entities with rich data for display
  gene_list: number[]; // Array of hgnc_ids as filter criterion
  status_filter: number | null; // category_id
  disease_id: string | null;
  batch_size: number;
  assigned_user_id: number | null;
}

interface PreviewEntity {
  entity_id: number;
  hgnc_id: number;
  gene_symbol: string;
  disease_ontology_name: string;
  review_date: string;
}

interface EntitySearchResult {
  entity_id: number;
  hgnc_id: number;
  symbol: string;
  disease_ontology_name: string;
  disease_ontology_id_version: string;
}

interface GeneOption {
  value: number;
  text: string;
}

interface StatusOption {
  value: number;
  text: string;
}

interface UserOption {
  value: number;
  text: string;
}

export function useBatchForm() {
  const { makeToast } = useToast();

  // Form state
  const formData = reactive<BatchFormData>({
    batch_name: '',
    date_range: { start: null, end: null },
    entity_list: [],
    gene_list: [],
    status_filter: null,
    disease_id: null,
    batch_size: 20,
    assigned_user_id: null,
  });

  // Entity search state
  const entitySearchQuery = ref('');
  const entitySearchResults = ref<EntitySearchResult[]>([]);
  const isEntitySearching = ref(false);

  // Loading states
  const isLoading = ref(false);
  const isPreviewLoading = ref(false);

  // Options for dropdowns (loaded from API)
  const geneOptions = ref<GeneOption[]>([]);
  const statusOptions = ref<StatusOption[]>([]);
  const userOptions = ref<UserOption[]>([]);

  // Preview data
  const previewEntities = ref<PreviewEntity[]>([]);
  const showPreviewModal = ref(false);
  // Gene-atomic boundary hint (issue #29): non-null `boundary_gene` means the
  // soft-LIMIT engaged and the last gene was extended past `batch_size` to
  // keep its entities together. UI surfaces a warning so the curator knows
  // the actual entity count differs from the requested cap.
  const previewBoundaryGene = ref<string | null>(null);
  const previewGeneCount = ref<number>(0);
  const previewEntityCount = ref<number>(0);

  // Validation: at least one criterion required
  const isFormValid = computed(() => {
    const hasEntityList = formData.entity_list.length > 0;
    const hasDateRange = formData.date_range.start && formData.date_range.end;
    const hasGeneList = formData.gene_list.length > 0;
    const hasStatusFilter = formData.status_filter !== null;
    const hasDiseaseId = formData.disease_id !== null && formData.disease_id !== '';

    return hasEntityList || hasDateRange || hasGeneList || hasStatusFilter || hasDiseaseId;
  });

  // Entity search function
  const searchEntities = async (query: string) => {
    if (!query || query.length < 2) {
      entitySearchResults.value = [];
      return;
    }

    isEntitySearching.value = true;
    const apiUrl = import.meta.env.VITE_API_URL;

    try {
      // Build filter: search by entity_id (if numeric), symbol, or disease name
      const isNumeric = /^\d+$/.test(query);
      const filter = isNumeric
        ? `equals(entity_id,${query})`
        : `or(contains(symbol,${query}),contains(disease_ontology_name,${query}))`;

      // Search entities using the API filter syntax. The apiClient request
      // interceptor injects the Bearer header when a session is present;
      // calls without a token simply fire no Authorization, matching the
      // pre-F2b behaviour (the ternary used to skip the header).
      const response = await apiClient.raw.get<{ data?: unknown } | unknown[]>(
        `${apiUrl}/api/entity/`,
        {
          params: {
            filter,
            page_size: 15,
          },
          withCredentials: true,
        }
      );
      const payload = response.data as { data?: unknown[] } | unknown[] | null;
      const data = Array.isArray(payload) ? payload : (payload?.data ?? []);
      entitySearchResults.value = Array.isArray(data) ? (data as EntitySearchResult[]) : [];
    } catch (error) {
      console.error('Entity search failed:', error);
      entitySearchResults.value = [];
    } finally {
      isEntitySearching.value = false;
    }
  };

  // Add entity to selection
  const addEntity = (entity: EntitySearchResult) => {
    // Check for duplicates
    if (formData.entity_list.some((e) => e.entity_id === entity.entity_id)) {
      return;
    }
    formData.entity_list.push({
      entity_id: entity.entity_id,
      symbol: entity.symbol,
      disease_ontology_name: entity.disease_ontology_name,
    });
    entitySearchQuery.value = '';
    entitySearchResults.value = [];
  };

  // Remove entity from selection
  const removeEntity = (entityId: number) => {
    const idx = formData.entity_list.findIndex((e) => e.entity_id === entityId);
    if (idx !== -1) {
      formData.entity_list.splice(idx, 1);
    }
  };

  // Build criteria object for API
  const buildCriteria = () => {
    const criteria: Record<string, unknown> = {
      batch_size: formData.batch_size,
    };

    // Entity list takes priority - direct entity IDs
    if (formData.entity_list.length > 0) {
      criteria.entity_ids = formData.entity_list.map((e) => e.entity_id);
    }

    if (formData.date_range.start && formData.date_range.end) {
      criteria.date_range = {
        start: formData.date_range.start,
        end: formData.date_range.end,
      };
    }

    if (formData.gene_list.length > 0) {
      criteria.gene_list = formData.gene_list;
    }

    if (formData.status_filter !== null) {
      criteria.status_filter = formData.status_filter;
    }

    if (formData.disease_id) {
      criteria.disease_id = formData.disease_id;
    }

    return criteria;
  };

  // Load dropdown options
  const loadOptions = async () => {
    const apiUrl = import.meta.env.VITE_API_URL;

    try {
      // Load users (Curators and Reviewers). The apiClient request
      // interceptor attaches the Bearer header from `useAuth().token.value`
      // — no manual header construction below.
      const usersResponse = await apiClient.raw.get<unknown>(
        `${apiUrl}/api/user/list?roles=Curator,Reviewer`,
        { withCredentials: true }
      );
      const usersData = usersResponse.data;
      userOptions.value = Array.isArray(usersData)
        ? (usersData as { user_id: number; user_name: string }[]).map((u) => ({
            value: u.user_id,
            text: u.user_name,
          }))
        : [];

      // Load status categories from /api/list/status
      const statusResponse = await apiClient.raw.get<unknown>(`${apiUrl}/api/list/status`, {
        withCredentials: true,
      });
      const statusData = statusResponse.data as { data?: unknown } | unknown[] | null;
      // Handle paginated response format
      const statusArray = Array.isArray(statusData) ? statusData : (statusData?.data ?? statusData);
      statusOptions.value = Array.isArray(statusArray)
        ? (statusArray as { category_id: number; category: string }[]).map((s) => ({
            value: s.category_id,
            text: s.category,
          }))
        : [];

      // Load genes from /api/gene/ (get all genes for selection)
      const genesResponse = await apiClient.raw.get<unknown>(
        `${apiUrl}/api/gene/?page_size=all&fields=symbol,hgnc_id`,
        { withCredentials: true }
      );
      const genesData = genesResponse.data as { data?: unknown } | unknown[] | null;
      // Handle paginated response format
      const genesArray = Array.isArray(genesData) ? genesData : (genesData?.data ?? genesData);
      geneOptions.value = Array.isArray(genesArray)
        ? (genesArray as { hgnc_id: number; symbol: string }[]).map((g) => ({
            value: g.hgnc_id,
            text: g.symbol,
          }))
        : [];
    } catch (error) {
      console.error('Failed to load form options:', error);
      makeToast('Failed to load some form options', 'Warning', 'warning');
    }
  };

  // Preview matching entities
  const handlePreview = async () => {
    if (!isFormValid.value) {
      makeToast('Please select at least one criterion', 'Validation', 'warning');
      return;
    }

    isPreviewLoading.value = true;
    const apiUrl = import.meta.env.VITE_API_URL;

    try {
      const response = await apiClient.raw.post<{
        data?: PreviewEntity[];
        boundary_gene?: string | null;
        gene_count?: number;
        entity_count?: number;
      }>(`${apiUrl}/api/re_review/batch/preview`, buildCriteria(), { withCredentials: true });

      previewEntities.value = response.data.data || [];
      // Capture gene-atomic boundary hint (issue #29). Plumber's
      // `list(na="string")` serializer emits NA as the literal "NA" string
      // for nullable scalars; treat that as "no boundary engaged".
      const rawBoundary = response.data.boundary_gene;
      previewBoundaryGene.value = rawBoundary == null || rawBoundary === 'NA' ? null : rawBoundary;
      previewGeneCount.value = response.data.gene_count ?? 0;
      previewEntityCount.value = response.data.entity_count ?? 0;
      showPreviewModal.value = true;
    } catch (error: unknown) {
      const message = isApiError<{ message?: string }>(error)
        ? error.response?.data?.message || error.message
        : 'Preview failed';
      makeToast(message, 'Error', 'danger');
    } finally {
      isPreviewLoading.value = false;
    }
  };

  // Create batch
  const handleSubmit = async () => {
    if (!isFormValid.value) {
      makeToast('Please select at least one criterion', 'Validation', 'warning');
      return false;
    }

    isLoading.value = true;
    const apiUrl = import.meta.env.VITE_API_URL;

    try {
      const payload = {
        ...buildCriteria(),
        batch_name: formData.batch_name || null,
        assigned_user_id: formData.assigned_user_id,
      };

      const response = await apiClient.raw.post<{ entry: { entity_count: number } }>(
        `${apiUrl}/api/re_review/batch/create`,
        payload,
        { withCredentials: true }
      );

      const result = response.data.entry;
      makeToast(`Batch created with ${result.entity_count} entities`, 'Success', 'success');

      // Reset form
      resetForm();
      return true;
    } catch (error: unknown) {
      const message = isApiError<{ message?: string }>(error)
        ? error.response?.data?.message || error.message
        : 'Batch creation failed';
      makeToast(message, 'Error', 'danger');
      return false;
    } finally {
      isLoading.value = false;
    }
  };

  // Reset form to initial state
  const resetForm = () => {
    formData.batch_name = '';
    formData.date_range = { start: null, end: null };
    formData.entity_list = [];
    formData.gene_list = [];
    formData.status_filter = null;
    formData.disease_id = null;
    formData.batch_size = 20;
    formData.assigned_user_id = null;
    entitySearchQuery.value = '';
    entitySearchResults.value = [];
    previewEntities.value = [];
    previewBoundaryGene.value = null;
    previewGeneCount.value = 0;
    previewEntityCount.value = 0;
  };

  // Preview table fields
  const previewFields = [
    { key: 'entity_id', label: 'Entity ID', sortable: true },
    { key: 'gene_symbol', label: 'Gene', sortable: true },
    { key: 'disease_ontology_name', label: 'Disease', sortable: true },
    { key: 'review_date', label: 'Last Review', sortable: true },
  ];

  return {
    // State
    formData,
    isLoading,
    isPreviewLoading,
    isFormValid,

    // Entity search
    entitySearchQuery,
    entitySearchResults,
    isEntitySearching,
    searchEntities,
    addEntity,
    removeEntity,

    // Options
    geneOptions,
    statusOptions,
    userOptions,

    // Preview
    previewEntities,
    previewFields,
    showPreviewModal,
    previewBoundaryGene,
    previewGeneCount,
    previewEntityCount,

    // Methods
    loadOptions,
    handlePreview,
    handleSubmit,
    resetForm,
  };
}

export default useBatchForm;
