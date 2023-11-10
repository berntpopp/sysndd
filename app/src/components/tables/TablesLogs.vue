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
          <b-table
            :items="logsData"
            :fields="logFields"
            :per-page="perPage"
            :current-page="currentPage"
            small
            striped
            hover
          >
            <template v-slot:cell(last_modified)="data">
              {{ new Date(data.item.last_modified).toLocaleString() }}
            </template>
          </b-table>

          <b-pagination
            v-model="currentPage"
            :total-rows="totalItems"
            :per-page="perPage"
            align="center"
            size="sm"
            class="my-0"
          />
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import axios from 'axios';

export default {
  name: 'TablesLogs',
  data() {
    // Initialize with placeholder data
    const placeholderData = Array(10).fill().map(() => ({
      remote_addr: 'Loading...',
      http_user_agent: 'Loading...',
      http_host: 'Loading...',
      request_method: 'Loading...',
      path_info: 'Loading...',
      query_string: 'Loading...',
      status: 'Loading...',
      duration: 'Loading...',
      filename: 'Loading...',
      last_modified: new Date().toISOString(),
    }));

    return {
      logsData: placeholderData,
      logFields: [
        // ... your field definitions ...
      ],
      currentPage: 1,
      perPage: 10,
      totalItems: 0,
      loading: false, // Start with false as we're showing placeholder data
    };
  },
  watch: {
    currentPage() {
      this.loadLogsData();
    },
  },
  mounted() {
    this.loadLogsData();
  },
  methods: {
    loadLogsData() {
      this.loading = true; // Start loading when actual API call is made

      const apiUrl = `${process.env.VUE_APP_API_URL}/api/logs`;

      axios.get(apiUrl, {
        params: {
          page_after: this.currentPage === 1 ? 0 : this.logsData[this.logsData.length - 1].last_modified,
          page_size: this.perPage,
        },
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
        },
      }).then((response) => {
        this.logsData = response.data.data;
        this.totalItems = response.data.meta[0].totalItems;
      }).catch((error) => {
        console.error('Error fetching logs:', error);
      }).finally(() => {
        this.loading = false; // Stop loading once API call is complete
      });
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
.badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
:deep(.vue-treeselect__placeholder) {
  color: #6C757D !important;
}
:deep(.vue-treeselect__control) {
  color: #6C757D !important;
}
</style>
