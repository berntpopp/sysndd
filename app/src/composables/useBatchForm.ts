/**
 * Composable for managing re-review batch creation form
 *
 * Handles form state, validation, preview, and submission for dynamic batch creation.
 * Follows single-form interface pattern from CONTEXT.md decisions.
 */
import { ref, reactive, computed } from 'vue';
import axios from 'axios';
import useToast from './useToast';

// Types for batch criteria
interface DateRange {
  start: string | null;  // YYYY-MM-DD format
  end: string | null;
}

interface BatchFormData {
  batch_name: string;
  date_range: DateRange;
  gene_list: number[];      // Array of hgnc_ids (BFormSelect multiple returns array)
  status_filter: number | null;  // category_id
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
    gene_list: [],
    status_filter: null,
    disease_id: null,
    batch_size: 20,
    assigned_user_id: null,
  });

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

  // Validation: at least one criterion required
  const isFormValid = computed(() => {
    const hasDateRange = formData.date_range.start && formData.date_range.end;
    const hasGeneList = formData.gene_list.length > 0;
    const hasStatusFilter = formData.status_filter !== null;
    const hasDiseaseId = formData.disease_id !== null && formData.disease_id !== '';

    return hasDateRange || hasGeneList || hasStatusFilter || hasDiseaseId;
  });

  // Build criteria object for API
  const buildCriteria = () => {
    const criteria: Record<string, unknown> = {
      batch_size: formData.batch_size,
    };

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
    const token = localStorage.getItem('token');
    const headers = { Authorization: `Bearer ${token}` };

    try {
      // Load users (Curators and Reviewers)
      const usersResponse = await axios.get(
        `${apiUrl}/api/user/list?roles=Curator,Reviewer`,
        { headers }
      );
      const usersData = usersResponse.data;
      userOptions.value = Array.isArray(usersData)
        ? usersData.map((u: { user_id: number; user_name: string }) => ({
            value: u.user_id,
            text: u.user_name,
          }))
        : [];

      // Load status categories
      const statusResponse = await axios.get(
        `${apiUrl}/api/entity/status/category/list`,
        { headers }
      );
      const statusData = statusResponse.data;
      statusOptions.value = Array.isArray(statusData)
        ? statusData.map((s: { category_id: number; category: string }) => ({
            value: s.category_id,
            text: s.category,
          }))
        : [];

      // Load genes (from entities for selection)
      // This loads unique genes that have entities
      const genesResponse = await axios.get(
        `${apiUrl}/api/entity/genes`,
        { headers }
      );
      const genesData = genesResponse.data;
      geneOptions.value = Array.isArray(genesData)
        ? genesData.map((g: { hgnc_id: number; gene_symbol: string }) => ({
            value: g.hgnc_id,
            text: g.gene_symbol,
          }))
        : [];
    } catch (error) {
      makeToast('Failed to load form options', 'Error', 'danger');
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
    const token = localStorage.getItem('token');

    try {
      const response = await axios.post(
        `${apiUrl}/api/re_review/batch/preview`,
        buildCriteria(),
        { headers: { Authorization: `Bearer ${token}` } }
      );

      previewEntities.value = response.data.data || [];
      showPreviewModal.value = true;
    } catch (error: unknown) {
      const message = axios.isAxiosError(error)
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
    const token = localStorage.getItem('token');

    try {
      const payload = {
        ...buildCriteria(),
        batch_name: formData.batch_name || null,
        assigned_user_id: formData.assigned_user_id,
      };

      const response = await axios.post(
        `${apiUrl}/api/re_review/batch/create`,
        payload,
        { headers: { Authorization: `Bearer ${token}` } }
      );

      const result = response.data.entry;
      makeToast(
        `Batch created with ${result.entity_count} entities`,
        'Success',
        'success'
      );

      // Reset form
      resetForm();
      return true;
    } catch (error: unknown) {
      const message = axios.isAxiosError(error)
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
    formData.gene_list = [];
    formData.status_filter = null;
    formData.disease_id = null;
    formData.batch_size = 20;
    formData.assigned_user_id = null;
    previewEntities.value = [];
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

    // Options
    geneOptions,
    statusOptions,
    userOptions,

    // Preview
    previewEntities,
    previewFields,
    showPreviewModal,

    // Methods
    loadOptions,
    handlePreview,
    handleSubmit,
    resetForm,
  };
}

export default useBatchForm;
