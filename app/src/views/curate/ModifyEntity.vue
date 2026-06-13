<!-- views/curate/ModifyEntity.vue — thin orchestration shell -->
<template>
  <AuthenticatedPageShell
    title="Modify Entity"
    description="Search for an entity, review the selected summary, then choose the edit workflow."
    content-class="authenticated-route-content"
    full-width
  >
    <div class="modify-entity-page">
      <BContainer fluid class="px-0">
        <div class="modify-entity-layout">
          <aside class="modify-entity-rail" aria-label="Entity modification controls">
            <section
              class="modify-entity-section modify-entity-section--search"
              aria-labelledby="modify-entity-search-title"
            >
              <div class="modify-entity-section__header">
                <h2 id="modify-entity-search-title">Find Entity</h2>
                <span class="modify-entity-chip">
                  <template v-if="entity_search_loading">Loading</template>
                  <template v-else-if="entity_search_results.length">
                    {{ entity_search_results.length }} results
                  </template>
                  <template v-else>Ready</template>
                </span>
              </div>

              <EntitySearchPanel
                :model-value="modify_entity_input"
                :display-value="entity_display"
                :search-results="entity_search_results"
                :loading="entity_search_loading"
                @update:model-value="onEntitySelected"
                @update:display-value="entity_display = $event"
                @search="searchEntity"
              />
              <p
                v-if="!entity_loaded && !entity_search_loading"
                class="modify-entity-empty-state"
                role="status"
              >
                Start typing to find a SysNDD entity by identifier, gene, or disease.
              </p>
            </section>
          </aside>

          <section
            class="modify-entity-section modify-entity-section--selection"
            aria-labelledby="modify-entity-selected-title"
          >
            <div class="modify-entity-section__header">
              <div>
                <h2 id="modify-entity-selected-title">Current Selection</h2>
              </div>
              <span v-if="!entity_loaded" class="modify-entity-chip"> Waiting for selection </span>
            </div>

            <EntityInfoHeader
              v-if="entity_loaded && entity_info.entity_id"
              :entity="entity_info"
              :stoplights-style="stoplights_style"
              :ndd-icon-style="ndd_icon_style"
              :ndd-icon="ndd_icon"
            />

            <div
              v-if="entity_loaded && entity_info.entity_id"
              class="modify-entity-workflow"
              aria-labelledby="modify-entity-workflow-title"
            >
              <div class="modify-entity-workflow__header">
                <h3 id="modify-entity-workflow-title">Edit Workflow</h3>
                <p>Pick one focused task. The form stays attached to this entity context.</p>
              </div>
              <div class="modify-entity-actions" aria-label="Edit workflow options">
                <BButton
                  class="modify-entity-actions__primary"
                  size="sm"
                  :variant="activeWorkflow === 'combined' ? 'primary' : 'outline-primary'"
                  :disabled="!entity_loaded || !!submitting"
                  aria-label="Modify status and review together"
                  @click="showCombinedModify"
                >
                  <BSpinner v-if="submitting === 'combined'" small class="me-1" />
                  <template v-else>
                    <i class="bi bi-stoplights" aria-hidden="true" />
                    <i class="bi bi-clipboard-plus" aria-hidden="true" />
                  </template>
                  Status &amp; Review
                </BButton>

                <BButton
                  size="sm"
                  :variant="activeWorkflow === 'rename' ? 'primary' : 'outline-primary'"
                  :disabled="!entity_loaded || !!submitting"
                  aria-label="Rename disease"
                  @click="showEntityRename"
                >
                  <BSpinner v-if="submitting === 'rename'" small class="me-1" />
                  <template v-else>
                    <i class="bi bi-pen" aria-hidden="true" />
                    <i class="bi bi-link" aria-hidden="true" />
                  </template>
                  Rename disease
                </BButton>

                <BButton
                  size="sm"
                  :variant="activeWorkflow === 'deactivate' ? 'danger' : 'outline-danger'"
                  :disabled="!entity_loaded || !!submitting"
                  aria-label="Deactivate entity"
                  @click="showEntityDeactivate"
                >
                  <BSpinner v-if="submitting === 'deactivate'" small class="me-1" />
                  <template v-else>
                    <i class="bi bi-x" aria-hidden="true" />
                    <i class="bi bi-link" aria-hidden="true" />
                  </template>
                  Deactivate entity
                </BButton>

                <BButton
                  size="sm"
                  :variant="activeWorkflow === 'review' ? 'primary' : 'outline-primary'"
                  :disabled="!entity_loaded || !!submitting"
                  aria-label="Modify review"
                  @click="showReviewModify"
                >
                  <BSpinner v-if="submitting === 'review'" small class="me-1" />
                  <template v-else>
                    <i class="bi bi-pen" aria-hidden="true" />
                    <i class="bi bi-clipboard-plus" aria-hidden="true" />
                  </template>
                  Modify review
                </BButton>

                <BButton
                  size="sm"
                  :variant="activeWorkflow === 'status' ? 'primary' : 'outline-primary'"
                  :disabled="!entity_loaded || !!submitting"
                  aria-label="Modify status"
                  @click="showStatusModify"
                >
                  <BSpinner v-if="submitting === 'status'" small class="me-1" />
                  <template v-else>
                    <i class="bi bi-pen" aria-hidden="true" />
                    <i class="bi bi-stoplights" aria-hidden="true" />
                  </template>
                  Modify status
                </BButton>
              </div>

              <InlineEntityWorkflow
                v-if="activeWorkflow && activeWorkflow !== 'combined'"
                :workflow="activeWorkflow"
                :loading="activeWorkflowLoading"
                :submitting="submitting"
                :ontology-display="ontology_display"
                :ontology-input="ontology_input"
                :ontology-search-results="ontology_search_results"
                :ontology-search-loading="ontology_search_loading"
                :deactivate-check="deactivate_check"
                :replace-check="replace_check"
                :replace-display="replace_entity_display"
                :replace-entity-input="replace_entity_input"
                :replace-search-results="replace_entity_search_results"
                :replace-search-loading="replace_entity_search_loading"
                :review="review_info"
                :select-phenotype="select_phenotype"
                :select-variation="select_variation"
                :select-additional-references="select_additional_references"
                :select-gene-reviews="select_gene_reviews"
                :phenotype-options="phenotypes_options ?? []"
                :variation-options="variation_ontology_options ?? []"
                :status-options="status_options"
                :status-options-loading="status_options_loading"
                :form-data="statusFormData"
                @update:ontology-display="ontology_display = $event"
                @search-ontology="searchOntology"
                @select-ontology="onOntologySelected"
                @update:deactivate-check="deactivate_check = $event"
                @update:replace-check="replace_check = $event"
                @update:replace-display="replace_entity_display = $event"
                @search-replacement="searchReplacementEntity"
                @select-replacement="onReplacementEntitySelected"
                @update:review="review_info = $event"
                @update:select-phenotype="select_phenotype = $event"
                @update:select-variation="select_variation = $event"
                @update:select-additional-references="select_additional_references = $event"
                @update:select-gene-reviews="select_gene_reviews = $event"
                @update:form-data="Object.assign(statusFormData, $event)"
                @submit-rename="onSubmitRename"
                @submit-deactivate="onSubmitDeactivate"
                @submit-review="onSubmitReview"
                @submit-status="onSubmitStatus"
                @cancel="clearActiveWorkflow"
              />

              <CombinedStatusReviewWorkflow
                v-if="activeWorkflow === 'combined'"
                :loading="activeWorkflowLoading"
                :submitting="submitting"
                :review="review_info"
                :select-phenotype="select_phenotype"
                :select-variation="select_variation"
                :select-additional-references="select_additional_references"
                :select-gene-reviews="select_gene_reviews"
                :phenotype-options="phenotypes_options ?? []"
                :variation-options="variation_ontology_options ?? []"
                :status-options="status_options"
                :status-options-loading="status_options_loading"
                :form-data="statusFormData"
                :direct-approval="combinedDirectApproval"
                :can-direct-approve="isCurator"
                @update:review="review_info = $event"
                @update:select-phenotype="select_phenotype = $event"
                @update:select-variation="select_variation = $event"
                @update:select-additional-references="select_additional_references = $event"
                @update:select-gene-reviews="select_gene_reviews = $event"
                @update:form-data="Object.assign(statusFormData, $event)"
                @update:direct-approval="combinedDirectApproval = $event"
                @submit="onSubmitCombined"
                @cancel="clearActiveWorkflow"
              />
            </div>

            <p
              v-else
              class="modify-entity-empty-state modify-entity-empty-state--compact"
              role="status"
            >
              No entity selected.
            </p>
          </section>
        </div>

        <!-- AriaLiveRegion for screen reader announcements -->
        <AriaLiveRegion :message="a11yMessage" :politeness="a11yPoliteness" />

        <!-- Confirm discard unsaved changes dialog -->
        <ConfirmDiscardDialog
          ref="confirmDiscardDialogRef"
          modal-id="modify-entity-confirm-discard"
          @discard="confirmDiscard"
          @keep-editing="cancelDiscard"
        />
      </BContainer>
    </div>
  </AuthenticatedPageShell>
