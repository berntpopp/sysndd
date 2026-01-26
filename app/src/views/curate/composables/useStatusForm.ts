// views/curate/composables/useStatusForm.ts
/**
 * Composable for status form state management.
 * Handles form fields, validation, and submission for status modification.
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles status form state and validation
 * - Open/Closed: Extensible through configuration
 * - Interface Segregation: Exposes only necessary methods
 */

import { ref, reactive, watch } from 'vue';
import axios from 'axios';
import Status from '@/assets/js/classes/submission/submissionStatus';
import useFormDraft from '@/composables/useFormDraft';

// Types
export interface StatusFormData {
  category_id: number | null;
  comment: string;
  problematic: boolean;
  // Metadata (set after loading, not editable)
  status_id?: number;
  entity_id?: number;
  status_user_name?: string;
  status_user_role?: string;
  status_date?: string;
  re_review_status_saved?: number;
}

/**
 * Validation rules for status form fields
 */
const validationRules = {
  category_id: (value: number | null) => {
    if (!value) return 'Status category is required';
    return true;
  },
};

/**
 * Main composable for status form management
 */
export default function useStatusForm(entityId?: string | number) {
  // Loading state
  const loading = ref(false);

  // Form data state
  const formData = reactive<StatusFormData>({
    category_id: null,
    comment: '',
    problematic: false,
  });

  // Field touched state for validation display
  const touched = reactive<Record<string, boolean>>({
    category_id: false,
  });

  // Draft persistence
  const draftKey = entityId ? `status-form-${entityId}` : 'status-form-new';
  const formDraft = useFormDraft<StatusFormData>(draftKey);
  const {
    hasDraft,
    lastSavedFormatted,
    isSaving,
    saveDraft,
    loadDraft,
    clearDraft,
    checkForDraft,
    scheduleSave,
  } = formDraft;

  // Watch for form changes and auto-save drafts
  watch(
    () => ({ ...formData }),
    (newData) => {
      // Only schedule save if form has meaningful content
      if (newData.category_id !== null || newData.comment) {
        scheduleSave(newData);
      }
    },
    { deep: true },
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

    const value = formData[fieldName as keyof StatusFormData];
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
   * Load status data from API by status ID
   */
  const loadStatusData = async (statusId: number, reReviewSaved?: number): Promise<void> => {
    loading.value = true;
    const apiUrl = `${import.meta.env.VITE_API_URL}/api/status/${statusId}`;

    try {
      const response = await axios.get(apiUrl);

      if (!response.data || response.data.length === 0) {
        throw new Error('Status not found');
      }

      const statusData = response.data[0];

      // Update form data
      formData.category_id = statusData.category_id;
      formData.comment = statusData.comment || '';
      formData.problematic = statusData.problematic || false;

      // Set metadata (not editable)
      formData.status_id = statusData.status_id;
      formData.entity_id = statusData.entity_id;
      formData.status_user_name = statusData.status_user_name;
      formData.status_user_role = statusData.status_user_role;
      formData.status_date = statusData.status_date;
      formData.re_review_status_saved = reReviewSaved;
    } catch (error) {
      console.error('Failed to load status:', error);
      throw error;
    } finally {
      loading.value = false;
    }
  };

  /**
   * Load status data by entity ID (for ModifyEntity view)
   */
  const loadStatusByEntity = async (entityId: number): Promise<void> => {
    loading.value = true;
    const apiUrl = `${import.meta.env.VITE_API_URL}/api/entity/${entityId}/status`;

    try {
      const response = await axios.get(apiUrl);

      if (!response.data || response.data.length === 0) {
        throw new Error('Status not found for entity');
      }

      const statusData = response.data[0];

      // Update form data
      formData.category_id = statusData.category_id;
      formData.comment = statusData.comment || '';
      formData.problematic = statusData.problematic || false;

      // Set metadata
      formData.status_id = statusData.status_id;
      formData.entity_id = statusData.entity_id;
    } catch (error) {
      console.error('Failed to load status by entity:', error);
      throw error;
    } finally {
      loading.value = false;
    }
  };

  /**
   * Submit form to API (create or update)
   */
  const submitForm = async (isUpdate: boolean, reReview: boolean): Promise<void> => {
    // Touch all fields to show validation errors
    touchField('category_id');

    // Validate
    const categoryResult = validateField('category_id');
    if (categoryResult !== true) {
      throw new Error(categoryResult);
    }

    // Create Status object
    const statusObj: any = new Status(
      formData.category_id,
      formData.comment,
      formData.problematic,
    );
    statusObj.status_id = formData.status_id;
    statusObj.entity_id = formData.entity_id;

    // Clean up user metadata before submission
    // (server will set these based on authenticated user)
    statusObj.status_user_name = null;
    statusObj.status_user_role = null;
    statusObj.re_review_status_saved = null;

    const token = localStorage.getItem('token');

    // Determine API endpoint
    let apiUrl: string;
    if (isUpdate) {
      apiUrl = `${import.meta.env.VITE_API_URL}/api/status/update`;
      if (reReview) {
        apiUrl += '?re_review=true';
      }
    } else {
      apiUrl = `${import.meta.env.VITE_API_URL}/api/status/create`;
      if (reReview) {
        apiUrl += '?re_review=true';
      }
    }

    try {
      if (isUpdate) {
        await axios.put(
          apiUrl,
          { status_json: statusObj },
          {
            headers: {
              Authorization: `Bearer ${token}`,
            },
          },
        );
      } else {
        await axios.post(
          apiUrl,
          { status_json: statusObj },
          {
            headers: {
              Authorization: `Bearer ${token}`,
            },
          },
        );
      }

      // Clear draft on successful submission
      clearDraft();
    } catch (error) {
      console.error('Failed to submit status:', error);
      throw error;
    }
  };

  /**
   * Reset form to initial state
   */
  const resetForm = () => {
    formData.category_id = null;
    formData.comment = '';
    formData.problematic = false;
    delete formData.status_id;
    delete formData.entity_id;
    delete formData.status_user_name;
    delete formData.status_user_role;
    delete formData.status_date;
    delete formData.re_review_status_saved;

    // Reset touched state
    Object.keys(touched).forEach((key) => {
      touched[key as keyof typeof touched] = false;
    });
  };

  /**
   * Restore form data from draft
   */
  const restoreFromDraft = (): boolean => {
    const draft = loadDraft();
    if (draft) {
      Object.assign(formData, draft);
      return true;
    }
    return false;
  };

  return {
    // State
    formData,
    loading,
    touched,

    // Validation
    validateField,
    getFieldError,
    getFieldState,
    touchField,

    // API methods
    loadStatusData,
    loadStatusByEntity,
    submitForm,

    // Form management
    resetForm,

    // Draft persistence
    hasDraft,
    lastSavedFormatted,
    isSaving,
    checkForDraft,
    restoreFromDraft,
    clearDraft,
  };
}
