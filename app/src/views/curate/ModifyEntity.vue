<!-- views/curate/ModifyEntity.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <!-- User Interface controls -->
          <BCard
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-1 text-start font-weight-bold">Modify an existing entity</h6>
            </template>
            <!-- User Interface controls -->

            <BCard class="my-2" body-class="p-2" header-class="p-1" border-variant="dark">
              <template #header>
                <h6 class="mb-1 text-start font-weight-bold">1. Select an entity to modify</h6>
              </template>

              <BRow>
                <BCol class="my-1">
                  <AutocompleteInput
                    v-model="modify_entity_input"
                    v-model:display-value="entity_display"
                    :results="entity_search_results"
                    :loading="entity_search_loading"
                    label="Entity"
                    input-id="entity-select"
                    placeholder="Search by ID, gene symbol, or disease name..."
                    item-key="entity_id"
                    item-label="symbol"
                    item-secondary="entity_id"
                    item-description="disease_ontology_name"
                    @search="searchEntity"
                    @update:model-value="onEntitySelected"
                  />
                  <small class="text-muted">
                    Search for entities by sysndd ID, gene symbol, or disease name
                  </small>
                </BCol>
              </BRow>
            </BCard>

            <!-- Entity Preview Card -->
            <BCard
              v-if="entity_loaded && entity_info.entity_id"
              class="my-2"
              body-class="p-3"
              header-class="p-2"
              border-variant="info"
            >
              <template #header>
                <h6 class="mb-0 text-start font-weight-bold d-flex align-items-center">
                  <i class="bi bi-info-circle me-2" aria-hidden="true" />
                  Selected Entity
                  <EntityBadge
                    :entity-id="entity_info.entity_id"
                    variant="primary"
                    size="md"
                    class="ms-2"
                  />
                </h6>
              </template>

              <BRow class="g-3">
                <BCol md="6">
                  <!-- Gene with badge and HGNC link -->
                  <div class="mb-2">
                    <strong class="text-muted small d-block mb-1">Gene:</strong>
                    <GeneBadge
                      :symbol="entity_info.symbol || 'N/A'"
                      :hgnc-id="entity_info.hgnc_id"
                      :link-to="
                        entity_info.hgnc_id
                          ? `https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/${entity_info.hgnc_id}`
                          : null
                      "
                      size="md"
                    />
                  </div>

                  <!-- Disease with badge and ontology link -->
                  <div class="mb-2">
                    <strong class="text-muted small d-block mb-1">Disease:</strong>
                    <DiseaseBadge
                      :name="entity_info.disease_ontology_name || 'N/A'"
                      :ontology-id="entity_info.disease_ontology_id_version"
                      :link-to="
                        entity_info.disease_ontology_id_version
                          ? `/Ontology/${entity_info.disease_ontology_id_version.replace(/_.+/g, '')}`
                          : null
                      "
                      size="md"
                      :max-length="40"
                    />
                  </div>
                </BCol>

                <BCol md="6">
                  <!-- Inheritance with icon -->
                  <div class="mb-2">
                    <strong class="text-muted small d-block mb-1">Inheritance:</strong>
                    <BBadge variant="info" class="d-inline-flex align-items-center">
                      <i class="bi bi-diagram-3 me-1" aria-hidden="true" />
                      {{
                        entity_info.hpo_mode_of_inheritance_term_name ||
                        entity_info.hpo_mode_of_inheritance_term ||
                        'N/A'
                      }}
                    </BBadge>
                  </div>

                  <!-- Category with stoplight style -->
                  <div class="mb-2">
                    <strong class="text-muted small d-block mb-1">Category:</strong>
                    <BBadge
                      :variant="stoplights_style[entity_info.category] || 'secondary'"
                      class="d-inline-flex align-items-center"
                    >
                      <i class="bi bi-stoplights me-1" aria-hidden="true" />
                      {{ entity_info.category || 'N/A' }}
                    </BBadge>
                  </div>

                  <!-- NDD Status with icon -->
                  <div class="mb-2">
                    <strong class="text-muted small d-block mb-1">NDD Status:</strong>
                    <BBadge
                      :variant="ndd_icon_style[entity_info.ndd_phenotype_word] || 'secondary'"
                      class="d-inline-flex align-items-center"
                    >
                      <i
                        :class="`bi bi-${ndd_icon[entity_info.ndd_phenotype_word] || 'question'} me-1`"
                        aria-hidden="true"
                      />
                      {{ entity_info.ndd_phenotype_word || 'N/A' }}
                    </BBadge>
                  </div>
                </BCol>
              </BRow>
            </BCard>

            <!-- Icon Legend -->
            <IconLegend
              v-if="entity_loaded && entity_info.entity_id"
              :legend-items="legendItems"
              title="Category & NDD Status Icons"
              class="my-2"
            />

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
                    :disabled="!entity_loaded || submitting"
                    aria-label="Rename disease"
                    @click="showEntityRename()"
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
                    :disabled="!entity_loaded || submitting"
                    aria-label="Deactivate entity"
                    @click="showEntityDeactivate()"
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
                    :disabled="!entity_loaded || submitting"
                    aria-label="Modify review"
                    @click="showReviewModify()"
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
                    :disabled="!entity_loaded || submitting"
                    aria-label="Modify status"
                    @click="showStatusModify()"
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

      <!-- Rename disease modal -->
      <BModal
        id="renameModal"
        ref="renameModal"
        size="lg"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        header-close-label="Close"
        @show="onRenameModalShow"
        @ok="submitEntityRename"
      >
        <template #title>
          <div class="d-flex flex-column gap-2">
            <h4 class="mb-0">
              Rename Entity Disease
              <EntityBadge
                :entity-id="entity_info.entity_id"
                variant="primary"
                size="md"
                class="ms-2"
              />
            </h4>
            <div class="d-flex flex-wrap gap-2 small">
              <span class="d-flex align-items-center">
                <i class="bi bi-file-earmark-medical me-1" />
                <strong>{{ entity_info.symbol || 'N/A' }}</strong>
              </span>
              <span class="text-muted">|</span>
              <span
                class="d-flex align-items-center text-truncate"
                style="max-width: 200px"
                :title="entity_info.disease_ontology_name"
              >
                <i class="bi bi-clipboard2-pulse me-1" />
                {{ entity_info.disease_ontology_name || 'N/A' }}
              </span>
              <span class="text-muted">|</span>
              <span class="d-flex align-items-center">
                <i class="bi bi-diagram-3 me-1" />
                {{
                  entity_info.hpo_mode_of_inheritance_term_name ||
                  entity_info.hpo_mode_of_inheritance_term ||
                  'N/A'
                }}
              </span>
              <span class="text-muted">|</span>
              <BBadge
                :variant="stoplights_style[entity_info.category] || 'secondary'"
                class="d-inline-flex align-items-center"
              >
                <i class="bi bi-stoplights me-1" />
                {{ entity_info.category || 'N/A' }}
              </BBadge>
            </div>
          </div>
        </template>

        <p class="my-3">Select a new disease name:</p>

        <AutocompleteInput
          v-model="ontology_input"
          v-model:display-value="ontology_display"
          :results="ontology_search_results"
          :loading="ontology_search_loading"
          label="Disease"
          input-id="ontology-select"
          placeholder="Search by disease name or ontology ID (e.g., OMIM:123456)..."
          item-key="id"
          item-label="label"
          item-secondary="id"
          @search="searchOntology"
          @update:model-value="onOntologySelected"
        />
        <small class="text-muted"> Search for diseases by name or ontology identifier </small>
      </BModal>
      <!-- Rename disease modal -->

      <!-- Deactivate entity modal -->
      <BModal
        id="deactivateModal"
        ref="deactivateModal"
        size="lg"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        header-close-label="Close"
        @show="onDeactivateModalShow"
        @ok="submitEntityDeactivation"
      >
        <template #title>
          <div class="d-flex flex-column gap-2">
            <h4 class="mb-0">
              Deactivate Entity
              <EntityBadge
                :entity-id="entity_info.entity_id"
                variant="primary"
                size="md"
                class="ms-2"
              />
            </h4>
            <div class="d-flex flex-wrap gap-2 small">
              <span class="d-flex align-items-center">
                <i class="bi bi-file-earmark-medical me-1" />
                <strong>{{ entity_info.symbol || 'N/A' }}</strong>
              </span>
              <span class="text-muted">|</span>
              <span
                class="d-flex align-items-center text-truncate"
                style="max-width: 200px"
                :title="entity_info.disease_ontology_name"
              >
                <i class="bi bi-clipboard2-pulse me-1" />
                {{ entity_info.disease_ontology_name || 'N/A' }}
              </span>
              <span class="text-muted">|</span>
              <span class="d-flex align-items-center">
                <i class="bi bi-diagram-3 me-1" />
                {{
                  entity_info.hpo_mode_of_inheritance_term_name ||
                  entity_info.hpo_mode_of_inheritance_term ||
                  'N/A'
                }}
              </span>
              <span class="text-muted">|</span>
              <BBadge
                :variant="stoplights_style[entity_info.category] || 'secondary'"
                class="d-inline-flex align-items-center"
              >
                <i class="bi bi-stoplights me-1" />
                {{ entity_info.category || 'N/A' }}
              </BBadge>
            </div>
          </div>
        </template>

        <div>
          <p class="my-2">1. Are you sure that you want to deactivate this entity?</p>

          <BFormCheckbox id="deactivateSwitch" v-model="deactivate_check" switch size="md">
            <strong>{{ deactivate_check ? 'Yes' : 'No' }}</strong>
          </BFormCheckbox>
        </div>

        <div v-if="deactivate_check">
          <p class="my-2">2. Was this entity replaced by another one?</p>

          <BFormCheckbox id="replaceSwitch" v-model="replace_check" switch size="md">
            <strong>{{ replace_check ? 'Yes' : 'No' }}</strong>
          </BFormCheckbox>
        </div>

        <div v-if="replace_check">
          <p class="my-2">3. Select the entity replacing the above one:</p>

          <AutocompleteInput
            v-model="replace_entity_input"
            v-model:display-value="replace_entity_display"
            :results="replace_entity_search_results"
            :loading="replace_entity_search_loading"
            label="Replacement Entity"
            input-id="replace-entity-select"
            placeholder="Search by ID, gene symbol, or disease name..."
            item-key="entity_id"
            item-label="symbol"
            item-secondary="entity_id"
            item-description="disease_ontology_name"
            @search="searchReplacementEntity"
            @update:model-value="onReplacementEntitySelected"
          />
          <small class="text-muted"> Search for the entity that replaces this one </small>
        </div>
      </BModal>
      <!-- Deactivate entity modal -->

      <!-- Modify review modal -->
      <BModal
        id="modifyReviewModal"
        ref="modifyReviewModal"
        size="xl"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        header-close-label="Close"
        :busy="loading_review_modal"
        @show="onModifyReviewModalShow"
        @ok="submitReviewChange"
      >
        <template #title>
          <div class="d-flex flex-column gap-2">
            <h4 class="mb-0">
              Modify Review
              <EntityBadge
                :entity-id="entity_info.entity_id"
                variant="primary"
                size="md"
                class="ms-2"
              />
            </h4>
            <div class="d-flex flex-wrap gap-2 small">
              <span class="d-flex align-items-center">
                <i class="bi bi-file-earmark-medical me-1" />
                <strong>{{ entity_info.symbol || 'N/A' }}</strong>
              </span>
              <span class="text-muted">|</span>
              <span
                class="d-flex align-items-center text-truncate"
                style="max-width: 200px"
                :title="entity_info.disease_ontology_name"
              >
                <i class="bi bi-clipboard2-pulse me-1" />
                {{ entity_info.disease_ontology_name || 'N/A' }}
              </span>
              <span class="text-muted">|</span>
              <span class="d-flex align-items-center">
                <i class="bi bi-diagram-3 me-1" />
                {{
                  entity_info.hpo_mode_of_inheritance_term_name ||
                  entity_info.hpo_mode_of_inheritance_term ||
                  'N/A'
                }}
              </span>
              <span class="text-muted">|</span>
              <BBadge
                :variant="stoplights_style[entity_info.category] || 'secondary'"
                class="d-inline-flex align-items-center"
              >
                <i class="bi bi-stoplights me-1" />
                {{ entity_info.category || 'N/A' }}
              </BBadge>
            </div>
          </div>
        </template>

        <BOverlay :show="loading_review_modal" rounded="sm">
          <BForm ref="form" @submit.stop.prevent="submitReviewChange">
            <!-- Synopsis textarea -->
            <label class="mr-sm-2 font-weight-bold" for="review-textarea-synopsis">Synopsis</label>
            <BFormTextarea
              id="review-textarea-synopsis"
              v-model="review_info.synopsis"
              rows="3"
              size="sm"
            />
            <!-- Synopsis textarea -->

            <!-- Phenotype select -->
            <label class="mr-sm-2 font-weight-bold" for="review-phenotype-select">Phenotypes</label>

            <TreeMultiSelect
              v-if="phenotypes_options && phenotypes_options.length > 0"
              id="review-phenotype-select"
              v-model="select_phenotype"
              :options="phenotypes_options"
              placeholder="Select phenotypes..."
              search-placeholder="Search phenotypes (name or HP:ID)..."
            />
            <!-- Phenotype select -->

            <!-- Variation ontolog select -->
            <label class="mr-sm-2 font-weight-bold" for="review-variation-select"
              >Variation ontology</label
            >

            <TreeMultiSelect
              v-if="variation_ontology_options && variation_ontology_options.length > 0"
              id="review-variation-select"
              v-model="select_variation"
              :options="variation_ontology_options"
              placeholder="Select variations..."
              search-placeholder="Search variation types..."
            />
            <!-- Variation ontolog select -->

            <!-- publications tag form with links out -->
            <label class="mr-sm-2 font-weight-bold" for="review-publications-select"
              >Publications</label
            >
            <BFormTags
              v-model="select_additional_references"
              input-id="review-literature-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                <BInputGroup class="my-0">
                  <BFormInput
                    v-bind="inputAttrs"
                    placeholder="Enter PMIDs separated by comma or semicolon"
                    class="form-control"
                    size="sm"
                    v-on="inputHandlers"
                  />
                  <BButton variant="secondary" size="sm" @click="addTag()"> Add </BButton>
                </BInputGroup>

                <div class="d-inline-block">
                  <h6>
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      @remove="removeTag(tag)"
                    >
                      <BLink
                        :href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')"
                        target="_blank"
                        class="text-light"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ tag }}
                      </BLink>
                    </BFormTag>
                  </h6>
                </div>
              </template>
            </BFormTags>
            <!-- publications tag form with links out -->

            <!-- genereviews tag form with links out -->
            <label class="mr-sm-2 font-weight-bold" for="review-genereviews-select"
              >Genereviews</label
            >
            <BFormTags
              v-model="select_gene_reviews"
              input-id="review-genereviews-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                <BInputGroup class="my-0">
                  <BFormInput
                    v-bind="inputAttrs"
                    placeholder="Enter PMIDs separated by comma or semicolon"
                    class="form-control"
                    size="sm"
                    v-on="inputHandlers"
                  />
                  <BButton variant="secondary" size="sm" @click="addTag()"> Add </BButton>
                </BInputGroup>

                <div class="d-inline-block">
                  <h6>
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      @remove="removeTag(tag)"
                    >
                      <BLink
                        :href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')"
                        target="_blank"
                        class="text-light"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ tag }}
                      </BLink>
                    </BFormTag>
                  </h6>
                </div>
              </template>
            </BFormTags>
            <!-- genereviews tag form with links out -->

            <!-- Review comment textarea -->
            <label class="mr-sm-2 font-weight-bold" for="review-textarea-comment">Comment</label>
            <BFormTextarea
              id="review-textarea-comment"
              v-model="review_info.comment"
              rows="2"
              size="sm"
              placeholder="Additional comments to this entity relevant for the curator."
            />
            <!-- Review comment textarea -->
          </BForm>
        </BOverlay>
      </BModal>
      <!-- Modify review modal -->

      <!-- Modify status modal -->
      <BModal
        id="modifyStatusModal"
        ref="modifyStatusModal"
        size="lg"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        header-close-label="Close"
        :busy="statusFormLoading"
        @show="onModifyStatusModalShow"
        @ok="submitStatusChange"
      >
        <template #title>
          <div class="d-flex flex-column gap-2">
            <h4 class="mb-0">
              Modify Status
              <EntityBadge
                :entity-id="entity_info.entity_id"
                variant="primary"
                size="md"
                class="ms-2"
              />
            </h4>
            <div class="d-flex flex-wrap gap-2 small">
              <span class="d-flex align-items-center">
                <i class="bi bi-file-earmark-medical me-1" />
                <strong>{{ entity_info.symbol || 'N/A' }}</strong>
              </span>
              <span class="text-muted">|</span>
              <span
                class="d-flex align-items-center text-truncate"
                style="max-width: 200px"
                :title="entity_info.disease_ontology_name"
              >
                <i class="bi bi-clipboard2-pulse me-1" />
                {{ entity_info.disease_ontology_name || 'N/A' }}
              </span>
              <span class="text-muted">|</span>
              <span class="d-flex align-items-center">
                <i class="bi bi-diagram-3 me-1" />
                {{
                  entity_info.hpo_mode_of_inheritance_term_name ||
                  entity_info.hpo_mode_of_inheritance_term ||
                  'N/A'
                }}
              </span>
              <span class="text-muted">|</span>
              <BBadge
                :variant="stoplights_style[entity_info.category] || 'secondary'"
                class="d-inline-flex align-items-center"
              >
                <i class="bi bi-stoplights me-1" />
                {{ entity_info.category || 'N/A' }}
              </BBadge>
            </div>
          </div>
        </template>

        <BOverlay :show="statusFormLoading" rounded="sm">
          <BForm ref="form" @submit.stop.prevent="submitStatusChange">
            <!-- Status dropdown with loading state -->
            <BSpinner v-if="status_options_loading" small label="Loading..." />
            <BFormSelect
              v-else-if="status_options && status_options.length > 0"
              id="status-select"
              v-model="statusFormData.category_id"
              :options="normalizeStatusOptions(status_options)"
              size="sm"
            >
              <template #first>
                <BFormSelectOption :value="null"> Select status... </BFormSelectOption>
              </template>
            </BFormSelect>
            <BAlert v-else-if="status_options !== null" variant="warning" class="mb-0">
              No status options available
            </BAlert>

            <BFormCheckbox id="removeSwitch" v-model="statusFormData.problematic" switch size="md">
              Suggest removal
            </BFormCheckbox>

            <label class="mr-sm-2 font-weight-bold" for="status-textarea-comment">Comment</label>
            <BFormTextarea
              id="status-textarea-comment"
              v-model="statusFormData.comment"
              rows="2"
              size="sm"
              placeholder="Why should this entities status be changed."
            />
          </BForm>
        </BOverlay>
      </BModal>
      <!-- Modify status modal -->

      <!-- AriaLiveRegion for screen reader announcements -->
      <AriaLiveRegion :message="a11yMessage" :politeness="a11yPoliteness" />
    </BContainer>
  </div>
