<!-- views/curate/ModifyEntity.vue — thin orchestration shell -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <BCard
            header-tag="header"
            align="start"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-1 text-start font-weight-bold">Modify an existing entity</h6>
            </template>

            <!-- 1. Search panel -->
            <EntitySearchPanel
              :model-value="modify_entity_input"
              :display-value="entity_display"
              :search-results="entity_search_results"
              :loading="entity_search_loading"
              @update:model-value="onEntitySelected"
              @update:display-value="entity_display = $event"
              @search="searchEntity"
            />

            <!-- 2. Entity info header (shown after selection) -->
            <EntityInfoHeader
              v-if="entity_loaded && entity_info.entity_id"
              :entity="entity_info"
              :legend-items="legendItems"
              :stoplights-style="stoplights_style"
              :ndd-icon-style="ndd_icon_style"
              :ndd-icon="ndd_icon"
            />

            <!-- 3. Action bar -->
            <BCard
              v-if="entity_loaded && entity_info.entity_id"
              class="my-2"
              body-class="p-2"
              header-class="p-1"
              border-variant="dark"
            >
              <template #header>
                <h6 class="mb-1 text-start font-weight-bold">
                  2. Options to modify the selected entity
                </h6>
              </template>

              <BRow>
                <BCol class="my-1">
                  <BButton
                    size="sm"
                    variant="dark"
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
                </BCol>

                <BCol class="my-1">
                  <BButton
                    size="sm"
                    variant="dark"
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
                </BCol>

                <BCol class="my-1">
                  <BButton
                    size="sm"
                    variant="dark"
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
                </BCol>

                <BCol class="my-1">
                  <BButton
                    size="sm"
                    variant="dark"
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
                </BCol>
              </BRow>
            </BCard>
          </BCard>
        </BCol>
      </BRow>

      <!-- Rename modal -->
      <EntityRenameDeactivateModal
        :visible="isRenameOpen"
        mode="rename"
        :entity="entity_info"
        :submitting="submitting"
        :stoplights-style="stoplights_style"
        :ontology-display="ontology_display"
        :ontology-input="ontology_input"
        :ontology-search-results="ontology_search_results"
        :ontology-search-loading="ontology_search_loading"
        @update:visible="isRenameOpen = $event"
        @update:ontology-display="ontology_display = $event"
        @search-ontology="searchOntology"
        @select-ontology="onOntologySelected"
        @submit="onSubmitRename"
        @cancel="close"
      />

      <!-- Deactivate modal -->
      <EntityRenameDeactivateModal
        :visible="isDeactivateOpen"
        mode="deactivate"
        :entity="entity_info"
        :submitting="submitting"
        :stoplights-style="stoplights_style"
        :deactivate-check="deactivate_check"
        :replace-check="replace_check"
        :replace-display="replace_entity_display"
        :replace-entity-input="replace_entity_input"
        :replace-search-results="replace_entity_search_results"
        :replace-search-loading="replace_entity_search_loading"
        @update:visible="isDeactivateOpen = $event"
        @update:deactivate-check="deactivate_check = $event"
        @update:replace-check="replace_check = $event"
        @update:replace-display="replace_entity_display = $event"
        @search-replacement="searchReplacementEntity"
        @select-replacement="onReplacementEntitySelected"
        @submit="onSubmitDeactivate"
        @cancel="close"
      />

      <!-- Review modal -->
      <ReviewModifyModal
        :visible="isReviewOpen"
        :loading="loadingReview"
        :submitting="submitting"
        :entity="entity_info"
        :review="review_info"
        :select-phenotype="select_phenotype"
        :select-variation="select_variation"
        :select-additional-references="select_additional_references"
        :select-gene-reviews="select_gene_reviews"
        :phenotype-options="phenotypes_options ?? []"
        :variation-options="variation_ontology_options ?? []"
        :has-changes="hasReviewChanges"
        :stoplights-style="stoplights_style"
        @update:visible="isReviewOpen = $event"
        @update:review="review_info = $event"
        @update:select-phenotype="select_phenotype = $event"
        @update:select-variation="select_variation = $event"
        @update:select-additional-references="select_additional_references = $event"
        @update:select-gene-reviews="select_gene_reviews = $event"
        @submit="onSubmitReview"
        @discard-request="requestDiscard($event)"
      />

      <!-- Status modal -->
      <StatusModifyModal
        :visible="isStatusOpen"
        :loading="loadingStatus"
        :submitting="submitting"
        :entity="entity_info"
        :status-options="status_options"
        :status-options-loading="status_options_loading"
        :form-data="statusFormData"
        :has-changes="hasStatusChanges"
        :stoplights-style="stoplights_style"
        @update:visible="isStatusOpen = $event"
        @update:form-data="Object.assign(statusFormData, $event)"
        @submit="onSubmitStatus"
        @discard-request="requestDiscard($event)"
      />

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
</template>

