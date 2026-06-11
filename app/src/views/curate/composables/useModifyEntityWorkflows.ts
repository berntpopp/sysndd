// app/src/views/curate/composables/useModifyEntityWorkflows.ts
/**
 * Orchestrates the ModifyEntity edit workflows (rename, deactivate, review,
 * status, and the combined Status & Review flow — issues #36 / #37).
 *
 * Extracted from ModifyEntity.vue to keep the thin-shell view under the
 * file-size ceiling. Owns `activeWorkflow`, the per-workflow show/submit
 * handlers, and the combined-flow orchestration; depends on the entity-info,
 * autocomplete, mutations, modals, and status-form composables passed in.
 */

import { computed, ref, type Ref } from 'vue';
import { useCombinedStatusReview } from './useCombinedStatusReview';
import type { useEntityInfo } from './useEntityInfo';
import type { useEntityAutocomplete } from './useEntityAutocomplete';
import type { useEntityMutations } from './useEntityMutations';
import type { useEntityModifyModals } from './useEntityModifyModals';
import type useStatusForm from './useStatusForm';

export type WorkflowKind = 'rename' | 'deactivate' | 'review' | 'status' | 'combined';

export interface UseModifyEntityWorkflowsDeps {
  info: ReturnType<typeof useEntityInfo>;
  search: ReturnType<typeof useEntityAutocomplete>;
  mutations: ReturnType<typeof useEntityMutations>;
  modals: ReturnType<typeof useEntityModifyModals>;
  statusForm: ReturnType<typeof useStatusForm>;
  deactivate_check: Ref<boolean>;
  replace_check: Ref<boolean>;
  onToast: (...args: unknown[]) => void;
  announce: (msg: string, politeness?: 'polite' | 'assertive') => void;
}

