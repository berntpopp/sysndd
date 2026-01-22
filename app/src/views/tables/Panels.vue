<template>
  <div class="container-fluid">
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <b-container
      v-else
      fluid
    >
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <!-- User Interface controls -->
          <b-card
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-1 text-left font-weight-bold">
                Panel compilation and download
                <b-badge
                  v-b-tooltip.hover.bottom
                  variant="primary"
                  :title="
                    'Loaded ' +
                      perPage +
                      '/' +
                      totalRows +
                      ' in ' +
                      executionTime
                  "
                >
                  Genes: {{ totalRows }}
                </b-badge>

                <b-badge
                  id="popover-badge-help-comparisons"
                  class="m-1"
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
                    Gene categories
                  </template>
                  A gene is assigned to the highest category of all entities it
                  is associated with. <br>
                  E.g. if there are two entities for a gene with "Definitive"
                  and "Limited" category, respectively, the gene is assigned to
                  the Definitive panel.
                </b-popover>
              </h6>
            </template>

            <b-row>
              <!-- column 1 -->
              <b-col
                class="my-1"
                sm="6"
              >
                <b-input-group
                  prepend="Category"
                  class="mb-1"
                  size="sm"
                >
                  <b-form-select
                    v-model="selected_category"
                    input-id="category-select"
                    :options="categories_list"
                    text-field="value"
                    size="sm"
                    @input="requestSelected"
                  />
                </b-input-group>

                <b-input-group
                  prepend="Inheritance"
                  class="mb-1"
                  size="sm"
                >
                  <b-form-select
                    v-model="selected_inheritance"
                    input-id="inheritance-select"
                    :options="inheritance_list"
                    text-field="value"
                    size="sm"
                    @input="requestSelected"
                  />
                </b-input-group>
              </b-col>

              <!-- column 2 -->
              <b-col
                class="my-1"
                sm="6"
              >
                <b-input-group
                  prepend="Columns"
                  class="mb-1"
                  size="sm"
                >
                  <b-form-select
                    v-model="selected_columns"
                    input-id="columns-select"
                    :options="columns_list"
                    text-field="value"
                    multiple
                    :select-size="3"
                    size="sm"
                    @input="requestSelected"
                  />
                </b-input-group>
              </b-col>

              <!-- column 3 -->
              <b-col
                class="my-1"
                sm="6"
              >
                <b-input-group
                  prepend="Sort"
                  class="mb-1"
                  size="sm"
                >
                  <b-form-select
                    v-model="sortBy"
                    input-id="sort-select"
                    :options="sort_list"
                    text-field="value"
                    size="sm"
                    @input="requestSelected"
                  />
                </b-input-group>

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

              <!-- column 4 -->
              <b-col
                class="my-1"
                sm="6"
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
                  :title="data.item.category"
                  class="w-100 text-truncate"
                >
                  {{ data.item.category }}
                </div>
              </template>

              <template #cell(inheritance)="data">
                <div
                  v-b-tooltip.hover.leftbottom
                  :title="data.item.inheritance"
                  class="w-100 text-truncate"
                >
                  {{ data.item.inheritance }}
                </div>
              </template>

              <template #cell(symbol)="data">
                <div
                  v-b-tooltip.hover.leftbottom
                  :title="data.item.symbol"
                  class="w-100 text-truncate"
                >
                  {{ data.item.symbol }}
                </div>
              </template>

              <template #cell(hgnc_id)="data">
                <div
                  v-b-tooltip.hover.leftbottom
                  :title="data.item.hgnc_id"
                  class="w-100 text-truncate"
                >
                  {{ data.item.hgnc_id }}
                </div>
              </template>

              <template #cell(entrez_id)="data">
                <div
                  v-b-tooltip.hover.leftbottom
                  :title="data.item.entrez_id"
                  class="w-100 text-truncate"
                >
                  {{ data.item.entrez_id }}
                </div>
              </template>

              <template #cell(ensembl_gene_id)="data">
                <div
                  v-b-tooltip.hover.leftbottom
                  :title="data.item.ensembl_gene_id"
                  class="w-100 text-truncate"
                >
                  {{ data.item.ensembl_gene_id }}
                </div>
              </template>

              <template #cell(ucsc_id)="data">
                <div
                  v-b-tooltip.hover.leftbottom
                  :title="data.item.ucsc_id"
                  class="w-100 text-truncate"
                >
                  {{ data.item.ucsc_id }}
                </div>
              </template>

              <template #cell(bed_hg19)="data">
                <div
                  v-b-tooltip.hover.leftbottom
                  :title="data.item.bed_hg19"
                  class="w-100 text-truncate"
                >
                  {{ data.item.bed_hg19 }}
                </div>
              </template>

              <template #cell(bed_hg38)="data">
                <div
                  v-b-tooltip.hover.leftbottom
                  :title="data.item.bed_hg38"
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
import toastMixin from '@/assets/js/mixins/toastMixin';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'Panels',
  mixins: [toastMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Panels',
    // all titles will be injected into this template
    titleTemplate:
      '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en',
    },
    meta: [
      {
        vmid: 'description',
        name: 'description',
        content:
          'The Panels table view allows composing panels of genes associated with NDD which can be sued for filtering in sequencing studies.',
      },
    ],
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
      perPage: '10',
      pageOptions: ['10', '25', '50', '200'],
      sortBy: 'symbol',
      sortDesc: false,
      sortDirection: 'asc',
      filter: null,
      filterOn: [],
      loading: true,
      isBusy: true,
      downloading: false,
      show_table: false,
    };
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
    },
  },
  mounted() {
    this.loadOptionsData();
    setTimeout(() => {
      this.loading = false;
    }, 500);
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
      if (value === 1) {
        this.currentItemID = 0;
        this.requestSelected();
      } else if (value === this.totalPages) {
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
      const filter_string_not_empty = Object.filter(
        this.filter,
        (value) => value !== '',
      );

      if (Object.keys(filter_string_not_empty).length !== 0) {
        this.filter_string = `contains(${
          Object.keys(filter_string_not_empty)
            .map((key) => [key, this.filter[key]].join(','))
            .join('),contains(')
        })`;
        this.requestSelected();
      } else {
        this.filter_string = '';
        this.requestSelected();
      }
    },
    removeFilters() {
      this.filter = { any: '' };
      this.filtered();
    },
    removeSearch() {
      this.filter.any = '';
      this.filtered();
    },
    async loadOptionsData() {
      this.loading = true;

      const apiUrl = `${process.env.VUE_APP_API_URL}/api/panels/options`;
      try {
        const response = await this.axios.get(apiUrl);
        this.categories_list = response.data[0].options;
        this.inheritance_list = response.data[1].options;
        this.columns_list = response.data[2].options;

        this.selected_category = this.$route.params.category_input;
        this.selected_inheritance = this.$route.params.inheritance_input;
        this.selected_columns = response.data[2].options;
        this.sort_list = response.data[2].options;

        const c = [];
        for (let i = 0; i < response.data[2].options.length; i += 1) {
          c.push(response.data[2].options[i].value);
        }

        this.selected_columns = c;

        this.requestSelected();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async requestSelected() {
      this.isBusy = true;

      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/panels/browse?sort=${
        this.sortDesc ? '-' : '+'
      }${this.sortBy
      }&filter=any(category,${
        this.selected_category
      }),any(inheritance_filter,${
        this.selected_inheritance
      })`
        + `&fields=${
          this.selected_columns.join()
        }&page_after=${
          this.currentItemID
        }&page_size=${
          this.perPage}`;

      try {
        const response = await this.axios.get(apiUrl);

        this.items = response.data.data;
        this.fields = response.data.fields;

        this.totalRows = response.data.meta[0].totalItems;
        // this solves an update issue in b-pagination component
        // based on https://github.com/bootstrap-vue/bootstrap-vue/issues/3541
        this.$nextTick(() => {
          this.currentPage = response.data.meta[0].currentPage;
        });
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

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();

      this.loading = false;
    },
    async requestExcel() {
      this.downloading = true;

      const urlParam = `sort=${
        this.sortDesc ? '-' : '+'
      }${this.sortBy
      }&filter=any(category,${
        this.selected_category
      }),any(inheritance_filter,${
        this.selected_inheritance
      })&page_after=`
        + '0'
        + '&page_size='
        + 'all'
        + '&format=xlsx';

      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/panels/browse?${
        urlParam}`;

      try {
        const response = await this.axios({
          url: apiUrl,
          method: 'GET',
          responseType: 'blob',
        });

        const fileURL = window.URL.createObjectURL(new Blob([response.data]));
        const fileLink = document.createElement('a');

        fileLink.href = fileURL;
        fileLink.setAttribute('download', 'sysndd_panels.xlsx');
        document.body.appendChild(fileLink);

        fileLink.click();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.downloading = false;
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
.input-group > .input-group-prepend {
  flex: 0 0 35%;
}
.input-group .input-group-text {
  width: 100%;
}
</style>
