// views/curate/composables/useReviewForm.ts
/**
 * Composable for review form state management.
 * Handles form fields, validation, API loading, and submission logic for review forms.
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles review form state and operations
 * - Open/Closed: Extensible through configuration
 * - Interface Segregation: Exposes only necessary methods
 *
 * Based on useEntityForm pattern for consistency.
 */

import { ref, reactive, computed, watch } from 'vue';
import axios from 'axios';
import Review from '@/assets/js/classes/submission/submissionReview';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';
import useFormDraft from '@/composables/useFormDraft';

// Types
export interface ReviewFormData {
  synopsis: string;
  phenotypes: string[]; // Format: "modifier_id-phenotype_id"
  variationOntology: string[]; // Format: "modifier_id-vario_id"
  publications: string[]; // PMID format
  genereviews: string[]; // PMID format
  comment: string;
}

/**
 * Review submission data shape (Review class instance + metadata added before submission)
 */
interface ReviewSubmissionData {
  synopsis: string;
  literature: unknown;
  phenotypes: unknown[];
  variation_ontology: unknown[];
  comment: string;
  review_id?: number | null;
  entity_id?: number | null;
}

/**
 * PMID tag validator
 */
export function validatePMID(tag: string): boolean {
  const cleanTag = tag.replace(/\s+/g, '');
  const pmidNumber = cleanTag.replace('PMID:', '');
  return (
    !Number.isNaN(Number(pmidNumber)) &&
    cleanTag.includes('PMID:') &&
    pmidNumber.length > 4 &&
    pmidNumber.length < 9
  );
}

/**
 * Sanitize PMID input by removing extra whitespace
 * Input: "PMID: 123456" -> Output: "PMID:123456"
 */
function sanitizePMID(input: string): string {
  if (!input) return '';
  const parts = input.split(':');
  if (parts.length !== 2 || !parts[0].trim().startsWith('PMID')) return input;
  return `${parts[0].trim()}:${parts[1].trim()}`;
}

/**
 * Validation rules for review form fields
 */
const validationRules = {
  synopsis: (value: string) => {
    if (!value || value.trim().length === 0) return 'Synopsis is required';
    if (value.length < 10) return 'Synopsis must be at least 10 characters';
    if (value.length > 5000) return 'Synopsis must be less than 5000 characters';
    return true;
  },
  publications: (value: string[]) => {
    // Validate each PMID format
    const invalidPMIDs = value.filter((pmid) => !validatePMID(pmid));
    if (invalidPMIDs.length > 0) {
      return `Invalid PMID format: ${invalidPMIDs.join(', ')}`;
    }
    return true;
  },
  genereviews: (value: string[]) => {
    // Validate each PMID format
    const invalidPMIDs = value.filter((pmid) => !validatePMID(pmid));
    if (invalidPMIDs.length > 0) {
      return `Invalid PMID format: ${invalidPMIDs.join(', ')}`;
    }
    return true;
  },
};

/**
 * Main composable for review form management
 */
