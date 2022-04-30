<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">


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

              <validation-observer ref="observer" v-slot="{ handleSubmit }">
              <b-form ref="form" @submit.stop.prevent="handleSubmit(checkSubmission)">

          <b-input-group-append>
            <b-button 
              size="sm"
              type="submit" 
              variant="dark"
            >
              <b-icon icon="plus-square" class="mx-1"></b-icon>
              Create new entity
            </b-button>
          </b-input-group-append>


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
          header-text-variant="light"
          title="Check entity submission"
          @ok="submitEntity"
          >
            <p class="my-4">Are you sure you want to submit this entity?</p>
          </b-modal>
          <!-- Submission check modal -->


          <b-row>
            <!-- column 1 -->
            <b-col class="my-1">
              <label class="mr-sm-2 font-weight-bold" for="gene-select">Gene</label>

              <treeselect
                id="gene-select" 
                :multiple="false"
                :async="true"
                :load-options="loadGeneInfoTree"
                v-model="gene_input"
                required
              />

            </b-col>

            <!-- column 2 -->
            <b-col class="my-1">
              <label class="mr-sm-2 font-weight-bold" for="ontology-select">Disease</label>

              <treeselect
                id="ontology-select" 
                :multiple="false"
                :async="true"
                :load-options="loadOntologyInfoTree"
                v-model="ontology_input"
                :normalizer="normalizerOntologySearch"
                required
              />

            </b-col>

            <!-- column 3 -->
            <b-col class="my-1">
              <label class="mr-sm-2 font-weight-bold" for="inheritance-select">Inheritance</label>

              <treeselect
                id="inheritance-select" 
                :multiple="false"
                :async="true"
                :load-options="loadInheritanceInfoTree"
                v-model="inheritance_input"
                required
              />

            </b-col>

            <!-- column 4 -->
            <b-col class="my-1">
              <label class="mr-sm-2 font-weight-bold" for="NDD-select">NDD</label>
              <b-form-select 
                id="NDD-select" 
                class="NDD-control"
                :options="Object.keys(NDD_options)"
                v-model="NDD_selected"
                size="sm"
                required
              >
              </b-form-select>
            </b-col>

            <!-- column 5 -->
            <b-col class="my-1">
              <label class="mr-sm-2 font-weight-bold" for="status-select">Status</label>
              <b-form-select 
                id="status-select" 
                class="status-control"
                :options="Object.keys(status_options)"
                v-model="status_selected"
                size="sm"
                required
              >
              </b-form-select>
            </b-col>
          </b-row>

          <!-- Sysnopsis input -->
          <label class="mr-sm-2 font-weight-bold" for="textarea-synopsis">Synopsis</label>

            <validation-provider
              name="validation-synopsis"
              :rules="{ required: true, min: 10, max: 2000 }"
              v-slot="validationContext"
            >

            <b-form-textarea
              id="textarea-synopsis"
              rows="3"
              size="sm" 
              v-model="synopsis_review"
              :state="getValidationState(validationContext)"
            >
            </b-form-textarea>

            </validation-provider>
          <!-- Sysnopsis input -->

          <!-- Phenotype select -->
          <label class="mr-sm-2 font-weight-bold" for="phenotype-select">Phenotypes</label>

            <treeselect 
              v-model="phenotypes_review" 
              :multiple="true" 
              :flat="true"
              :options="phenotypes_options"
              :normalizer="normalizePhenotypes"
              required
            />
          <!-- Phenotype select -->

          <!-- Variation ontology select -->
          <label class="mr-sm-2 font-weight-bold" for="phenotype-select">Variation ontology</label>

            <treeselect 
              v-model="variation_ontology_review" 
              :multiple="true" 
              :flat="true"
              :options="variation_ontology_options"
              :normalizer="normalizeVariationOntology"
              required
            />
              
          <!-- Variation ontology select -->

          <!-- Publication select -->
            <label class="mr-sm-2 font-weight-bold" for="publications-select">Publications</label>

              <!-- publications tag form with links out -->
              <b-form-tags
              input-id="literature-select"
              v-model="literature_review" 
              no-outer-focus 
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
              >
                <template v-slot="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                  <b-input-group class="my-0">
                    <b-form-input
                      v-bind="inputAttrs"
                      v-on="inputHandlers"
                      autocomplete="off" 
                      placeholder="Enter PMIDs separated by space, comma or semicolon"
                      class="form-control"
                      size="sm"
                    ></b-form-input>
                    <b-input-group-append>
                      <b-button @click="addTag()" 
                      variant="secondary"
                      size="sm"
                      >
                      Add
                      </b-button>
                    </b-input-group-append>
                  </b-input-group>

                  <div class="d-inline-block">
                    <h6>
                    <b-form-tag
                    v-for="tag in tags"
                    @remove="removeTag(tag)"
                    :key="tag"
                    :title="tag"
                    variant="secondary"
                    >
                      <b-link 
                      v-bind:href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')" 
                      target="_blank" 
                      class="text-light"
                      >
                      <b-icon icon="box-arrow-up-right" font-scale="0.9"></b-icon>
                        {{ tag }}
                      </b-link>
                    </b-form-tag>
                    </h6>
                  </div>

                </template>
              </b-form-tags>
          <!-- Publication select -->

          <!-- Genereviews select -->
            <label class="mr-sm-2 font-weight-bold" for="genereviews-select">GeneReviews</label>
            
              <!-- genereviews tag form with links out -->
              <b-form-tags 
              input-id="genereviews-select"
              v-model="genereviews_review" 
              no-outer-focus 
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
              >
                <template v-slot="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                  <b-input-group class="my-0">
                    <b-form-input
                      v-bind="inputAttrs"
                      v-on="inputHandlers"
                      autocomplete="off" 
                      placeholder="Enter PMIDs separated by space, comma or semicolon"
                      class="form-control"
                      size="sm"
                    ></b-form-input>
                    <b-input-group-append>
                      <b-button @click="addTag()" 
                      variant="secondary"
                      size="sm"
                      >
                      Add
                      </b-button>
                    </b-input-group-append>
                  </b-input-group>

                  <div class="d-inline-block">
                    <h6>
                    <b-form-tag
                    v-for="tag in tags"
                    @remove="removeTag(tag)"
                    :key="tag"
                    :title="tag"
                    variant="secondary"
                    >
                      <b-link 
                      v-bind:href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')" 
                      target="_blank" 
                      class="text-light"
                      >
                      <b-icon icon="box-arrow-up-right" font-scale="0.9"></b-icon>
                        {{ tag }}
                      </b-link>
                    </b-form-tag>
                    </h6>
                  </div>

                </template>
              </b-form-tags>
          <!-- Genereviews select -->

          <!-- Review comments -->
          <label class="mr-sm-2 font-weight-bold" for="textarea-review">Comment</label>
          <b-form-textarea
            id="textarea-review"
            rows="2"
            size="sm" 
            v-model="review_comment"
            placeholder="Additional comments to this entity relevant for the curator."
          >
          </b-form-textarea>
          <!-- Review comments -->

              </b-form>
              </validation-observer>
            </b-container>
          </b-card>

        </b-col>
      </b-row>

    </b-container>
  </div>