export function useModifyEntityWorkflows(deps: UseModifyEntityWorkflowsDeps) {
  const { info, search, mutations, modals, statusForm, deactivate_check, replace_check } = deps;
  const { onToast, announce } = deps;

  const activeWorkflow = ref<WorkflowKind | null>(null);
  const combinedLoading = ref(false);

  const combined = useCombinedStatusReview(
    {
      hasReviewChanges: info.hasReviewChanges,
      hasStatusChanges: statusForm.hasChanges,
      getReviewArgs: () => ({
        review_info: info.review_info.value,
        select_phenotype: info.select_phenotype.value,
        select_variation: info.select_variation.value,
        select_additional_references: info.select_additional_references.value,
        select_gene_reviews: info.select_gene_reviews.value,
      }),
      submitReview: (args) => mutations.submitReview(args as never),
      submitStatus: (isUpdate, reReview, directApproval) =>
        statusForm.submitForm(isUpdate, reReview, directApproval),
    },
    {
      onToast,
      onAnnounce: announce,
      setSubmittingState: (state) => mutations.setSubmittingState(state),
    }
  );

  const activeWorkflowLoading = computed(() => {
    switch (activeWorkflow.value) {
      case 'rename':
        return modals.loadingRename.value;
      case 'deactivate':
        return modals.loadingDeactivate.value;
      case 'review':
        return modals.loadingReview.value;
      case 'status':
        return modals.loadingStatus.value;
      case 'combined':
        return combinedLoading.value;
      default:
        return false;
    }
  });

  function clearActiveWorkflow(): void {
    activeWorkflow.value = null;
    combined.reset();
    modals.close();
  }

  async function showEntityRename(): Promise<void> {
    activeWorkflow.value = 'rename';
    modals.setLoading('rename', true);
    search.ontology_input.value = null;
    search.ontology_display.value = '';
    search.ontology_search_results.value = [];
    modals.setLoading('rename', false);
  }

  async function showEntityDeactivate(): Promise<void> {
    deactivate_check.value = false;
    replace_check.value = false;
    search.replace_entity_input.value = null;
    search.replace_entity_display.value = '';
    // Clear stale autocomplete results so the dropdown doesn't open with
    // leftover suggestions from a previous deactivation attempt.
    search.replace_entity_search_results.value = [];
    search.replace_entity_search_loading.value = false;
    activeWorkflow.value = 'deactivate';
    modals.setLoading('deactivate', false);
  }

  async function showReviewModify(): Promise<void> {
    activeWorkflow.value = 'review';
    modals.setLoading('review', true);
    await info.loadReview(info.entity_info.value.entity_id);
    modals.setLoading('review', false);
  }

  async function showStatusModify(): Promise<void> {
    statusForm.resetForm();
    activeWorkflow.value = 'status';
    modals.setLoading('status', true);
    await statusForm.loadStatusByEntity(info.entity_info.value.entity_id);
    modals.setLoading('status', false);
  }

  // Combined Status & Review workflow (issue #36): load BOTH the review and the
  // status so the curator can edit them together in one panel.
  async function showCombinedModify(): Promise<void> {
    statusForm.resetForm();
    combined.reset();
    activeWorkflow.value = 'combined';
    combinedLoading.value = true;
    try {
      const entityId = info.entity_info.value.entity_id;
      await Promise.all([info.loadReview(entityId), statusForm.loadStatusByEntity(entityId)]);
    } finally {
      combinedLoading.value = false;
    }
  }

  function reviewArgs() {
    return {
      review_info: info.review_info.value,
      select_phenotype: info.select_phenotype.value,
      select_variation: info.select_variation.value,
      select_additional_references: info.select_additional_references.value,
      select_gene_reviews: info.select_gene_reviews.value,
    };
  }

  function clearSelection(): void {
    clearActiveWorkflow();
    info.reset();
    search.clearAll();
  }

  async function onSubmitRename(): Promise<void> {
    try {
      await mutations.rename({
        entity_info: info.entity_info.value,
        ontology_input: search.ontology_input.value,
      });
      clearSelection();
    } catch {
      // error already toasted in composable
    }
  }

  async function onSubmitDeactivate(): Promise<void> {
    try {
      await mutations.deactivate({
        entity_info: info.entity_info.value,
        deactivate_check: deactivate_check.value,
        replace_entity_input: search.replace_entity_input.value,
      });
      clearSelection();
      deactivate_check.value = false;
      replace_check.value = false;
    } catch {
      // error already toasted in composable
    }
  }

  async function onSubmitReview(): Promise<void> {
    if (!info.hasReviewChanges.value) {
      clearActiveWorkflow();
      return;
    }
    try {
      await mutations.submitReview(reviewArgs());
      clearSelection();
    } catch {
      // error already toasted in composable
    }
  }

  async function onSubmitStatus(): Promise<void> {
    if (!statusForm.hasChanges.value) {
      clearActiveWorkflow();
      return;
    }
    mutations.setSubmittingState('status');
    try {
      await statusForm.submitForm(false, false);
      onToast('Status submitted successfully', 'Success', 'success');
      announce('Status submitted successfully');
      statusForm.resetForm();
      clearSelection();
    } catch (e) {
      onToast(e, 'Error', 'danger');
      announce('Failed to submit status', 'assertive');
    } finally {
      mutations.setSubmittingState(null);
    }
  }

  async function onSubmitCombined(): Promise<void> {
    try {
      // The composable toasts success and threads the (server-re-checked)
      // direct-approval flag through both write paths. A no-op returns false so
      // we just close without firing a stray success message.
      await combined.submit();
      statusForm.resetForm();
      clearSelection();
    } catch {
      // submitReview / submitForm already toasted the failure; keep the
      // selection so the curator can fix and retry.
    }
  }

  async function onEntitySelected(entityId: number | null): Promise<void> {
    search.onEntitySelected(entityId);
    if (!entityId) {
      info.reset();
      clearActiveWorkflow();
      return;
    }
    await info.loadEntity(entityId);
    if (info.entity_info.value?.entity_id) {
      search.entity_loaded.value = true;
    }
  }

  // submitReviewChange bypasses the hasReviewChanges guard (spec compat).
  async function submitReviewChange(): Promise<void> {
    try {
      await mutations.submitReview(reviewArgs());
      clearSelection();
    } catch {
      // error already toasted in composable
    }
  }

  return {
    activeWorkflow,
    activeWorkflowLoading,
    combinedDirectApproval: combined.directApproval,
    clearActiveWorkflow,
    showEntityRename,
    showEntityDeactivate,
    showReviewModify,
    showStatusModify,
    showCombinedModify,
    onSubmitRename,
    onSubmitDeactivate,
    onSubmitReview,
    onSubmitStatus,
    onSubmitCombined,
    onEntitySelected,
    submitReviewChange,
  };
}

export default useModifyEntityWorkflows;
