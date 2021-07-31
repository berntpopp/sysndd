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
            <h6 class="mb-0 text-left font-weight-bold">Panel compilation and download</h6>
          </template>
          <b-row>
            <b-col sm="5" md="2" class="my-1">
              <b-form-group description="Category" label-for="category-select">
                <b-form-select 
                input-id="category-select"
                v-model="selected_category" 
                :options="categories_list" 
                text-field="value"
                size="sm"
                >
                </b-form-select>
              </b-form-group>

              <b-form-group description="Inheritance" label-for="category-select">
                <b-form-select 
                input-id="inheritance-select"
                v-model="selected_inheritance" 
                :options="inheritance_list" 
                text-field="value"
                size="sm"
                >
                </b-form-select>
              </b-form-group>
            </b-col>

            <b-col sm="5" md="2" class="my-1">
              <b-form-group description="Request columns" label-for="columns-select">
                <b-form-select 
                input-id="columns-select"
                v-model="selected_columns" 
                :options="columns_list" 
                text-field="value"
                multiple
                :select-size="5"
                size="sm"
                >
                </b-form-select>
              </b-form-group>
            </b-col>

            <b-col sm="5" md="2" class="my-1">

              <b-form-group description="Sort" label-for="sort-select">
                <b-form-select 
                input-id="sort-select"
                v-model="selected_sort" 
                :options="sort_list" 
                text-field="value"
                size="sm"
                >
                </b-form-select>
              </b-form-group>

              <b-button v-on:click="requestSelected">Browse</b-button>
              <b-button v-on:click="requestExcel"><b-icon icon="table"></b-icon>.xlsx</b-button>
              <b-badge>Genes: {{totalRows}} </b-badge>
            </b-col>
        
          <!-- User Interface controls -->
          <b-row>

            <b-col sm="5" md="6" class="my-1">
              <b-form-group
                description="Per page"
                label-for="per-page-select"
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

          </b-row>
        </b-card>

          <!-- Main table element -->
          
          <b-table
            :items="panel_data"
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
            striped
            hover
            sort-icon-left
            style="width: 100%; white-space: nowrap;"
          >
          </b-table>

        </b-col>
      </b-row>
      
    </b-container>
  </div>
</template>


<script>
export default {
  name: 'Panels',
  data() {
        return {
          categories_list: [],
          inheritance_list: [],
          columns_list: [],
          sort_list: [],
          selected_category: null,
          selected_inheritance: null,
          selected_columns: [],
          selected_sort: "symbol",
          panel_data: [],
          totalRows: 0,
          currentPage: 1,
          perPage: 10,
          pageOptions: [10, 25, 50, { value: 100, text: "Show a lot" }],
          sortBy: '',
          sortDesc: false,
          sortDirection: 'asc',
          filter: null,
          filterOn: [],
          loading: true,
          show_table: false
        }
      },
      mounted() {
        // Set the initial number of items
        this.loadOptionsData();
      },
      methods: {
        async loadOptionsData() {
          this.loading = true;

          let apiUrl = process.env.VUE_APP_API_URL + '/api/panels/options';
          try {
            let response = await this.axios.get(apiUrl);
            this.categories_list = response.data[0].options;
            this.inheritance_list = response.data[1].options;
            this.columns_list = response.data[2].options;
            
            this.selected_category = this.$route.params.category_input;
            this.selected_inheritance = this.$route.params.inheritance_input;
            this.selected_columns = response.data[2].options;
            this.sort_list = response.data[2].options;

            var c = [];
            for (var key in response.data[2].options) c.push(response.data[2].options[key].value);
            this.selected_columns = c;

            this.requestSelected();

          } catch (e) {
            console.error(e);
          }

        },
        async requestSelected() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/panels?category_input=' + this.selected_category + '&inheritance_input=' + this.selected_inheritance + '&output_columns=' + this.selected_columns.join() + '&output_sort=' + this.selected_sort;
          try {
            let response = await this.axios.get(apiUrl);
            
            this.panel_data = response.data;
            
            this.totalRows = response.data.length;
            this.currentPage = 1;

          } catch (e) {
            console.error(e);
          }

          this.loading = false;
        },
        async requestExcel() {
          //based on https://morioh.com/p/f4d331b62cda
          let apiUrl = process.env.VUE_APP_API_URL + '/api/panels/excel?category_input=' + this.selected_category + '&inheritance_input=' + this.selected_inheritance + '&output_columns=' + this.selected_columns.join() + '&output_sort=' + this.selected_sort;
          try {
            let response = await this.axios({
                    url: apiUrl,
                    method: 'GET',
                    responseType: 'blob',
                }).then((response) => {
                     var fileURL = window.URL.createObjectURL(new Blob([response.data]));
                     var fileLink = document.createElement('a');

                     fileLink.href = fileURL;
                     fileLink.setAttribute('download', 'panel.xlsx');
                     document.body.appendChild(fileLink);

                     fileLink.click();
                });

          } catch (e) {
            console.error(e);
          }
        },
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