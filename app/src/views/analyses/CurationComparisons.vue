<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

          <div>
          <b-tabs content-class="mt-3" v-model="tabIndex">

            <b-tab title="Overlap" active>
              <b-spinner label="Loading..." v-if="loadingUpset" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>

                <!-- User Interface controls -->
                <b-card 
                  header-tag="header"
                  body-class="p-0"
                  header-class="p-1"
                  border-variant="dark"
                >
                <template #header>
                  <h6 class="mb-1 text-left font-weight-bold">Upset plot showing the overlap between different selected curation effors for neurodevelopmental disorders.</h6>
                </template>
                  <b-row>
                    <!-- column 1 -->
                    <b-col class="my-1">

              <treeselect
                id="columns-select"
                :multiple="true"
                :options="columns_list"
                v-model="selected_columns"
                :normalizer="normalizeLists"
              />

                    </b-col>

                  </b-row>
                <!-- User Interface controls -->

                <UpSetJS :sets="sets" :width="width" :height="height" @hover="hover" :selection="selection"></UpSetJS>

                </b-card>
              </b-container>
            </b-tab>

            <b-tab title="Similarity">
              <b-spinner label="Loading..." v-if="loadingMatrix" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>

                <!-- User Interface controls -->
                <b-card 
                  header-tag="header"
                  body-class="p-0"
                  header-class="p-1"
                  border-variant="dark"
                >
                <template #header>
                  <h6 class="mb-1 text-left font-weight-bold">Matrix plot of the cosine similarity between different curation effors for neurodevelopmental disorders.</h6>
                </template>
                  <b-row>
                    <!-- column 1 -->
                    <b-col class="my-1">
                    </b-col>

                    <!-- column 2 -->
                    <b-col class="my-1">
                    </b-col>

                    <!-- column 3 -->
                    <b-col class="my-1">
                    </b-col>

                    <!-- column 4 -->
                    <b-col class="my-1">
                    </b-col>
                  </b-row>
                <!-- User Interface controls -->

                </b-card>

              </b-container>
              
                <!-- Content -->
                <div id="matrix_dataviz" class="svg-container"></div>
                <!-- Content -->

            </b-tab>

            <b-tab title="Table">

          <!-- User Interface controls -->
          <b-card 
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
          <template #header>
            <h6 class="mb-1 text-left font-weight-bold">Comparing the presence of a gene in different curation effors for neurodevelopmental disorders.</h6>
            <h6 class="mb-1 text-left font-weight-bold"><b-badge variant="success" v-b-tooltip.hover.bottom v-bind:title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime">Genes: {{totalRows}} </b-badge></h6>
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
                    v-model="filter['any']"
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
                    Reset
                  </b-button>
                </b-col>

                <b-col class="my-1">
                  <b-button block v-on:click="requestExcel" size="sm">
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
          <!-- User Interface controls -->

              <!-- Main table element -->
              <b-spinner label="Loading..." v-if="loadingTable" class="float-center m-5"></b-spinner>
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

              <template #cell(SysNDD)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.SysNDD]"
                  :variant="yn_icon_style[data.item.SysNDD]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.SysNDD"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(radboudumc_ID)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.radboudumc_ID]"
                  :variant="yn_icon_style[data.item.radboudumc_ID]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.radboudumc_ID"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(gene2phenotype)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.gene2phenotype]"
                  :variant="yn_icon_style[data.item.gene2phenotype]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.gene2phenotype"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(panelapp)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.panelapp]"
                  :variant="yn_icon_style[data.item.panelapp]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.panelapp"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(sfari)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.sfari]"
                  :variant="yn_icon_style[data.item.sfari]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.sfari"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(geisinger_DBD)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.geisinger_DBD]"
                  :variant="yn_icon_style[data.item.geisinger_DBD]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.geisinger_DBD"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(omim_ndd)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.omim_ndd]"
                  :variant="yn_icon_style[data.item.omim_ndd]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.omim_ndd"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(orphanet_id)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.orphanet_id]"
                  :variant="yn_icon_style[data.item.orphanet_id]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.orphanet_id"
                  >
                  </b-avatar>
                </div> 
              </template>

              </b-table>
          </b-card>

            </b-tab>
            
          </b-tabs>
          </div>
          
        </b-col>
      </b-row>
      
    </b-container>
  </div>
</template>


