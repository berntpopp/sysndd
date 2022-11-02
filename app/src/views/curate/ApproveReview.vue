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
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-1 text-left font-weight-bold">
                Approve new reviews
              </h6>
            </template>
            <!-- User Interface controls -->

            <!-- button for approve all -->
            <b-form
              ref="form"
              @submit.stop.prevent="checkAllApprove"
            >
              <b-input-group-append class="p-1">
                <b-button
                  size="sm"
                  type="submit"
                  variant="dark"
                >
                  <b-icon
                    icon="check2-circle"
                    class="mx-1"
                  />
                  Approve all reviews
                </b-button>
              </b-input-group-append>
            </b-form>
            <!-- button for approve all -->

            <!-- Table Interface controls -->
            <b-row>
              <b-col class="my-1">
                <b-form-group class="mb-1">
                  <b-input-group
                    prepend="Search"
                    size="sm"
                  >
                    <b-form-input
                      id="filter-input"
                      v-model="filter"
                      type="search"
                      placeholder="any field by typing here"
                      debounce="500"
                    />
                  </b-input-group>
                </b-form-group>
              </b-col>

              <b-col class="my-1" />

              <b-col class="my-1" />

              <b-col class="my-1">
                <b-input-group
                  prepend="Per page"
                  class="mb-1"
                  size="sm"
                >
                  <b-form-select
                    id="per-page-select"
                    v-model="perPage"
                    :options="pageOptions"
                    size="sm"
                  />
                </b-input-group>

                <b-pagination
                  v-model="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  align="fill"
                  size="sm"
                  class="my-0"
                  last-number
                />
              </b-col>
            </b-row>
            <!-- Table Interface controls -->

            <!-- Main table -->
            <b-spinner
              v-if="loading_review_approve"
              label="Loading..."
              class="float-center m-5"
            />
            <b-table
              v-else
              :items="items_ReviewTable"
              :fields="fields_ReviewTable"
              :busy="isBusy"
              :current-page="currentPage"
              :per-page="perPage"
              :filter="filter"
              :filter-included-fields="filterOn"
              :sort-by.sync="sortBy"
              :sort-desc.sync="sortDesc"
              :sort-direction="sortDirection"
              stacked="md"
              head-variant="light"
              show-empty
              small
              fixed
              striped
              hover
              sort-icon-left
              @filtered="onFiltered"
            >
              <template #cell(entity_id)="data">
                <div>
                  <b-link :href="'/Entities/' + data.item.entity_id">
                    <b-badge
                      variant="primary"
                      style="cursor: pointer"
                    >
                      sysndd:{{ data.item.entity_id }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(symbol)="data">
                <div class="font-italic">
                  <b-link :href="'/Genes/' + data.item.hgnc_id">
                    <b-badge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="success"
                      :title="data.item.hgnc_id"
                    >
                      {{ data.item.symbol }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(disease_ontology_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-link
                    :href="
                      '/Ontology/' +
                        data.item.disease_ontology_id_version.replace(/_.+/g, '')
                    "
                    target="_blank"
                  >
                    <b-badge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="secondary"
                      :title="
                        data.item.disease_ontology_name +
                          '; ' +
                          data.item.disease_ontology_id_version
                      "
                    >
                      {{ truncate(data.item.disease_ontology_name, 40) }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-badge
                    v-b-tooltip.hover.leftbottom
                    pill
                    variant="info"
                    class="justify-content-md-center"
                    size="1.3em"
                    :title="
                      data.item.hpo_mode_of_inheritance_term_name +
                        ' (' +
                        data.item.hpo_mode_of_inheritance_term +
                        ')'
                    "
                  >
                    {{
                      inheritance_short_text[
                        data.item.hpo_mode_of_inheritance_term_name
                      ]
                    }}
                  </b-badge>
                </div>
              </template>

              <template #cell(synopsis)="data">
                <div>
                  <b-form-textarea
                    plaintext
                    size="sm"
                    rows="1"
                    :value="data.item.synopsis"
                    :aria-label="'Synopsis for ' + data.item.entity_id"
                    v-b-tooltip.hover.leftbottom
                    :title="data.item.synopsis"
                  />
                </div>
              </template>

              <template #cell(comment)="data">
                <div>
                  <b-form-textarea
                    plaintext
                    size="sm"
                    rows="1"
                    :value="data.item.comment"
                    :aria-label="'Comment for ' + data.item.entity_id"
                    v-b-tooltip.hover.leftbottom
                    :title="data.item.comment"
                  />
                </div>
              </template>

              <template #cell(review_date)="data">
                <div>
                  <b-icon
                    icon="pen"
                    font-scale="0.7"
                  />
                  <b-badge
                    v-b-tooltip.hover.right
                    variant="light"
                    :title="data.item.review_date"
                  >
                    {{ data.item.review_date.substring(0,10) }}
                  </b-badge>
                </div>
              </template>

              <template #cell(review_user_name)="data">
                <div>
                  <b-icon
                    icon="person-circle"
                    font-scale="1.0"
                  />
                  <b-badge
                    v-b-tooltip.hover.right
                    variant="dark"
                    :title="data.item.review_user_role"
                  >
                    {{ data.item.review_user_name }}
                  </b-badge>
                </div>
              </template>

              <template #cell(actions)="row">
                <b-button
                  size="sm"
                  class="mr-1 btn-xs"
                  variant="outline-primary"
                  @click="row.toggleDetails"
                >
                  <b-icon
                    :icon="row.detailsShowing ? 'eye-slash' : 'eye'"
                    font-scale="0.9"
                  />
                </b-button>

                <b-button
                  v-b-tooltip.hover.left
                  size="sm"
                  class="mr-1 btn-xs"
                  variant="secondary"
                  title="Edit review"
                  @click="infoReview(row.item, row.index, $event.target)"
                >
                  <b-icon
                    icon="pen"
                    font-scale="0.9"
                  />
                </b-button>

                <b-button
                  v-b-tooltip.hover.right
                  size="sm"
                  class="mr-1 btn-xs"
                  variant="danger"
                  title="Approve review"
                  @click="infoApproveReview(row.item, row.index, $event.target)"
                >
                  <b-icon
                    icon="check2-circle"
                    font-scale="0.9"
                  />
                </b-button>
              </template>

              <template #row-details="row">
                <b-card>
                  <b-table
                    :items="[row.item]"
                    :fields="fields_details_ReviewTable"
                    stacked
                    small
                  />
                </b-card>
              </template>
            </b-table>
            <!-- Main table -->
          </b-card>
        </b-col>
      </b-row>

      <!-- Approve modal -->
      <b-modal
        :id="approveModal.id"
        size="sm"
        centered
        ok-title="Approve"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        @ok="handleApproveOk"
      >
        <template #modal-title>
          <h4>
            Entity:
            <b-badge variant="primary">
              {{ approveModal.title }}
            </b-badge>
          </h4>
        </template>

        You have finished checking this review and
        <span class="font-weight-bold">want to submit it</span>?
      </b-modal>
      <!-- Approve modal -->

      <!-- Modify review modal -->
      <b-modal
        :id="reviewModal.id"
        :ref="reviewModal.id"
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
            <b-link
              :href="'/Entities/' + review_info.entity_id"
              target="_blank"
            >
              <b-badge variant="primary">
                sysndd:{{ review_info.entity_id }}
              </b-badge>
            </b-link>
            <b-link
              :href="'/Genes/' + entity_info.symbol"
              target="_blank"
            >
              <b-badge
                v-b-tooltip.hover.leftbottom
                pill
                variant="success"
                :title="entity_info.hgnc_id"
              >
                {{ entity_info.symbol }}
              </b-badge>
            </b-link>
            <b-link
              :href="
                '/Ontology/' +
                  entity_info.disease_ontology_id_version.replace(/_.+/g, '')
              "
              target="_blank"
            >
              <b-badge
                v-b-tooltip.hover.leftbottom
                pill
                variant="secondary"
                :title="
                  entity_info.disease_ontology_name +
                    '; ' +
                    entity_info.disease_ontology_id_version
                "
              >
                {{ truncate(entity_info.disease_ontology_name, 40) }}
              </b-badge>
            </b-link>
            <b-badge
              v-b-tooltip.hover.leftbottom
              pill
              variant="info"
              class="justify-content-md-center"
              size="1.3em"
              :title="
                entity_info.hpo_mode_of_inheritance_term_name +
                  ' (' +
                  entity_info.hpo_mode_of_inheritance_term +
                  ')'
              "
            >
              {{
                inheritance_short_text[
                  entity_info.hpo_mode_of_inheritance_term_name
                ]
              }}
            </b-badge>
          </h4>
        </template>

        <template #modal-footer="{ ok, cancel }">
          <div class="w-100">
            <p class="float-left">
              Review by:
              <b-icon
                icon="person-circle"
                font-scale="1.0"
              />
              <b-badge variant="dark">
                {{ review_info.review_user_name }}
              </b-badge>
              <b-badge variant="dark">
                {{ review_info.review_user_role }}
              </b-badge>
            </p>

            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button
              variant="primary"
              class="float-right mr-2"
              @click="ok()"
            >
              Save review
            </b-button>
            <b-button
              variant="secondary"
              class="float-right mr-2"
              @click="cancel()"
            >
              Cancel
            </b-button>
          </div>
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
              separator=" ,;"
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

      <!-- Check approve all modal -->
      <b-modal
        id="approveAllModal"
        ref="approveAllModal"
        size="lg"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        title="Approve all reviews"
        @ok="handleAllReviewsOk"
      >
        <p class="my-4">
          Are you sure you want to
          <span class="font-weight-bold">approve ALL</span> reviews below?
        </p>
        <div class="custom-control custom-switch">
          <input
            id="removeSwitch"
            v-model="approve_all_selected"
            type="checkbox"
            button-variant="info"
            class="custom-control-input"
          >
          <label
            class="custom-control-label"
            for="removeSwitch"
          ><b>{{ switch_approve_text[approve_all_selected] }}</b></label>
        </div>
      </b-modal>
      <!-- Check approve all modal -->
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

import Entity from '@/assets/js/classes/submission/submissionEntity';
import Review from '@/assets/js/classes/submission/submissionReview';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

export default {
  name: 'ApproveReview',
  // register the Treeselect component
  components: { Treeselect },
  mixins: [toastMixin, colorAndSymbolsMixin, textMixin],
  data() {
    return {
      phenotypes_options: [],
      variation_ontology_options: [],
      items_ReviewTable: [],
      fields_ReviewTable: [
        {
          key: 'entity_id',
          label: 'Entity',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-left',
        },
        {
          key: 'symbol',
          label: 'Gene',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-left',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          sortable: true,
          class: 'text-left',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: true,
          class: 'text-left',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'synopsis',
          label: 'Clinical synopsis',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'comment',
          label: 'Comment',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'review_date',
          label: 'Review date',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'review_user_name',
          label: 'User',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        { key: 'actions', label: 'Actions' },
      ],
      fields_details_ReviewTable: [
        {
          key: 'review_id',
          label: 'Review ID',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-left',
        },
        {
          key: 'review_date',
          label: 'Review date',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'disease_ontology_id_version',
          label: 'Ontology ID version',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease ontology name',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'review_user_name',
          label: 'Review user',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'is_primary',
          label: 'Primary',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'synopsis',
          label: 'Clinical synopsis',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
      ],
      totalRows: 0,
      currentPage: 1,
      perPage: '10',
      pageOptions: ['10', '25', '50', '200'],
      sortBy: '',
      sortDesc: false,
      sortDirection: 'asc',
      filter: null,
      filterOn: [],
      entity: [],
      approveModal: {
        id: 'approve-modal',
        title: '',
        content: [],
      },
      reviewModal: {
        id: 'review-modal',
        title: '',
        content: [],
      },
      entity_info: {
        entity_id: 0,
        symbol: '',
        hgnc_id: '',
        disease_ontology_id_version: '',
        disease_ontology_name: '',
        hpo_mode_of_inheritance_term_name: '',
        hpo_mode_of_inheritance_term: '',
      },
      review_info: new Review(),
      select_phenotype: [],
      select_variation: [],
      select_additional_references: [],
      select_gene_reviews: [],
      approve_all_selected: false,
      switch_approve_text: { true: 'Yes', false: 'No' },
      loading_review_approve: true,
      loading_review_modal: true,
      isBusy: true,
    };
  },
  mounted() {
    this.loadPhenotypesList();
    this.loadVariationOntologyList();
    this.loadReviewTableData();
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
    async loadVariationOntologyList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/list/variation_ontology?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.variation_ontology_options = response.data;
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
    normalizeVariationOntology(node) {
      return {
        id: node.id,
        label: node.label,
      };
    },
    async loadReviewTableData() {
      this.isBusy = true;
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/review`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.items_ReviewTable = response.data;
        this.totalRows = response.data.length;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.isBusy = false;
      this.loading_review_approve = false;
    },
    async loadReviewInfo(review_id) {
      this.loading_review_modal = true;

      const apiGetReviewURL = `${process.env.VUE_APP_API_URL}/api/review/${review_id}`;
      const apiGetPhenotypesURL = `${process.env.VUE_APP_API_URL
      }/api/review/${
        review_id
      }/phenotypes`;
      const apiGetVariationURL = `${process.env.VUE_APP_API_URL}/api/review/${review_id}/variation`;
      const apiGetPublicationsURL = `${process.env.VUE_APP_API_URL
      }/api/review/${
        review_id
      }/publications`;

      try {
        const response_review = await this.axios.get(apiGetReviewURL);
        const response_phenotypes = await this.axios.get(apiGetPhenotypesURL);
        const response_variation = await this.axios.get(apiGetVariationURL);
        const response_publications = await this.axios.get(apiGetPublicationsURL);

        // define phenotype specific attributes as constants from response
        const new_phenotype = response_phenotypes.data.map((item) => new Phenotype(item.phenotype_id, item.modifier_id));
        this.select_phenotype = response_phenotypes.data.map((item) => `${item.modifier_id}-${item.phenotype_id}`);

        // define variation specific attributes as constants from response
        const new_variation = response_variation.data.map((item) => new Variation(item.vario_id, item.modifier_id));
        this.select_variation = response_variation.data.map((item) => `${item.modifier_id}-${item.vario_id}`);

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
        this.review_info.review_user_name = response_review.data[0].review_user_name;
        this.review_info.review_user_role = response_review.data[0].review_user_role;

        this.loading_review_modal = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async getEntity(entity_input) {
      const apiGetURL = `${process.env.VUE_APP_API_URL
      }/api/entity?filter=equals(entity_id,${
        entity_input
      })`;

      try {
        const response = await this.axios.get(apiGetURL);
        // assign to local variable
        [this.entity_info] = response.data.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async submitReviewChange() {
      this.isBusy = true;
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/review/update`;

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

      // perform update PUT request
      try {
        const response = await this.axios.put(
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
        this.loadReviewTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    infoReview(item, index, button) {
      this.reviewModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadReviewInfo(item.review_id);
      this.$root.$emit('bv::show::modal', this.reviewModal.id, button);
    },
    infoApproveReview(item, index, button) {
      this.approveModal.title = `sysndd:${item.entity_id}`;
      this.entity = [];
      this.entity.push(item);
      this.$root.$emit('bv::show::modal', this.approveModal.id, button);
    },
    async handleApproveOk(bvModalEvt) {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/review/approve/${
        this.entity[0].review_id
      }?review_ok=true`;

      try {
        const response = await this.axios.put(
          apiUrl,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );

        this.loadReviewTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async handleAllReviewsOk() {
      if (this.approve_all_selected) {
        const apiUrl = `${process.env.VUE_APP_API_URL
        }/api/review/approve/all?review_ok=true`;
        try {
          const response = this.axios.put(
            apiUrl,
            {},
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            },
          );

          this.loadReviewTableData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      }
    },
    checkAllApprove() {
      this.$refs.approveAllModal.show();
    },
    resetForm() {
      this.entity_info = {
        entity_id: 0,
        symbol: '',
        hgnc_id: '',
        disease_ontology_id_version: '',
        disease_ontology_name: '',
        hpo_mode_of_inheritance_term_name: '',
        hpo_mode_of_inheritance_term: '',
      };
      this.review_info = new Review();
      this.select_phenotype = [];
      this.select_variation = [];
      this.select_additional_references = [];
      this.select_gene_reviews = [];
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
    onFiltered(filteredItems) {
      // Trigger pagination to update the number of buttons/pages due to filtering
      this.totalRows = filteredItems.length;
      this.currentPage = 1;
    },
    truncate(str, n) {
      return str.length > n ? `${str.substr(0, n - 1)}...` : str;
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
