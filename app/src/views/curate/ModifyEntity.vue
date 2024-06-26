<!-- views/curate/ModifyEntity.vue -->
<template>
  <div class="container-fluid">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <!-- User Interface controls -->
          <b-card
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-1 text-left font-weight-bold">
                Modify an existing entity
              </h6>
            </template>
            <!-- User Interface controls -->

            <b-card
              class="my-2"
              body-class="p-0"
              header-class="p-1"
              border-variant="dark"
            >
              <template #header>
                <h6 class="mb-1 text-left font-weight-bold">
                  1. Select an entity to modify
                </h6>
              </template>

              <b-row>
                <b-col class="my-1">
                  <treeselect
                    id="entity-select"
                    v-model="modify_entity_input"
                    :multiple="false"
                    :async="true"
                    :load-options="searchEntityInfo"
                    :normalizer="normalizerEntitySearch"
                    required
                  />
                </b-col>
              </b-row>
            </b-card>

            <b-card
              v-if="modify_entity_input"
              class="my-2"
              body-class="p-0"
              header-class="p-1"
              border-variant="dark"
            >
              <template #header>
                <h6 class="mb-1 text-left font-weight-bold">
                  2. Options to modify the selected entity
                  <b-badge variant="primary">
                    sysndd:{{ modify_entity_input }}
                  </b-badge>
                </h6>
              </template>

              <b-row>
                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button
                      size="sm"
                      variant="dark"
                      @click="showEntityRename()"
                    >
                      <b-icon
                        icon="pen"
                        font-scale="1.0"
                      />
                      <b-icon
                        icon="link"
                        font-scale="1.0"
                      />
                      Rename disease
                    </b-button>
                  </b-input-group-append>
                </b-col>

                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button
                      size="sm"
                      variant="dark"
                      @click="showEntityDeactivate()"
                    >
                      <b-icon
                        icon="x"
                        font-scale="1.0"
                      />
                      <b-icon
                        icon="link"
                        font-scale="1.0"
                      />
                      Deactivate entity
                    </b-button>
                  </b-input-group-append>
                </b-col>

                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button
                      size="sm"
                      variant="dark"
                      @click="showReviewModify()"
                    >
                      <b-icon
                        icon="pen"
                        font-scale="1.0"
                      />
                      <b-icon
                        icon="clipboard-plus"
                        font-scale="1.0"
                      />
                      Modify review
                    </b-button>
                  </b-input-group-append>
                </b-col>

                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button
                      size="sm"
                      variant="dark"
                      @click="showStatusModify()"
                    >
                      <b-icon
                        icon="pen"
                        font-scale="1.0"
                      />
                      <b-icon
                        icon="stoplights"
                        font-scale="1.0"
                      />
                      Modify status
                    </b-button>
                  </b-input-group-append>
                </b-col>
              </b-row>
            </b-card>
          </b-card>
        </b-col>
      </b-row>

      <!-- Rename disease modal -->
      <b-modal
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
            <b-badge variant="primary">
              sysndd:{{ entity_info.entity_id }}
            </b-badge>
          </h4>
        </template>

        <p class="my-4">
          Select a new disease name:
        </p>

        <treeselect
          id="ontology-select"
          v-model="ontology_input"
          :multiple="false"
          :async="true"
          :load-options="loadOntologyInfoTree"
          :normalizer="normalizerOntologySearch"
          required
        />
      </b-modal>
      <!-- Rename disease modal -->

      <!-- Deactivate entity modal -->
      <b-modal
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
            <b-badge variant="primary">
              sysndd:{{ entity_info.entity_id }}
            </b-badge>
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

          <treeselect
            id="entity-select"
            v-model="replace_entity_input"
            :multiple="false"
            :async="true"
            :load-options="searchEntityInfo"
            :normalizer="normalizerEntitySearch"
            required
          />
        </div>
      </b-modal>
      <!-- Deactivate entity modal -->

      <!-- Modify review modal -->
      <b-modal
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
            <b-badge variant="primary">
              sysndd:{{ entity_info.entity_id }}
            </b-badge>
          </h4>
        </template>

        <b-overlay
          :show="loading_review_modal"
          rounded="sm"
        >
          <b-form
            ref="form"
            @submit.stop.prevent="submitReviewChange"
          >
            <!-- Synopsis textarea -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-textarea-synopsis"
            >Synopsis</label>
            <b-form-textarea
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

            <treeselect
              id="review-phenotype-select"
              v-model="select_phenotype"
              :multiple="true"
              :flat="true"
              :options="phenotypes_options"
              :normalizer="normalizePhenotypes"
              required
            />
            <!-- Phenotype select -->

            <!-- Variation ontolog select -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-variation-select"
            >Variation ontology</label>

            <treeselect
              id="review-variation-select"
              v-model="select_variation"
              :multiple="true"
              :flat="true"
              :options="variation_ontology_options"
              :normalizer="normalizeVariationOntology"
              required
            />
            <!-- Variation ontolog select -->

            <!-- publications tag form with links out -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-publications-select"
            >Publications</label>
            <b-form-tags
              v-model="select_additional_references"
              input-id="review-literature-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template
                v-slot="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
              >
                <b-input-group class="my-0">
                  <b-form-input
                    v-bind="inputAttrs"
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
            <!-- publications tag form with links out -->

            <!-- genereviews tag form with links out -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-genereviews-select"
            >Genereviews</label>
            <b-form-tags
              v-model="select_gene_reviews"
              input-id="review-genereviews-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template
                v-slot="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
              >
                <b-input-group class="my-0">
                  <b-form-input
                    v-bind="inputAttrs"
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
            <!-- genereviews tag form with links out -->

            <!-- Review comment textarea -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-textarea-comment"
            >Comment</label>
            <b-form-textarea
              id="review-textarea-comment"
              v-model="review_info.comment"
              rows="2"
              size="sm"
              placeholder="Additional comments to this entity relevant for the curator."
            />
            <!-- Review comment textarea -->
          </b-form>
        </b-overlay>
      </b-modal>
      <!-- Modify review modal -->

      <!-- Modify status modal -->
      <b-modal
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
            <b-badge variant="primary">
              sysndd:{{ entity_info.entity_id }}
            </b-badge>
          </h4>
        </template>

        <b-overlay
          :show="loading_status_modal"
          rounded="sm"
        >
          <b-form
            ref="form"
            @submit.stop.prevent="submitStatusChange"
          >
            <treeselect
              id="status-select"
              v-model="status_info.category_id"
              :multiple="false"
              :options="status_options"
              :normalizer="normalizeStatus"
            />

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
            <b-form-textarea
              id="status-textarea-comment"
              v-model="status_info.comment"
              rows="2"
              size="sm"
              placeholder="Why should this entities status be changed."
            />
          </b-form>
        </b-overlay>
      </b-modal>
      <!-- Modify status modal -->
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';

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
  name: 'ApproveStatus',
  // register the Treeselect component
  components: { Treeselect },
  mixins: [toastMixin, colorAndSymbolsMixin],
  data() {
    return {
      status_options: [],
      phenotypes_options: [],
      variation_ontology_options: [],
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
    async searchEntityInfo({ searchQuery, callback }) {
      const apiSearchURL = `${process.env.VUE_APP_API_URL
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
      const apiGetURL = `${process.env.VUE_APP_API_URL
      }/api/entity?filter=equals(entity_id,${
        this.modify_entity_input
      })`;

      try {
        const response = await this.axios.get(apiGetURL);

        // compose entity
        this.entity_info = new Entity(
          response.data.data[0].hgnc_id,
          response.data.data[0].disease_ontology_id_version,
          response.data.data[0].hpo_mode_of_inheritance_term,
          response.data.data[0].ndd_phenotype,
          response.data.data[0].entity_id,
          response.data.data[0].is_active,
          response.data.data[0].replaced_by,
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async getReview() {
      this.loading_review_modal = true;

      const apiGetReviewURL = `${process.env.VUE_APP_API_URL
      }/api/entity/${
        this.modify_entity_input
      }/review`;
      const apiGetPhenotypesURL = `${process.env.VUE_APP_API_URL
      }/api/entity/${
        this.modify_entity_input
      }/phenotypes`;
      const apiGetVariationURL = `${process.env.VUE_APP_API_URL
      }/api/entity/${
        this.modify_entity_input
      }/variation`;
      const apiGetPublicationsURL = `${process.env.VUE_APP_API_URL
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

      const apiGetURL = `${process.env.VUE_APP_API_URL
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
    showEntityRename() {
      this.getEntity();
      this.$refs.renameModal.show();
    },
    showEntityDeactivate() {
      this.getEntity();
      this.$refs.deactivateModal.show();
    },
    showReviewModify() {
      this.getEntity();
      this.getReview();
      this.$refs.modifyReviewModal.show();
    },
    showStatusModify() {
      this.getEntity();
      this.getStatus();
      this.$refs.modifyStatusModal.show();
    },
    async submitEntityRename() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/entity/rename`;

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
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/entity/deactivate`;

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
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/review/create`;

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
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/status/create`;

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
