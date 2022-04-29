<template>
  <div class="container-fluid">
    <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
    
      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

          <!-- User Interface controls -->
          <b-card 
          header-tag="header"
          body-class="p-0"
          header-class="p-1"
          border-variant="dark"
          >
          <template #header>
            <h6 class="mb-1 text-left font-weight-bold">Panel compilation and download <b-badge variant="primary" v-b-tooltip.hover.bottom v-bind:title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime">Genes: {{totalRows}} </b-badge></h6>
          </template>

          <b-row>

            <!-- column 1 -->
            <b-col class="my-1">
              <b-input-group
                prepend="Category"
                class="mb-1"
                size="sm"
              >
                <b-form-select 
                @input="requestSelected"
                input-id="category-select"
                v-model="selected_category" 
                :options="categories_list" 
                text-field="value"
                size="sm"
                >
                </b-form-select>
              </b-input-group>

              <b-input-group
                prepend="Inheritance"
                class="mb-1"
                size="sm"
              >
                <b-form-select 
                @input="requestSelected"
                input-id="inheritance-select"
                v-model="selected_inheritance" 
                :options="inheritance_list" 
                text-field="value"
                size="sm"
                >
                </b-form-select>
              </b-input-group>
            </b-col>

            <!-- column 2 -->
            <b-col class="my-1">
              <b-input-group
                prepend="Request columns"
                class="mb-1"
                size="sm"
              >
                <b-form-select 
                @input="requestSelected"
                input-id="columns-select"
                v-model="selected_columns" 
                :options="columns_list" 
                text-field="value"
                multiple
                :select-size="3"
                size="sm"
                >
                </b-form-select>
              </b-input-group>
            </b-col>

            <!-- column 3 -->
            <b-col class="my-1">
              <b-input-group
                prepend="Sort"
                class="mb-1"
                size="sm"
              >
                <b-form-select 
                @input="requestSelected"
                input-id="sort-select"
                v-model="sortBy" 
                :options="sort_list" 
                text-field="value"
                size="sm"
                >
                </b-form-select>
              </b-input-group>
              <b-row>
                <b-col class="my-1">
                  <b-button block v-on:click="requestExcel" size="sm">
                    <b-icon icon="table" class="mx-1"></b-icon>
                    <b-icon icon="download" v-if="!downloading"></b-icon>
                    <b-spinner small v-if="downloading"></b-spinner>
                    .xlsx
                  </b-button>
                </b-col>

                <b-col class="my-1">

                </b-col>
              </b-row>
            </b-col>

            <!-- column 4 -->
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
                @change="handlePageChange"
                v-model="currentPage"
                :total-rows="totalRows"
                :per-page="perPage"
                align="fill"
                size="sm"
                class="my-0"
                limit=2
              ></b-pagination>
            </b-col>

          </b-row>


          <!-- Main table element -->
          <b-table
            :items="items"
            :fields="fields"
            :current-page="currentPage"
            :filter-included-fields="filterOn"
            :sort-by.sync="sortBy"
            :sort-desc.sync="sortDesc"
            :busy="isBusy"
            stacked="md"
            head-variant="light"
            show-empty
            small
            fixed
            striped
            hover
            sort-icon-left
            no-local-sorting
            no-local-pagination
          >

            <template #cell(category)="data">
              <div 
              v-b-tooltip.hover.leftbottom
              v-bind:title="data.item.category"
              class="w-100 text-truncate"
              >
                {{ data.item.category }}
              </div> 
            </template>

            <template #cell(inheritance)="data">
              <div 
              v-b-tooltip.hover.leftbottom
              v-bind:title="data.item.inheritance"
              class="w-100 text-truncate"
              >
                {{ data.item.inheritance }}
              </div> 
            </template>

            <template #cell(symbol)="data">
              <div 
              v-b-tooltip.hover.leftbottom
              v-bind:title="data.item.symbol"
              class="w-100 text-truncate"
              >
                {{ data.item.symbol }}
              </div> 
            </template>

            <template #cell(hgnc_id)="data">
              <div 
              v-b-tooltip.hover.leftbottom
              v-bind:title="data.item.hgnc_id"
              class="w-100 text-truncate"
              >
                {{ data.item.hgnc_id }}
              </div> 
            </template>

            <template #cell(entrez_id)="data">
              <div 
              v-b-tooltip.hover.leftbottom
              v-bind:title="data.item.entrez_id"
              class="w-100 text-truncate"
              >
                {{ data.item.entrez_id }}
              </div> 
            </template>

            <template #cell(ensembl_gene_id)="data">
              <div 
              v-b-tooltip.hover.leftbottom
              v-bind:title="data.item.ensembl_gene_id"
              class="w-100 text-truncate"
              >
                {{ data.item.ensembl_gene_id }}
              </div> 
            </template>

            <template #cell(ucsc_id)="data">
              <div 
              v-b-tooltip.hover.leftbottom
              v-bind:title="data.item.ucsc_id"
              class="w-100 text-truncate"
              >
                {{ data.item.ucsc_id }}
              </div> 
            </template>

            <template #cell(bed_hg19)="data">
              <div 
              v-b-tooltip.hover.leftbottom
              v-bind:title="data.item.bed_hg19"
              class="w-100 text-truncate"
              >
                {{ data.item.bed_hg19 }}
              </div> 
            </template>

            <template #cell(bed_hg38)="data">
              <div 
              v-b-tooltip.hover.leftbottom
              v-bind:title="data.item.bed_hg38"
              class="w-100 text-truncate"
              >
                {{ data.item.bed_hg38 }}
              </div> 
            </template>

          </b-table>
        </b-card>

        </b-col>
      </b-row>
      
    </b-container>
  </div>
