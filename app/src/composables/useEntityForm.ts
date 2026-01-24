// composables/useEntityForm.ts
/**
 * Composable for entity creation form state management.
 * Handles form fields, validation, and step-based validation for the wizard.
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles form state and validation
 * - Open/Closed: Extensible through configuration
 * - Interface Segregation: Exposes only necessary methods
 */

import { ref, computed, reactive, watch } from 'vue';
import { useForm, useField } from 'vee-validate';
import { required, min, max } from '@vee-validate/rules';

// Types
export interface GeneSearchResult {
  id: string;
  symbol: string;
  name: string;
}

export interface OntologySearchResult {
  id: string;
  disease_ontology_name: string;
}

export interface SelectOption {
  value: string | number | null;
  text: string;
  disabled?: boolean;
}

export interface SelectOptionGroup {
  label: string;
  options: SelectOption[];
}

export type GroupedSelectOptions = (SelectOption | SelectOptionGroup)[];

export interface EntityFormData {
  // Step 1: Core Entity
  geneId: string | null;
  geneDisplay: string;
  diseaseId: string | null;
  diseaseDisplay: string;
  inheritanceId: string | null;
  nddPhenotype: boolean | null;
  // Step 2: Evidence
  publications: string[];
  genereviews: string[];
  synopsis: string;
  // Step 3: Phenotype & Variation
  phenotypes: string[];
  variationOntology: string[];
  // Step 4: Classification
  statusId: string | null;
  comment: string;
}

export interface StepValidation {
  isValid: boolean;
  errors: string[];
}

export type WizardStep = 'core' | 'evidence' | 'phenotype' | 'classification' | 'review';

const WIZARD_STEPS: WizardStep[] = ['core', 'evidence', 'phenotype', 'classification', 'review'];

const STEP_LABELS: Record<WizardStep, string> = {
  core: 'Core Entity',
  evidence: 'Evidence',
  phenotype: 'Phenotype & Variation',
  classification: 'Classification',
  review: 'Review & Submit',
};

/**
 * Validation rules for each form field
 */
const validationRules = {
  geneId: (value: string | null) => {
    if (!value) return 'Gene is required';
    return true;
  },
  diseaseId: (value: string | null) => {
    if (!value) return 'Disease is required';
    return true;
  },
  inheritanceId: (value: string | null) => {
    if (!value) return 'Inheritance pattern is required';
    return true;
  },
  nddPhenotype: (value: boolean | null) => {
    if (value === null) return 'NDD phenotype selection is required';
    return true;
  },
  synopsis: (value: string) => {
    if (!value || value.trim().length === 0) return 'Synopsis is required';
    if (value.length < 10) return 'Synopsis must be at least 10 characters';
    if (value.length > 2000) return 'Synopsis must be less than 2000 characters';
    return true;
  },
  publications: (value: string[]) => {
    if (!value || value.length === 0) return 'At least one publication is required';
    return true;
  },
  statusId: (value: string | null) => {
    if (!value) return 'Status is required';
    return true;
  },
};

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
 * Main composable for entity form management
 */
