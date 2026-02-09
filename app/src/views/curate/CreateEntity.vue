<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BOverlay :show="isSubmitting" rounded="sm">
        <BRow class="justify-content-md-center py-2">
          <BCol col md="12">
            <!-- Page Header -->
            <div class="page-header mb-4">
              <h4 class="mb-1">Create New Entity</h4>
              <p class="text-muted mb-0">
                Add a new gene-disease relationship to the SysNDD database
              </p>
            </div>

            <!-- Draft Recovery Alert -->
            <BAlert
              v-if="showDraftRecovery"
              variant="info"
              dismissible
              :model-value="true"
              class="mb-4"
              @dismissed="dismissDraft"
            >
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <i class="bi bi-clock-history me-2" />
                  <strong>Unsaved draft found</strong>
                  <span class="text-muted ms-2"> Last saved {{ draftLastSaved }} </span>
                </div>
                <div>
                  <BButton variant="outline-primary" size="sm" class="me-2" @click="restoreDraft">
                    Restore Draft
                  </BButton>
                  <BButton variant="outline-secondary" size="sm" @click="dismissDraft">
                    Discard
                  </BButton>
                </div>
              </div>
            </BAlert>

            <!-- Main Wizard Form -->
            <FormWizard
              :steps="steps"
              :step-labels="stepLabels"
              :current-step-index="currentStepIndex"
              :is-current-step-valid="isCurrentStepValid"
              :is-form-valid="isFormValid"
              :is-submitting="isSubmitting"
              :direct-approval="directApproval"
              :is-saving="draftIsSaving"
              :last-saved-formatted="draftLastSavedFormatted"
              @next="handleNext"
              @back="handleBack"
              @submit="handleSubmit"
              @go-to-step="handleGoToStep"
              @update:direct-approval="directApproval = $event"
            >
              <!-- Step 1: Core Entity -->
              <template #core>
                <StepCoreEntity
                  :inheritance-options="inheritanceOptions"
                  @search-gene="handleGeneSearch"
                  @search-disease="handleDiseaseSearch"
                />
              </template>

              <!-- Step 2: Evidence -->
              <template #evidence>
                <StepEvidence />
              </template>

              <!-- Step 3: Phenotype & Variation -->
              <template #phenotype>
                <StepPhenotypeVariation
                  :phenotype-options="phenotypeOptions"
                  :variation-options="variationOptions"
                />
              </template>

              <!-- Step 4: Classification -->
              <template #classification>
                <StepClassification :status-options="statusOptions" />
              </template>

              <!-- Step 5: Review -->
              <template #review>
                <StepReview
                  :inheritance-options="inheritanceOptions"
                  :status-options="statusOptions"
                  :phenotype-options="phenotypeOptions"
                  :variation-options="variationOptions"
                  @edit-step="handleGoToStep"
                />
              </template>
            </FormWizard>
          </BCol>
        </BRow>
      </BOverlay>
    </BContainer>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, provide, onMounted, watch } from 'vue';
import { BContainer, BRow, BCol, BOverlay, BAlert, BButton } from 'bootstrap-vue-next';
import axios from 'axios';

// Composables
import { useToast, type TreeNode } from '@/composables';
import useEntityForm, { type SelectOption, type EntityFormData } from '@/composables/useEntityForm';
import useFormDraft from '@/composables/useFormDraft';

// Components
import FormWizard from '@/components/forms/wizard/FormWizard.vue';
import StepCoreEntity from '@/components/forms/wizard/StepCoreEntity.vue';
import StepEvidence from '@/components/forms/wizard/StepEvidence.vue';
import StepPhenotypeVariation from '@/components/forms/wizard/StepPhenotypeVariation.vue';
import StepClassification from '@/components/forms/wizard/StepClassification.vue';
import StepReview from '@/components/forms/wizard/StepReview.vue';

// Submission classes
import Submission from '@/assets/js/classes/submission/submissionSubmission';
import Entity from '@/assets/js/classes/submission/submissionEntity';
import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