</template>

<script lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import { computed, defineComponent, ref, watch } from 'vue';
import { useToast, useColorAndSymbols, useAriaLive } from '@/composables';
import { useAuth } from '@/composables/useAuth';
import useStatusForm from './composables/useStatusForm';
import { useEntityAutocomplete } from './composables/useEntityAutocomplete';
import { useEntityInfo } from './composables/useEntityInfo';
import { useEntityMutations } from './composables/useEntityMutations';
import { useEntityModifyModals } from './composables/useEntityModifyModals';
import { useModifyEntityLookups } from './composables/useModifyEntityLookups';
import { useModifyEntityWorkflows } from './composables/useModifyEntityWorkflows';

import EntityInfoHeader from './components/EntityInfoHeader.vue';
import EntitySearchPanel from './components/EntitySearchPanel.vue';
import InlineEntityWorkflow from './components/InlineEntityWorkflow.vue';
import CombinedStatusReviewWorkflow from './components/CombinedStatusReviewWorkflow.vue';
import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import ConfirmDiscardDialog from '@/components/ui/ConfirmDiscardDialog.vue';

export default defineComponent({
  name: 'ModifyEntity',
  components: {
    AuthenticatedPageShell,
    EntityInfoHeader,
    EntitySearchPanel,
    InlineEntityWorkflow,
    CombinedStatusReviewWorkflow,
    AriaLiveRegion,
    ConfirmDiscardDialog,
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    const { message: a11yMessage, politeness: a11yPoliteness, announce } = useAriaLive();

    // Cast makeToast to the composables' broader (...unknown[]) signature.
    // makeToast's full typed signature differs from the (...args: unknown[]) =&gt; void
    // expected by the composable interface (TOAST-SHIM cohort).
    const toastFn = makeToast as unknown as (...args: unknown[]) => void;
    const info = useEntityInfo({ onToast: toastFn });
    const search = useEntityAutocomplete({
      onToast: toastFn,
      getCurrentEntityId: () => info.entity_info.value.entity_id,
    });
    const mutations = useEntityMutations({ onToast: toastFn, onAnnounce: announce });
    const modals = useEntityModifyModals();
    const statusForm = useStatusForm();
    const { hasMinRole } = useAuth();

    // Direct approval is a Curator+ action (mirrors entity-create + the
    // /approve endpoints). The toggle is hidden for non-permitted roles and
    // re-checked server-side, so this is visibility only — never trust it.
    const isCurator = computed(() => hasMinRole('Curator'));

    // Local modal-specific state not owned by composables
    const deactivate_check = ref(false);
    const replace_check = ref(false);

    // Workflow orchestration (rename / deactivate / review / status / combined).
    const workflows = useModifyEntityWorkflows({
      info,
      search,
      mutations,
      modals,
      statusForm,
      deactivate_check,
      replace_check,
      onToast: toastFn,
      announce,
    });

    // Tree options (app-global lookup data loaded once on mount)
    const {
      phenotypes_options,
      variation_ontology_options,
      status_options,
      status_options_loading,
    } = useModifyEntityLookups({ onToast: toastFn });

    // ConfirmDiscardDialog ref — needed to programmatically show it
    const confirmDiscardDialogRef = ref<any>(null);

    // Watch pendingDiscardTarget to show/hide the confirm dialog
    watch(
      () => modals.pendingDiscardTarget.value,
      (target) => {
        if (target) {
          confirmDiscardDialogRef.value?.show();
        } else {
          confirmDiscardDialogRef.value?.hide();
        }
      }
    );

    return {
      // entity info composable
      ...info,
      // search composable
      ...search,
      // mutations composable
      ...mutations,
      // modals composable
      ...modals,
      // workflow orchestration (rename/deactivate/review/status/combined)
      ...workflows,
      // statusForm composable
      statusFormData: statusForm.formData,
      hasStatusChanges: statusForm.hasChanges,
      // combined status & review workflow (#36/#37)
      isCurator,
      // local state
      deactivate_check,
      replace_check,
      // tree options
      phenotypes_options,
      variation_ontology_options,
      status_options,
      status_options_loading,
      // a11y
      a11yMessage,
      a11yPoliteness,
      announce,
      // color/symbols
      ...colorAndSymbols,
      // backward-compat aliases (used by existing specs)
      submitEntityRename: workflows.onSubmitRename,
      submitEntityDeactivation: workflows.onSubmitDeactivate,
      // ref for confirm dialog
      confirmDiscardDialogRef,
      // static data
      makeToast,
    };
  },
});
</script>

