<!-- src/components/analyses/PublicationsNDDPubtator.vue -->
<template>
  <div class="container-fluid pt-3">
    <!-- Overlay Spinner while loading -->
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />

    <!-- Once loaded, show the table container -->
    <b-container
      v-else
      fluid
    >
      <b-card
        header-tag="header"
        body-class="p-0"
        header-class="p-1"
        border-variant="dark"
      >
        <!-- Card Header -->
        <template #header>
          <b-row>
            <b-col>
              <h6 class="mb-1 text-left font-weight-bold">
                Recent NDD publications
                <mark
                  v-b-tooltip.hover.leftbottom
                  title="This section displays recent publications related to Neurodevelopmental Disorders (NDD) fetched from Pubtator."
                >
                  (Pubtator)
                </mark>
                .
                <b-badge
                  id="popover-badge-help-publications"
                  pill
                  href="#"
                  variant="info"
                >
                  <b-icon icon="question-circle-fill" />
                </b-badge>
                <b-popover
                  target="popover-badge-help-publications"
                  variant="info"
                  triggers="focus"
                >
                  <template #title>
                    Publications Details
                  </template>
                  We query the PubTator API to retrieve publications based on a given search query related to NDD.
                  The search retrieves a list of publications' metadata, such as PMIDs, titles, journals, and dates.
                </b-popover>
              </h6>
            </b-col>
          </b-row>
        </template>

        <!-- Pagination Controls -->
        <b-row>
          <b-col
            class="my-1"
            sm="12"
          >
            <TablePaginationControls
              :total-rows="totalRows"
              :initial-per-page="perPage"
              :page-options="pageOptions"
              @page-change="handlePageChange"
              @per-page-change="handlePerPageChange"
            />
          </b-col>
        </b-row>
        <!-- /Pagination Controls -->

        <!-- Table Component -->
        <GenericTable
          :items="publicationsData"
          :fields="tableFields"
          :current-page="currentPage"
          :busy="isLoading"
        >
          <!-- Custom slot for the 'pmid' column -->
          <template v-slot:cell-pmid="{ row }">
            <div>
              <b-link
                :href="'https://pubmed.ncbi.nlm.nih.gov/' + row.pmid"
                target="_blank"
              >
                {{ row.pmid }}
              </b-link>
            </div>
          </template>

          <!-- Custom slot for the 'title' column -->
          <template v-slot:cell-title="{ row }">
            <div
              v-b-tooltip.hover
              :title="row.title"
            >
              {{ truncate(row.title, 30) }}
            </div>
          </template>
        </GenericTable>
      </b-card>
    </b-container>
  </div>
</template>

<script>
import axios from 'axios';
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import Utils from '@/assets/js/utils';

export default {
  name: 'PublicationsNDDPubtator',
  components: {
    GenericTable,
    TablePaginationControls,
  },
  data() {
    return {
      // Table data and fields
      publicationsData: [],
      tableFields: [
        {
          key: 'pmid',
          label: 'PMID',
          sortable: false,
          class: 'text-left',
        },
        {
          key: 'title',
          label: 'Title',
          sortable: false,
          class: 'text-left',
        },
        {
          key: 'journal',
          label: 'Journal',
          sortable: false,
          class: 'text-left',
        },
        {
          key: 'date',
          label: 'Date',
          sortable: false,
          class: 'text-left',
        },
      ],

      // Basic pagination state
      currentPage: 1,
      perPage: 10,
      pageOptions: [10, 25, 50],
      totalRows: 0,

      // UI states
      isLoading: false, // used by the GenericTable
      loading: true, // for overlay spinner
    };
  },
  mounted() {
    // On mount, fetch first page
    this.fetchPublicationsData(this.currentPage);
  },
  methods: {
    /**
     * Fetch data from the PubTator endpoint.
     *
     * @param {number} page - The page number
     */
    async fetchPublicationsData(page) {
      this.isLoading = true;
      try {
        const response = await axios.get(
          // You can pass perPage if your endpoint supports it, or keep simple
          `${process.env.VUE_APP_API_URL}/api/publication/pubtator/search?current_page=${page}`,
        );
        // Suppose each page is 10 items fixed by the API, or you can pass params for perPage
        this.publicationsData = response.data.data || [];

        // totalPages -> totalRows if we want consistent b-pagination usage
        const totalPages = parseInt(response.data.meta.totalPages, 10) || 1;
        this.totalRows = totalPages * this.perPage;
      } catch (error) {
        console.error('Failed to fetch publications:', error);
      } finally {
        this.isLoading = false;
        this.loading = false;
      }
    },

    /**
     * handlePageChange
     * Called by TablePaginationControls when user picks a new page
     */
    handlePageChange(newPage) {
      this.currentPage = newPage;
      this.fetchPublicationsData(newPage);
    },

    /**
     * handlePerPageChange
     * Called by TablePaginationControls when user picks a new page size
     */
    handlePerPageChange(newSize) {
      // Convert to integer
      const numericSize = parseInt(newSize, 10) || 10;
      // Update local perPage
      this.perPage = numericSize;

      // If the backend's endpoint supports `page_size` or something similar,
      // you can pass it in the request. Right now, the endpoint apparently
      // only uses `current_page`, so the below line just re-fetches at page=1:
      this.currentPage = 1;
      this.fetchPublicationsData(this.currentPage);
    },

    /**
     * truncate
     * Utility: shortens text to n chars + '...', from utils.js
     */
    truncate(str, n) {
      return Utils.truncate(str, n);
    },
  },
};
</script>

<style scoped>
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>