export default defineComponent({
  name: 'CreateEntity',

  components: {
    BContainer,
    BRow,
    BCol,
    BOverlay,
    BAlert,
    BButton,
    FormWizard,
    StepCoreEntity,
    StepEvidence,
    StepPhenotypeVariation,
    StepClassification,
    StepReview,
  },

  setup() {
    const { makeToast } = useToast();

    // Initialize form composable
    const entityForm = useEntityForm();
    const {
      formData,
      touched: _touched,
      currentStepIndex,
      currentStep,
      steps,
      stepLabels,
      totalSteps,
      directApproval,
      validateStep: _validateStep,
      getFieldError,
      getFieldState,
      touchField,
      isCurrentStepValid,
      isFormValid,
      nextStep,
      previousStep,
      goToStep,
      resetForm,
      getFormSnapshot,
      restoreFromSnapshot,
    } = entityForm;

    // Initialize draft composable
    const formDraft = useFormDraft<EntityFormData>('create-entity');
    const {
      hasDraft: _hasDraft,
      lastSavedFormatted: draftLastSavedFormatted,
      isSaving: draftIsSaving,
      saveDraft: _saveDraft,
      loadDraft,
      clearDraft,
      checkForDraft,
      scheduleSave,
    } = formDraft;

    // Local state
    const isSubmitting = ref(false);
    const showDraftRecovery = ref(false);
    const draftLastSaved = ref<string | null>(null);

    // Options loaded from API
    const inheritanceOptions = ref<SelectOption[]>([]);
    const phenotypeOptions = ref<TreeNode[]>([]);
    const variationOptions = ref<TreeNode[]>([]);
    const statusOptions = ref<SelectOption[]>([]);

    // Provide form state to child components
    provide('formData', formData);
    provide('getFieldError', getFieldError);
    provide('getFieldState', getFieldState);
    provide('touchField', touchField);
    provide('isFormValid', isFormValid);
    provide('directApproval', directApproval);

    // Watch form data for auto-save
    watch(
      () => getFormSnapshot(),
      (newData) => {
        scheduleSave(newData);
      },
      { deep: true }
    );

    // API helper for loading flat options (inheritance, status)
    const loadFlatOptions = async (endpoint: string, targetRef: typeof inheritanceOptions) => {
      try {
        const response = await axios.get(
          `${import.meta.env.VITE_API_URL}/api/list/${endpoint}?tree=true`,
          { withCredentials: true }
        );
        targetRef.value = flattenTreeOptions(response.data);
      } catch (e) {
        makeToast(e as Error, 'Error', 'danger');
      }
    };

    // Flatten tree options for simple selects (inheritance, status)
    const flattenTreeOptions = (
      options: { id: string; label: string; children?: unknown[] }[],
      result: SelectOption[] = []
    ): SelectOption[] => {
      options.forEach((opt) => {
        result.push({
          value: opt.id,
          text: opt.label,
        });
        if (opt.children && Array.isArray(opt.children)) {
          flattenTreeOptions(opt.children as typeof options, result);
        }
      });
      return result;
    };

    /**
     * Transform phenotype/variation tree to make all modifiers selectable children.
     * Copied from ModifyEntity.vue - API returns "present: X" as parent with
     * [uncertain, variable, rare, absent] as children. We want "X" as parent
     * with [present, uncertain, variable, rare, absent] as children.
     *
     * Output format matches TreeMultiSelect's expected { id, label, children } structure.
     */
    const transformModifierTree = (
      nodes: { id: string; label: string; children?: { id: string; label: string }[] }[]
    ): TreeNode[] => {
      return nodes.map((node) => {
        const phenotypeName = node.label.replace(/^present:\s*/, '');
        const ontologyCode = node.id.replace(/^\d+-/, '');
        return {
          id: `parent-${ontologyCode}`,
          label: phenotypeName,
          children: [
            { id: node.id, label: `present: ${phenotypeName}` },
            ...(node.children || []).map((child) => {
              const modifier = child.label.replace(/:\s*.*$/, '');
              return { id: child.id, label: `${modifier}: ${phenotypeName}` };
            }),
          ],
        };
      });
    };

    // API helper for loading tree options (phenotypes, variations)
    const loadTreeOptions = async (endpoint: string, targetRef: typeof phenotypeOptions) => {
      try {
        const response = await axios.get(
          `${import.meta.env.VITE_API_URL}/api/list/${endpoint}?tree=true`,
          { withCredentials: true }
        );
        const rawData = Array.isArray(response.data) ? response.data : response.data?.data || [];
        targetRef.value = transformModifierTree(rawData);
      } catch (e) {
        makeToast(e as Error, 'Error', 'danger');
        targetRef.value = [];
      }
    };

    // Load all options on mount
    onMounted(async () => {
      await Promise.all([
        loadFlatOptions('inheritance', inheritanceOptions),
        loadTreeOptions('phenotype', phenotypeOptions),
        loadTreeOptions('variation_ontology', variationOptions),
        loadFlatOptions('status', statusOptions),
      ]);

      // Check for existing draft
      if (checkForDraft()) {
        showDraftRecovery.value = true;
        draftLastSaved.value = draftLastSavedFormatted.value;
      }
    });

    // Gene search handler
    const handleGeneSearch = async (
      query: string,
      callback: (results: Record<string, unknown>[]) => void
    ) => {
      try {
        const response = await axios.get(
          `${import.meta.env.VITE_API_URL}/api/search/gene/${query}?tree=true`,
          { withCredentials: true }
        );
        callback(response.data);
      } catch (e) {
        makeToast(e as Error, 'Error', 'danger');
        callback([]);
      }
    };

    // Disease search handler
    const handleDiseaseSearch = async (
      query: string,
      callback: (results: Record<string, unknown>[]) => void
    ) => {
      try {
        const response = await axios.get(
          `${import.meta.env.VITE_API_URL}/api/search/ontology/${query}?tree=true`,
          { withCredentials: true }
        );
        callback(response.data);
      } catch (e) {
        makeToast(e as Error, 'Error', 'danger');
        callback([]);
      }
    };

    // Navigation handlers
    const handleNext = () => {
      nextStep();
    };

    const handleBack = () => {
      previousStep();
    };

    const handleGoToStep = (index: number) => {
      goToStep(index);
    };

    // Draft handlers
    const restoreDraft = () => {
      const draft = loadDraft();
      if (draft) {
        restoreFromSnapshot(draft);
        showDraftRecovery.value = false;
        makeToast('Draft restored successfully', 'Draft Restored', 'success');
      }
    };

    const dismissDraft = () => {
      clearDraft();
      showDraftRecovery.value = false;
    };

    // Build submission object from form data
    const buildSubmissionObject = () => {
      // Clean PMID arrays
      const cleanPMIDs = (arr: string[]) => arr.map((item) => item.replace(/\s+/g, ''));

      const literature = new Literature(
        cleanPMIDs(formData.publications),
        cleanPMIDs(formData.genereviews)
      );

      const phenotypes = formData.phenotypes.map((item) => {
        const [prefix, id] = item.split('-');
        return new Phenotype(id, prefix);
      });

      const variations = formData.variationOntology.map((item) => {
        const [prefix, id] = item.split('-');
        return new Variation(id, prefix);
      });

      const review = new Review(
        formData.synopsis,
        literature,
        phenotypes,
        variations,
        formData.comment
      );

      const status = new Status(formData.statusId, '', 0);

      const entity = new Entity(
        formData.geneId,
        formData.diseaseId,
        formData.inheritanceId,
        formData.nddPhenotype ? 1 : 0
      );

      return new Submission(entity, review, status);
    };

    // Submit handler
    const handleSubmit = async () => {
      if (!isFormValid.value) {
        makeToast('Please fix validation errors before submitting', 'Validation Error', 'warning');
        return;
      }

      isSubmitting.value = true;

      try {
        const submission = buildSubmissionObject();
        const apiUrl = `${import.meta.env.VITE_API_URL}/api/entity/create?direct_approval=${directApproval.value}`;

        const response = await axios.post(
          apiUrl,
          { create_json: submission },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
            withCredentials: true,
          }
        );

        makeToast(
          `Entity submitted successfully (status ${response.status})`,
          'Success',
          'success'
        );

        // Clear draft and reset form on success
        clearDraft();
        resetForm();
      } catch (e) {
        makeToast(e as Error, 'Submission Error', 'danger');
      } finally {
        isSubmitting.value = false;
      }
    };

    return {
      // Form state
      formData,
      currentStepIndex,
      currentStep,
      steps,
      stepLabels,
      totalSteps,
      directApproval,
      isCurrentStepValid,
      isFormValid,
      isSubmitting,

      // Draft state
      showDraftRecovery,
      draftLastSaved,
      draftIsSaving,
      draftLastSavedFormatted,

      // Options
      inheritanceOptions,
      phenotypeOptions,
      variationOptions,
      statusOptions,

      // Handlers
      handleNext,
      handleBack,
      handleGoToStep,
      handleGeneSearch,
      handleDiseaseSearch,
      handleSubmit,
      restoreDraft,
      dismissDraft,
    };
  },
});
</script>

<style scoped>
.page-header {
  border-bottom: 1px solid #e9ecef;
  padding-bottom: 1rem;
}

.page-header h4 {
  font-weight: 600;
}
</style>