export default function useEntityForm() {
  // Current wizard step
  const currentStepIndex = ref(0);
  const currentStep = computed(() => WIZARD_STEPS[currentStepIndex.value]);

  // Form data state
  const formData = reactive<EntityFormData>({
    geneId: null,
    geneDisplay: '',
    diseaseId: null,
    diseaseDisplay: '',
    inheritanceId: null,
    nddPhenotype: null,
    publications: [],
    genereviews: [],
    synopsis: '',
    phenotypes: [],
    variationOntology: [],
    statusId: null,
    comment: '',
  });

  // Field touched state for validation display
  const touched = reactive<Record<string, boolean>>({
    geneId: false,
    diseaseId: false,
    inheritanceId: false,
    nddPhenotype: false,
    synopsis: false,
    publications: false,
    statusId: false,
  });

  // Direct approval toggle
  const directApproval = ref(false);

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

    const value = formData[fieldName as keyof EntityFormData];
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
   * Validate fields for a specific step
   */
  const validateStep = (step: WizardStep): StepValidation => {
    const errors: string[] = [];

    switch (step) {
      case 'core':
        ['geneId', 'diseaseId', 'inheritanceId', 'nddPhenotype'].forEach((field) => {
          const result = validateField(field as keyof typeof validationRules);
          if (result !== true) errors.push(result);
        });
        break;

      case 'evidence':
        ['publications', 'synopsis'].forEach((field) => {
          const result = validateField(field as keyof typeof validationRules);
          if (result !== true) errors.push(result);
        });
        break;

      case 'phenotype':
        // Optional step, no required fields
        break;

      case 'classification':
        const statusResult = validateField('statusId');
        if (statusResult !== true) errors.push(statusResult);
        break;

      case 'review':
        // Review step validates all previous steps
        break;
    }

    return {
      isValid: errors.length === 0,
      errors,
    };
  };

  /**
   * Check if current step is valid
   */
  const isCurrentStepValid = computed(() => {
    return validateStep(currentStep.value).isValid;
  });

  /**
   * Touch all fields in a step
   */
  const touchStepFields = (step: WizardStep) => {
    switch (step) {
      case 'core':
        touched.geneId = true;
        touched.diseaseId = true;
        touched.inheritanceId = true;
        touched.nddPhenotype = true;
        break;
      case 'evidence':
        touched.publications = true;
        touched.synopsis = true;
        break;
      case 'classification':
        touched.statusId = true;
        break;
    }
  };

  /**
   * Navigate to next step (with validation)
   */
  const nextStep = (): boolean => {
    touchStepFields(currentStep.value);

    if (!isCurrentStepValid.value) {
      return false;
    }

    if (currentStepIndex.value < WIZARD_STEPS.length - 1) {
      currentStepIndex.value++;
      return true;
    }
    return false;
  };

  /**
   * Navigate to previous step
   */
  const previousStep = (): boolean => {
    if (currentStepIndex.value > 0) {
      currentStepIndex.value--;
      return true;
    }
    return false;
  };

  /**
   * Go to a specific step (for editing from review)
   */
  const goToStep = (stepIndex: number) => {
    if (stepIndex >= 0 && stepIndex < WIZARD_STEPS.length) {
      currentStepIndex.value = stepIndex;
    }
  };

  /**
   * Check if all form data is valid for submission
   */
  const isFormValid = computed(() => {
    return (
      validateStep('core').isValid &&
      validateStep('evidence').isValid &&
      validateStep('classification').isValid
    );
  });

  /**
   * Synopsis character count and remaining
   */
  const synopsisCharCount = computed(() => formData.synopsis.length);
  const synopsisCharsRemaining = computed(() => 2000 - formData.synopsis.length);

  /**
   * Reset form to initial state
   */
  const resetForm = () => {
    formData.geneId = null;
    formData.geneDisplay = '';
    formData.diseaseId = null;
    formData.diseaseDisplay = '';
    formData.inheritanceId = null;
    formData.nddPhenotype = null;
    formData.publications = [];
    formData.genereviews = [];
    formData.synopsis = '';
    formData.phenotypes = [];
    formData.variationOntology = [];
    formData.statusId = null;
    formData.comment = '';

    // Reset touched state
    Object.keys(touched).forEach((key) => {
      touched[key as keyof typeof touched] = false;
    });

    // Reset wizard
    currentStepIndex.value = 0;
    directApproval.value = false;
  };

  /**
   * Get form data as serializable object (for submission/draft)
   */
  const getFormSnapshot = (): EntityFormData => {
    return { ...formData };
  };

  /**
   * Restore form data from snapshot
   */
  const restoreFromSnapshot = (snapshot: Partial<EntityFormData>) => {
    Object.assign(formData, snapshot);
  };

  return {
    // State
    formData,
    touched,
    currentStepIndex,
    currentStep,
    directApproval,

    // Step info
    steps: WIZARD_STEPS,
    stepLabels: STEP_LABELS,
    totalSteps: WIZARD_STEPS.length,

    // Validation
    validateField,
    validateStep,
    getFieldError,
    getFieldState,
    isCurrentStepValid,
    isFormValid,
    touchField,
    touchStepFields,

    // Navigation
    nextStep,
    previousStep,
    goToStep,

    // Synopsis helpers
    synopsisCharCount,
    synopsisCharsRemaining,

    // PMID validation
    validatePMID,

    // Form management
    resetForm,
    getFormSnapshot,
    restoreFromSnapshot,
  };
}
