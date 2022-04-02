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
            <h6 class="mb-1 text-left font-weight-bold">Phenotypes search <b-badge variant="primary" v-b-tooltip.hover.bottom v-bind:title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime">Associated entities: {{totalRows}} </b-badge></h6>
         </template>
          <b-row>
            <b-col class="my-1">
                <multiselect 
                id="phenotype_select"
                @input="requestSelected"
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
              <b-row>
                <b-col class="my-1">
                  <b-form-checkbox 
                  switch 
                  v-model="checked" 
                  name="check-button"
                  @input="requestSelected"
                  >
                    <b>{{ switch_text[checked] }}</b>
                  </b-form-checkbox>
                </b-col>

                <b-col class="my-1">
                  <b-button block v-on:click="requestSelectedExcel" size="sm">
                    <b-icon icon="table" class="mx-1"></b-icon>
                    <b-icon icon="download" v-if="!downloading"></b-icon>
                    <b-spinner small v-if="downloading"></b-spinner>
                    .xlsx
                  </b-button>
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
          </b-card>

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
                  {{ truncate(data.item.disease_ontology_name, 40) }}
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
            
          </b-table>

        </b-col>
      </b-row>
      
    </b-container>
  </div>
</template>


<script>
export default {
  name: 'Phenotypes',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Phenotypes',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Phenotypes table view allows browsing NDD associated entities by pehnotype and filtering with download possibility.' }
    ]
  },
  data() {
        return {
          stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          ndd_icon: {"No": "x", "Yes": "check"},
          ndd_icon_style: {"No": "warning", "Yes": "success"},
          ndd_icon_text: {"No": "not associated with NDDs", "Yes": "associated with NDDs"},
          inheritance_short_text: {"Autosomal dominant inheritance": "AD", "Autosomal recessive inheritance": "AR", "X-linked inheritance": "X", "X-linked recessive inheritance": "XR", "X-linked dominant inheritance": "XD", "Mitochondrial inheritance": "M", "Somatic mutation": "S", "Semidominant mode of inheritance": "sD"},
          switch_text: {true: "OR", false: "AND"},
          value: [{
            "phenotype_id": "HP:0001249",
            "HPO_term": "Intellectual disability"}
          ],
          phenotypes_options: [],
          selected_input: [],
          items: [],
          fields: [
            { 
              key: 'entity_id', 
              label: 'Entity', 
              sortable: true, 
              sortDirection: 'desc', 
              class: 'text-left' 
              },
            { 
              key: 'symbol', 
              label: 'Gene Symbol', 
              sortable: true, 
              class: 'text-left'
            },
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
            { 
              key: 'ndd_phenotype', 
              label: 'NDD', 
              sortable: true, 
              class: 'text-left'
            },
            { 
              key: 'actions', 
              label: 'Actions' 
            }
          ],
          fields_details: [
            { key: 'hgnc_id', label: 'HGNC ID', class: 'text-left' },
            { key: 'disease_ontology_id_version', label: 'Ontology ID version', class: 'text-left' },
            { key: 'disease_ontology_name', label: 'Disease ontology name', class: 'text-left' },
            { key: 'entry_date', label: 'Entry date', class: 'text-left' },
          ],
          totalRows: 0,
          currentPage: 1,
          currentItemID: 0,
          prevItemID: null,
          nextItemID: null,
          lastItemID: null,
          executionTime: 0,
          perPage: 10,
          pageOptions: [10, 25, 50, { value: 100, text: "Show a lot" }],
          sortBy: "entity_id",
          sortDesc: false,
          sortDirection: 'asc',
          filter: null,
          filterOn: [],
          checked: false,
          downloading: false,
          loading: true,
          isBusy: true
        }
      },
      mounted() {
        this.loadPhenotypesData();
        this.requestSelected();
        setTimeout(() => {this.loading = false}, 1000);
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
          this.loadEntitiesFromPhenotypes();
        },
        handlePerPageChange() {
          this.currentItemID = 0;
          this.loadEntitiesFromPhenotypes();
        },
        handlePageChange(value) {
          if (value == 1) {
            this.currentItemID = 0;
            this.loadEntitiesFromPhenotypes();
          } else if (value == this.totalPages) {
            this.currentItemID = this.lastItemID;
            this.loadEntitiesFromPhenotypes();
          } else if (value > this.currentPage) {
            this.currentItemID = this.nextItemID;
            this.loadEntitiesFromPhenotypes();
          } else if (value < this.currentPage) {
            this.currentItemID = this.prevItemID;
            this.loadEntitiesFromPhenotypes();
          }
        },
        filtered() {
          let filter_string_not_empty = Object.filter(this.filter, value => value !== '');

          if (Object.keys(filter_string_not_empty).length !== 0) {
            this.filter_string = 'contains(' + Object.keys(filter_string_not_empty).map((key) => [key, this.filter[key]].join(',')).join('),contains(') + ')';
            this.loadEntitiesFromPhenotypes();
          } else {
            this.filter_string = '';
            this.loadEntitiesFromPhenotypes();
          }
        },
        removeFilters() {
          this.filter = {any: '', entity_id: '', symbol: '', disease_ontology_name: '', disease_ontology_id_version: '', hpo_mode_of_inheritance_term_name: '', hpo_mode_of_inheritance_term: '', ndd_phenotype: '', category: ''};
          this.filtered();
        },
        removeSearch() {
          this.filter['any']  = '';
          this.filtered();
        },
        async loadPhenotypesData() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotype_list';
          try {
            let response = await this.axios.get(apiUrl);
            this.phenotypes_options = response.data;
          } catch (e) {
            console.error(e);
          }
        },
        async loadEntitiesFromPhenotypes() {
          this.isBusy = true;

          let logical_operator = "";

          switch (this.checked)
          {
          case true:
          logical_operator = "or";
          break;
          case false:
          logical_operator = "and";
          break;
          }

          let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotype/entities/browse?sort=' + ((this.sortDesc) ? '-' : '+') + this.sortBy + '&filter=' + logical_operator + '(equals(' + this.selected_input.join(',TRUE),equals(') + ',TRUE))' + '&page[after]=' + this.currentItemID + '&page[size]=' + this.perPage;

          try {
            let response = await this.axios.get(apiUrl);

            this.items = response.data.data;

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
        },
        addTag(newTag) {
            const tag = {
              phenotype_id: newTag
            }
            this.options.push(tag);
            this.value.push(tag);
          },
        requestSelected() {
            if (this.value.length > 0) {
              this.selected_input = [];
              for (var i in this.value) {
                this.selected_input.push(this.value[i]['phenotype_id']);
              }
              this.loadEntitiesFromPhenotypes();
            } else {
              this.items = [];
              this.totalRows = 0;
            }
          },
        requestSelectedExcel() {
            if (this.value.length > 0) {
              this.selected_input = [];
              for (var i in this.value) {
                this.selected_input.push(this.value[i]['phenotype_id']);
              }
              this.requestExcel();
            }
          },
        async requestExcel() {
          this.downloading = true;

          let logical_operator = "";

          switch (this.checked)
          {
          case true:
          logical_operator = "or";
          break;
          case false:
          logical_operator = "and";
          break;
          }

          //based on https://morioh.com/p/f4d331b62cda
          let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotype/entities/excel?hpo_list=' + this.selected_input.join() + '&logical_operator=' + logical_operator;
          try {
            let response = await this.axios({
                    url: apiUrl,
                    method: 'GET',
                    responseType: 'blob',
                }).then((response) => {
                     var fileURL = window.URL.createObjectURL(new Blob([response.data]));
                     var fileLink = document.createElement('a');

                     fileLink.href = fileURL;
                     fileLink.setAttribute('download', 'phenotype_panel.xlsx');
                     document.body.appendChild(fileLink);

                     fileLink.click();
                });

          } catch (e) {
            console.error(e);
          }

          this.downloading = false;

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
</style>