</template>


<script>
  // import the Treeselect component
  import Treeselect from '@riophae/vue-treeselect'
  // import the Treeselect styles
  import '@riophae/vue-treeselect/dist/vue-treeselect.css'

export default {
  // register the Treeselect component
  components: { Treeselect },
  name: 'CreateEntity',
    data() {
      return {
        entity_submission: {},
        gene_input: null,
        ontology_input: null,
        inheritance_input: null,
        phenotypes_options: [],
        phenotypes_review: [],
        variation_ontology_options: [],
        variation_ontology_review: [],
        synopsis_review: "",
        literature_review: [],
        genereviews_review: [],
        review_comment: "",
        status_options: [],
        status_selected: null,
        NDD_options: {"No": [{"boolean_id": 0, "logical": "FALSE"}], "Yes": [{"boolean_id": 1, "logical": "TRUE"}]},
        NDD_selected: null,
      };
    },
    mounted() {
      this.loadPhenotypesList();
      this.loadVariationOntologyList();
      this.loadStatusList();
    },
    methods: {
        getValidationState({ dirty, validated, valid = null }) {
          return dirty || validated ? valid : null;
        },
        async loadPhenotypesList() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/list/phenotype?tree=true';
          try {
            let response = await this.axios.get(apiUrl);
            this.phenotypes_options = response.data;
          } catch (e) {
            console.error(e);
          }
        },
        normalizePhenotypes(node) {
          return {
            id: node.id,
            label: node.label,
          }
        },
        async loadVariationOntologyList() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/list/variation_ontology?tree=true';
          try {
            let response = await this.axios.get(apiUrl);
            this.variation_ontology_options = response.data;
          } catch (e) {
            console.error(e);
          }
        },
        normalizeVariationOntology(node) {
          return {
            id: node.id,
            label: node.label,
          }
        },
        async loadStatusList() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/list/status';
          try {
            let response = await this.axios.get(apiUrl);
            this.status_options = response.data[0];
          } catch (e) {
            console.error(e);
          }
        },
        tagValidatorPMID(tag) {
          // Individual PMID tag validator function
          tag = tag.replace(/\s+/g,'');
          return !isNaN(Number(tag.replaceAll('PMID:', ''))) && tag.includes('PMID:') && tag.replace('PMID:', '').length > 4 && tag.replace('PMID:', '').length < 9;
        },
        async loadGeneInfoTree({searchQuery, callback}) {
          let apiSearchURL = process.env.VUE_APP_API_URL + '/api/search/gene/' + searchQuery + '?tree=true';

          try {
            let response_search = await this.axios.get(apiSearchURL);
            callback(null, response_search.data);
            } catch (e) {
            console.error(e);
            }
        },
        async loadOntologyInfoTree({searchQuery, callback}) {
          let apiSearchURL = process.env.VUE_APP_API_URL + '/api/search/ontology/' + searchQuery + '?tree=true';

          try {
            let response_search = await this.axios.get(apiSearchURL);
            callback(null, response_search.data);
            } catch (e) {
            console.error(e);
            }
        },
        normalizerOntologySearch(node) {
          return {
            id: node.id,
            label: node.id + " (" + node.label + ")",
          }
        },
        async loadInheritanceInfoTree({searchQuery, callback}) {
          let apiSearchURL = process.env.VUE_APP_API_URL + '/api/search/inheritance/' + searchQuery + '?tree=true';

          try {
            let response_search = await this.axios.get(apiSearchURL);
            callback(null, response_search.data);
            } catch (e) {
            console.error(e);
            }
        },
        infoEntity() {
          // define entity specific attributes as constants from inputs
          const entity_hgnc_id = this.gene_input;
          const entity_disease_ontology_id_version = this.ontology_input;
          const entity_hpo_mode_of_inheritance_term = this.inheritance_input;
          const entity_ndd_phenotype = this.NDD_options[this.NDD_selected][0].boolean_id;

          // define literature specific attributes as constants from inputs
          // first clean the arrays
          const literature_review_clean = this.literature_review.map(element => {
            return element.replace(/\s+/g,'');
          });

          const genereviews_review_clean = this.genereviews_review.map(element => {
            return element.replace(/\s+/g,'');
          });

          const new_literature = new this.Literature(literature_review_clean, genereviews_review_clean);

          // define phenotype specific attributes as constants from inputs
          const new_phenotype = this.phenotypes_review.map(item => {
              return new this.Phenotype(item.split('-')[1], item.split('-')[0]);
            });

          // define variation ontology specific attributes as constants from inputs
          const new_variation_ontology = this.variation_ontology_review.map(item => {
              return new this.Variation(item.split('-')[1], item.split('-')[0]);
            });

          // define review specific attributes as constants from inputs
          const review_synopsis = this.synopsis_review;
          const review_comment = this.review_comment;
          const new_review = new this.Review(review_synopsis, new_literature, new_phenotype, new_variation_ontology, review_comment);

          // define status specific attributes as constants from inputs
          const status_category_id = this.status_options[this.status_selected][0].category_id;
          const new_status = new this.Status(status_category_id, "", 0);

          // compose entity
          const new_entity = new this.Entity(entity_hgnc_id, entity_disease_ontology_id_version, entity_hpo_mode_of_inheritance_term, entity_ndd_phenotype);

          // compose submission
          const new_submission = new this.Submission(new_entity, new_review, new_status);
          
          this.entity_submission = new_submission;

        },
        async submitEntity() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/entity/create?create_json=';

          try {
            let submission_json = JSON.stringify(this.entity_submission);

            let response = await this.axios.post(apiUrl + submission_json, {}, {
               headers: {
                 'Authorization': 'Bearer ' + localStorage.getItem('token')
               }
             });

            this.makeToast('The new entity has been submitted ' + '(status ' + response.status + ' (' + response.statusText + ').', 'Success', 'success');
            this.resetForm();

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }
        },
        checkSubmission() {
          this.$refs['submissionModal'].show();
          this.infoEntity();
        },
        resetForm() {
          this.entity_submission = {};
          this.gene_input = null;
          this.ontology_input = null;
          this.inheritance_input = null;
          this.phenotypes_review = [],
          this.variation_ontology_review = [];
          this.synopsis_review = "";
          this.literature_review = [];
          this.genereviews_review = [];
          this.review_comment = "";
          this.status_selected = null;
          this.NDD_selected = null;

          this.$nextTick(() => {
            this.$refs.observer.reset();
          });
        },
        makeToast(event, title = null, variant = null) {
            this.$bvToast.toast('' + event, {
              title: title,
              toaster: 'b-toaster-top-right',
              variant: variant,
              solid: true
            })
        },
