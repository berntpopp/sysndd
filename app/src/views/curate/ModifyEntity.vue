<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">


          <!-- User Interface controls -->
          <b-card 
          header-tag="header"
          bg-variant="light"
          align="left"
          >
            <template #header>
              <h6 class="mb-1 text-left font-weight-bold">
                Modify an existing entity
              </h6>
            </template>
          <!-- User Interface controls -->

            <b-card
              class="my-2"
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
                    :multiple="false"
                    :async="true"
                    :load-options="searchEntityInfo"
                    v-model="modify_entity_input"
                    :normalizer="normalizer"
                    required
                  />

                </b-col>
              </b-row>

            </b-card>

            <b-card
              class="my-2"
              v-if="modify_entity_input"
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
                      <b-icon icon="pen" font-scale="1.0"></b-icon> 
                      <b-icon icon="link" font-scale="1.0"></b-icon> 
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
                      <b-icon icon="x" font-scale="1.0"></b-icon> 
                      <b-icon icon="link" font-scale="1.0"></b-icon> 
                      Deactivate entity
                    </b-button>
                  </b-input-group-append>
                </b-col>

                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button 
                      size="sm"
                      variant="dark"
                      v-b-modal.modifyReviewModal
                    >
                      <b-icon icon="pen" font-scale="1.0"></b-icon> 
                      <b-icon icon="clipboard-plus" font-scale="1.0"></b-icon> 
                      Modify review
                    </b-button>
                  </b-input-group-append>
                </b-col>

                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button 
                      size="sm"
                      variant="dark"
                      v-b-modal.modifyStatusModal
                    >
                      <b-icon icon="pen" font-scale="1.0"></b-icon> 
                      <b-icon icon="stoplights" font-scale="1.0"></b-icon> 
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
        title="Rename entity disease"
        @ok="submitEntityRename"
      >
        <p class="my-4">Select a new disease name:</p>

        <treeselect
          id="ontology-select" 
          :multiple="false"
          :async="true"
          :load-options="loadOntologyInfoTree"
          v-model="ontology_input"
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
        title="Deactivate entity"
        @ok="submitEntityDeactivation"
      >
        <div>
          <p class="my-2">1. Are you sure that you want to deactivate this entity?</p>

          <div class="custom-control custom-switch">
          <input 
            type="checkbox" 
            button-variant="info"
            class="custom-control-input" 
            id="deactivateSwitch"
            v-model="deactivate_check"
          >
          <label class="custom-control-label" for="deactivateSwitch">
            {{ deactivate_check ? 'Yes' : 'No' }}
          </label>
          </div>
        </div>

        <div
          v-if="deactivate_check"
        >
          <p class="my-2">2. Was this entity replaced by another one?</p>

          <div class="custom-control custom-switch">
          <input 
            type="checkbox" 
            button-variant="info"
            class="custom-control-input" 
            id="replaceSwitch"
            v-model="replace_check"
          >
          <label class="custom-control-label" for="replaceSwitch">
            {{ replace_check ? 'Yes' : 'No' }}
          </label>
          </div>
        </div>

        <div
          v-if="replace_check"
        >
          <p class="my-2">3. Select the entity replacing the above one:</p>

            <treeselect
              id="entity-select" 
              :multiple="false"
              :async="true"
              :load-options="searchEntityInfo"
              v-model="replace_entity_input"
              :normalizer="normalizer"
              required
            />

        </div>
      </b-modal>
      <!-- Deactivate entity modal -->


      <!-- Modify review modal -->
      <b-modal 
      id="modifyReviewModal" 
      ref="modifyReviewModal" 
      size="lg" 
      centered 
      ok-title="Submit" 
      no-close-on-esc 
      no-close-on-backdrop 
      header-bg-variant="dark" 
      header-text-variant="light"
      title="Modify review for entity"
      >
        <p class="my-4">Inputs to modify review data</p>
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
      title="Modify status for entity"
      >
        <p class="my-4">Inputs to modify status data</p>
      </b-modal>
      <!-- Modify status modal -->

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
  name: 'ApproveStatus',
    data() {
      return {
        modify_entity_input: null,
        replace_entity_input: null,
        ontology_input: null,
        entity_info: null,
        deactivate_check: false,
        replace_check: false,
      };
    },
    mounted() {
    },
    methods: {
        async searchEntityInfo({searchQuery, callback}) {
          let apiSearchURL = process.env.VUE_APP_API_URL + '/api/entity?filter=contains(any,' + searchQuery + ')';

          try {
            let response_search = await this.axios.get(apiSearchURL);

            callback(null, response_search.data.data);
            } catch (e) {
            console.error(e);
            }
        },
        async getEntity() {
          let apiSearchURL = process.env.VUE_APP_API_URL + '/api/entity?filter=equals(entity_id,' + this.modify_entity_input + ')';

          try {
            let response = await this.axios.get(apiSearchURL);

            // compose entity
            this.entity_info = new this.Entity(response.data.data[0].hgnc_id, response.data.data[0].disease_ontology_id_version, response.data.data[0].hpo_mode_of_inheritance_term, response.data.data[0].ndd_phenotype, response.data.data[0].entity_id, response.data.data[0].is_active, response.data.data[0].replaced_by);

            } catch (e) {
            console.error(e);
            }
        },
        normalizer(node) {
          return {
            id: node.entity_id,
            label: "sysndd:" + node.entity_id + " (" + node.symbol + " - " + node.disease_ontology_id_version + " - " + node.hpo_mode_of_inheritance_term_name + ")",
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
        showEntityRename() {
          this.getEntity();
          this.$refs['renameModal'].show();
        },
        showEntityDeactivate() {
          this.getEntity();
          this.$refs['deactivateModal'].show();
        },
        async submitEntityRename() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/entity/rename?rename_json=';

          // assign new disease_ontology_id
          this.entity_info.disease_ontology_id_version = this.ontology_input;

          // compose submission
          const submission = new this.Submission(this.entity_info);

          try {
            let submission_json = JSON.stringify(submission);

            let response = await this.axios.post(apiUrl + submission_json, {}, {
               headers: {
                 'Authorization': 'Bearer ' + localStorage.getItem('token')
               }
             });

            this.makeToast('The new disease name for this entity has been submitted ' + '(status ' + response.status + ' (' + response.statusText + ').', 'Success', 'success');
            this.resetForm();

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }
        },
        async submitEntityDeactivation() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/entity/deactivate?deactivate_json=';

          // assign new is_active
          this.entity_info.is_active = (this.deactivate_check ? '0' : '1');

          // assign replace_entity_input
          this.entity_info.replaced_by = (this.replace_entity_input == null ? "NULL" : this.replace_entity_input);
          
          // compose submission
          const submission = new this.Submission(this.entity_info);

          try {
            let submission_json = JSON.stringify(submission);
            console.log(submission_json);

            let response = await this.axios.post(apiUrl + submission_json, {}, {
               headers: {
                 'Authorization': 'Bearer ' + localStorage.getItem('token')
               }
             });

            this.makeToast('The deactivation for this entity has been submitted ' + '(status ' + response.status + ' (' + response.statusText + ').', 'Success', 'success');
            this.resetForm();

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }
        },
        resetForm() {
          this.modify_entity_input = null;
          this.replace_entity_input = null;
          this.ontology_input = null;
          this.entity_info = null;
          this.deactivate_check = false;
          this.replace_check = false;
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
// to do: adapt this elsewhere to contain entity_id, is_active and make them optional
Entity(hgnc_id, disease_ontology_id_version, hpo_mode_of_inheritance_term, ndd_phenotype, entity_id, is_active, replaced_by) {
      this.hgnc_id = hgnc_id;
      this.disease_ontology_id_version = disease_ontology_id_version;
      this.hpo_mode_of_inheritance_term = hpo_mode_of_inheritance_term;
      this.ndd_phenotype = ndd_phenotype;
      this.entity_id = entity_id;
      this.is_active = is_active;
      this.replaced_by = replaced_by;
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