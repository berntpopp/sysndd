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
            <h6 class="mb-1 text-left font-weight-bold">Entities table <b-badge variant="primary">Entities: {{totalRows}} </b-badge></h6>
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
                    v-model="filter['search']"
                    type="search"
                    placeholder="any field by typing here"
                    debounce="500"
                    @click="removeFilters()"
                    @update="filtered()"
                  >
                  </b-form-input>
                </b-input-group>
              </b-form-group>
            </b-col>

            <b-col>
              <b-row>
                <b-col class="my-1">
                  <b-button block v-on:click="removeFilters(); removeSearch();" size="sm">
                    <b-icon icon="filter" class="mx-1"></b-icon>
                    Reset filters
                  </b-button>
                </b-col>

                <b-col class="my-1">
                </b-col>
              </b-row>
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
                last-number
              ></b-pagination>
            </b-col>
          </b-row>
          </b-card>
          <!-- User Interface controls -->


          <!-- Main table element -->
          <b-table
            :items="filtered_items"
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
          >

            <!-- based on:  https://stackoverflow.com/questions/52959195/bootstrap-vue-b-table-with-filter-in-header -->
            <template slot="top-row" slot-scope="{ fields }">
              <td v-for="field in fields" :key="field.key">
                <b-form-input 
                v-model="filter[field.key]" 
                placeholder="..."
                debounce="500"
                size="sm"
                type="search"
                @click="removeSearch()"
                @update="filtered()"
                >
                </b-form-input>
              </td>
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
              <div>
                <b-link v-bind:href="'/Entities/' + data.item.entity_id">
                  <b-badge 
                  variant="primary"
                  style="cursor:pointer"
                  >
                  sysndd:{{ data.item.entity_id }}
                  </b-badge>
                </b-link>
              </div>
            </template>

            <template #cell(symbol)="data">
              <div class="font-italic">
                <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
                  <b-badge pill variant="success"
                  v-b-tooltip.hover.leftbottom 
                  v-bind:title="data.item.hgnc_id"
                  >
                  {{ data.item.symbol }}
                  </b-badge>
                </b-link>
              </div> 
            </template>

            <template #cell(disease_ontology_name)="data">
              <div class="overflow-hidden text-truncate">
                <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')"> 
                  <b-badge 
                  pill 
                  variant="secondary"
                  v-b-tooltip.hover.leftbottom
                  v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version"
                  >
                  {{ data.item.disease_ontology_name }}
                  </b-badge>
                </b-link>
              </div> 
            </template>

            <template #cell(hpo_mode_of_inheritance_term_name)="data">
              <div>
                <b-badge 
                pill 
                variant="info" 
                class="justify-content-md-center" 
                size="1.3em"
                v-b-tooltip.hover.leftbottom 
                v-bind:title="data.item.hpo_mode_of_inheritance_term_name + ' (' + data.item.hpo_mode_of_inheritance_term + ')'"
                >
                {{ inheritance_short_text[data.item.hpo_mode_of_inheritance_term_name] }}
                </b-badge>
              </div>
            </template>

            <template #cell(ndd_phenotype)="data">
              <div>
                <b-avatar 
                size="1.4em" 
                :icon="ndd_icon[data.item.ndd_phenotype]"
                :variant="ndd_icon_style[data.item.ndd_phenotype]"
                v-b-tooltip.hover.left 
                v-bind:title="ndd_icon_text[data.item.ndd_phenotype]"
                >
                </b-avatar>
              </div> 
            </template>

            <template #cell(category)="data">
              <div>
                <b-avatar
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[data.item.category]"
                v-b-tooltip.hover.left 
                v-bind:title="data.item.category"
                >
                </b-avatar>
              </div> 
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
          stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          ndd_icon: {"No": "x", "Yes": "check"},
          ndd_icon_style: {"No": "warning", "Yes": "success"},
          ndd_icon_text: {"No": "not associated with NDDs", "Yes": "associated with NDDs"},
          inheritance_short_text: {"Autosomal dominant inheritance": "AD", "Autosomal recessive inheritance": "AR", "X-linked inheritance": "X", "X-linked recessive inheritance": "XR", "X-linked dominant inheritance": "XD", "Mitochondrial inheritance": "M", "Somatic mutation": "S", "Semidominant mode of inheritance": "sD"},
          items: [],
          filtered_items: [],
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
            { key: 'category', label: 'Category', sortable: true, filterable: true, class: 'text-left' },
            { key: 'ndd_phenotype', label: 'NDD', sortable: true, filterable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
          ],
          fields_details: [
            { key: 'hgnc_id', label: 'HGNC ID', class: 'text-left' },
            { key: 'disease_ontology_id_version', label: 'Ontology ID version', class: 'text-left' },
            { key: 'disease_ontology_name', label: 'Disease ontology name', class: 'text-left' },
            { key: 'entry_date', label: 'Entry date', class: 'text-left' },
            { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-left' },
          ],
          totalRows: 0,
          currentPage: 1,
          perPage: 10,
          pageOptions: [10, 25, 50, { value: 100, text: "Show a lot" }],
          sortBy: '',
          sortDesc: false,
          sortDirection: 'asc',
          filterTable: null,
          filter: {search: '', entity_id: '', symbol: '', disease_ontology_name: '', disease_ontology_id_version: '', hpo_mode_of_inheritance_term_name: '', hpo_mode_of_inheritance_term: '', ndd_phenotype: '', category: ''},
          filterOn: [],
          infoModal: {
            id: 'info-modal',
            title: '',
            content: ''
          },
          loading: true
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
        filtered() {
          if (this.filter['search'] !== '') {
              this.filtered_items = this.items.filter(item => {
                return Object.keys(this.filter).some(key =>
                    String(item[key]).toLowerCase().includes(this.filter['search'].toLowerCase()));
              });
          } else {
              this.filtered_items = this.items.filter(item => {
                return Object.keys(this.filter).every(key =>
                    String(item[key]).toLowerCase().includes(this.filter[key].toLowerCase()));
              });
          }
          this.onFiltered(this.filtered_items);
        },
        removeFilters(){
          this.filter = {search: '', entity_id: '', symbol: '', disease_ontology_name: '', disease_ontology_id_version: '', hpo_mode_of_inheritance_term_name: '', hpo_mode_of_inheritance_term: '', ndd_phenotype: '', category: ''};
          this.filtered();
        },
        removeSearch(){
          this.filter['search'] = '';
          this.filtered();
        },
        async loadEntitiesData() {
          this.loading = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/entities';
          try {
            let response = await this.axios.get(apiUrl);
            this.items = response.data.data;
            this.filtered_items = response.data.data;
            this.totalRows = response.data.data.length;
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
  .input-group>.input-group-prepend {
    flex: 0 0 35%;
  }
  .input-group .input-group-text {
      width: 100%;
  }
  .badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space:nowrap;
  }

</style>