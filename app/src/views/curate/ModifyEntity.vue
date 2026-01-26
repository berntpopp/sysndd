<!-- views/curate/ModifyEntity.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <!-- User Interface controls -->
          <BCard
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-1 text-start font-weight-bold">
                Modify an existing entity
              </h6>
            </template>
            <!-- User Interface controls -->

            <BCard
              class="my-2"
              body-class="p-0"
              header-class="p-1"
              border-variant="dark"
            >
              <template #header>
                <h6 class="mb-1 text-start font-weight-bold">
                  1. Select an entity to modify
                </h6>
              </template>

              <BRow>
                <BCol class="my-1">
                  <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
                  <!-- Async search temporarily disabled - use text input -->
                  <!-- <treeselect
                    id="entity-select"
                    v-model="modify_entity_input"
                    :multiple="false"
                    :async="true"
                    :load-options="searchEntityInfo"
                    :normalizer="normalizerEntitySearch"
                    required
                  /> -->
                  <BFormInput
                    id="entity-select"
                    v-model="modify_entity_input"
                    size="sm"
                    placeholder="Enter entity ID (e.g., 123)"
                    type="number"
                    required
                  />
                </BCol>
              </BRow>
            </BCard>

            <BCard
              v-if="modify_entity_input"
              class="my-2"
              body-class="p-0"
              header-class="p-1"
              border-variant="dark"
            >
              <template #header>
                <h6 class="mb-1 text-start font-weight-bold">
                  2. Options to modify the selected entity
                  <BBadge variant="primary">
                    sysndd:{{ modify_entity_input }}
                  </BBadge>
                </h6>
              </template>

              <BRow>
                <BCol class="my-1">
                  <BButton
                    size="sm"
                    variant="dark"
                    @click="showEntityRename()"
                  >
                    <i class="bi bi-pen" />
                    <i class="bi bi-link" />
                    Rename disease
                  </BButton>
                </BCol>

                <BCol class="my-1">
                  <BButton
                    size="sm"
                    variant="dark"
                    @click="showEntityDeactivate()"
                  >
                    <i class="bi bi-x" />
                    <i class="bi bi-link" />
                    Deactivate entity
                  </BButton>
                </BCol>

                <BCol class="my-1">
                  <BButton
                    size="sm"
                    variant="dark"
                    @click="showReviewModify()"
                  >
                    <i class="bi bi-pen" />
                    <i class="bi bi-clipboard-plus" />
                    Modify review
                  </BButton>
                </BCol>

                <BCol class="my-1">
                  <BButton
                    size="sm"
                    variant="dark"
                    @click="showStatusModify()"
                  >
                    <i class="bi bi-pen" />
                    <i class="bi bi-stoplights" />
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
        @ok="submitEntityRename"
      >
        <template #modal-title>
          <h4>
            Rename entity disease:
            <BBadge variant="primary">
              sysndd:{{ entity_info.entity_id }}
            </BBadge>
          </h4>
        </template>

        <p class="my-4">
          Select a new disease name:
        </p>

        <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
        <!-- Async search temporarily disabled - use text input -->
        <!-- <treeselect
          id="ontology-select"
          v-model="ontology_input"
          :multiple="false"
          :async="true"
          :load-options="loadOntologyInfoTree"
          :normalizer="normalizerOntologySearch"
          required
        /> -->
        <BFormInput
          id="ontology-select"
          v-model="ontology_input"
          size="sm"
          placeholder="Enter Ontology ID (e.g., OMIM:123456)"
          required
        />
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
        @ok="submitEntityDeactivation"
      >
        <template #modal-title>
          <h4>
            Deactivate entity:
            <BBadge variant="primary">
              sysndd:{{ entity_info.entity_id }}
            </BBadge>
          </h4>
        </template>

        <div>
          <p class="my-2">
            1. Are you sure that you want to deactivate this entity?
          </p>

          <div class="custom-control custom-switch">
            <input
              id="deactivateSwitch"
              v-model="deactivate_check"
              type="checkbox"
              button-variant="info"
              class="custom-control-input"
            >
            <label
              class="custom-control-label"
              for="deactivateSwitch"
            >
              {{ deactivate_check ? "Yes" : "No" }}
            </label>
          </div>
        </div>

        <div v-if="deactivate_check">
          <p class="my-2">
            2. Was this entity replaced by another one?
          </p>

          <div class="custom-control custom-switch">
            <input
              id="replaceSwitch"
              v-model="replace_check"
              type="checkbox"
              button-variant="info"
              class="custom-control-input"
            >
            <label
              class="custom-control-label"
              for="replaceSwitch"
            >
              {{ replace_check ? "Yes" : "No" }}
            </label>
          </div>
        </div>

        <div v-if="replace_check">
          <p class="my-2">
            3. Select the entity replacing the above one:
          </p>

          <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
          <!-- Async search temporarily disabled - use text input -->
          <!-- <treeselect
            id="entity-select"
            v-model="replace_entity_input"
            :multiple="false"
            :async="true"
            :load-options="searchEntityInfo"
            :normalizer="normalizerEntitySearch"
            required
          /> -->
          <BFormInput
            id="replace-entity-select"
            v-model="replace_entity_input"
            size="sm"
            placeholder="Enter replacement entity ID (e.g., 123)"
            type="number"
            required
          />
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
        :busy="loading_review_modal"
        @ok="submitReviewChange"
      >
        <template #modal-title>
          <h4>
            Modify review for entity:
            <BBadge variant="primary">
              sysndd:{{ entity_info.entity_id }}
            </BBadge>
          </h4>
        </template>

        <BOverlay
          :show="loading_review_modal"
          rounded="sm"
        >
          <BForm
            ref="form"
            @submit.stop.prevent="submitReviewChange"
          >
            <!-- Synopsis textarea -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-textarea-synopsis"
            >Synopsis</label>
            <BFormTextarea
              id="review-textarea-synopsis"
              v-model="review_info.synopsis"
              rows="3"
              size="sm"
            />
            <!-- Synopsis textarea -->

            <!-- Phenotype select -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-phenotype-select"
            >Phenotypes</label>

            <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
            <!-- Multi-select temporarily disabled - using single select -->
            <!-- <treeselect
              id="review-phenotype-select"
              v-model="select_phenotype"
              :multiple="true"
              :flat="true"
              :options="phenotypes_options"
              :normalizer="normalizePhenotypes"
              required
            /> -->
            <BFormSelect
              v-if="phenotypes_options && phenotypes_options.length > 0"
              id="review-phenotype-select"
              v-model="select_phenotype[0]"
              :options="normalizePhenotypesOptions(phenotypes_options)"
              size="sm"
            >
              <template #first>
                <BFormSelectOption :value="null">
                  Select phenotype...
                </BFormSelectOption>
              </template>
            </BFormSelect>
            <!-- Phenotype select -->

            <!-- Variation ontolog select -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-variation-select"
            >Variation ontology</label>

            <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
            <!-- Multi-select temporarily disabled - using single select -->
            <!-- <treeselect
              id="review-variation-select"
              v-model="select_variation"
              :multiple="true"
              :flat="true"
              :options="variation_ontology_options"
              :normalizer="normalizeVariationOntology"
              required
            /> -->
            <BFormSelect
              v-if="variation_ontology_options && variation_ontology_options.length > 0"
              id="review-variation-select"
              v-model="select_variation[0]"
              :options="normalizeVariationOntologyOptions(variation_ontology_options)"
              size="sm"
            >
              <template #first>
                <BFormSelectOption :value="null">
                  Select variation...
                </BFormSelectOption>
              </template>
            </BFormSelect>
            <!-- Variation ontolog select -->

            <!-- publications tag form with links out -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-publications-select"
            >Publications</label>
            <BFormTags
              v-model="select_additional_references"
              input-id="review-literature-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template
                #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
              >
                <BInputGroup class="my-0">
                  <BFormInput
                    v-bind="inputAttrs"
                    placeholder="Enter PMIDs separated by comma or semicolon"
                    class="form-control"
                    size="sm"
                    v-on="inputHandlers"
                  />
                  <BButton
                    variant="secondary"
                    size="sm"
                    @click="addTag()"
                  >
                    Add
                  </BButton>
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
                        :href="
                          'https://pubmed.ncbi.nlm.nih.gov/' +
                            tag.replace('PMID:', '')
                        "
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
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-genereviews-select"
            >Genereviews</label>
            <BFormTags
              v-model="select_gene_reviews"
              input-id="review-genereviews-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template
                #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
              >
                <BInputGroup class="my-0">
                  <BFormInput
                    v-bind="inputAttrs"
                    placeholder="Enter PMIDs separated by comma or semicolon"
                    class="form-control"
                    size="sm"
                    v-on="inputHandlers"
                  />
                  <BButton
                    variant="secondary"
                    size="sm"
                    @click="addTag()"
                  >
                    Add
                  </BButton>
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
                        :href="
                          'https://pubmed.ncbi.nlm.nih.gov/' +
                            tag.replace('PMID:', '')
                        "
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
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-textarea-comment"
            >Comment</label>
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
        :busy="loading_status_modal"
        @ok="submitStatusChange"
      >
        <template #modal-title>
          <h4>
            Modify status for entity:
            <BBadge variant="primary">
              sysndd:{{ entity_info.entity_id }}
            </BBadge>
          </h4>
        </template>

        <BOverlay
          :show="loading_status_modal"
          rounded="sm"
        >
          <BForm
            ref="form"
            @submit.stop.prevent="submitStatusChange"
          >
            <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
            <!-- <treeselect
              id="status-select"
              v-model="status_info.category_id"
              :multiple="false"
              :options="status_options"
              :normalizer="normalizeStatus"
            /> -->
            <!-- Status dropdown with loading state -->
            <BSpinner
              v-if="status_options_loading"
              small
              label="Loading..."
            />
            <BFormSelect
              v-else-if="status_options && status_options.length > 0"
              id="status-select"
              v-model="status_info.category_id"
              :options="normalizeStatusOptions(status_options)"
              size="sm"
            >
              <template #first>
                <BFormSelectOption :value="null">
                  Select status...
                </BFormSelectOption>
              </template>
            </BFormSelect>
            <BAlert
              v-else-if="status_options !== null"
              variant="warning"
              class="mb-0"
            >
              No status options available
            </BAlert>

            <div class="custom-control custom-switch">
              <input
                id="removeSwitch"
                v-model="status_info.problematic"
                type="checkbox"
                button-variant="info"
                class="custom-control-input"
              >
              <label
                class="custom-control-label"
                for="removeSwitch"
              >Suggest removal</label>
            </div>

            <label
              class="mr-sm-2 font-weight-bold"
              for="status-textarea-comment"
            >Comment</label>
            <BFormTextarea
              id="status-textarea-comment"
              v-model="status_info.comment"
              rows="2"
              size="sm"
              placeholder="Why should this entities status be changed."
            />
          </BForm>
        </BOverlay>
      </BModal>
      <!-- Modify status modal -->
    </BContainer>
  </div>