export default function useReviewForm(entityId?: string | number) {
  // Form data state
  const formData = reactive<ReviewFormData>({
    synopsis: '',
    phenotypes: [],
    variationOntology: [],
    publications: [],
    genereviews: [],
    comment: '',
  });

  // Track loaded data for change detection
  const loadedData = ref<{
    synopsis: string;
    comment: string;
    phenotypes: string[];
    variationOntology: string[];
    publications: string[];
    genereviews: string[];
  } | null>(null);

  /**
   * Helper function for array comparison
   */
  function arraysEqual(a: string[], b: string[]): boolean {
    if (a.length !== b.length) return false;
    return a.every((val, idx) => val === b[idx]);
  }

  // Change detection
  const hasChanges = computed(() => {
    if (!loadedData.value) return false;
    return (
      formData.synopsis !== loadedData.value.synopsis ||
      formData.comment !== loadedData.value.comment ||
      !arraysEqual(formData.phenotypes, loadedData.value.phenotypes) ||
      !arraysEqual(formData.variationOntology, loadedData.value.variationOntology) ||
      !arraysEqual(formData.publications, loadedData.value.publications) ||
      !arraysEqual(formData.genereviews, loadedData.value.genereviews)
    );
  });

  // Field touched state for validation display
  const touched = reactive<Record<string, boolean>>({
    synopsis: false,
    publications: false,
    genereviews: false,
  });

  // Loading state
  const loading = ref(false);

  // Internal state for tracking review metadata
  const reviewId = ref<number | null>(null);
  const entityIdRef = ref<number | null>(null);

  // BUG-05 fix: Store originally loaded publications to ensure they're never accidentally deleted
  // When submitting, we merge original publications with any user additions
  const originalPublications = ref<string[]>([]);
  const originalGenereviews = ref<string[]>([]);

  // Draft persistence (key includes entity ID for entity-specific drafts)
  const draftKey = entityId ? `review-form-${entityId}` : 'review-form-new';
  const formDraft = useFormDraft<ReviewFormData>(draftKey);
  const {
    hasDraft,
    lastSavedFormatted,
    isSaving,
    loadDraft,
    clearDraft,
    checkForDraft,
    scheduleSave,
  } = formDraft;

  // Watch for form changes and auto-save drafts
  // Note: Watch formData directly, not via getFormSnapshot (which isn't defined yet)
  watch(
    formData,
    (newData) => {
      // Only schedule save if form has meaningful content
      if (newData.synopsis || newData.phenotypes.length || newData.publications.length) {
        scheduleSave({ ...newData });
      }
    },
    { deep: true }
  );

  /**
   * Mark a field as touched (for validation display)
   */
  const touchField = (fieldName: keyof typeof touched) => {
    touched[fieldName] = true;
  };

  /**
   * Validate a single field
   */
  const validateField = (fieldName: keyof typeof validationRules): string | true => {
    const validator = validationRules[fieldName];
    if (!validator) return true;

    const value = formData[fieldName as keyof ReviewFormData];
    return validator(value as never);
  };

  /**
   * Get field error if touched and invalid
   */
  const getFieldError = (fieldName: keyof typeof validationRules): string | null => {
    if (!touched[fieldName]) return null;
    const result = validateField(fieldName);
    return result === true ? null : result;
  };

  /**
   * Get field validation state for Bootstrap components
   */
  const getFieldState = (fieldName: keyof typeof validationRules): boolean | null => {
    if (!touched[fieldName]) return null;
    return validateField(fieldName) === true;
  };

  /**
   * Check if form is valid for submission
   */
  const isFormValid = computed(() => {
    return validateField('synopsis') === true;
  });

  /**
   * Load review data from API
   */
  const loadReviewData = async (
    reviewIdInput: number,
    _reReviewReviewSaved?: number
  ): Promise<void> => {
    loading.value = true;
    reviewId.value = reviewIdInput;

    const apiGetReviewURL = `${import.meta.env.VITE_API_URL}/api/review/${reviewIdInput}`;
    const apiGetPhenotypesURL = `${import.meta.env.VITE_API_URL}/api/review/${reviewIdInput}/phenotypes`;
    const apiGetVariationURL = `${import.meta.env.VITE_API_URL}/api/review/${reviewIdInput}/variation`;
    const apiGetPublicationsURL = `${import.meta.env.VITE_API_URL}/api/review/${reviewIdInput}/publications`;

    try {
      const [responseReview, responsePhenotypes, responseVariation, responsePublications] =
        await Promise.all([
          axios.get(apiGetReviewURL, { withCredentials: true }),
          axios.get(apiGetPhenotypesURL, { withCredentials: true }),
          axios.get(apiGetVariationURL, { withCredentials: true }),
          axios.get(apiGetPublicationsURL, { withCredentials: true }),
        ]);

      // Load synopsis and comment
      if (responseReview.data && responseReview.data.length > 0) {
        formData.synopsis = responseReview.data[0].synopsis || '';
        formData.comment = responseReview.data[0].comment || '';
        entityIdRef.value = responseReview.data[0].entity_id;
      }

      // Load phenotypes (format: "modifier_id-phenotype_id")
      formData.phenotypes = responsePhenotypes.data.map(
        (item: { phenotype_id: number; modifier_id: number }) =>
          `${item.modifier_id}-${item.phenotype_id}`
      );

      // Load variation ontology (format: "modifier_id-vario_id")
      formData.variationOntology = responseVariation.data.map(
        (item: { vario_id: number; modifier_id: number }) => `${item.modifier_id}-${item.vario_id}`
      );

      // Load publications (filter by type)
      const publicationsData = responsePublications.data as Array<{
        publication_id: string;
        publication_type: string;
      }>;

      formData.genereviews = publicationsData
        .filter((item) => item.publication_type === 'gene_review')
        .map((item) => item.publication_id);

      formData.publications = publicationsData
        .filter((item) => item.publication_type === 'additional_references')
        .map((item) => item.publication_id);

      // BUG-05 fix: Store original publications to preserve them during submission
      // This ensures existing publications are never accidentally deleted even if
      // there are reactivity issues with the form bindings
      originalPublications.value = [...formData.publications];
      originalGenereviews.value = [...formData.genereviews];

      // Snapshot loaded values for change detection
      loadedData.value = {
        synopsis: formData.synopsis,
        comment: formData.comment,
        phenotypes: [...formData.phenotypes],
        variationOntology: [...formData.variationOntology],
        publications: [...formData.publications],
        genereviews: [...formData.genereviews],
      };

      loading.value = false;
    } catch (error) {
      loading.value = false;
      throw error;
    }
  };

  /**
   * Submit form (create or update review)
   */
  const submitForm = async (isUpdate: boolean, reReview: boolean): Promise<void> => {
    // Touch all fields for validation
    touchField('synopsis');
    touchField('publications');
    touchField('genereviews');

    // Validate before submit
    if (!isFormValid.value) {
      throw new Error('Form validation failed');
    }

    // BUG-05 fix: Merge original publications with current form data
    // This ensures existing publications are preserved even if there are reactivity issues
    // Use Set to deduplicate and preserve both original and newly added publications
    const mergedPublications = [
      ...new Set([...originalPublications.value, ...formData.publications]),
    ];
    const mergedGenereviews = [...new Set([...originalGenereviews.value, ...formData.genereviews])];

    // Sanitize PMIDs
    const cleanPublications = mergedPublications.map(sanitizePMID);
    const cleanGenereviews = mergedGenereviews.map(sanitizePMID);

    // Transform form data to API format
    const literature = new Literature(cleanPublications, cleanGenereviews);

    const phenotypes = formData.phenotypes.map((item) => {
      const [modifierId, phenotypeId] = item.split('-');
      return new Phenotype(Number(phenotypeId), Number(modifierId));
    });

    const variations = formData.variationOntology.map((item) => {
      const [modifierId, varioId] = item.split('-');
      return new Variation(Number(varioId), Number(modifierId));
    });

    const reviewData = new Review(
      formData.synopsis,
      literature,
      phenotypes,
      variations,
      formData.comment
    );

    // Add metadata
    const reviewSubmission = reviewData as ReviewSubmissionData;
    reviewSubmission.review_id = reviewId.value;
    reviewSubmission.entity_id = entityIdRef.value;

    // Determine API endpoint
    const method = isUpdate ? 'put' : 'post';
    const action = isUpdate ? 'update' : 'create';
    const apiUrl = `${import.meta.env.VITE_API_URL}/api/review/${action}?re_review=${reReview}`;

    // Submit to API
    await axios[method](
      apiUrl,
      { review_json: reviewData },
      {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
        },
        withCredentials: true,
      }
    );

    // Clear draft on successful submission
    clearDraft();
  };

  /**
   * Reset form to initial state
   */
  const resetForm = () => {
    formData.synopsis = '';
    formData.phenotypes = [];
    formData.variationOntology = [];
    formData.publications = [];
    formData.genereviews = [];
    formData.comment = '';

    // Reset touched state
    Object.keys(touched).forEach((key) => {
      touched[key as keyof typeof touched] = false;
    });

    // Reset internal state
    reviewId.value = null;
    entityIdRef.value = null;

    // BUG-05 fix: Clear original publications on form reset
    originalPublications.value = [];
    originalGenereviews.value = [];

    // Clear loaded data snapshot
    loadedData.value = null;
  };

  /**
   * Get form data as serializable object (for drafts)
   */
  const getFormSnapshot = (): ReviewFormData => {
    return { ...formData };
  };

  /**
   * Restore form data from snapshot
   */
  const restoreFromSnapshot = (snapshot: Partial<ReviewFormData>) => {
    Object.assign(formData, snapshot);
  };

  /**
   * Restore form data from draft
   */
  const restoreFromDraft = (): boolean => {
    const draft = loadDraft();
    if (draft) {
      restoreFromSnapshot(draft);
      return true;
    }
    return false;
  };

  return {
    // State
    formData,
    touched,
    loading,

    // Change detection
    hasChanges,

    // Validation
    validateField,
    getFieldError,
    getFieldState,
    isFormValid,
    touchField,

    // PMID validation
    validatePMID,

    // API operations
    loadReviewData,
    submitForm,

    // Form management
    resetForm,
    getFormSnapshot,
    restoreFromSnapshot,

    // Draft persistence
    hasDraft,
    lastSavedFormatted,
    isSaving,
    checkForDraft,
    restoreFromDraft,
    clearDraft,
  };
}