<script>
  import toastMixin from '@/assets/js/mixins/toastMixin.js'

  import UpSetJS, { extractSets, ISets, ISet } from '@upsetjs/vue';
  import * as d3 from 'd3';

  import {createElement} from "@upsetjs/bundle";

  // import the Treeselect component
  import Treeselect from '@riophae/vue-treeselect'
  // import the Treeselect styles
  import '@riophae/vue-treeselect/dist/vue-treeselect.css'

  export default {
  // register the Treeselect component
  components: {Treeselect, UpSetJS},
  name: 'CurationComparisons',
  mixins: [toastMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Curation comparisons',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Comparisions analysis can be used to compare different curation efforts for neurodevelopmental disorders (inlucing attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability) based on UpSet plots, similarity matrix or tabular views.' }
    ]
  },
    data() {
      return {
        yn_icon: {"no": "x", "yes": "check"},
        yn_icon_style: {"no": "warning", "yes": "success"},
        elems: [ {
          "name": "AAAS",
          "sets": [
            "SysNDD",
            "radboudumc_ID",
            "sfari",
            "gene2phenotype",
            "panelapp",
            "geisinger_DBD"
          ]
        }],
        width: 1400,
        height: 600,
        columns_list: [],
        selected_columns: ['SysNDD', 'panelapp', 'gene2phenotype'],
        items: [],
        itemsMatrix: [],
        fields: [
          { 
            key: 'symbol', 
            label: 'Symbol', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'SysNDD', 
            label: 'SysNDD', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'radboudumc_ID', 
            label: 'Radboud UMC ID', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'gene2phenotype', 
            label: 'gene2phenotype', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'panelapp', 
            label: 'PanelApp', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'sfari', 
            label: 'SFARI', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'geisinger_DBD', 
            label: 'Geisinger DBD', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'omim_ndd', 
            label: 'OMIM NDD', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'orphanet_id', 
            label: 'Orphanet ID', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
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
        sortBy: 'symbol',
        sortDesc: false,
        filter: {any: ''}, 
        filter_string: '', 
        filterOn: [],
        selection: null,
        image: '',
        loadingUpset: true,
        loadingMatrix: true,
        loadingTable: true,
        tabIndex: 0,
        isBusy: true,
        downloading: false,
      };
    },
    watch: {
      tabIndex(value) {
        if (value === 2 & this.loadingTable) {
          this.loadTableData();
          this.loadingTable = false;
        } else if (value === 1 & this.loadingMatrix) {
          this.loadMatrixData();
        }
      },
      sortBy() {
        this.handleSortChange();
      },
      perPage() {
        this.handlePerPageChange();
      },
      sortDesc() {
        this.handleSortChange();
      },
      selected_columns() {
        this.loadComparisonsUpsetData();
      },
    },
    computed: {
      sets() {
        return extractSets(this.elems);
      },
    },
    mounted() {
      this.loadOptionsData();
    },
    methods: {
        customStyleFactory(rules) {
          return createElement(
            'style',
            {
              extra: 'abc',
            },
            rules
          );
        },
        async loadOptionsData() {
          // have to add other options here and normalize the function both here and in the API
          this.loading = true;

          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/options';
          try {
            let response = await this.axios.get(apiUrl);
            this.columns_list = response.data.list;

            this.loadComparisonsUpsetData();

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }

        },
        handleSortChange() {
          this.currentItemID = 0;
          this.loadTableData();
        },
        handlePerPageChange() {
          this.currentItemID = 0;
          this.loadTableData();
        },
        handlePageChange(value) {
          if (value == 1) {
            this.currentItemID = 0;
            this.loadTableData();
          } else if (value == this.totalPages) {
            this.currentItemID = this.lastItemID;
            this.loadTableData();
          } else if (value > this.currentPage) {
            this.currentItemID = this.nextItemID;
            this.loadTableData();
          } else if (value < this.currentPage) {
            this.currentItemID = this.prevItemID;
            this.loadTableData();
          }
        },
        filtered() {
          let filter_string_not_empty = Object.filter(this.filter, value => value !== '');

          if (Object.keys(filter_string_not_empty).length !== 0) {
            this.filter_string = 'contains(' + Object.keys(filter_string_not_empty).map((key) => [key, this.filter[key]].join(',')).join('),contains(') + ')';
            this.loadTableData();
          } else {
            this.filter_string = '';
            this.loadTableData();
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
        async loadComparisonsUpsetData() {
          this.loadingUpset = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/upset?fields=' + this.selected_columns.join();

          try {
            let response = await this.axios.get(apiUrl);
            this.elems = response.data;

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }

          this.loadingUpset = false;

        },
        async loadTableData() {
          this.isBusy = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/browse?sort=' + ((this.sortDesc) ? '-' : '+') + this.sortBy + '&filter=' + this.filter_string + '&page[after]=' + this.currentItemID + '&page[size]=' + this.perPage;
          
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
            this.makeToast(e, 'Error', 'danger');
          }
        },
        normalizeLists(node) {
          return {
            id: node.list,
            label: node.list,
          }
        },
        async requestExcel() {
          this.downloading = true;

          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/excel?sort=' + ((this.sortDesc) ? '-' : '+') + this.sortBy + '&filter=' + this.filter_string;

          try {
            let response = await this.axios({
                    url: apiUrl,
                    method: 'GET',
                    responseType: 'blob',
                }).then((response) => {
                     var fileURL = window.URL.createObjectURL(new Blob([response.data]));
                     var fileLink = document.createElement('a');

                     fileLink.href = fileURL;
                     fileLink.setAttribute('download', 'curation_comparisons.xlsx');
                     document.body.appendChild(fileLink);

                     fileLink.click();
                });

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }

          this.downloading = false;

        },
        async loadMatrixData() {
          this.loadingMatrix = true;

          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/similarity';

          try {
            let response = await this.axios.get(apiUrl);

            this.itemsMatrix = response.data;

            this.generateGraph();

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }

          this.loadingMatrix = false;
      },
      generateGraph() {
      // Graph dimension
      const margin = {top: 20, right: 50, bottom: 200, left: 220},
          width = 650 - margin.left - margin.right,
          height = 620 - margin.top - margin.bottom;

      // Create the svg area
      const svg = d3.select("#matrix_dataviz")
        .append("svg")
        .attr("viewBox", `0 0 700 700`)
        .attr("preserveAspectRatio", "xMinYMin meet")
        .append("g")
          .attr("transform", `translate(${margin.left},${margin.top})`);

      // 
      const data = this.itemsMatrix;

      // List of all variables and number of them
      const domain = Array.from(new Set(data.map(function(d) { return d.x })))

      // Build X scales and axis:
      const x = d3.scaleBand()
        .range([ 0, width ])
        .domain(domain)
        .padding(0.01);

      svg.append("g")
        .attr("transform", `translate(0, ${height})`)
        .call(d3.axisBottom(x))
        .selectAll("text")  
            .style("text-anchor", "end")
            .attr("dx", "-.8em")
            .attr("dy", ".15em")
            .attr("transform", "rotate(-90)" );

      // Build Y scales and axis:
      const y = d3.scaleBand()
        .range([ height, 0 ])
        .domain(domain)
        .padding(0.01);

      svg.append("g")
        .call(d3.axisLeft(y));

      // Build color scale
      const myColor = d3.scaleLinear()
        .range(["#000080", "#fff", "#B22222"])
        .domain([-1, 0, 1]);

      // create a tooltip
      const tooltip = d3.select("#matrix_dataviz")
        .append("div")
        .style("opacity", 0)
        .attr("class", "tooltip")
        .style("background-color", "white")
        .style("border", "solid")
        .style("border-width", "1px")
        .style("border-radius", "5px")
        .style("padding", "2px")

      // Three function that change the tooltip when user hover / move / leave a cell
      const mouseover = function(event,d) {
        tooltip
          .style("opacity", 1)
        d3.select(this)
          .style("stroke", "black")
          .style("opacity", 1);
      }
      const mousemove = function(event,d) {
        tooltip
          .html("S(c): " + d.value + "<br>(" + d.x + " &<br>" + d.y + ")")
          .style("left", `${event.layerX+20}px`)
          .style("top", `${event.layerY+20}px`)
      }
      const mouseleave = function(event,d) {
        tooltip
          .style("opacity", 0)
        d3.select(this)
          .style("stroke", "none")
          .style("opacity", 0.8);
      }

      // add the squares
      svg.selectAll()
        .data(data, function(d) {return d.x+':'+d.y;})
        .enter()
        .append("rect")
          .attr("x", function(d) { return x(d.x) })
          .attr("y", function(d) { return y(d.y) })
          .attr("width", x.bandwidth() )
          .attr("height", y.bandwidth() )
          .style("fill", function(d) { return myColor(d.value)} )
        .on("mouseover", mouseover)
        .on("mousemove", mousemove)
        .on("mouseleave", mouseleave)

      },
      hover(s) {
        this.selection = s;
      },
      onFiltered(filteredItems) {
        // Trigger pagination to update the number of buttons/pages due to filtering
        this.totalRows = filteredItems.length
        this.currentPage = 1
      }
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
  .svg-container {
    display: inline-block;
    position: relative;
    width: 100%;
    max-width: 600px;
    vertical-align: top;
    overflow: hidden;
}
.svg-content {
    display: inline-block;
    position: absolute;
    top: 0;
    left: 0;
}
</style>
