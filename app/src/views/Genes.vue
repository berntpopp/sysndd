<template>
  <div class="container-fluid" style="min-height:90vh">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

          <b-card 
          header-tag="header"
          bg-variant="light"
          >
          <template #header>
            <h6 class="mb-0 text-left font-weight-bold">Genes table</h6>
          </template>

          <b-row>
            <b-col class="my-1">
              <b-form-group
                class="mb-0"
              >
                <b-input-group
                prepend="Search" 
                size="sm">
                  <b-form-input
                    id="filter-input"
                    v-model="filter"
                    type="search"
                    placeholder="any field by typing here"
                    debounce="500"
                  ></b-form-input>
                </b-input-group>
              </b-form-group>
            </b-col>

            <b-col class="my-1">
              <b-input-group
                prepend="Per page"
                class="mb-0"
                size="sm"
              >
                <b-form-select
                  id="per-page-select"
                  v-model="perPage"
                  :options="pageOptions"
                  size="sm"
                ></b-form-select>
              </b-input-group>
            </b-col>

            <b-col class="my-1">
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
              <b-button class="btn-xs" @click="row.toggleDetails" variant="outline-primary">
                {{ row.detailsShowing ? 'Hide' : 'Show' }} Details
              </b-button>
            </template>

            <template #row-details="row">
              <b-card>
                <b-table
                  :items="row.item.entities"
                  :fields="entities_fields"
                  head-variant="light"
                  show-empty
                  small
                  fixed
                  striped
                  sort-icon-left
                >

                  <template #cell(entity_id)="data">
                    <b-link v-bind:href="'/Entities/' + data.item.entity_id">
                      <div style="cursor:pointer">sysndd:{{ data.item.entity_id }}</div>
                    </b-link>
                  </template>

                  <template #cell(disease_ontology_name)="data">
                    <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version"> 
                      <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version">{{ data.item.disease_ontology_name }}</div> 
                    </b-link>
                  </template>

                </b-table>
              </b-card>
            </template>

            <template #cell(symbol)="data">
              <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
                <div class="font-italic" v-b-tooltip.hover.leftbottom v-bind:title="data.item.hgnc_id">{{ data.item.symbol }}</div> 
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
  name: 'Genes',
  data() {
        return {
          items: [],
          fields: [
            { key: 'symbol', label: 'Gene Symbol', sortable: true, class: 'text-left' },
            { key: 'category', label: 'Category', sortable: true, class: 'text-left' },
            {
              key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { key: 'actions', label: 'Actions' }
          ],
          entities_fields: [
            { key: 'entity_id', label: 'Entity', sortable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'disease_ontology_name',
              label: 'Disease',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { key: 'ndd_phenotype', label: 'NDD Association', sortable: true, class: 'text-left' }
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
            content: ''
          },
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
      },
      methods: {
        onFiltered(filteredItems) {
          // Trigger pagination to update the number of buttons/pages due to filtering
          this.totalRows = filteredItems.length
          this.currentPage = 1
        },
        async loadEntitiesData() {
          this.loading = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/genes';
          try {
            let response = await this.axios.get(apiUrl);
            this.items = response.data;
            this.totalRows = response.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loading = false;
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