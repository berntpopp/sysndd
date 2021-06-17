<template>
  <div class="container-fluid" style="padding-top: 80px;">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>

      <b-row class="justify-content-md-center mt-8">
        <b-col col md="10">

          <h3>Review</h3>

          <!-- User Interface controls -->
          <b-row>
            <b-col lg="6" class="my-1">
              <b-form-group
                label="Filter"
                label-for="filter-input"
                label-cols-sm="3"
                label-align-sm="right"
                label-size="sm"
                class="mb-0"
              >
                <b-input-group size="sm">
                  <b-form-input
                    id="filter-input"
                    v-model="filter"
                    type="search"
                    placeholder="Type to Search"
                  ></b-form-input>

                  <b-input-group-append>
                    <b-button :disabled="!filter" @click="filter = ''">Clear</b-button>
                  </b-input-group-append>
                </b-input-group>
              </b-form-group>
            </b-col>

            <b-col sm="5" md="6" class="my-1">
              <b-form-group
                label="Per page"
                label-for="per-page-select"
                label-cols-sm="6"
                label-cols-md="4"
                label-cols-lg="3"
                label-align-sm="right"
                label-size="sm"
                class="mb-0"
              >
                <b-form-select
                  id="per-page-select"
                  v-model="perPage"
                  :options="pageOptions"
                  size="sm"
                ></b-form-select>
              </b-form-group>
            </b-col>

            <b-col sm="7" md="6" class="my-1">
              <b-pagination
                v-model="currentPage"
                :total-rows="totalRows"
                :per-page="perPage"
                align="fill"
                size="sm"
                class="my-0"
              ></b-pagination>
            </b-col>
          </b-row>

          <!-- Main table element -->
          <b-table
            :items="items"
            :fields="fields"
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

            <template #cell(actions)="row">
              <b-button 
                size="sm" 
                @click="info(row.item, row.index, $event.target)" 
                class="mr-1"
                v-b-tooltip.hover.left 
                title="new review"
                >
                  <b-icon icon="pen"></b-icon>
              </b-button>
              <b-button 
                size="sm" 
                @click="info(row.item, row.index, $event.target)" 
                class="mr-1" 
                :variant="stoplights_style[row.item.category]"
                v-b-tooltip.hover.top 
                title="edit status"
                >
                  <b-icon icon="stoplights"></b-icon>
              </b-button>
              <b-button 
                size="sm" 
                @click="info(row.item, row.index, $event.target)" 
                class="mr-1"
                v-b-tooltip.hover.right 
                title="mark for removal"
              >
                <b-icon icon="x-circle"></b-icon>
              </b-button>
            </template>

            <template #cell(entity_id)="data">
              <b-link v-bind:href="'/Entities/' + data.item.entity_id">
                <div style="cursor:pointer">sysndd:{{ data.item.entity_id }}</div>
              </b-link>
            </template>

            <template #cell(symbol)="data">
              <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
                <div class="font-italic" v-b-tooltip.hover.leftbottom v-bind:title="data.item.hgnc_id">{{ data.item.symbol }}</div> 
              </b-link>
            </template>

            <template #cell(disease_ontology_name)="data">
              <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version"> 
                <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version">{{ truncate(data.item.disease_ontology_name, 20) }}</div> 
              </b-link>
            </template>

            <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.hpo_mode_of_inheritance_term">{{ data.item.hpo_mode_of_inheritance_term_name.replace(" inheritance", "") }}</div> 
            </template>
            
          </b-table>

        </b-col>
      </b-row>
      

      <!-- New review modal -->
      <b-modal 
      :id="infoModal.id" 
      :title="infoModal.title" 
      size="xl" 
      centered 
      ok-title="Save review" 
      no-close-on-esc 
      no-close-on-backdrop 
      header-bg-variant="dark" 
      header-text-variant="light" 
      @hide="resetInfoModal" 
      @ok="handleOk"
      >
        <form ref="form" @submit.stop.prevent="handleSubmit">

            <b-table
                :items="entity"
                :fields="entity_fields"
                small
            >
            </b-table>

              <label class="mr-sm-2 font-weight-bold" for="select-status">Association Category</label>
              <b-form-select
                id="select-status"
                v-model="status_review"
                :options="status_options"
                class="mb-3"
                value-field="category_id"
                text-field="category"
                disabled-field="notEnabled"
                size="sm" 
              ></b-form-select>

              <label class="mr-sm-2 font-weight-bold" for="textarea-synopsis">Synopsis</label>
              <b-form-textarea
                id="textarea-synopsis"
                rows="3"
                size="sm" 
                v-model="synopsis_review"
              >
              </b-form-textarea>

              <label class="mr-sm-2 font-weight-bold" for="phenotype-select">Phenotypes</label>
              <multiselect 
                id="phenotype-select"
                v-model="phenotypes_review"
                tag-placeholder="Add this as new tag" 
                placeholder="Search or add a tag" 
                label="HPO_term" 
                track-by="phenotype_id" 
                :options="phenotypes_options" 
                :multiple="true"
                :taggable="true" 
                @tag="addTag"
                >
              </multiselect> 

              <label class="mr-sm-2 font-weight-bold" for="publications-select">Publications</label>
                <b-form-tags
                  input-id="publications-select"
                  v-model="literature_review"
                  separator=" ,;"
                  placeholder="Enter PMIDs separated by space, comma or semicolon"
                  :tag-validator="tagValidatorPMID"
                  remove-on-delete
                >
                </b-form-tags>

              <label class="mr-sm-2 font-weight-bold" for="genereviews-select">GeneReviews</label>
                <b-form-tags
                  input-id="genereviews-select"
                  v-model="genereviews_review"
                  separator=" ,;"
                  placeholder="Enter PMIDs separated by space, comma or semicolon"
                  :tag-validator="tagValidatorPMID"
                  remove-on-delete
                ></b-form-tags>
        </form>
      </b-modal>
      <!-- New review modal -->

      
    </b-container>
  </div>