// these object constructor functions should go in a mixin
// https://learnvue.co/2019/12/how-to-manage-mixins-in-vuejs/#the-solution-vuejs-mixins
Submission(entity, review, status) {
      this.entity = entity;
      this.review = review;
      this.status = status;
    },
Entity(hgnc_id, disease_ontology_id_version, hpo_mode_of_inheritance_term, ndd_phenotype) {
      this.hgnc_id = hgnc_id;
      this.disease_ontology_id_version = disease_ontology_id_version;
      this.hpo_mode_of_inheritance_term = hpo_mode_of_inheritance_term;
      this.ndd_phenotype = ndd_phenotype;
    },
Review(synopsis, literature, phenotypes, variation_ontology, comment) {
      this.synopsis = synopsis;
      this.literature = literature;
      this.phenotypes = phenotypes;
      this.variation_ontology = variation_ontology;
      this.comment = comment;
    },
Status(category_id, comment, problematic) {
      this.category_id = category_id;
      this.comment = comment;
      this.problematic = problematic;
    },
Phenotype(phenotype_id, modifier_id) {
      this.phenotype_id = phenotype_id;
      this.modifier_id = modifier_id;
    },
Variation(vario_id, modifier_id) {
      this.vario_id = vario_id;
      this.modifier_id = modifier_id;
    },
Literature(additional_references, gene_review) {
      this.additional_references = additional_references;
      this.gene_review = gene_review;
    },
// these functions should go in a mixin
      }
    };
</script>


<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>