<script lang="ts">
import { defineComponent, onMounted, ref, watch } from 'vue';
import { useToast, useColorAndSymbols, useAriaLive } from '@/composables';
import useStatusForm from './composables/useStatusForm';
import { useEntityAutocomplete } from './composables/useEntityAutocomplete';
import { useEntityInfo } from './composables/useEntityInfo';
import { useEntityMutations } from './composables/useEntityMutations';
import { useEntityModifyModals } from './composables/useEntityModifyModals';

import {
  listPhenotypesTree,
  listVariationOntologyTree,
  listStatusCategoriesTree,
} from '@/api/list';

import EntityInfoHeader from './components/EntityInfoHeader.vue';
import EntitySearchPanel from './components/EntitySearchPanel.vue';
import EntityRenameDeactivateModal from './components/EntityRenameDeactivateModal.vue';
import ReviewModifyModal from './components/ReviewModifyModal.vue';
import StatusModifyModal from './components/StatusModifyModal.vue';
import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import ConfirmDiscardDialog from '@/components/ui/ConfirmDiscardDialog.vue';

const transformModifierTree = (nodes: any[]) =>
  nodes.map((node) => {
    const phenotypeName = node.label.replace(/^present:\s*/, '');
    const ontologyCode = node.id.replace(/^\d+-/, '');
    return {
      id: `parent-${ontologyCode}`,
      label: phenotypeName,
      children: [
        { id: node.id, label: `present: ${phenotypeName}` },
        ...(node.children || []).map((child: any) => {
          const modifier = child.label.replace(/:\s*.*$/, '');
          return { id: child.id, label: `${modifier}: ${phenotypeName}` };
        }),
      ],
    };
  });