</template>


<script>
export default {
  name: 'Panels',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Panels',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Panels table view allows composing panels of genes associated with NDD which can be sued for filtering in sequencing studies.' }
    ]
  },
  data() {
        return {
          categories_list: [],
          inheritance_list: [],
          columns_list: [],
          sort_list: [],
          selected_category: null,
          selected_inheritance: null,
          selected_columns: [],
          items: [],
          fields: [],
          totalRows: 0,
          currentPage: 1,
          currentItemID: 0,
          prevItemID: null,
          nextItemID: null,
          lastItemID: null,
          executionTime: 0,
          perPage: 10,
          pageOptions: [10, 25, 50, { value: 100, text: "Show a lot" }],
          sortBy: "symbol",
          sortDesc: false,
          sortDirection: 'asc',
          filter: null,
          filterOn: [],
          loading: true,
          isBusy: true,
          downloading: false,
          show_table: false
        }
      },
      mounted() {
        this.loadOptionsData();
        setTimeout(() => {this.loading = false}, 500);
      },
      watch: {
        sortBy(value) {
          this.handleSortChange();
        },
        perPage(value) {
          this.handlePerPageChange();
        },
        sortDesc(value) {
          this.handleSortChange();
        }
      },
      methods: {
        handleSortChange() {
          this.currentItemID = 0;
          this.requestSelected();
        },
        handlePerPageChange() {
          this.currentItemID = 0;
          this.requestSelected();
        },
        handlePageChange(value) {
          if (value == 1) {
            this.currentItemID = 0;
            this.requestSelected();
          } else if (value == this.totalPages) {
            this.currentItemID = this.lastItemID;
            this.requestSelected();
          } else if (value > this.currentPage) {
            this.currentItemID = this.nextItemID;
            this.requestSelected();
          } else if (value < this.currentPage) {
            this.currentItemID = this.prevItemID;
            this.requestSelected();
          }
        },
        filtered() {
          let filter_string_not_empty = Object.filter(this.filter, value => value !== '');

          if (Object.keys(filter_string_not_empty).length !== 0) {
            this.filter_string = 'contains(' + Object.keys(filter_string_not_empty).map((key) => [key, this.filter[key]].join(',')).join('),contains(') + ')';
            this.requestSelected();
          } else {
            this.filter_string = '';
            this.requestSelected();
          }
        },
        removeFilters() {
          this.filter = {any: ''};
          this.filtered();
        },
        removeSearch() {
          this.filter['any']  = '';
          this.filtered();
        },
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
          this.isBusy = true;

          let apiUrl = process.env.VUE_APP_API_URL + '/api/panels/browse?sort=' + ((this.sortDesc) ? '-' : '+') + this.sortBy + '&filter=any(category,' + this.selected_category + '),any(inheritance_filter,' + this.selected_inheritance + ')' + '&fields=' + this.selected_columns.join() + '&page[after]=' + this.currentItemID + '&page[size]=' + this.perPage;
         
          try {
            let response = await this.axios.get(apiUrl);
            
            this.items = response.data.data;
            this.fields = response.data.fields;
            
            this.totalRows = response.data.meta[0].totalItems;
            this.currentPage = response.data.meta[0].currentPage;
            this.totalPages = response.data.meta[0].totalPages;
            this.prevItemID = response.data.meta[0].prevItemID;
            this.currentItemID = response.data.meta[0].currentItemID;
            this.nextItemID = response.data.meta[0].nextItemID;
            this.lastItemID = response.data.meta[0].lastItemID;
            this.executionTime = response.data.meta[0].executionTime;

            this.isBusy = false;

          } catch (e) {
            console.error(e);
          }

          this.loading = false;
        },
        async requestExcel() {
          this.downloading = true;
          
          let apiUrl = process.env.VUE_APP_API_URL + '/api/panels/excel?sort=' + ((this.sortDesc) ? '-' : '+') + this.sortBy + '&filter=any(category,' + this.selected_category + '),any(inheritance_filter,' + this.selected_inheritance + ')' + '&fields=' + this.selected_columns.join();
         
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
          
          this.downloading = false;
          
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
  .input-group>.input-group-prepend {
    flex: 0 0 35%;
  }
  .input-group .input-group-text {
      width: 100%;
  }
</style>