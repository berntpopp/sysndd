<template>
  <b-container fluid>
    <!-- User Interface controls -->
    <b-card
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <b-row>
          <b-col>
            <h6 class="mb-1 text-left font-weight-bold">
              Comparing the presence of a gene in different
              <mark
                v-b-tooltip.hover.leftbottom
                title="These have been reviewed to include lists which are regularly updated. Below table allows users to filter the presence of a gene (yes/ no) in the respective list overlaps."
              >curation effors</mark>
              for neurodevelopmental disorders.

              <b-badge
                id="popover-badge-help-comparisons"
                pill
                href="#"
                variant="info"
              >
                <b-icon icon="question-circle-fill" />
              </b-badge>

              <b-popover
                target="popover-badge-help-comparisons"
                variant="info"
                triggers="focus"
              >
                <template #title>
                  Comparisons selection
                </template>
                The NDD databases and lists for the comparison with SysNDD are:
                <br>
                <strong>1) radboudumc ID,</strong> downloaded and normalized
                from https://order.radboudumc.nl/en/LabProduct/Pdf/30240, <br>
                <strong>2) gene2phenotype ID</strong> downloaded and normalized
                from
                https://www.ebi.ac.uk/gene2phenotype/downloads/DDG2P.csv.gz,
                <br>
                <strong>3) panelapp ID</strong> downloaded and normalized from
                https://panelapp.genomicsengland.co.uk/panels/285/download/01234/,
                <br>
                <strong>4) sfari</strong> downloaded and normalized from
                https://gene.sfari.org//wp-content/themes/sfari-gene/utilities/download-csv.php?api-endpoint=genes,
                <br>
                <strong>5) geisinger DBD</strong> downloaded and normalized from
                https://dbd.geisingeradmi.org/downloads/DBD-Genes-Full-Data.csv,
                <br>
                <strong>6) orphanet ID</strong> downloaded and normalized from
                https://id-genes.orphanet.app/es/index/sysid_index_1, <br>
                <strong>7) OMIM NDD</strong> filtered OMIM for the HPO term
                "Neurodevelopmental abnormality" (HP:0012759) and all its child
                terms using the files phenotype_to_genes
                (http://purl.obolibrary.org/obo/hp/hpoa/phenotype_to_genes.txt)
                and genemap2
                (https://data.omim.org/downloads/VVpx0Ng3TneJyOfawPWFcg/genemap2.txt),
                <br>
              </b-popover>
            </h6>

            <h6 class="mb-1 text-left font-weight-bold">
              <b-badge
                v-b-tooltip.hover.bottom
                variant="success"
                :title="
                  'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime
                "
              >
                Genes: {{ totalRows }}
              </b-badge>
            </h6>
          </b-col>
          <b-col>
            <h6 class="mb-1 text-right font-weight-bold">
              <b-button
                v-b-tooltip.hover.bottom
                size="sm"
                :title="
                  'The table is ' +
                    (filter_string === '' ? 'not' : '') +
                    ' filtered.' +
                    (filter_string === '' ? '' : ' Click to remove all filters.')
                "
                :variant="filter_string === '' ? 'info' : 'warning'"
                @click="removeFilters()"
              >
                <b-icon
                  icon="filter"
                  font-scale="1.0"
                />
              </b-button>
            </h6>
          </b-col>
        </b-row>
      </template>

      <b-row>
        <b-col
          class="my-1"
          sm="6"
        >
          <b-form-group class="mb-1">
            <b-input-group
              prepend="Search"
              size="sm"
            >
              <b-form-input
                id="filter-input"
                v-model="filter['any']"
                type="search"
                placeholder="any field by typing here"
                debounce="500"
                @click="removeFilters()"
                @update="filtered()"
              />
            </b-input-group>
          </b-form-group>
        </b-col>

        <b-col
          class="my-1"
          sm="2"
        >
          <b-row>
            <b-col>
              <b-button
                block
                size="sm"
                @click="requestExcel"
              >
                <b-icon
                  icon="table"
                  class="mx-1"
                />
                <b-icon
                  v-if="!downloading"
                  icon="download"
                />
                <b-spinner
                  v-if="downloading"
                  small
                />
                .xlsx
              </b-button>
            </b-col>
          </b-row>
        </b-col>

        <b-col
          class="my-1"
          sm="4"
        >
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
            />
          </b-input-group>

          <b-pagination
            v-model="currentPage"
            :total-rows="totalRows"
            :per-page="perPage"
            align="fill"
            size="sm"
            class="my-0"
            limit="2"
            @change="handlePageChange"
          />
        </b-col>
      </b-row>
      <!-- User Interface controls -->

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
        <!-- based on:  https://stackoverflow.com/questions/52959195/bootstrap-vue-b-table-with-filter-in-header -->
        <template slot="top-row">
          <td
            v-for="field in fields"
            :key="field.key"
          >
            <b-form-input
              v-if="field.filterable"
              v-model="filter[field.key]"
              :placeholder="' .. ' + truncate(field.label, 20) + ' .. '"
              debounce="500"
              size="sm"
              type="search"
              autocomplete="off"
              @click="removeSearch()"
              @update="filtered()"
            />

            <b-form-select
              v-if="field.selectable"
              v-model="filter[field.key]"
              :options="field.selectOptions"
              size="sm"
              type="search"
              @input="removeSearch()"
              @change="filtered()"
            >
              <template v-slot:first>
                <b-form-select-option value="">
                  .. {{ truncate(field.label, 20) }} ..
                </b-form-select-option>
              </template>
            </b-form-select>
          </td>
        </template>

        <template #cell(symbol)="data">
          <div class="font-italic">
            <b-link :href="'/Genes/' + data.item.hgnc_id">
              <b-badge
                v-b-tooltip.hover.leftbottom
                pill
                variant="success"
                :title="data.item.hgnc_id"
              >
                {{ data.item.symbol }}
              </b-badge>
            </b-link>
          </div>
        </template>

        <template #cell(SysNDD)="data">
          <div>
            <b-avatar
              v-b-tooltip.hover.left
              size="1.4em"
              :icon="yn_icon[data.item.SysNDD]"
              :variant="yn_icon_style[data.item.SysNDD]"
              :title="data.item.SysNDD"
            />
          </div>
        </template>

        <template #cell(radboudumc_ID)="data">
          <div>
            <b-avatar
              v-b-tooltip.hover.left
              size="1.4em"
              :icon="yn_icon[data.item.radboudumc_ID]"
              :variant="yn_icon_style[data.item.radboudumc_ID]"
              :title="data.item.radboudumc_ID"
            />
          </div>
        </template>

        <template #cell(gene2phenotype)="data">
          <div>
            <b-avatar
              v-b-tooltip.hover.left
              size="1.4em"
              :icon="yn_icon[data.item.gene2phenotype]"
              :variant="yn_icon_style[data.item.gene2phenotype]"
              :title="data.item.gene2phenotype"
            />
          </div>
        </template>

        <template #cell(panelapp)="data">
          <div>
            <b-avatar
              v-b-tooltip.hover.left
              size="1.4em"
              :icon="yn_icon[data.item.panelapp]"
              :variant="yn_icon_style[data.item.panelapp]"
              :title="data.item.panelapp"
            />
          </div>
        </template>

        <template #cell(sfari)="data">
          <div>
            <b-avatar
              v-b-tooltip.hover.left
              size="1.4em"
              :icon="yn_icon[data.item.sfari]"
              :variant="yn_icon_style[data.item.sfari]"
              :title="data.item.sfari"
            />
          </div>
        </template>

        <template #cell(geisinger_DBD)="data">
          <div>
            <b-avatar
              v-b-tooltip.hover.left
              size="1.4em"
              :icon="yn_icon[data.item.geisinger_DBD]"
              :variant="yn_icon_style[data.item.geisinger_DBD]"
              :title="data.item.geisinger_DBD"
            />
          </div>
        </template>

        <template #cell(omim_ndd)="data">
          <div>
            <b-avatar
              v-b-tooltip.hover.left
              size="1.4em"
              :icon="yn_icon[data.item.omim_ndd]"
              :variant="yn_icon_style[data.item.omim_ndd]"
              :title="data.item.omim_ndd"
            />
          </div>
        </template>

        <template #cell(orphanet_id)="data">
          <div>
            <b-avatar
              v-b-tooltip.hover.left
              size="1.4em"
              :icon="yn_icon[data.item.orphanet_id]"
              :variant="yn_icon_style[data.item.orphanet_id]"
              :title="data.item.orphanet_id"
            />
          </div>
        </template>
      </b-table>
    </b-card>
  </b-container>
</template>


<script>
import toastMixin from "@/assets/js/mixins/toastMixin.js";

export default {
  name: "AnalysesCurationComparisonsTable",
  // register the Treeselect component
  components: {},
  mixins: [toastMixin],
  data() {
    return {
      yn_icon: { no: "x", yes: "check" },
      yn_icon_style: { no: "warning", yes: "success" },
      items: [],
      fields: [
        {
          key: "symbol",
          label: "Symbol",
          sortable: true,
          filterable: true,
          class: "text-left",
        },
        {
          key: "SysNDD",
          label: "SysNDD",
          sortable: true,
          filterable: true,
          class: "text-left",
        },
        {
          key: "radboudumc_ID",
          label: "Radboud UMC ID",
          sortable: true,
          filterable: true,
          class: "text-left",
        },
        {
          key: "gene2phenotype",
          label: "gene2phenotype",
          sortable: true,
          filterable: true,
          class: "text-left",
        },
        {
          key: "panelapp",
          label: "PanelApp",
          sortable: true,
          filterable: true,
          class: "text-left",
        },
        {
          key: "sfari",
          label: "SFARI",
          sortable: true,
          filterable: true,
          class: "text-left",
        },
        {
          key: "geisinger_DBD",
          label: "Geisinger DBD",
          sortable: true,
          filterable: true,
          class: "text-left",
        },
        {
          key: "omim_ndd",
          label: "OMIM NDD",
          sortable: true,
          filterable: true,
          class: "text-left",
        },
        {
          key: "orphanet_id",
          label: "Orphanet ID",
          sortable: true,
          filterable: true,
          class: "text-left",
        },
      ],
      totalRows: 0,
      currentPage: 1,
      currentItemID: 0,
      prevItemID: null,
      nextItemID: null,
      lastItemID: null,
      executionTime: 0,
      perPage: "10",
      pageOptions: ["10", "25", "50", "200"],
      sortBy: "symbol",
      sortDesc: false,
      filter: {
        any: "",
        SysNDD: "",
        radboudumc_ID: "",
        gene2phenotype: "",
        panelapp: "",
        sfari: "",
        geisinger_DBD: "",
        omim_ndd: "",
        orphanet_id: "",
      },
      filter_string: "",
      filterOn: [],
      selection: null,
      image: "",
      loadingUpset: true,
      loadingMatrix: true,
      loadingTable: true,
      tabIndex: 0,
      isBusy: true,
      downloading: false,
    };
  },
  computed: {},
  watch: {
    sortBy() {
      this.handleSortChange();
    },
    perPage() {
      this.handlePerPageChange();
    },
    sortDesc() {
      this.handleSortChange();
    },
  },
  mounted() {
    this.loadTableData();
  },
  methods: {
    async loadTableData() {
      this.isBusy = true;
      let apiUrl =
        process.env.VUE_APP_API_URL +
        "/api/comparisons/browse?sort=" +
        (this.sortDesc ? "-" : "+") +
        this.sortBy +
        "&filter=" +
        this.filter_string +
        "&page_after=" +
        this.currentItemID +
        "&page_size=" +
        this.perPage;

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
        this.fields = response.data.meta[0].fspec;

        this.isBusy = false;
      } catch (e) {
        this.makeToast(e, "Error", "danger");
      }
    },
    async requestExcel() {
      this.downloading = true;

      let apiUrl =
        process.env.VUE_APP_API_URL +
        "/api/comparisons/excel?sort=" +
        (this.sortDesc ? "-" : "+") +
        this.sortBy +
        "&filter=" +
        this.filter_string;

      try {
        let response = await this.axios({
          url: apiUrl,
          method: "GET",
          responseType: "blob",
        }).then((response) => {
          var fileURL = window.URL.createObjectURL(new Blob([response.data]));
          var fileLink = document.createElement("a");

          fileLink.href = fileURL;
          fileLink.setAttribute("download", "curation_comparisons.xlsx");
          document.body.appendChild(fileLink);

          fileLink.click();
        });
      } catch (e) {
        this.makeToast(e, "Error", "danger");
      }

      this.downloading = false;
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
      let filter_string_not_empty = Object.filter(
        this.filter,
        (value) => value !== ""
      );

      if (Object.keys(filter_string_not_empty).length !== 0) {
        this.filter_string =
          "contains(" +
          Object.keys(filter_string_not_empty)
            .map((key) => [key, this.filter[key]].join(","))
            .join("),contains(") +
          ")";
        this.loadTableData();
      } else {
        this.filter_string = "";
        this.loadTableData();
      }
    },
    removeFilters() {
      this.filter = {
        any: "",
        entity_id: "",
        symbol: "",
        disease_ontology_name: "",
        disease_ontology_id_version: "",
        hpo_mode_of_inheritance_term_name: "",
        hpo_mode_of_inheritance_term: "",
        ndd_phenotype: "",
        category: "",
      };
      this.filtered();
    },
    removeSearch() {
      this.filter["any"] = "";
      this.filtered();
    },
    onFiltered(filteredItems) {
      // Trigger pagination to update the number of buttons/pages due to filtering
      this.totalRows = filteredItems.length;
      this.currentPage = 1;
    },
    truncate(str, n) {
      return str.length > n ? str.substr(0, n - 1) + "..." : str;
    },
  },
};
</script>


<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>