<!-- views/analyses/PublicationsNDD.vue -->
<template>
  <div class="container-fluid pt-3">
    <b-container fluid>
      <!-- b-card wrapper -->
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
              <!-- You can put a title or additional controls here -->
              <h6 class="mb-1 text-left font-weight-bold">
                Recent NDD publications
                <mark
                  v-b-tooltip.hover.leftbottom
                  title="This section displays recent publications related to Neurodevelopmental Disorders (NDD) fetched from Pubtator."
                > (Pubtator)</mark>.
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
        <TablePaginationControls
          :total-rows="totalRows"
          :initial-per-page="perPage"
          :page-options="pageOptions"
          @page-change="handlePageChange"
          @per-page-change="handlePerPageChange"
        />

        <!-- Table Component -->
        <GenericTable
          :items="publicationsData"
          :fields="tableFields"
          :current-page="currentPage"
          :busy="isLoading"
        >
          <!-- Custom slot for the 'PMID' column -->
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

// Import the utilities file
import Utils from '@/assets/js/utils';

export default {
  name: 'PublicationsNDD',
  components: {
    GenericTable,
    TablePaginationControls,
  },
  data() {
    return {
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
      currentPage: 1,
      isLoading: false,
      totalRows: 0,
      perPage: 10,
      pageOptions: [10],
    };
  },
  created() {
    this.fetchPublicationsData();
  },
  methods: {
    async fetchPublicationsData(page = 1) {
      this.isLoading = true;
      try {
        const response = await axios.get(`${process.env.VUE_APP_API_URL}/api/publication/pubtator/search?current_page=${page}&max_pages=${this.perPage}`);
        this.publicationsData = response.data.data;
        // TODO: review and correct this for total pages vs total rows
        [this.totalRows] = response.data.meta.totalPages;
      } catch (error) {
        console.error('Failed to fetch publications:', error);
      } finally {
        this.isLoading = false;
      }
    },
    handlePageChange(newPage) {
      this.currentPage = newPage;
      this.fetchPublicationsData(newPage);
    },
    handlePerPageChange(newSize) {
      this.perPage = newSize;
      this.fetchPublicationsData(this.currentPage);
    },
    // Function to truncate a string to a specified length.
    // If the string is longer than the specified length, it adds '...' to the end.
    // imported from utils.js
    truncate(str, n) {
      // Use the utility function here
      return Utils.truncate(str, n);
    },
  },
  // ... Rest of your metaInfo and styles
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
