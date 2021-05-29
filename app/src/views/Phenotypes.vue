<template>
  <div class="container-fluid" style="padding-top: 80px;">
    <b-container fluid>

      <b-row class="justify-content-md-center mt-8">
        <b-col col md="12">

          <h3>Phenotype Search</h3>
        
          <b-row>
            <b-col sm="5" md="2" class="my-1">
            </b-col>
            <b-col sm="5" md="8" class="my-1">
                <multiselect 
                id="phenotype_select"
                v-model="value"
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
            </b-col>
            <b-col>
              <b-button v-on:click="requestSelected">Submit</b-button>
            </b-col>
          </b-row>

          <!-- User Interface controls -->
          <b-row>

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
            :items="entities_data"
            :fields="entities_data_fields"
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
          >

            <template #cell(actions)="row">
              <b-button class="btn-xs" @click="row.toggleDetails" variant="outline-primary">
                {{ row.detailsShowing ? 'Hide' : 'Show' }} Details
              </b-button>
            </template>

            <template #row-details="row">
              <b-card>
                <ul>
                  <li v-for="(value, key) in row.item" :key="key">{{ key }}: {{ value }}</li>
                </ul>
              </b-card>
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
              <b-link v-bind:href="'/Disease/' + data.item.disease_ontology_id_version"> 
                <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version">{{ truncate(data.item.disease_ontology_name, 20) }}</div> 
              </b-link>
            </template>

            <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.hpo_mode_of_inheritance_term">{{ data.item.hpo_mode_of_inheritance_term_name.replace(" inheritance", "") }}</div> 
            </template>
            
          </b-table>

        </b-col>
      </b-row>
      
    </b-container>
  </div>
</template>


<script>
export default {
  name: 'Phenotypes',
  data() {
        return {value: null,
          phenotypes_options: [],
          selected_input: [],
          entities: [],
          entities_data: [],
          entities_data_fields: [
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
          loading: true
        }
      },
      mounted() {
        // Set the initial number of items
        this.loadPhenotypesData();
      },
      methods: {
        async loadPhenotypesData() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotypes_list';
          try {
            let response = await this.axios.get(apiUrl);
            this.phenotypes_options = response.data;
          } catch (e) {
            console.error(e);
          }
        },
        async loadEntitiesFromPhenotypes() {
          this.entities = [];
          let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotypes/' + this.selected_input.join() + '/entities';
          try {
            let response = await this.axios.get(apiUrl);
            
            for (var i in response.data) {
              this.entities.push(response.data[i]['entity_id']);
            }

          } catch (e) {
            console.error(e);
          }
            this.loadEntities();
        },
        async loadEntities() {
          this.entities_data = [];
          let apiUrl = process.env.VUE_APP_API_URL + '/api/entities/' + this.entities.join();
          try {
            let response = await this.axios.get(apiUrl);
            this.entities_data = response.data;
            this.totalRows = response.data.length;
            this.currentPage =1;
            console.log(this.entities_data)
          } catch (e) {
            console.error(e);
          }
        },
        addTag(newTag) {
            const tag = {
              phenotype_id: newTag
            }
            this.options.push(tag);
            this.value.push(tag);
          },
        requestSelected() {
            this.selected_input = [];
            for (var i in this.value) {
              this.selected_input.push(this.value[i]['phenotype_id']);
            }
            this.loadEntitiesFromPhenotypes();
          },
        truncate(str, n){
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