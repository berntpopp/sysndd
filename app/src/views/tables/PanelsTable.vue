<template>
  <div class="container-fluid py-2">
    <TableShell
      title="Panel compilation"
      :meta="`Genes: ${totalRows}`"
      :description="`Loaded ${perPage}/${totalRows} in ${executionTime}`"
      :loading="loading"
    >
      <template v-if="!loading" #actions>
        <BButton
          id="panel-table-help"
          v-b-tooltip.hover.bottom
          class="me-1"
          size="sm"
          variant="info"
          aria-label="Show panel table category help"
        >
          <i class="bi bi-question-circle-fill" />
        </BButton>
        <BPopover target="panel-table-help" variant="info" triggers="focus">
          <template #title> Gene categories </template>
          A gene is assigned to the highest category of all entities it is associated with.
          <br />
          E.g. if there are two entities for a gene with "Definitive" and "Limited" category,
          respectively, the gene is assigned to the Definitive panel.
        </BPopover>

        <BButton size="sm" @click="requestExcel">
          <i class="bi bi-table mx-1" />
          <i v-if="!downloading" class="bi bi-download" />
          <BSpinner v-if="downloading" small />
          .xlsx
        </BButton>
      </template>

      <template v-if="!loading" #toolbar>
        <PanelsTableControls
          :categories="categories_list"
          :inheritance="inheritance_list"
          :columns="columns_list"
          :selected-category="selected_category"
          :selected-inheritance="selected_inheritance"
          :selected-columns="selected_columns"
          :sort-by="sortBy"
          :busy="isBusy"
          @update:category="handleCategoryChange"
          @update:inheritance="handleInheritanceChange"
          @update:columns="handleColumnsChange"
          @update:sort="handleSortControlChange"
        />

        <div class="panels-table__pagination">
          <TablePaginationControls
            :total-rows="totalRows"
            :initial-per-page="perPage"
            :page-options="pageOptions"
            :current-page="currentPage"
            @page-change="handlePageChange"
            @per-page-change="handlePerPageChange"
          />
        </div>
      </template>

      <template #loading>
        <TableLoadingState label="Loading panel genes" />
      </template>

      <div class="d-none d-md-block">
        <BTable
          :items="items"
          :fields="fields"
          :filter-included-fields="filterOn"
          :sort-by="sortBy"
          :busy="isBusy"
          :stacked="false"
          head-variant="light"
          show-empty
          small
          fixed
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
            <div v-b-tooltip.hover.leftbottom :title="data.item.symbol" class="w-100 text-truncate">
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
      </div>

      <div class="d-md-none">
        <PanelsMobileRows :items="items" :selected-field-keys="selected_columns" />
      </div>
    </TableShell>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import { useToast } from '@/composables';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableShell from '@/components/table/TableShell.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';
import PanelsMobileRows from './PanelsMobileRows.vue';
import PanelsTableControls from './PanelsTableControls.vue';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

import { getPanelOptions, browsePanels, browsePanelsXlsx } from '@/api/panels';

export default {
  name: 'PanelsTable',
  components: {
    TableShell,
    TableLoadingState,
    PanelsMobileRows,
    PanelsTableControls,
    TablePaginationControls,
  },
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
  },
  mounted() {
    this.loadOptionsData();
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
    handleCategoryChange(value) {
      this.selected_category = value;
      this.currentItemID = 0;
      this.requestSelected();
    },
    handleInheritanceChange(value) {
      this.selected_inheritance = value;
      this.currentItemID = 0;
      this.requestSelected();
    },
    handleColumnsChange(value) {
      this.selected_columns = value;
      this.currentItemID = 0;
      this.requestSelected();
    },
    handleSortControlChange(value) {
      this.sortBy = value;
    },
    handlePerPageChange(newPerPage) {
      if (newPerPage === undefined || newPerPage === null) return;
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
      const filter_string_not_empty = Object.filter(this.filter, (value) => value !== '');

      if (Object.keys(filter_string_not_empty).length !== 0) {
        this.filter_string = `contains(${Object.keys(filter_string_not_empty)
          .map((key) => [key, this.filter[key]].join(','))
          .join('),contains(')})`;
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

      try {
        const data = await getPanelOptions();
        this.categories_list = data[0].options;
        this.inheritance_list = data[1].options;
        this.columns_list = data[2].options;

        this.selected_category = this.$route.params.category_input;
        this.selected_inheritance = this.$route.params.inheritance_input;
        this.selected_columns = data[2].options;
        this.sort_list = data[2].options;

        const c = [];
        for (let i = 0; i < data[2].options.length; i += 1) {
          c.push(data[2].options[i].value);
        }

        this.selected_columns = c;

        this.requestSelected();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.loading = false;
      }
    },
    async requestSelected() {
      this.isBusy = true;

      // Extract sort column and order from array-based sortBy (Bootstrap-Vue-Next format)
      const sortColumn = this.sortBy.length > 0 ? this.sortBy[0].key : 'symbol';
      const sortOrder = this.sortBy.length > 0 ? this.sortBy[0].order : 'asc';

      try {
        const data = await browsePanels({
          sort: `${sortOrder === 'desc' ? '-' : '+'}${sortColumn}`,
          filter: `any(category,${this.selected_category}),any(inheritance_filter,${this.selected_inheritance})`,
          fields: this.selected_columns.join(),
          page_after: this.currentItemID,
          page_size: String(this.perPage),
        });

        this.items = data.data;
        this.fields = data.fields;

        this.totalRows = data.meta[0].totalItems;
        // this solves an update issue in b-pagination component
        // based on https://github.com/bootstrap-vue/bootstrap-vue/issues/3541
        this.$nextTick(() => {
          this.currentPage = data.meta[0].currentPage;
        });
        this.totalPages = data.meta[0].totalPages;
        this.prevItemID = data.meta[0].prevItemID;
        this.currentItemID = data.meta[0].currentItemID;
        this.nextItemID = data.meta[0].nextItemID;
        this.lastItemID = data.meta[0].lastItemID;
        this.executionTime = data.meta[0].executionTime;

        this.isBusy = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.isBusy = false;
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

      try {
        const blob = await browsePanelsXlsx({
          sort: `${sortOrder === 'desc' ? '-' : '+'}${sortColumn}`,
          filter: `any(category,${this.selected_category}),any(inheritance_filter,${this.selected_inheritance})`,
          page_after: 0,
          page_size: 'all',
        });

        const fileURL = window.URL.createObjectURL(new Blob([blob]));
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
.panels-table__pagination {
  margin-top: 0.45rem;
}

@media (min-width: 768px) {
  .panels-table__pagination {
    max-width: 34rem;
  }
}
</style>

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
