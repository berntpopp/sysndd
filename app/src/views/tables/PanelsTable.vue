<template>
  <div class="container-fluid">
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <BContainer
      v-else
      fluid
    >
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <!-- User Interface controls -->
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-1 text-start font-weight-bold">
                Panel compilation and download
                <BBadge
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
                </BBadge>

                <BBadge
                  id="popover-badge-help-comparisons"
                  class="m-1"
                  pill
                  href="#"
                  variant="info"
                >
                  <i class="bi bi-question-circle-fill" />
                </BBadge>

                <BPopover
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
                </BPopover>
              </h6>
            </template>

            <BRow>
              <!-- column 1 -->
              <BCol
                class="my-1"
                sm="6"
              >
                <BInputGroup
                  prepend="Category"
                  class="mb-1"
                  size="sm"
                >
                  <BFormSelect
                    v-model="selected_category"
                    input-id="category-select"
                    :options="categories_list"
                    text-field="value"
                    size="sm"
                    @update:model-value="requestSelected"
                  />
                </BInputGroup>

                <BInputGroup
                  prepend="Inheritance"
                  class="mb-1"
                  size="sm"
                >
                  <BFormSelect
                    v-model="selected_inheritance"
                    input-id="inheritance-select"
                    :options="inheritance_list"
                    text-field="value"
                    size="sm"
                    @update:model-value="requestSelected"
                  />
                </BInputGroup>
              </BCol>

              <!-- column 2 -->
              <BCol
                class="my-1"
                sm="6"
              >
                <BInputGroup
                  prepend="Columns"
                  class="mb-1"
                  size="sm"
                >
                  <BFormSelect
                    v-model="selected_columns"
                    input-id="columns-select"
                    :options="columns_list"
                    text-field="value"
                    multiple
                    :select-size="3"
                    size="sm"
                    @update:model-value="requestSelected"
                  />
                </BInputGroup>
              </BCol>

              <!-- column 3 -->
              <BCol
                class="my-1"
                sm="6"
              >
                <BInputGroup
                  prepend="Sort"
                  class="mb-1"
                  size="sm"
                >
                  <BFormSelect
                    v-model="sortBy"
                    input-id="sort-select"
                    :options="sort_list"
                    text-field="value"
                    size="sm"
                    @update:model-value="requestSelected"
                  />
                </BInputGroup>

                <BButton
                  block
                  size="sm"
                  @click="requestExcel"
                >
                  <i class="bi bi-table mx-1" />
                  <i
                    v-if="!downloading"
                    class="bi bi-download"
                  />
                  <BSpinner
                    v-if="downloading"
                    small
                  />
                  .xlsx
                </BButton>
              </BCol>

              <!-- column 4 -->
              <BCol
                class="my-1"
                sm="6"
              >
                <BInputGroup
                  prepend="Per page"
                  class="mb-1"
                  size="sm"
                >
                  <BFormSelect
                    id="per-page-select"
                    :model-value="perPage"
                    :options="pageOptions"
                    size="sm"
                    @update:model-value="handlePerPageChange"
                  />
                </BInputGroup>

                <BPagination
                  :model-value="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  align="fill"
                  size="sm"
                  class="my-0"
                  limit="2"
                  @update:model-value="handlePageChange"
                />
              </BCol>
            </BRow>

            <!-- Main table element -->
            <BTable
              :items="items"
              :fields="fields"
              :filter-included-fields="filterOn"
              :sort-by="sortBy"
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
              @update:sort-by="handleSortByUpdate"
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
            </BTable>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import { useToast } from '@/composables';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'PanelsTable',
  setup() {
    const { makeToast } = useToast();

    useHead({
      title: 'Panels',
      meta: [
        {
          name: 'description',
          content:
            'The Panels table view allows composing panels of genes associated with NDD which can be sued for filtering in sequencing studies.',
        },
      ],
    });

    return {
      makeToast,
    };
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
      pageOptions: [10, 25, 50, 200],
      // Bootstrap-Vue-Next uses array-based sortBy format
      sortBy: [{ key: 'symbol', order: 'asc' }],
      filter: null,
      filterOn: [],
      loading: true,
      isBusy: true,
      downloading: false,
      show_table: false,
    };
  },
  watch: {
    // Deep watch for array-based sortBy
    sortBy: {
      handler() {
        this.handleSortChange();
      },
      deep: true,
    },
    perPage(_value) {
      this.handlePerPageChange();
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
    /**
     * Handle sort-by updates from Bootstrap-Vue-Next BTable.
     * @param {Array} newSortBy - Array of sort objects: [{ key: 'column', order: 'asc'|'desc' }]
     */
    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
    },
    handlePerPageChange(newPerPage) {
      this.perPage = typeof newPerPage === 'string' ? parseInt(newPerPage, 10) : newPerPage;
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

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/panels/options`;
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

      // Extract sort column and order from array-based sortBy (Bootstrap-Vue-Next format)
      const sortColumn = this.sortBy.length > 0 ? this.sortBy[0].key : 'symbol';
      const sortOrder = this.sortBy.length > 0 ? this.sortBy[0].order : 'asc';

      const apiUrl = `${import.meta.env.VITE_API_URL
      }/api/panels/browse?sort=${
        sortOrder === 'desc' ? '-' : '+'
      }${sortColumn
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

      // Extract sort column and order from array-based sortBy (Bootstrap-Vue-Next format)
      const sortColumn = this.sortBy.length > 0 ? this.sortBy[0].key : 'symbol';
      const sortOrder = this.sortBy.length > 0 ? this.sortBy[0].order : 'asc';

      const urlParam = `sort=${
        sortOrder === 'desc' ? '-' : '+'
      }${sortColumn
      }&filter=any(category,${
        this.selected_category
      }),any(inheritance_filter,${
        this.selected_inheritance
      })&page_after=`
        + '0'
        + '&page_size='
        + 'all'
        + '&format=xlsx';

      const apiUrl = `${import.meta.env.VITE_API_URL
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