</template>


<script>
export default {
  name: 'Review',
  data() {
        return {
          stoplights_style: {Definitive: "success", Moderate: "warning", Candidate: "primary", Refuted: "danger"},
          items: [],
          fields: [
            { key: 'entity_id', label: 'Entity', sortable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'symbol', label: 'Gene Symbol', sortable: true, class: 'text-left' },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            {
              key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { key: 'ndd_phenotype', label: 'NDD Association', sortable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
          ],
          totalRows: 1,
          currentPage: 1,
          perPage: 10,
          pageOptions: [10, 25, 50, { value: 100, text: "Show a lot" }],
          sortBy: '',
          sortDesc: false,
          sortDirection: 'asc',
          filter: null,
          filterOn: [],
          infoModal: {
            id: 'info-modal',
            title: '',
            content: []
          },
          entity: [],
          entity_fields: [
            { key: 'symbol', label: 'Gene Symbol', sortable: true, class: 'text-left' },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            {
              key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { key: 'ndd_phenotype', label: 'NDD Association', sortable: true, class: 'text-left' }
          ],
          status: [],
          status_fields: [
            { key: 'category', label: 'Association Category', class: 'text-left' },
          ],
          review: [{synopsis: ''}],
          review_fields: [
            { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-left' },
          ],
          review_number: 0,
          synopsis_review: '',
          status_review: '',
          publications: [],
          literature_review: [],
          genereviews_review: [],
          publication_options: [],
          phenotypes_review: [],
          phenotypes_options: [],
          status_options: [],
          loading: true
        }
      },
      computed: {
        sortOptions() {
          // Create an options list from our fields
          return this.fields
            .filter(f => f.sortable)
            .map(f => {
              return { text: f.label, value: f.key }
            })
        }
      },
      mounted() {
        // Set the initial number of items
        this.loadEntitiesData();
        this.loadPhenotypesList();
        this.loadStatusList();
      },
      methods: {
        onFiltered(filteredItems) {
          // Trigger pagination to update the number of buttons/pages due to filtering
          this.totalRows = filteredItems.length
          this.currentPage = 1
        },
        resetInfoModal() {
          this.infoModal.title = '';
          this.infoModal.content = [];
          this.entity = [];
          this.entity_review = [];
          this.status_review = '';
          this.synopsis_review = '';
          this.literature_review = [];
          this.genereviews_review = [];
        },
        info(item, index, button) {
          this.infoModal.title = `Entity: sysndd:${item.entity_id}`;
          this.entity.push(item);
          this.loadEntityInfo(item.entity_id);
          this.$root.$emit('bv::show::modal', this.infoModal.id, button);
        },
        async loadEntitiesData() {
          this.loading = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/entities';
          try {
            let response = await this.axios.get(apiUrl);
            this.items = response.data;
            this.totalRows = response.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loading = false;
        },
        async loadEntityInfo(sysndd_id) {
          // define API query URLs
          let apiStatusURL = process.env.VUE_APP_API_URL + '/api/entities/' + sysndd_id + '/status';
          let apiReviewURL = process.env.VUE_APP_API_URL + '/api/entities/' + sysndd_id + '/review';
          let apiPublicationsURL = process.env.VUE_APP_API_URL + '/api/entities/' + sysndd_id + '/publications';
          let apiPhenotypesURL = process.env.VUE_APP_API_URL + '/api/entities/' + sysndd_id + '/phenotypes';

          try {
            // get API responses
            let response_status = await this.axios.get(apiStatusURL);
            let response_review = await this.axios.get(apiReviewURL);
            let response_publications = await this.axios.get(apiPublicationsURL);
            let response_phenotypes = await this.axios.get(apiPhenotypesURL);

            // assign response data to global variables
            this.status = response_status.data;
            this.review = response_review.data;
            this.phenotypes = response_phenotypes.data;

            this.status_review = this.status[this.review_number].category_id;
            this.synopsis_review = this.review[this.review_number].synopsis;
            this.phenotypes_review = this.phenotypes;

            // filter the publications data into groups and assign to global variables
            let literature_filter = response_publications.data.filter(li => li.publication_type === "additional_references");
            let genereviews_filter = response_publications.data.filter(gr => gr.publication_type === "gene_review");

            Object.entries(literature_filter).forEach(([key, value]) => this.literature_review.push(value.publication_id));
            Object.entries(genereviews_filter).forEach(([key, value]) => this.genereviews_review.push(value.publication_id));

            } catch (e) {
            console.error(e);
            }
        },
        async loadPhenotypesList() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotypes_list';
          try {
            let response = await this.axios.get(apiUrl);
            this.phenotypes_options = response.data;
          } catch (e) {
            console.error(e);
          }
        },
        async loadStatusList() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/status_list';
          try {
            let response = await this.axios.get(apiUrl);
            this.status_options = response.data;
          } catch (e) {
            console.error(e);
          }
        },
        async submitReview(submission) {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/entities/review?review_json=';
          try {
            let submission_json = JSON.stringify(submission);
            let response = await this.axios.post(apiUrl + submission_json);

            localStorage.setItem('submissions', submission);

          } catch (e) {
            console.error(e);
          }
        },
        handleOk(bvModalEvt) {

          let review_submission = {};
          let phenotypes_submission = [];
          let modifiers_submission = [];

          Object.entries(this.phenotypes_review).forEach(([key, value]) => {
            phenotypes_submission.push(value.phenotype_id);
            modifiers_submission.push(value.modifier_id);
            }
          );

          review_submission.entity = this.entity[0].entity_id;
          review_submission.synopsis = this.synopsis_review;
          review_submission.literature = {};
          review_submission.literature.additional_references = this.literature_review;
          review_submission.literature.gene_review = this.genereviews_review;
          review_submission.phenotypes = {};
          review_submission.phenotypes.phenotype_id = phenotypes_submission;
          review_submission.phenotypes.modifier_id = modifiers_submission;

          console.log(review_submission);
          this.submitReview(review_submission);
          this.resetInfoModal();
        },
        addTag(newTag) {
            const tag = {
              phenotype_id: newTag
            }
            this.options.push(tag);
            this.value.push(tag);
          },
        tagValidatorPMID(tag) {
          // Individual PMID tag validator function
          return !isNaN(Number(tag.replace('PMID:', ''))) && tag.includes('PMID:') && tag.replace('PMID:', '').length > 4 && tag.replace('PMID:', '').length < 10;
        },
        truncate(str, n) {
          return (str.length > n) ? str.substr(0, n-1) + '...' : str;
        }
      }
  }
</script>


<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>