</template>

<script>
import { useToast, useColorAndSymbols, useAriaLive } from '@/composables';
import useStatusForm from '@/views/curate/composables/useStatusForm';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';
import AutocompleteInput from '@/components/forms/AutocompleteInput.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import IconLegend from '@/components/accessibility/IconLegend.vue';

import Submission from '@/assets/js/classes/submission/submissionSubmission';
import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

export default {
  name: 'ModifyEntity',
  components: {
    TreeMultiSelect,
    AutocompleteInput,
    GeneBadge,
    DiseaseBadge,
    EntityBadge,
    AriaLiveRegion,
    IconLegend,
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    const { message: a11yMessage, politeness: a11yPoliteness, announce } = useAriaLive();

    // Initialize status form composable
    const statusForm = useStatusForm();
    const {
      formData: statusFormData,
      loading: statusFormLoading,
      loadStatusByEntity,
      submitForm: submitStatusForm,
      resetForm: resetStatusForm,
    } = statusForm;

    return {
      makeToast,
      ...colorAndSymbols,
      statusFormData,
      statusFormLoading,
      loadStatusByEntity,
      submitStatusForm,
      resetStatusForm,
      a11yMessage,
      a11yPoliteness,
      announce,
    };
  },
  data() {
    return {
      status_options: null, // null = not loaded, [] = loaded but empty
      status_options_loading: false,
      phenotypes_options: null, // null = not loaded, [] = loaded but empty
      variation_ontology_options: null, // null = not loaded, [] = loaded but empty
      // Entity search autocomplete state
      modify_entity_input: null,
      entity_display: '', // Display value for autocomplete
      entity_search_results: [],
      entity_search_loading: false,
      entity_loaded: false, // True when entity info has been fetched
      replace_entity_input: null,
      ontology_input: null,
      ontology_display: '', // Display value for ontology autocomplete
      ontology_search_results: [],
      ontology_search_loading: false,
      // Replacement entity autocomplete state
      replace_entity_display: '', // Display value for replacement entity autocomplete
      replace_entity_search_results: [],
      replace_entity_search_loading: false,
      entity_info: {},
      review_info: new Review(),
      select_phenotype: [],
      select_variation: [],
      select_additional_references: [],
      select_gene_reviews: [],
      status_info: new Status(),
      deactivate_check: false,
      replace_check: false,
      loading_rename_modal: true,
      loading_deactivate_modal: true,
      loading_review_modal: true,
      loading_status_modal: true,
      submitting: null, // null | 'rename' | 'deactivate' | 'review' | 'status'
      legendItems: [
        { icon: 'bi bi-stoplights-fill', color: '#4caf50', label: 'Definitive' },
        { icon: 'bi bi-stoplights-fill', color: '#2196f3', label: 'Moderate' },
        { icon: 'bi bi-stoplights-fill', color: '#ff9800', label: 'Limited' },
        { icon: 'bi bi-stoplights-fill', color: '#f44336', label: 'Refuted' },
        { icon: 'bi bi-check', color: '#198754', label: 'NDD: Yes' },
        { icon: 'bi bi-x', color: '#ffc107', label: 'NDD: No' },
      ],
    };
  },
  mounted() {
    this.loadStatusList();
    this.loadPhenotypesList();
    this.loadVariationOntologyList();
  },
  methods: {
    /**
     * Transform phenotype/variation tree to make all modifiers selectable children.
     * API returns: "present: X" as parent with [uncertain, variable, rare, absent] as children.
     * We want: "X" as parent with [present, uncertain, variable, rare, absent] as children.
     */
    transformModifierTree(nodes) {
      return nodes.map((node) => {
        // Extract phenotype name from "present: Phenotype Name" format
        const phenotypeName = node.label.replace(/^present:\s*/, '');
        // Extract the HP/ontology code from the ID (e.g., "1-HP:0001999" -> "HP:0001999")
        const ontologyCode = node.id.replace(/^\d+-/, '');

        // Create new parent with just the phenotype name
        const newParent = {
          id: `parent-${ontologyCode}`,
          label: phenotypeName,
          children: [
            // Add "present" as first child (the original parent node, now selectable)
            {
              id: node.id,
              label: `present: ${phenotypeName}`,
            },
            // Add all other modifiers as children with phenotype name for context
            ...(node.children || []).map((child) => {
              const modifier = child.label.replace(/:\s*.*$/, '');
              return {
                id: child.id,
                label: `${modifier}: ${phenotypeName}`,
              };
            }),
          ],
        };

        return newParent;
      });
    },
    async loadPhenotypesList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/phenotype?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        const rawData = Array.isArray(response.data) ? response.data : response.data?.data || [];
        // Transform to make all modifiers selectable
        this.phenotypes_options = this.transformModifierTree(rawData);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.phenotypes_options = [];
      }
    },
    async loadVariationOntologyList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/variation_ontology?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        const rawData = Array.isArray(response.data) ? response.data : response.data?.data || [];
        // Transform to make all modifiers selectable
        this.variation_ontology_options = this.transformModifierTree(rawData);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.variation_ontology_options = [];
      }
    },
    async loadStatusList() {
      this.status_options_loading = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.status_options = Array.isArray(response.data)
          ? response.data
          : response.data?.data || [];
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.status_options = [];
      } finally {
        this.status_options_loading = false;
      }
    },
    async searchEntity(query) {
      if (!query || query.length < 2) {
        this.entity_search_results = [];
        return;
      }

      this.entity_search_loading = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/entity?filter=contains(any,${encodeURIComponent(query)})`;

      try {
        const response = await this.axios.get(apiUrl);
        const data = response.data?.data || response.data || [];
        this.entity_search_results = Array.isArray(data) ? data.slice(0, 10) : [];
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.entity_search_results = [];
      } finally {
        this.entity_search_loading = false;
      }
    },
    async searchOntology(query) {
      if (!query || query.length < 2) {
        this.ontology_search_results = [];
        return;
      }

      this.ontology_search_loading = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/search/ontology/${encodeURIComponent(query)}?tree=true`;

      try {
        const response = await this.axios.get(apiUrl);
        // Ontology API returns flat array with {id, label} format
        const data = Array.isArray(response.data) ? response.data : [];
        this.ontology_search_results = data.slice(0, 10);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.ontology_search_results = [];
      } finally {
        this.ontology_search_loading = false;
      }
    },
    onOntologySelected(ontologyId) {
      this.ontology_input = ontologyId;
    },
    async searchReplacementEntity(query) {
      if (!query || query.length < 2) {
        this.replace_entity_search_results = [];
        return;
      }

      this.replace_entity_search_loading = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/entity?filter=contains(any,${encodeURIComponent(query)})`;

      try {
        const response = await this.axios.get(apiUrl);
        const data = response.data?.data || response.data || [];
        // Filter out the current entity from replacement options
        const filtered = Array.isArray(data)
          ? data.filter((e) => e.entity_id !== this.entity_info.entity_id).slice(0, 10)
          : [];
        this.replace_entity_search_results = filtered;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.replace_entity_search_results = [];
      } finally {
        this.replace_entity_search_loading = false;
      }
    },
    onReplacementEntitySelected(entityId) {
      this.replace_entity_input = entityId;
    },
    async onEntitySelected(entityId) {
      if (!entityId) {
        this.entity_loaded = false;
        this.entity_info = {};
        return;
      }

      // Set the modify_entity_input to the selected entity ID
      this.modify_entity_input = entityId;

      // Fetch full entity details
      await this.getEntity();

      // Mark entity as loaded if successful
      if (this.entity_info?.entity_id) {
        this.entity_loaded = true;
      }
    },
    async searchEntityInfo({ searchQuery, callback }) {
      const apiSearchURL = `${import.meta.env.VITE_API_URL}/api/entity?filter=contains(any,${
        searchQuery
      })`;

      try {
        const response_search = await this.axios.get(apiSearchURL);

        callback(null, response_search.data.data);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async getEntity() {
      const apiGetURL = `${import.meta.env.VITE_API_URL}/api/entity?filter=equals(entity_id,${
        this.modify_entity_input
      })`;

      try {
        const response = await this.axios.get(apiGetURL);

        // Defensive check for valid response data
        const entityData = response.data?.data;
        if (!Array.isArray(entityData) || entityData.length === 0) {
          this.makeToast(`Entity ${this.modify_entity_input} not found`, 'Error', 'danger');
          this.entity_info = {};
          return;
        }

        const entity = entityData[0];

        // Store full API response for enhanced preview display
        // (includes symbol, disease_ontology_name, category, ndd_phenotype_word, etc.)
        this.entity_info = entity;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.entity_info = {};
      }
    },
    async getReview() {
      this.loading_review_modal = true;

      const apiGetReviewURL = `${import.meta.env.VITE_API_URL}/api/entity/${
        this.modify_entity_input
      }/review`;
      const apiGetPhenotypesURL = `${import.meta.env.VITE_API_URL}/api/entity/${
        this.modify_entity_input
      }/phenotypes`;
      const apiGetVariationURL = `${import.meta.env.VITE_API_URL}/api/entity/${
        this.modify_entity_input
      }/variation`;
      const apiGetPublicationsURL = `${import.meta.env.VITE_API_URL}/api/entity/${
        this.modify_entity_input
      }/publications`;

      try {
        const response_review = await this.axios.get(apiGetReviewURL);
        const response_phenotypes = await this.axios.get(apiGetPhenotypesURL);
        const response_variation = await this.axios.get(apiGetVariationURL);
        const response_publications = await this.axios.get(apiGetPublicationsURL);

        // define phenotype specific attributes as constants from response
        const new_phenotype = response_phenotypes.data.map(
          (item) => new Phenotype(item.phenotype_id, item.modifier_id)
        );

        this.select_phenotype = response_phenotypes.data.map(
          (item) => `${item.modifier_id}-${item.phenotype_id}`
        );

        // define variation specific attributes as constants from response
        const new_variation = response_variation.data.map(
          (item) => new Variation(item.vario_id, item.modifier_id)
        );

        this.select_variation = response_variation.data.map(
          (item) => `${item.modifier_id}-${item.vario_id}`
        );

        // define publication specific attributes as constants from response
        const literature_gene_reviews = response_publications.data
          .filter((item) => item.publication_type === 'gene_review')
          .map((item) => item.publication_id);

        const literature_additional_references = response_publications.data
          .filter((item) => item.publication_type === 'additional_references')
          .map((item) => item.publication_id);

        this.select_additional_references = literature_additional_references;
        this.select_gene_reviews = literature_gene_reviews;

        const new_literature = new Literature(
          literature_additional_references,
          literature_gene_reviews
        );

        // compose review
        this.review_info = new Review(
          response_review.data[0].synopsis,
          new_literature,
          new_phenotype,
          new_variation,
          response_review.data[0].comment
        );

        this.review_info.review_id = response_review.data[0].review_id;
        this.review_info.entity_id = response_review.data[0].entity_id;

        this.loading_review_modal = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async getStatus() {
      this.loading_status_modal = true;

      const apiGetURL = `${import.meta.env.VITE_API_URL}/api/entity/${
        this.modify_entity_input
      }/status`;

      try {
        const response = await this.axios.get(apiGetURL);

        // compose entity
        this.status_info = new Status(
          response.data[0].category_id,
          response.data[0].comment,
          response.data[0].problematic
        );

        this.status_info.status_id = response.data[0].status_id;
        this.status_info.entity_id = response.data[0].entity_id;

        this.loading_status_modal = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    normalizerEntitySearch(node) {
      return {
        id: node.entity_id,
        label: `sysndd:${node.entity_id} (${node.symbol} - ${node.disease_ontology_name} - (${
          node.disease_ontology_id_version
        }) - ${node.hpo_mode_of_inheritance_term_name})`,
      };
    },
    normalizerOntologySearch(node) {
      return {
        id: node.id,
        label: `${node.id} (${node.label})`,
      };
    },
    normalizeStatus(node) {
      return {
        id: node.category_id,
        label: node.category,
      };
    },
    // Normalize status options for BFormSelect
    normalizeStatusOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return options.map((opt) => ({
        value: opt.id,
        text: opt.label,
      }));
    },
    async loadOntologyInfoTree({ searchQuery, callback }) {
      const apiSearchURL = `${import.meta.env.VITE_API_URL}/api/search/ontology/${
        searchQuery
      }?tree=true`;

      try {
        const response_search = await this.axios.get(apiSearchURL);
        callback(null, response_search.data);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async showEntityRename() {
      await this.getEntity();
      if (!this.entity_info?.entity_id) {
        return;
      }
      this.$refs.renameModal.show();
    },
    async showEntityDeactivate() {
      await this.getEntity();
      if (!this.entity_info?.entity_id) {
        return;
      }
      this.$refs.deactivateModal.show();
    },
    async showReviewModify() {
      await this.getEntity();
      if (!this.entity_info?.entity_id) {
        return;
      }
      this.getReview();
      this.$refs.modifyReviewModal.show();
    },
    async showStatusModify() {
      // Reset form FIRST to ensure clean state before loading data
      this.resetStatusForm();

      // Load entity and status data
      await this.getEntity();

      // Guard against entity not found
      if (!this.entity_info?.entity_id) {
        // Error already shown by getEntity()
        return;
      }

      await this.loadStatusByEntity(this.modify_entity_input);

      // Ensure status options are loaded
      if (this.status_options === null) {
        await this.loadStatusList();
      }

      // Guard against empty options
      if (!this.status_options || this.status_options.length === 0) {
        this.makeToast(
          'Failed to load status options. Please refresh and try again.',
          'Error',
          'danger'
        );
        return;
      }

      this.$refs.modifyStatusModal.show();
    },
    async submitEntityRename() {
      this.submitting = 'rename';
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/entity/rename`;

      // assign new disease_ontology_id
      this.entity_info.disease_ontology_id_version = this.ontology_input;

      // compose submission
      const submission = new Submission(this.entity_info);

      try {
        const response = await this.axios.post(
          apiUrl,
          { rename_json: submission },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          }
        );

        this.makeToast(
          `${'The new disease name for this entity has been submitted ' + '(status '}${
            response.status
          } (${response.statusText}).`,
          'Success',
          'success'
        );
        this.announce('Disease name updated successfully');
        this.resetForm();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Failed to update disease name', 'assertive');
      } finally {
        this.submitting = null;
      }
    },
    async submitEntityDeactivation() {
      this.submitting = 'deactivate';
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/entity/deactivate`;

      // assign new is_active
      this.entity_info.is_active = this.deactivate_check ? '0' : '1';

      // assign replace_entity_input
      this.entity_info.replaced_by =
        this.replace_entity_input === null ? 'NULL' : this.replace_entity_input;

      // compose submission
      const submission = new Submission(this.entity_info);

      try {
        const response = await this.axios.post(
          apiUrl,
          { deactivate_json: submission },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          }
        );

        this.makeToast(
          `${'The deactivation for this entity has been submitted ' + '(status '}${
            response.status
          } (${response.statusText}).`,
          'Success',
          'success'
        );
        this.announce('Entity deactivation submitted successfully');
        this.resetForm();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Failed to deactivate entity', 'assertive');
      } finally {
        this.submitting = null;
      }
    },
    async submitReviewChange() {
      this.submitting = 'review';
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/review/create`;

      // define literature specific attributes as constants from inputs
      // first clean the arrays
      const select_additional_references_clean = this.select_additional_references.map((element) =>
        element.replace(/\s+/g, '')
      );

      const select_gene_reviews_clean = this.select_gene_reviews.map((element) =>
        element.replace(/\s+/g, '')
      );

      const replace_literature = new Literature(
        select_additional_references_clean,
        select_gene_reviews_clean
      );

      // compose phenotype specific attributes as constants from inputs
      const replace_phenotype = this.select_phenotype.map(
        (item) => new Phenotype(item.split('-')[1], item.split('-')[0])
      );

      // compose variation ontology specific attributes as constants from inputs
      const replace_variation_ontology = this.select_variation.map(
        (item) => new Variation(item.split('-')[1], item.split('-')[0])
      );

      // assign to object
      this.review_info.literature = replace_literature;
      this.review_info.phenotypes = replace_phenotype;
      this.review_info.variation_ontology = replace_variation_ontology;

      // perform update POST request
      try {
        const response = await this.axios.post(
          apiUrl,
          { review_json: this.review_info },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          }
        );

        this.makeToast(
          `${'The new review for this entity has been submitted ' + '(status '}${
            response.status
          } (${response.statusText}).`,
          'Success',
          'success'
        );
        this.announce('Review submitted successfully');
        this.resetForm();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Failed to submit review', 'assertive');
      } finally {
        this.submitting = null;
      }
    },
    async submitStatusChange() {
      this.submitting = 'status';
      try {
        await this.submitStatusForm(false, false); // isUpdate=false (always create), reReview=false
        this.makeToast('Status submitted successfully', 'Success', 'success');
        this.announce('Status submitted successfully');
        this.resetStatusForm();
        this.resetForm(); // Also reset entity selection
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Failed to submit status', 'assertive');
      } finally {
        this.submitting = null;
      }
    },
    resetForm() {
      this.modify_entity_input = null;
      this.entity_display = '';
      this.entity_loaded = false;
      this.replace_entity_input = null;
      this.replace_entity_display = '';
      this.replace_entity_search_results = [];
      this.ontology_input = null;
      this.ontology_display = '';
      this.ontology_search_results = [];
      this.entity_info = {};
      this.review_info = new Review();
      this.select_phenotype = [];
      this.select_variation = [];
      this.select_additional_references = [];
      this.select_gene_reviews = [];
      this.status_info = new Status();
      this.deactivate_check = false;
      this.replace_check = false;
    },
    tagValidatorPMID(tag) {
      // Individual PMID tag validator function
      const tag_copy = tag.replace(/\s+/g, '');
      return (
        !Number.isNaN(Number(tag_copy.replaceAll('PMID:', ''))) &&
        tag_copy.includes('PMID:') &&
        tag_copy.replace('PMID:', '').length > 4 &&
        tag_copy.replace('PMID:', '').length < 9
      );
    },
    onRenameModalShow() {
      // Reset rename-specific state (FORM-07: prevents stale data)
      this.ontology_input = null;
      this.ontology_display = '';
      this.ontology_search_results = [];
    },
    onDeactivateModalShow() {
      // Reset deactivate-specific state (FORM-07: prevents stale data)
      this.deactivate_check = false;
      this.replace_check = false;
      this.replace_entity_input = null;
      this.replace_entity_display = '';
    },
    onModifyReviewModalShow() {
      // Reset form state on show (FORM-07: prevents stale data flash)
      this.review_info = new Review();
      this.select_phenotype = [];
      this.select_variation = [];
      this.select_additional_references = [];
      this.select_gene_reviews = [];
    },
    onModifyStatusModalShow() {
      // Reset moved to showStatusModify() — intentionally empty to preserve loaded data
      // The reset must happen BEFORE data load, not after modal renders
    },
  },
};
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
