<template>
  <div class="container-fluid" style="min-height:90vh">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

          <!-- User Interface controls -->
          <b-card 
          header-tag="header"
          bg-variant="light"
          >
          <template #header>
            <h6 class="mb-1 text-left font-weight-bold">Entities table</h6>
          </template>
          <b-row>
            <b-col class="my-1">
              <b-form-group
                class="mb-1"
              >
                <b-input-group
                prepend="Search"
                size="sm">
                  <b-form-input
                    id="filter-input"
                    v-model="filter.search"
                    type="search"
                    placeholder="any field by typing here"
                    debounce="500"
                    @click="changeFilter(null)"
                    @update="applyFilter('search')"
                    @blur="removeFilter('search')"
                  >
                  </b-form-input>
                </b-input-group>
              </b-form-group>
            </b-col>

            <b-col class="my-1">
            </b-col>

            <b-col class="my-1">
            </b-col>

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
                ></b-form-select>
              </b-input-group>

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
          </b-card>

          <!-- Main table element -->
          <b-table
            :items="items"
            :fields="fields"
            :current-page="currentPage"
            :per-page="perPage"
            :filter="filterTable"
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

          <template #head()="data">
                <b-input-group
                size="sm">
                <b-input-group-prepend is-text><b>{{ data.label }}</b></b-input-group-prepend>
                  <b-form-input
                    v-bind:id="'filter-input-' + data.label"
                    v-model="filter[data.label]"
                    type="search"
                    placeholder="..."
                    debounce="500"
                    size="sm"
                    @click="changeFilter(data.label)"
                    @update="applyFilter(data.label)"
                    @blur="removeFilter(data.label)"
                  >
                  </b-form-input>
                </b-input-group>
          </template>

            <template #cell(actions)="row">
              <b-button class="btn-xs" @click="row.toggleDetails" variant="outline-primary">
                {{ row.detailsShowing ? 'Hide' : 'Show' }} Details
              </b-button>
            </template>

            <template #row-details="row">
              <b-card>
                <b-table
                  :items="[row.item]"
                  :fields="fields_details"
                  stacked 
                  small
                >
                </b-table>
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
              <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')"> 
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
  name: 'Entities',
  data() {
        return {
          items: [],
          fields: [
            { key: 'entity_id', label: 'Entity', sortable: true, filterable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'symbol', label: 'Symbol', sortable: true, filterable: true, class: 'text-left' },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              sortable: true,
              filterable: true, 
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            {
              key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: true,
              filterable: true, 
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { key: 'ndd_phenotype', label: 'NDD', sortable: true, filterable: true, class: 'text-left' },
            { key: 'category', label: 'Category', sortable: true, filterable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
          ],
          fields_details: [
            { key: 'hgnc_id', label: 'HGNC ID', class: 'text-left' },
            { key: 'disease_ontology_id_version', label: 'Intology ID version', class: 'text-left' },
            { key: 'disease_ontology_name', label: 'Disease ontology name', class: 'text-left' },
            { key: 'entry_date', label: 'Entry date', class: 'text-left' },
          ],
          totalRows: 1,
          currentPage: 1,
          perPage: 10,
          pageOptions: [10, 25, 50, { value: 100, text: "Show a lot" }],
          sortBy: '',
          sortDesc: false,
          sortDirection: 'asc',
          filterTable: null,
          filter: {search: null, Entity: null, Symbol: null, Inheritance: null, NDD: null, Category: null, Actions: null},
          filterOn: [],
          infoModal: {
            id: 'info-modal',
            title: '',
            content: ''
          },
          loading: true
        }
      },
      computed: {
      },
      mounted() {
        // Set the initial number of items
        this.loadEntitiesData();
      },
      methods: {
        onFiltered(filteredItems) {
          // Trigger pagination to update the number of buttons/pages due to filtering
          this.totalRows = filteredItems.length
          this.currentPage = 1
        },
        async loadEntitiesData() {
          this.loading = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/entities';
          try {
            let response = await this.axios.get(apiUrl);
            console.log(response);
            this.items = response.data.data;
            this.totalRows = response.data.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loading = false;
        },
        truncate(str, n){
          return (str.length > n) ? str.substr(0, n-1) + '...' : str;
        },
        changeFilter(value){
          this.filterOn = this.fields
                      .filter(f => f.filterable)
                      .filter(f => f.label == value)
                      .map(f => {
                        return [ f.key ]
                      })[0];
        },
        applyFilter(value){
          this.filterTable = this.filter[value];
        },
        removeFilter(value){
          this.filter[value] = null;
          this.filterTable = null;
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
  .input-group>.input-group-prepend {
    flex: 0 0 35%;
  }
  .input-group .input-group-text {
      width: 100%;
  }
</style>