<style scoped>
.modify-entity-page {
  min-width: 0;
}

.modify-entity-layout {
  display: grid;
  grid-template-columns: minmax(300px, 360px) minmax(0, 1fr);
  align-items: start;
  gap: 1rem;
}

.modify-entity-rail {
  display: grid;
  gap: 1rem;
}

.modify-entity-section {
  display: grid;
  gap: 0.85rem;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
  text-align: left;
}

.modify-entity-section--selection {
  min-height: 14rem;
}

.modify-entity-section--search {
  position: relative;
  z-index: 20;
}

.modify-entity-section__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.65rem 1rem;
  border-bottom: 1px solid #e6ebf2;
  background: #fff;
  text-align: left;
}

.modify-entity-section__header > div {
  min-width: 0;
}

.modify-entity-section__header h2 {
  margin: 0;
  color: #172033;
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.3;
}

.modify-entity-section__header p {
  margin: 0.15rem 0 0;
  color: #526070;
  font-size: 0.8125rem;
  line-height: 1.35;
}

.modify-entity-section > :not(.modify-entity-section__header) {
  margin-right: 1rem;
  margin-left: 1rem;
}

.modify-entity-section > :last-child {
  margin-bottom: 1rem;
}

.modify-entity-chip {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  min-height: 1.45rem;
  padding: 0.15rem 0.5rem;
  border: 1px solid #d7dee8;
  border-radius: 999px;
  background: #f8fafc;
  color: #526070;
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

.modify-entity-chip.is-selected {
  border-color: #b8d3f7;
  background: #eef6ff;
  color: #0b5cad;
}

.modify-entity-empty-state {
  margin: 0;
  color: #526070;
  font-size: 0.875rem;
  line-height: 1.45;
}

.modify-entity-empty-state--compact {
  padding-bottom: 0.75rem;
}

.modify-entity-workflow {
  display: grid;
  gap: 0.85rem;
  padding-top: 0.15rem;
}

.modify-entity-workflow__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 0.75rem;
}

