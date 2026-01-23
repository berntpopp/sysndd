<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BOverlay
        :show="checking_entity"
        rounded="sm"
      >
        <BRow class="justify-content-md-center py-2">
          <BCol
            col
            md="12"
          >
            <!-- User Interface controls -->
            <BCard
              header-tag="header"
              align="left"
              body-class="p-0"
              header-class="p-1"
              border-variant="dark"
            >
              <template #header>
                <h6 class="mb-1 text-start font-weight-bold">
                  Create new entity
                </h6>
              </template>

              <BContainer fluid>
                <validation-observer
                  ref="observer"
                  v-slot="{ handleSubmit }"
                >
                  <BForm
                    ref="form"
                    @submit.stop.prevent="handleSubmit(checkSubmission)"
                  >
                    <div class="py-1">
                      <BButton
                        size="sm"
                        type="submit"
                        variant="dark"
                      >
                        <i class="bi bi-plus-square mx-1" />
                        Create new entity
                      </BButton>
                    </div>

                    <hr class="mt-2 mb-3">

                    <!-- Submission check modal -->
                    <BModal
                      id="submissionModal"
                      ref="submissionModal"
                      size="lg"
                      centered
                      ok-title="Submit"
                      no-close-on-esc
                      no-close-on-backdrop
                      header-bg-variant="dark"
                      :footer-bg-variant="header_style[direct_approval]"
                      header-text-variant="light"
                      title="Check entity submission"
                      @hide="hideSubmitEntityModal"
                      @ok="submitEntity"
                    >
                      <p class="my-4">
                        Are you sure you want to submit this entity?
                      </p>

                      <template #modal-footer="{ ok, cancel }">
                        <div class="w-100">
                          <!-- Emulate built in modal footer ok and cancel button actions -->
                          <p class="float-end">
                            <BButton
                              variant="primary"
                              class="float-end me-2"
                              @click="ok()"
                            >
                              Submit
                            </BButton>
                          </p>
                          <p class="float-end">
                            <BButton
                              variant="secondary"
                              class="float-end me-2"
                              @click="cancel()"
                            >
                              Cancel
                            </BButton>
                          </p>
                          <!-- Emulate built in modal footer ok and cancel button actions -->
                          <p class="float-end">
                            <BButton
                              v-b-tooltip.hover.top
                              title="It is not recommended to skip double review and should be performed only by very experienced curators."
                              variant="outline-warning"
                              class="float-end me-2"
                            >
                              <div class="custom-control custom-switch">
                                <input
                                  id="directApprovalSwitch"
                                  v-model="direct_approval"
                                  type="checkbox"
                                  button-variant="info"
                                  class="custom-control-input"
                                >
                                <label
                                  class="custom-control-label"
                                  for="directApprovalSwitch"
                                >Direct approval</label>
                              </div>
                            </BButton>
                          </p>
                        </div>
                      </template>
                    </BModal>
                    <!-- Submission check modal -->

                    <BRow>
                      <!-- column 1 -->
                      <BCol class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="gene-select"
                        >Gene</label>

                        <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
                        <!-- Async search temporarily disabled - use text input -->
                        <!-- <treeselect
                          id="gene-select"
                          v-model="gene_input"
                          :multiple="false"
                          :async="true"
                          :load-options="loadGeneInfoTree"
                          :normalizer="normalizerGeneSearch"
                          required
                        /> -->
                        <BFormInput
                          id="gene-select"
                          v-model="gene_input"
                          size="sm"
                          placeholder="Enter HGNC ID (e.g., HGNC:1234)"
                          required
                        />
                      </BCol>
                    </BRow>
                    <BRow>
                      <!-- column 2 -->
                      <BCol class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="ontology-select"
                        >Disease</label>

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
                      </BCol>
                    </BRow>
                    <BRow>
                      <!-- column 3 -->
                      <BCol class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="inheritance-select"
                        >Inheritance</label>

                        <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
                        <!-- <treeselect
                          id="inheritance-select"
                          v-model="inheritance_input"
                          :multiple="false"
                          :options="inheritance_options"
                          required
                        /> -->
                        <BFormSelect
                          v-if="inheritance_options && inheritance_options.length > 0"
                          id="inheritance-select"
                          v-model="inheritance_input"
                          :options="normalizeInheritanceOptions(inheritance_options)"
                          size="sm"
                          required
                        >
                          <template v-slot:first>
                            <BFormSelectOption :value="null">
                              Select inheritance...
                            </BFormSelectOption>
                          </template>
                        </BFormSelect>
                      </BCol>
                    </BRow>
                    <BRow>
                      <!-- column 4 -->
                      <BCol class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="NDD-select"
                        >NDD</label>
                        <BFormSelect
                          id="NDD-select"
                          v-model="NDD_selected"
                          class="NDD-control"
                          :options="Object.keys(NDD_options)"
                          size="sm"
                          required
                        />
                      </BCol>

                      <!-- column 5 -->
                      <BCol class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="status-select"
                        >Status</label>

                        <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
                        <!-- <treeselect
                          id="status-select"
                          v-model="status_selected"
                          class="status-control"
                          :multiple="false"
                          :options="status_options"
                          :normalizer="normalizeStatus"
                          required
                        /> -->
                        <BFormSelect
                          v-if="status_options && status_options.length > 0"
                          id="status-select"
                          v-model="status_selected"
                          class="status-control"
                          :options="normalizeStatusOptions(status_options)"
                          size="sm"
                          required
                        >
                          <template v-slot:first>
                            <BFormSelectOption :value="null">
                              Select status...
                            </BFormSelectOption>
                          </template>
                        </BFormSelect>
                      </BCol>
                    </BRow>

                    <hr class="mt-2 mb-3">

                    <!-- Sysnopsis input -->
                    <label
                      class="mr-sm-2 mb-0 font-weight-bold"
                      for="textarea-synopsis"
                    >Synopsis</label>

                    <validation-provider
                      v-slot="validationContext"
                      name="validation-synopsis"
                      :rules="{ required: true, min: 10, max: 2000 }"
                    >
                      <BFormTextarea
                        id="textarea-synopsis"
                        v-model="synopsis_review"
                        rows="3"
                        size="sm"
                        :state="getValidationState(validationContext)"
                      />
                    </validation-provider>
                    <!-- Sysnopsis input -->

                    <!-- Phenotype select -->
                    <label
                      class="mr-sm-2 mb-0 font-weight-bold"
                      for="phenotype-select"
                    >Phenotypes</label>

                    <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
                    <!-- Multi-select temporarily disabled - using single select -->
                    <!-- <treeselect
                      v-model="phenotypes_review"
                      :multiple="true"
                      :flat="true"
                      :options="phenotypes_options"
                      :normalizer="normalizePhenotypes"
                    /> -->
                    <BFormSelect
                      v-if="phenotypes_options && phenotypes_options.length > 0"
                      id="phenotype-select"
                      v-model="phenotypes_review[0]"
                      :options="normalizePhenotypesOptions(phenotypes_options)"
                      size="sm"
                    >
                      <template v-slot:first>
                        <BFormSelectOption :value="null">
                          Select phenotype...
                        </BFormSelectOption>
                      </template>
                    </BFormSelect>
                    <!-- Phenotype select -->

                    <!-- Variation ontology select -->
                    <label
                      class="mr-sm-2 mb-0 font-weight-bold"
                      for="phenotype-select"
                    >Variation ontology</label>

                    <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
                    <!-- Multi-select temporarily disabled - using single select -->
                    <!-- <treeselect
                      v-model="variation_ontology_review"
                      :multiple="true"
                      :flat="true"
                      :options="variation_ontology_options"
                      :normalizer="normalizeVariationOntology"
                    /> -->
                    <BFormSelect
                      v-if="variation_ontology_options && variation_ontology_options.length > 0"
                      id="variation-select"
                      v-model="variation_ontology_review[0]"
                      :options="normalizeVariationOntologyOptions(variation_ontology_options)"
                      size="sm"
                    >
                      <template v-slot:first>
                        <BFormSelectOption :value="null">
                          Select variation...
                        </BFormSelectOption>
                      </template>
                    </BFormSelect>

                    <!-- Variation ontology select -->
                    <hr class="mt-2 mb-3">

                    <!-- Publication select -->
                    <label
                      class="mr-sm-2 mb-0 font-weight-bold"
                      for="publications-select"
                    >Publications</label>

                    <!-- publications tag form with links out -->
                    <BFormTags
                      v-model="literature_review"
                      input-id="literature-select"
                      no-outer-focus
                      class="my-0"
                      separator=",;"
                      :tag-validator="tagValidatorPMID"
                      remove-on-delete
                    >
                      <template
                        v-slot="{
                          tags,
                          inputAttrs,
                          inputHandlers,
                          addTag,
                          removeTag,
                        }"
                      >
                        <BInputGroup class="my-0">
                          <BFormInput
                            v-bind="inputAttrs"
                            autocomplete="off"
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
                    <!-- Publication select -->

                    <!-- Genereviews select -->
                    <label
                      class="mr-sm-2 mb-0 font-weight-bold"
                      for="genereviews-select"
                    >GeneReviews</label>

                    <!-- genereviews tag form with links out -->
                    <BFormTags
                      v-model="genereviews_review"
                      input-id="genereviews-select"
                      no-outer-focus
                      class="my-0"
                      separator=",;"
                      :tag-validator="tagValidatorPMID"
                      remove-on-delete
                    >
                      <template
                        v-slot="{
                          tags,
                          inputAttrs,
                          inputHandlers,
                          addTag,
                          removeTag,
                        }"
                      >
                        <BInputGroup class="my-0">
                          <BFormInput
                            v-bind="inputAttrs"
                            autocomplete="off"
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
                    <!-- Genereviews select -->

                    <hr class="mt-2 mb-3">

                    <!-- Review comments -->
                    <label
                      class="me-sm-2 mb-0 fw-bold"
                      for="textarea-review"
                    >Comment</label>
                    <BFormTextarea
                      id="textarea-review"
                      v-model="review_comment"
                      rows="2"
                      size="sm"
                      placeholder="Additional comments to this entity relevant for the curator."
                    />
                    <!-- Review comments -->
                  </BForm>
                </validation-observer>
              </BContainer>
            </BCard>
          </BCol>
        </BRow>
      </BOverlay>
    </BContainer>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

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
  name: 'CreateEntity',
  // TODO: Treeselect disabled pending Bootstrap-Vue-Next migration
  components: {},
  mixins: [toastMixin, colorAndSymbolsMixin, textMixin],
  data() {
    return {
      entity_submission: {},
      gene_input: null,
      ontology_input: null,
      inheritance_options: [],
      inheritance_input: null,
      phenotypes_options: [],
      phenotypes_review: [],
      variation_ontology_options: [],
      variation_ontology_review: [],
      synopsis_review: '',
      literature_review: [],
      genereviews_review: [],
      review_comment: '',
      status_options: [],
      status_selected: null,
      NDD_options: {
        Yes: [{ boolean_id: 1, logical: 'TRUE' }],
        No: [{ boolean_id: 0, logical: 'FALSE' }],
      },
      NDD_selected: null,
      checking_entity: false,
      direct_approval: false,
    };
  },
  mounted() {
    this.loadPhenotypesList();
    this.loadVariationOntologyList();
    this.loadStatusList();
    this.loadInheritanceList();
  },
  methods: {
    getValidationState({ dirty, validated, valid = null }) {
      return dirty || validated ? valid : null;
    },
    async loadPhenotypesList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/list/phenotype?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.phenotypes_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    normalizePhenotypes(node) {
      return {
        id: node.id,
        label: node.label,
      };
    },
    async loadVariationOntologyList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/list/variation_ontology?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.variation_ontology_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    normalizeVariationOntology(node) {
      return {
        id: node.id,
        label: node.label,
      };
    },
    async loadStatusList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/list/status?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.status_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadInheritanceList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/list/inheritance?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.inheritance_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
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
    async loadGeneInfoTree({ searchQuery, callback }) {
      const apiSearchURL = `${process.env.VUE_APP_API_URL
      }/api/search/gene/${
        searchQuery
      }?tree=true`;

      try {
        const response_search = await this.axios.get(apiSearchURL);
        callback(null, response_search.data);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadOntologyInfoTree({ searchQuery, callback }) {
      const apiSearchURL = `${process.env.VUE_APP_API_URL
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
    normalizerOntologySearch(node) {
      return {
        id: node.id,
        label: `${node.id} (${node.disease_ontology_name})`,
      };
    },
    normalizerGeneSearch(node) {
      return {
        id: node.id,
        label: `${node.id} (${node.symbol}; ${node.name})`,
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
        value: opt.category_id,
        text: opt.category,
      }));
    },
    // Normalize inheritance options for BFormSelect
    normalizeInheritanceOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return this.flattenTreeOptions(options);
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
    infoEntity() {
      // define entity specific attributes as constants from inputs
      const entity_hgnc_id = this.gene_input;
      const entity_disease_ontology_id_version = this.ontology_input;
      const entity_hpo_mode_of_inheritance_term = this.inheritance_input;
      const entity_ndd_phenotype = this.NDD_options[this.NDD_selected][0].boolean_id;

      // define literature specific attributes as constants from inputs
      // first clean the arrays
      const literature_review_clean = this.literature_review.map((element) => element.replace(/\s+/g, ''));

      const genereviews_review_clean = this.genereviews_review.map(
        (element) => element.replace(/\s+/g, ''),
      );

      const new_literature = new Literature(
        literature_review_clean,
        genereviews_review_clean,
      );

      // define phenotype specific attributes as constants from inputs
      const new_phenotype = this.phenotypes_review.map((item) => new Phenotype(item.split('-')[1], item.split('-')[0]));

      // define variation ontology specific attributes as constants from inputs
      const new_variation_ontology = this.variation_ontology_review.map(
        (item) => new Variation(item.split('-')[1], item.split('-')[0]),
      );

      // define review specific attributes as constants from inputs
      const review_synopsis = this.synopsis_review;
      const { review_comment } = this;
      const new_review = new Review(
        review_synopsis,
        new_literature,
        new_phenotype,
        new_variation_ontology,
        review_comment,
      );

      // define status specific attributes as constants from inputs
      const new_status = new Status(this.status_selected, '', 0);

      // compose entity
      const new_entity = new Entity(
        entity_hgnc_id,
        entity_disease_ontology_id_version,
        entity_hpo_mode_of_inheritance_term,
        entity_ndd_phenotype,
      );

      // compose submission
      const new_submission = new Submission(
        new_entity,
        new_review,
        new_status,
      );

      this.entity_submission = new_submission;
    },
    async submitEntity() {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/entity/create?direct_approval=${
        this.direct_approval}`;

      try {
        const response = await this.axios.post(
          apiUrl,
          { create_json: this.entity_submission },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );

        this.makeToast(
          `${'The new entity has been submitted '
            + '(status '}${
            response.status
          } (${
            response.statusText
          }).`,
          'Success',
          'success',
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.resetForm();
        this.checking_entity = false;
      }
    },
    checkSubmission() {
      this.checking_entity = true;
      this.$refs.submissionModal.show();
      this.infoEntity();
    },
    resetForm() {
      this.entity_submission = {};
      this.gene_input = null;
      this.ontology_input = null;
      this.inheritance_input = null;
      this.phenotypes_review = [];
      this.variation_ontology_review = [];
      this.synopsis_review = '';
      this.literature_review = [];
      this.genereviews_review = [];
      this.review_comment = '';
      this.status_selected = null;
      this.NDD_selected = null;
      this.direct_approval = false;

      this.$nextTick(() => {
        this.$refs.observer.reset();
      });
    },
    hideSubmitEntityModal() {
      this.checking_entity = false;
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