</template>

<script>
import { useToast, useColorAndSymbols } from '@/composables';

// TODO: vue3-treeselect disabled pending Bootstrap-Vue-Next migration
// import the Treeselect component
// import Treeselect from '@zanmato/vue3-treeselect';
// import the Treeselect styles
// import '@zanmato/vue3-treeselect/dist/vue3-treeselect.min.css';

import Submission from '@/assets/js/classes/submission/submissionSubmission';
import Entity from '@/assets/js/classes/submission/submissionEntity';
import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

export default {
  name: 'ModifyEntity',
  // TODO: Treeselect disabled pending Bootstrap-Vue-Next migration
  components: {},
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();

    return {
      makeToast,
      ...colorAndSymbols,
    };
  },
  data() {
    return {
      status_options: null, // null = not loaded, [] = loaded but empty
      status_options_loading: false,
      phenotypes_options: null, // null = not loaded, [] = loaded but empty
      variation_ontology_options: null, // null = not loaded, [] = loaded but empty
      modify_entity_input: null,
      replace_entity_input: null,
      ontology_input: null,
      entity_info: new Entity(),
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
    };
  },
  mounted() {
    this.loadStatusList();
    this.loadPhenotypesList();
    this.loadVariationOntologyList();
  },
  methods: {
    async loadPhenotypesList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/phenotype?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.phenotypes_options = Array.isArray(response.data)
          ? response.data
          : response.data?.data || [];
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.phenotypes_options = [];
      }
    },
    normalizePhenotypes(node) {
      return {
        id: node.id,
        label: node.label,
      };
    },
    async loadVariationOntologyList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/variation_ontology?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.variation_ontology_options = Array.isArray(response.data)
          ? response.data
          : response.data?.data || [];
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.variation_ontology_options = [];
      }
    },
    normalizeVariationOntology(node) {
      return {
        id: node.id,
        label: node.label,
      };
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
    async searchEntityInfo({ searchQuery, callback }) {
      const apiSearchURL = `${import.meta.env.VITE_API_URL
      }/api/entity?filter=contains(any,${
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
      const apiGetURL = `${import.meta.env.VITE_API_URL
      }/api/entity?filter=equals(entity_id,${
        this.modify_entity_input
      })`;

      try {
        const response = await this.axios.get(apiGetURL);

        // Defensive check for valid response data
        const entityData = response.data?.data;
        if (!Array.isArray(entityData) || entityData.length === 0) {
          this.makeToast(`Entity ${this.modify_entity_input} not found`, 'Error', 'danger');
          this.entity_info = new Entity();
          return;
        }

        const entity = entityData[0];

        // compose entity
        this.entity_info = new Entity(
          entity.hgnc_id,
          entity.disease_ontology_id_version,
          entity.hpo_mode_of_inheritance_term,
          entity.ndd_phenotype,
          entity.entity_id,
          entity.is_active,
          entity.replaced_by,
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.entity_info = new Entity();
      }
    },
    async getReview() {
      this.loading_review_modal = true;

      const apiGetReviewURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.modify_entity_input
      }/review`;
      const apiGetPhenotypesURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.modify_entity_input
      }/phenotypes`;
      const apiGetVariationURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.modify_entity_input
      }/variation`;
      const apiGetPublicationsURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.modify_entity_input
      }/publications`;

      try {
        const response_review = await this.axios.get(apiGetReviewURL);
        const response_phenotypes = await this.axios.get(apiGetPhenotypesURL);
        const response_variation = await this.axios.get(apiGetVariationURL);
        const response_publications = await this.axios.get(apiGetPublicationsURL);

        // define phenotype specific attributes as constants from response
        const new_phenotype = response_phenotypes.data.map((
          (item) => new Phenotype(item.phenotype_id, item.modifier_id)
        ));

        this.select_phenotype = response_phenotypes.data.map((
          (item) => `${item.modifier_id}-${item.phenotype_id}`
        ));

        // define variation specific attributes as constants from response
        const new_variation = response_variation.data.map((
          (item) => new Variation(item.vario_id, item.modifier_id)
        ));

        this.select_variation = response_variation.data.map((
          (item) => `${item.modifier_id}-${item.vario_id}`
        ));

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
          literature_gene_reviews,
        );

        // compose review
        this.review_info = new Review(
          response_review.data[0].synopsis,
          new_literature,
          new_phenotype,
          new_variation,
          response_review.data[0].comment,
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

      const apiGetURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.modify_entity_input
      }/status`;

      try {
        const response = await this.axios.get(apiGetURL);

        // compose entity
        this.status_info = new Status(
          response.data[0].category_id,
          response.data[0].comment,
          response.data[0].problematic,
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
        label:
          `sysndd:${
            node.entity_id
          } (${
            node.symbol
          } - ${
            node.disease_ontology_name
          } - (${
            node.disease_ontology_id_version
          }) - ${
            node.hpo_mode_of_inheritance_term_name
          })`,
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
    // Normalize phenotypes options for BFormSelect
    normalizePhenotypesOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return this.flattenTreeOptions(options);
    },
    // Normalize variation ontology options for BFormSelect
    normalizeVariationOntologyOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return this.flattenTreeOptions(options);
    },
    // Flatten tree options for BFormSelect
    flattenTreeOptions(options, result = []) {
      options.forEach((opt) => {
        result.push({
          value: opt.id,
          text: opt.label,
        });
        if (opt.children && opt.children.length > 0) {
          this.flattenTreeOptions(opt.children, result);
        }
      });
      return result;
    },
    async loadOntologyInfoTree({ searchQuery, callback }) {
      const apiSearchURL = `${import.meta.env.VITE_API_URL
      }/api/search/ontology/${
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
      // Load entity and status data
      await this.getEntity();

      // Guard against entity not found
      if (!this.entity_info?.entity_id) {
        // Error already shown by getEntity()
        return;
      }

      await this.getStatus();

      // Ensure status options are loaded
      if (this.status_options === null) {
        await this.loadStatusList();
      }

      // Guard against empty options
      if (!this.status_options || this.status_options.length === 0) {
        this.makeToast('Failed to load status options. Please refresh and try again.', 'Error', 'danger');
        return;
      }

      this.$refs.modifyStatusModal.show();
    },
    async submitEntityRename() {
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
          },
        );

        this.makeToast(
          `${'The new disease name for this entity has been submitted '
            + '(status '}${
            response.status
          } (${
            response.statusText
          }).`,
          'Success',
          'success',
        );
        this.resetForm();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async submitEntityDeactivation() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/entity/deactivate`;

      // assign new is_active
      this.entity_info.is_active = this.deactivate_check ? '0' : '1';

      // assign replace_entity_input
      this.entity_info.replaced_by = this.replace_entity_input === null ? 'NULL' : this.replace_entity_input;

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
          },
        );

        this.makeToast(
          `${'The deactivation for this entity has been submitted '
            + '(status '}${
            response.status
          } (${
            response.statusText
          }).`,
          'Success',
          'success',
        );
        this.resetForm();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async submitReviewChange() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/review/create`;

      // define literature specific attributes as constants from inputs
      // first clean the arrays
      const select_additional_references_clean = this.select_additional_references.map((element) => element.replace(/\s+/g, ''));

      const select_gene_reviews_clean = this.select_gene_reviews.map(
        (element) => element.replace(/\s+/g, ''),
      );

      const replace_literature = new Literature(
        select_additional_references_clean,
        select_gene_reviews_clean,
      );

      // compose phenotype specific attributes as constants from inputs
      const replace_phenotype = this.select_phenotype.map((item) => new Phenotype(item.split('-')[1], item.split('-')[0]));

      // compose variation ontology specific attributes as constants from inputs
      const replace_variation_ontology = this.select_variation.map((item) => new Variation(item.split('-')[1], item.split('-')[0]));

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
          },
        );

        this.makeToast(
          `${'The new review for this entity has been submitted '
            + '(status '}${
            response.status
          } (${
            response.statusText
          }).`,
          'Success',
          'success',
        );
        this.resetForm();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async submitStatusChange() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/status/create`;

      // perform update POST request
      try {
        const response = await this.axios.post(
          apiUrl,
          { status_json: this.status_info },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );

        this.makeToast(
          `${'The new status for this entity has been submitted '
            + '(status '}${
            response.status
          } (${
            response.statusText
          }).`,
          'Success',
          'success',
        );
        this.resetForm();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    resetForm() {
      this.modify_entity_input = null;
      this.replace_entity_input = null;
      this.ontology_input = null;
      this.entity_info = new Entity();
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
        !Number.isNaN(Number(tag_copy.replaceAll('PMID:', '')))
        && tag_copy.includes('PMID:')
        && tag_copy.replace('PMID:', '').length > 4
        && tag_copy.replace('PMID:', '').length < 9
      );
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

:deep(.vue-treeselect__menu) {
  outline: 1px solid red;
  color: blue;
}
</style>
