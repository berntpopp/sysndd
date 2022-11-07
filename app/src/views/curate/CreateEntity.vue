<template>
  <div class="container-fluid">
    <b-container fluid>
      <b-overlay
        :show="checking_entity"
        rounded="sm"
      >
        <b-row class="justify-content-md-center py-2">
          <b-col
            col
            md="12"
          >
            <!-- User Interface controls -->
            <b-card
              header-tag="header"
              align="left"
              body-class="p-0"
              header-class="p-1"
              border-variant="dark"
            >
              <template #header>
                <h6 class="mb-1 text-left font-weight-bold">
                  Create new entity
                </h6>
              </template>

              <b-container fluid>
                <validation-observer
                  ref="observer"
                  v-slot="{ handleSubmit }"
                >
                  <b-form
                    ref="form"
                    @submit.stop.prevent="handleSubmit(checkSubmission)"
                  >
                    <b-input-group-append class="py-1">
                      <b-button
                        size="sm"
                        type="submit"
                        variant="dark"
                      >
                        <b-icon
                          icon="plus-square"
                          class="mx-1"
                        />
                        Create new entity
                      </b-button>
                    </b-input-group-append>

                    <hr class="mt-2 mb-3">

                    <!-- Submission check modal -->
                    <b-modal
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
                          <p class="float-right">
                            <b-button
                              variant="primary"
                              class="float-right mr-2"
                              @click="ok()"
                            >
                              Submit
                            </b-button>
                          </p>
                          <p class="float-right">
                            <b-button
                              variant="secondary"
                              class="float-right mr-2"
                              @click="cancel()"
                            >
                              Cancel
                            </b-button>
                          </p>
                          <!-- Emulate built in modal footer ok and cancel button actions -->
                          <p class="float-right">
                            <b-button
                              v-b-tooltip.hover.top
                              title="It is not recommended to skip double review and should be performed only by very experienced curators."
                              variant="outline-warning"
                              class="float-right mr-2"
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
                            </b-button>
                          </p>
                        </div>
                      </template>
                    </b-modal>
                    <!-- Submission check modal -->

                    <b-row>
                      <!-- column 1 -->
                      <b-col class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="gene-select"
                        >Gene</label>

                        <treeselect
                          id="gene-select"
                          v-model="gene_input"
                          :multiple="false"
                          :async="true"
                          :load-options="loadGeneInfoTree"
                          :normalizer="normalizerGeneSearch"
                          required
                        />
                      </b-col>
                    </b-row>
                    <b-row>
                      <!-- column 2 -->
                      <b-col class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="ontology-select"
                        >Disease</label>

                        <treeselect
                          id="ontology-select"
                          v-model="ontology_input"
                          :multiple="false"
                          :async="true"
                          :load-options="loadOntologyInfoTree"
                          :normalizer="normalizerOntologySearch"
                          required
                        />
                      </b-col>
                    </b-row>
                    <b-row>
                      <!-- column 3 -->
                      <b-col class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="inheritance-select"
                        >Inheritance</label>

                        <treeselect
                          id="inheritance-select"
                          v-model="inheritance_input"
                          :multiple="false"
                          :options="inheritance_options"
                          required
                        />
                      </b-col>
                    </b-row>
                    <b-row>
                      <!-- column 4 -->
                      <b-col class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="NDD-select"
                        >NDD</label>
                        <b-form-select
                          id="NDD-select"
                          v-model="NDD_selected"
                          class="NDD-control"
                          :options="Object.keys(NDD_options)"
                          size="sm"
                          required
                        />
                      </b-col>

                      <!-- column 5 -->
                      <b-col class="my-1">
                        <label
                          class="mr-sm-2 mb-0 font-weight-bold"
                          for="status-select"
                        >Status</label>

                        <treeselect
                          id="status-select"
                          v-model="status_selected"
                          class="status-control"
                          :multiple="false"
                          :options="status_options"
                          :normalizer="normalizeStatus"
                          required
                        />
                      </b-col>
                    </b-row>

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
                      <b-form-textarea
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

                    <treeselect
                      v-model="phenotypes_review"
                      :multiple="true"
                      :flat="true"
                      :options="phenotypes_options"
                      :normalizer="normalizePhenotypes"
                    />
                    <!-- Phenotype select -->

                    <!-- Variation ontology select -->
                    <label
                      class="mr-sm-2 mb-0 font-weight-bold"
                      for="phenotype-select"
                    >Variation ontology</label>

                    <treeselect
                      v-model="variation_ontology_review"
                      :multiple="true"
                      :flat="true"
                      :options="variation_ontology_options"
                      :normalizer="normalizeVariationOntology"
                    />

                    <!-- Variation ontology select -->
                    <hr class="mt-2 mb-3">

                    <!-- Publication select -->
                    <label
                      class="mr-sm-2 mb-0 font-weight-bold"
                      for="publications-select"
                    >Publications</label>

                    <!-- publications tag form with links out -->
                    <b-form-tags
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
                        <b-input-group class="my-0">
                          <b-form-input
                            v-bind="inputAttrs"
                            autocomplete="off"
                            placeholder="Enter PMIDs separated by comma or semicolon"
                            class="form-control"
                            size="sm"
                            v-on="inputHandlers"
                          />
                          <b-input-group-append>
                            <b-button
                              variant="secondary"
                              size="sm"
                              @click="addTag()"
                            >
                              Add
                            </b-button>
                          </b-input-group-append>
                        </b-input-group>

                        <div class="d-inline-block">
                          <h6>
                            <b-form-tag
                              v-for="tag in tags"
                              :key="tag"
                              :title="tag"
                              variant="secondary"
                              @remove="removeTag(tag)"
                            >
                              <b-link
                                :href="
                                  'https://pubmed.ncbi.nlm.nih.gov/' +
                                    tag.replace('PMID:', '')
                                "
                                target="_blank"
                                class="text-light"
                              >
                                <b-icon
                                  icon="box-arrow-up-right"
                                  font-scale="0.9"
                                />
                                {{ tag }}
                              </b-link>
                            </b-form-tag>
                          </h6>
                        </div>
                      </template>
                    </b-form-tags>
                    <!-- Publication select -->

                    <!-- Genereviews select -->
                    <label
                      class="mr-sm-2 mb-0 font-weight-bold"
                      for="genereviews-select"
                    >GeneReviews</label>

                    <!-- genereviews tag form with links out -->
                    <b-form-tags
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
                        <b-input-group class="my-0">
                          <b-form-input
                            v-bind="inputAttrs"
                            autocomplete="off"
                            placeholder="Enter PMIDs separated by comma or semicolon"
                            class="form-control"
                            size="sm"
                            v-on="inputHandlers"
                          />
                          <b-input-group-append>
                            <b-button
                              variant="secondary"
                              size="sm"
                              @click="addTag()"
                            >
                              Add
                            </b-button>
                          </b-input-group-append>
                        </b-input-group>

                        <div class="d-inline-block">
                          <h6>
                            <b-form-tag
                              v-for="tag in tags"
                              :key="tag"
                              :title="tag"
                              variant="secondary"
                              @remove="removeTag(tag)"
                            >
                              <b-link
                                :href="
                                  'https://pubmed.ncbi.nlm.nih.gov/' +
                                    tag.replace('PMID:', '')
                                "
                                target="_blank"
                                class="text-light"
                              >
                                <b-icon
                                  icon="box-arrow-up-right"
                                  font-scale="0.9"
                                />
                                {{ tag }}
                              </b-link>
                            </b-form-tag>
                          </h6>
                        </div>
                      </template>
                    </b-form-tags>
                    <!-- Genereviews select -->

                    <hr class="mt-2 mb-3">

                    <!-- Review comments -->
                    <label
                      class="mr-sm-2 mb-0 font-weight-bold"
                      for="textarea-review"
                    >Comment</label>
                    <b-form-textarea
                      id="textarea-review"
                      v-model="review_comment"
                      rows="2"
                      size="sm"
                      placeholder="Additional comments to this entity relevant for the curator."
                    />
                    <!-- Review comments -->
                  </b-form>
                </validation-observer>
              </b-container>
            </b-card>
          </b-col>
        </b-row>
      </b-overlay>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

// import the Treeselect component
import Treeselect from '@riophae/vue-treeselect';
// import the Treeselect styles
import '@riophae/vue-treeselect/dist/vue-treeselect.css';

import Submission from '@/assets/js/classes/submission/submissionSubmission';
import Entity from '@/assets/js/classes/submission/submissionEntity';
import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

export default {
  name: 'CreateEntity',
  // register the Treeselect component
  components: { Treeselect },
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