export default defineComponent({
  name: 'ModifyEntity',
  components: {
    EntityInfoHeader,
    EntitySearchPanel,
    EntityRenameDeactivateModal,
    ReviewModifyModal,
    StatusModifyModal,
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

    // Local modal-specific state not owned by composables
    const deactivate_check = ref(false);
    const replace_check = ref(false);

    // Tree options (app-global lookup data loaded once)
    const phenotypes_options = ref<any[] | null>(null);
    const variation_ontology_options = ref<any[] | null>(null);
    const status_options = ref<any[] | null>(null);
    const status_options_loading = ref(false);

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

    onMounted(async () => {
      status_options_loading.value = true;
      try {
        const [phenotypes_data, variation_data, status_data] = await Promise.all([
          listPhenotypesTree(),
          listVariationOntologyTree(),
          listStatusCategoriesTree(),
        ]);
        const raw1: any = Array.isArray(phenotypes_data)
          ? phenotypes_data
          : (phenotypes_data as any)?.data || [];
        phenotypes_options.value = transformModifierTree(raw1);

        const raw2: any = Array.isArray(variation_data)
          ? variation_data
          : (variation_data as any)?.data || [];
        variation_ontology_options.value = transformModifierTree(raw2);

        status_options.value = Array.isArray(status_data)
          ? status_data
          : (status_data as any)?.data || [];
      } catch (e) {
        makeToast(e, 'Error', 'danger');
        // Set deterministic empty defaults so downstream modals render
        // their empty-state alerts instead of staying in the null/loading
        // limbo (StatusModifyModal hides both the select and the empty
        // alert while statusOptions is null).
        if (phenotypes_options.value === null) phenotypes_options.value = [];
        if (variation_ontology_options.value === null) variation_ontology_options.value = [];
        if (status_options.value === null) status_options.value = [];
      } finally {
        status_options_loading.value = false;
      }
    });

    // Modal show handlers
    async function showEntityRename(): Promise<void> {
      modals.openRename();
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
      // Clear stale autocomplete results so the dropdown doesn't open
      // with leftover suggestions from a previous deactivation attempt.
      search.replace_entity_search_results.value = [];
      search.replace_entity_search_loading.value = false;
      modals.openDeactivate();
      modals.setLoading('deactivate', false);
    }

    async function showReviewModify(): Promise<void> {
      modals.openReview();
      modals.setLoading('review', true);
      await info.loadReview(info.entity_info.value.entity_id);
      modals.setLoading('review', false);
    }

    async function showStatusModify(): Promise<void> {
      statusForm.resetForm();
      modals.openStatus();
      modals.setLoading('status', true);
      await statusForm.loadStatusByEntity(info.entity_info.value.entity_id);
      modals.setLoading('status', false);
    }

    // Submit handlers
    async function onSubmitRename(): Promise<void> {
      try {
        await mutations.rename({
          entity_info: info.entity_info.value,
          ontology_input: search.ontology_input.value,
        });
        modals.close();
        info.reset();
        search.clearAll();
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
        modals.close();
        info.reset();
        search.clearAll();
        deactivate_check.value = false;
        replace_check.value = false;
      } catch {
        // error already toasted in composable
      }
    }

    async function onSubmitReview(): Promise<void> {
      if (!info.hasReviewChanges.value) {
        modals.close();
        return;
      }
      try {
        await mutations.submitReview({
          review_info: info.review_info.value,
          select_phenotype: info.select_phenotype.value,
          select_variation: info.select_variation.value,
          select_additional_references: info.select_additional_references.value,
          select_gene_reviews: info.select_gene_reviews.value,
        });
        modals.close();
        info.reset();
        search.clearAll();
      } catch {
        // error already toasted in composable
      }
    }

    async function onSubmitStatus(): Promise<void> {
      if (!statusForm.hasChanges.value) {
        modals.close();
        return;
      }
      mutations.setSubmittingState('status');
      try {
        await statusForm.submitForm(false, false);
        makeToast('Status submitted successfully', 'Success', 'success');
        announce('Status submitted successfully');
        statusForm.resetForm();
        modals.close();
        info.reset();
        search.clearAll();
      } catch (e) {
        makeToast(e, 'Error', 'danger');
        announce('Failed to submit status', 'assertive');
      } finally {
        mutations.setSubmittingState(null);
      }
    }

    async function onEntitySelected(entityId: number | null): Promise<void> {
      search.onEntitySelected(entityId);
      if (!entityId) {
        info.reset();
        return;
      }
      await info.loadEntity(entityId);
      if (info.entity_info.value?.entity_id) {
        search.entity_loaded.value = true;
      }
    }

    const legendItems = [
      { icon: 'bi bi-stoplights-fill', color: '#4caf50', label: 'Definitive' },
      { icon: 'bi bi-stoplights-fill', color: '#2196f3', label: 'Moderate' },
      { icon: 'bi bi-stoplights-fill', color: '#ff9800', label: 'Limited' },
      { icon: 'bi bi-stoplights-fill', color: '#f44336', label: 'Refuted' },
      { icon: 'bi bi-check', color: '#198754', label: 'NDD: Yes' },
      { icon: 'bi bi-x', color: '#ffc107', label: 'NDD: No' },
    ];

    return {
      // entity info composable
      ...info,
      // search composable
      ...search,
      // mutations composable
      ...mutations,
      // modals composable
      ...modals,
      // statusForm composable
      statusFormData: statusForm.formData,
      hasStatusChanges: statusForm.hasChanges,
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
      // event handlers
      showEntityRename,
      showEntityDeactivate,
      showReviewModify,
      showStatusModify,
      onSubmitRename,
      onSubmitDeactivate,
      onSubmitReview,
      onSubmitStatus,
      onEntitySelected,
      // backward-compat aliases (used by existing specs)
      submitEntityRename: onSubmitRename,
      submitEntityDeactivation: onSubmitDeactivate,
      // submitReviewChange bypasses the hasReviewChanges guard (spec compat)
      submitReviewChange: async () => {
        try {
          await mutations.submitReview({
            review_info: info.review_info.value,
            select_phenotype: info.select_phenotype.value,
            select_variation: info.select_variation.value,
            select_additional_references: info.select_additional_references.value,
            select_gene_reviews: info.select_gene_reviews.value,
          });
          modals.close();
          info.reset();
          search.clearAll();
        } catch {
          // error already toasted in composable
        }
      },
      // ref for confirm dialog
      confirmDiscardDialogRef,
      // static data
      legendItems,
      makeToast,
    };
  },
});
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
</style>