.modify-entity-workflow__header h3 {
  margin: 0;
  color: #172033;
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.3;
}

.modify-entity-workflow__header p {
  margin: 0.15rem 0 0;
  color: #526070;
  font-size: 0.8125rem;
  line-height: 1.35;
}

.modify-entity-actions {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.5rem;
}

.modify-entity-actions > .btn {
  display: inline-flex;
  align-items: center;
  justify-content: flex-start;
  gap: 0.35rem;
  min-height: 2.25rem;
}

/* The combined Status & Review action is the streamlined primary path; it
   spans the full row above the four focused single-task actions. */
.modify-entity-actions__primary {
  grid-column: 1 / -1;
  justify-content: center !important;
}

.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

@media (max-width: 991.98px) {
  .modify-entity-layout {
    grid-template-columns: 1fr;
  }

  .modify-entity-rail {
    display: contents;
  }

  .modify-entity-section--search {
    order: 1;
  }

  .modify-entity-section--selection {
    order: 2;
  }
}

@media (max-width: 575.98px) {
  .modify-entity-section__header {
    flex-direction: column;
    padding: 0.8rem;
  }

  .modify-entity-section > :not(.modify-entity-section__header) {
    margin-right: 0.8rem;
    margin-left: 0.8rem;
  }

  .modify-entity-section--selection {
    min-height: 0;
  }

  .modify-entity-workflow__header {
    display: grid;
  }

  .modify-entity-actions {
    grid-template-columns: 1fr;
  }

  .modify-entity-actions > .btn {
    width: 100%;
  }
}
</style>
