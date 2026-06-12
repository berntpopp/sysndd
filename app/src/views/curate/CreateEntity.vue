<template>
  <AuthenticatedPageShell
    title="Create Entity"
    description="Add a new gene-disease relationship to the SysNDD database."
    content-class="authenticated-route-content"
    full-width
  >
    <div class="create-entity-page">
      <BOverlay :show="isSubmitting" rounded="sm">
        <div class="create-entity-page__inner">
          <BAlert
            v-if="showDraftRecovery"
            variant="info"
            dismissible
            :model-value="true"
            class="create-entity-page__draft-alert"
            @dismissed="dismissDraft"
          >
            <div class="create-entity-page__draft">
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
        </div>
      </BOverlay>
    </div>
  </AuthenticatedPageShell>
</template>

<script lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import { defineComponent, ref, provide, onMounted, watch } from 'vue';
import { BOverlay, BAlert, BButton } from 'bootstrap-vue-next';

// Composables
import { useToast } from '@/composables';
import useEntityForm, { type EntityFormData } from '@/composables/useEntityForm';
import useFormDraft from '@/composables/useFormDraft';
import useEntityCreateOptions from '@/composables/useEntityCreateOptions';

// Typed API clients
import {
  searchGene,
  searchOntology,
  type GeneSearchTreeNode,
  type OntologyTreeNode,
} from '@/api/search';
import { createEntity, type EntityCreatePayload } from '@/api/entity';

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
    AuthenticatedPageShell,
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

    // Entity option trees (inheritance / phenotype / variation / status),
    // loaded from the typed list API in a dedicated composable.
    const {
      inheritanceOptions,
      phenotypeOptions,
      variationOptions,
      statusOptions,
      loadAllOptions,
    } = useEntityCreateOptions();

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

    // Load all options on mount
    onMounted(async () => {
      await loadAllOptions();

      // Check for existing draft
      if (checkForDraft()) {
        showDraftRecovery.value = true;
        draftLastSaved.value = draftLastSavedFormatted.value;
      }
    });

    // Gene search handler. With the W7-followup overload, passing
    // `{ tree: true }` to `searchGene` narrows the return type to
    // `GeneSearchTreeNode[]`, which is structurally assignable to the
    // `Record<string, unknown>[]` callback contract emitted by the
    // `<StepCoreEntity>` wrapper.
    const handleGeneSearch = async (
      query: string,
      callback: (results: GeneSearchTreeNode[]) => void
    ) => {
      try {
        const data = await searchGene(query, { tree: true });
        callback(data);
      } catch (e) {
        makeToast(e as Error, 'Error', 'danger');
        callback([]);
      }
    };

    // Disease search handler — same overload-narrowing pattern as above.
    const handleDiseaseSearch = async (
      query: string,
      callback: (results: OntologyTreeNode[]) => void
    ) => {
      try {
        const data = await searchOntology(query, { tree: true });
        callback(data);
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

    // Build submission object from form data. The JS-side submission
    // classes (`Submission`, `Entity`, ...) drive the runtime shape; this
    // function returns the same payload but typed against the API
    // contract so the `createEntity()` call site can drop its
    // `as unknown as Parameters<typeof createEntity>[0]['create_json']`
    // cast in favour of a single, named `EntityCreatePayload` reference.
    const buildSubmissionObject = (): EntityCreatePayload => {
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

      // The JS classes have no TS surface; the resulting `Submission`
      // instance is structurally compatible with `EntityCreatePayload`
      // (TS classes vs. plain interfaces — JSON serialisation flattens
      // both to the same wire shape). Cast through the typed contract
      // so any future divergence in `EntityCreatePayload` surfaces here
      // rather than at the call site.
      return new Submission(entity, review, status) as unknown as EntityCreatePayload;
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

        // v11.0 closeout F2a: the inline Authorization header construction
        // here has been removed. The `apiClient` request interceptor
        // (`@/api/client`) reads `useAuth().token.value` and injects the
        // Bearer header on every outbound call against the shared axios
        // singleton.
        await createEntity({ create_json: submission }, { direct_approval: directApproval.value });

        makeToast('Entity submitted successfully', 'Success', 'success');

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
.create-entity-page {
  min-width: 0;
}

.create-entity-page__inner {
  width: min(100%, 1180px);
  margin: 0 auto;
}

.create-entity-page__draft-alert {
  margin-bottom: 1rem;
}

.create-entity-page__draft {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.create-entity-page :deep(.form-wizard) {
  max-width: 100%;
}

.create-entity-page :deep(.wizard-progress) {
  overflow-x: auto;
  padding: 0.1rem 0.15rem 0.65rem;
}

.create-entity-page :deep(.wizard-steps) {
  min-width: 620px;
}

.create-entity-page :deep(.wizard-content) {
  margin-bottom: 1rem !important;
}

.create-entity-page :deep(.wizard-navigation) {
  position: static;
  flex-wrap: wrap;
  gap: 0.6rem;
  padding: 0;
  border: 0;
  background: transparent;
  box-shadow: none;
}

.create-entity-page :deep(.wizard-navigation > .d-flex) {
  flex-wrap: wrap;
  justify-content: flex-end;
}

.create-entity-page :deep(.step-core-entity),
.create-entity-page :deep(.step-evidence),
.create-entity-page :deep(.step-phenotype-variation),
.create-entity-page :deep(.step-classification),
.create-entity-page :deep(.step-review) {
  max-width: none;
}

.create-entity-page :deep(.step-core-entity),
.create-entity-page :deep(.step-evidence),
.create-entity-page :deep(.step-phenotype-variation),
.create-entity-page :deep(.step-classification__grid) {
  display: grid;
  gap: 0.85rem 1rem;
}

.create-entity-page :deep(.step-core-entity) {
  grid-template-columns:
    minmax(11rem, 1fr)
    minmax(16rem, 1.35fr)
    minmax(12rem, 1fr)
    minmax(8rem, 0.55fr);
  align-items: start;
}

.create-entity-page :deep(.step-evidence),
.create-entity-page :deep(.step-phenotype-variation),
.create-entity-page :deep(.step-classification__grid) {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.create-entity-page :deep(.step-classification__grid) {
  grid-template-columns: minmax(14rem, 0.55fr) minmax(0, 1.45fr);
}

.create-entity-page :deep(.step-evidence__synopsis),
.create-entity-page :deep(.step-evidence__synopsis) {
  grid-column: 1 / -1;
}

.create-entity-page :deep(.form-text),
.create-entity-page :deep(small.text-muted) {
  color: #64748b !important;
  font-size: 0.76rem;
}

@media (max-width: 575.98px) {
  .create-entity-page__draft {
    align-items: flex-start;
    flex-direction: column;
  }

  .create-entity-page :deep(.wizard-steps) {
    min-width: 0;
  }

  .create-entity-page :deep(.wizard-navigation) {
    bottom: calc(var(--app-footer-height, 48px) + 0.35rem);
    align-items: stretch !important;
  }

  .create-entity-page :deep(.wizard-navigation > .d-flex),
  .create-entity-page :deep(.wizard-navigation button) {
    width: 100%;
  }

  .create-entity-page :deep(.step-core-entity),
  .create-entity-page :deep(.step-evidence),
  .create-entity-page :deep(.step-phenotype-variation),
  .create-entity-page :deep(.step-classification__grid) {
    grid-template-columns: 1fr;
  }
}
</style>
