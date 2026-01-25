<!-- src/components/analyses/AnalyseGeneClusters.vue -->
<template>
  <BContainer fluid>
    <!-- Main card -->
    <BCard
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            Functionally enriched
            <mark
              v-b-tooltip.hover.leftbottom
              title="This section displays gene clusters that are enriched based on functional annotations. It allows users to explore and analyze the clusters."
            >
              gene clusters
            </mark>.
            <BBadge
              id="popover-badge-help-geneclusters"
              pill
              href="#"
              variant="info"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover
              target="popover-badge-help-geneclusters"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Gene Clusters Information
              </template>
              This section provides insights into gene clusters that are enriched based on their functional annotations.
              Users can explore various clusters/subclusters, and analyze the associated genes and their properties.
            </BPopover>
          </h6>
          <!-- Network export buttons now in NetworkVisualization component -->
        </div>
      </template>

      <!-- ROW: LEFT = Graph, RIGHT = Table -->
      <BRow>
        <!-- LEFT COLUMN (Network Visualization) -->
        <BCol md="5">
          <!-- NetworkVisualization component replaces D3.js bubble chart -->
          <div class="my-3 mx-2">
            <NetworkVisualization
              :cluster-type="selectType"
              @cluster-selected="handleClusterSelected"
            />
          </div>
        </BCol>

        <!-- RIGHT COLUMN (Table) -->
        <BCol md="7">
          <BCard
            header-tag="header"
            class="my-3 mx-2 text-start"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <!-- TABLE HEADER (Table type, Search input, etc.) -->
            <template #header>
              <div class="mb-0 font-weight-bold">
                <BRow>
                  <BCol
                    sm="6"
                    class="mb-1"
                  >
                    <!-- Table type selector (term_enrichment vs. identifiers) -->
                    <BInputGroup
                      prepend="Table type"
                      size="sm"
                    >
                      <BFormSelect
                        v-model="tableType"
                        :options="tableOptions"
                        size="sm"
                      />
                    </BInputGroup>
                  </BCol>

                  <BCol
                    sm="6"
                    class="mb-1 text-end"
                  >
                    <!-- A global 'any' filter for searching all columns -->
                    <TableSearchInput
                      v-model="filter.any.content"
                      :placeholder="'Search any field...'"
                      :debounce-time="500"
                      @input="onFilterChange"
                    />
                  </BCol>
                </BRow>
              </div>
            </template>

            <BCardText class="text-start">
              <!-- GenericTable for main table content -->
              <GenericTable
                :items="displayedItems"
                :fields="fieldsComputed"
                :sort-by="sortBy"
                :sort-desc="sortDesc"
                @update-sort="handleSortUpdate"
              >
                <!-- Optional column-level filters -->
                <template v-slot:filter-controls>
                  <td
                    v-for="field in fieldsComputed"
                    :key="field.key"
                  >
                    <BFormInput
                      v-if="field.key !== 'details'"
                      v-model="filter[field.key].content"
                      :placeholder="'Filter ' + field.label"
                      debounce="500"
                      @input="onFilterChange"
                    />
                  </td>
                </template>

                <!-- category cell -->
                <template #cell-category="{ row }">
                  <!-- Render only if tableType === 'term_enrichment' -->
                  <div v-if="tableType === 'term_enrichment'">
                    <BBadge
                      v-b-tooltip.hover.rightbottom
                      variant="light"
                      :style="'border-color: ' + (clusterCategoryStyle[row.category] || clusterCategoryStyle.default) + '; border-width: medium;'"
                      :title="row.category"
                    >
                      {{ findCategoryText(row.category) }}
                    </BBadge>
                  </div>
                </template>

                <template #cell-number_of_genes="{ row }">
                  <BBadge variant="info">
                    {{ row['number_of_genes'] }}
                  </BBadge>
                </template>

                <!-- fdr cell -->
                <template #cell-fdr="{ row }">
                  <!-- Render only if tableType === 'term_enrichment' -->
                  <div
                    v-if="tableType === 'term_enrichment'"
                    v-b-tooltip.hover.leftbottom
                    class="overflow-hidden text-truncate"
                    :title="row.fdr != null ? Number(row.fdr).toFixed(10) : ''"
                  >
                    <BBadge variant="warning">
                      {{ row.fdr }}
                    </BBadge>
                  </div>
                </template>

                <!-- description cell -->
                <template #cell-description="{ row }">
                  <!-- Render only if tableType === 'term_enrichment' -->
                  <div v-if="tableType === 'term_enrichment'">
                    <BButton
                      v-b-tooltip.hover.leftbottom
                      class="btn-xs mx-2"
                      variant="outline-primary"
                      :href="findCategoryLink(row.category, row.term)"
                      :title="row.term"
                      target="_blank"
                    >
                      <i class="bi bi-box-arrow-up-right" />
                      {{ row.description }}
                    </BButton>
                  </div>
                </template>

                <!-- symbol cell -->
                <template #cell-symbol="{ row }">
                  <!-- Render only if tableType === 'identifiers' -->
                  <div
                    v-if="tableType === 'identifiers'"
                    class="font-italic"
                  >
                    <BLink :href="'/Genes/' + row.hgnc_id">
                      <BBadge
                        v-b-tooltip.hover.leftbottom
                        pill
                        variant="success"
                        :title="row.hgnc_id"
                      >
                        {{ row.symbol }}
                      </BBadge>
                    </BLink>
                  </div>
                </template>

                <!-- STRING_id cell -->
                <template #cell-STRING_id="{ row }">
                  <!-- Render only if tableType === 'identifiers' -->
                  <div
                    v-if="tableType === 'identifiers'"
                    class="overflow-hidden text-truncate"
                  >
                    <BButton
                      class="btn-xs mx-2"
                      variant="outline-primary"
                      :href="'https://string-db.org/network/' + row.STRING_id"
                      target="_blank"
                    >
                      <i class="bi bi-box-arrow-up-right" />
                      {{ row.STRING_id }}
                    </BButton>
                  </div>
                </template>
              </GenericTable>

              <!-- OPTIONAL bottom pagination controls -->
              <BRow class="justify-content-end">
                <BCol
                  cols="12"
                  md="auto"
                  class="my-1"
                >
                  <TablePaginationControls
                    :total-rows="totalRows"
                    :initial-per-page="perPage"
                    :page-options="[5, 10, 20]"
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  />
                </BCol>
              </BRow>
            </BCardText>
          </BCard>
        </BCol>
      </BRow>
    </BCard>
  </BContainer>
</template>

<script>
import { useToast, useColorAndSymbols } from '@/composables';

// Import small table components
import GenericTable from '@/components/small/GenericTable.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

// Import NetworkVisualization component (replaces D3.js bubble chart)
import NetworkVisualization from '@/components/analyses/NetworkVisualization.vue';

export default {
  name: 'AnalyseGeneClusters',
  components: {
    GenericTable,
    TableSearchInput,
    TablePaginationControls,
    NetworkVisualization,
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();

    return {
      makeToast,
      ...colorAndSymbols,
    };
  },
  data() {
    return {
      /* --------------------------------------
       * Data from the API
       * ------------------------------------ */
      itemsCluster: [],
      valueCategories: [], // for showing text, link, etc. by category
      selectedCluster: {
        term_enrichment: [],
      },

      /*
       * If you color badges by category, define clusterCategoryStyle object here
       * with fallback "default" color (renamed to avoid conflict with mixin's category_style)
       */
      clusterCategoryStyle: {
        GO: '#AA00AA',
        KEGG: '#AA5500',
        MONDO: '#0088AA',
        default: '#666666', // fallback if row.category not in object
      },

      /* --------------------------------------
       * Table logic
       * ------------------------------------ */
      tableType: 'term_enrichment',
      tableOptions: [
        { value: 'term_enrichment', text: 'Term enrichment' },
        { value: 'identifiers', text: 'Identifiers' },
      ],

      // You can define classes for columns in fields using thClass/tdClass if desired
      // (in computed fieldsComputed below)
      filter: {
        any: { content: null, operator: 'contains' },
        category: { content: null, operator: 'contains' },
        number_of_genes: { content: null, operator: 'contains' },
        fdr: { content: null, operator: 'contains' },
        description: { content: null, operator: 'contains' },
        symbol: { content: null, operator: 'contains' },
        STRING_id: { content: null, operator: 'contains' },
      },
      sortBy: 'category',
      sortDesc: false,

      // Pagination
      perPage: 10,
      totalRows: 1,
      currentPage: 1,

      /* --------------------------------------
       * Clustering logic
       * ------------------------------------ */
      selectOptions: [
        { value: 'clusters', text: 'Clusters' },
        { value: 'subclusters', text: 'Subclusters' },
      ],
      selectType: 'clusters',
      activeParentCluster: 1,
      activeSubCluster: 1,

      loading: true,
      loadingStage: 'initializing', // 'initializing' | 'submitting' | 'processing' | 'loading_data'
      loadingProgress: 0,
      estimatedSeconds: 15,
      jobId: null,
      algorithm: 'leiden', // 'leiden' (fast) or 'walktrap' (legacy)
      algorithmOptions: [
        { value: 'leiden', text: 'Leiden (Fast)' },
        { value: 'walktrap', text: 'Walktrap (Legacy)' },
      ],
    };
  },
  computed: {
    /**
     * fieldsComputed: Return fields array based on tableType
     * with thClass/tdClass for styling
     */
    fieldsComputed() {
      if (this.tableType === 'term_enrichment') {
        return [
          {
            key: 'category',
            label: 'Category',
            sortable: true,
            thClass: 'text-start bg-light', // header cell class
            tdClass: 'text-start', // data cell class
          },
          {
            key: 'number_of_genes',
            label: '#Genes',
            sortable: true,
            thClass: 'text-start bg-light',
            tdClass: 'text-start',
          },
          {
            key: 'fdr',
            label: 'FDR',
            sortable: true,
            thClass: 'text-start bg-light',
            tdClass: 'text-start',
          },
          {
            key: 'description',
            label: 'Description',
            sortable: true,
            thClass: 'text-start bg-light',
            tdClass: 'text-start',
          },
        ];
      }
      // 'identifiers' case
      return [
        {
          key: 'symbol',
          label: 'Symbol',
          sortable: true,
          thClass: 'text-start bg-light',
          tdClass: 'text-start',
        },
        {
          key: 'STRING_id',
          label: 'STRING ID',
          sortable: true,
          thClass: 'text-start bg-light',
          tdClass: 'text-start',
        },
      ];
    },

    /**
     * displayedItems: Filtered + paginated items for the current tableType
     */
    displayedItems() {
      let dataArray = this.selectedCluster[this.tableType] || [];
      dataArray = this.applyFilters(dataArray);

      // Pagination
      const start = (this.currentPage - 1) * this.perPage;
      const end = start + this.perPage;
      return dataArray.slice(start, end);
    },
  },
  watch: {
    activeParentCluster() {
      if (this.selectType === 'clusters') {
        this.setActiveCluster();
      }
    },
    activeSubCluster() {
      if (this.selectType === 'subclusters') {
        this.setActiveCluster();
      }
    },
    tableType() {
      // When user changes tableType, re-check totalRows
      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
      this.currentPage = 1;
    },
    selectType() {
      this.resetCluster();
    },
  },
  mounted() {
    this.loadClusterData();
  },
  methods: {
    /**
     * Helper method: find category text from valueCategories
     */
    findCategoryText(categoryVal) {
      const found = this.valueCategories.find((cat) => cat.value === categoryVal);
      return found ? found.text : categoryVal; // fallback to raw category if not found
    },
    /**
     * Helper method: build link from valueCategories
     */
    findCategoryLink(categoryVal, termVal) {
      const found = this.valueCategories.find((cat) => cat.value === categoryVal);
      return found ? found.link + termVal : '#';
    },

    /* --------------------------------------
     * Load cluster data from API using async job system
     * ------------------------------------ */
    async loadClusterData() {
      this.loading = true;
      this.loadingStage = 'submitting';
      this.loadingProgress = 5;

      const baseUrl = import.meta.env.VITE_API_URL;

      try {
        // Step 1: Submit async job
        const submitResponse = await this.axios.post(
          `${baseUrl}/api/jobs/clustering/submit`,
          { algorithm: this.algorithm },
        );

        // Extract job info (R returns arrays for scalars)
        const jobId = Array.isArray(submitResponse.data.job_id)
          ? submitResponse.data.job_id[0]
          : submitResponse.data.job_id;
        const estSeconds = Array.isArray(submitResponse.data.estimated_seconds)
          ? submitResponse.data.estimated_seconds[0]
          : submitResponse.data.estimated_seconds;

        this.jobId = jobId;
        this.estimatedSeconds = estSeconds || 30;

        this.loadingStage = 'processing';
        this.loadingProgress = 15;

        // Step 2: Poll for results
        await this.pollJobStatus();
      } catch (e) {
        // Handle 409 Conflict (duplicate job) - silently use existing job
        if (e.response && e.response.status === 409) {
          const existingJobId = Array.isArray(e.response.data.existing_job_id)
            ? e.response.data.existing_job_id[0]
            : e.response.data.existing_job_id;
          this.jobId = existingJobId;
          this.loadingStage = 'processing';
          this.loadingProgress = 15;
          await this.pollJobStatus();
          return;
        }

        // Other errors: show toast and fall back to sync endpoint
        this.makeToast('Using synchronous loading (async unavailable)', 'Info', 'info');
        await this.loadClusterDataSync();
      }
    },

    /**
     * Poll job status until complete
     */
    async pollJobStatus() {
      const baseUrl = import.meta.env.VITE_API_URL;
      const maxAttempts = 60; // 5 minutes max (60 * 5 seconds)
      let attempts = 0;
      const startTime = Date.now();

      const poll = async () => {
        attempts += 1;

        try {
          const statusResponse = await this.axios.get(
            `${baseUrl}/api/jobs/${this.jobId}/status`,
          );

          const responseData = statusResponse.data;

          // R/plumber may return scalars as single-element arrays
          const status = Array.isArray(responseData.status)
            ? responseData.status[0]
            : responseData.status;
          const result = responseData.result;
          const progress = responseData.progress;

          // Update progress based on elapsed time vs estimate
          const elapsed = (Date.now() - startTime) / 1000;
          const estimatedProgress = Math.min(90, 15 + (elapsed / this.estimatedSeconds) * 75);
          this.loadingProgress = progress || estimatedProgress;

          if (status === 'completed') {
            this.loadingStage = 'loading_data';
            this.loadingProgress = 95;

            // Process result - handle both {clusters, categories} and flat array formats
            if (result && result.clusters) {
              this.itemsCluster = result.clusters;
              this.valueCategories = result.categories || [];
            } else if (Array.isArray(result)) {
              this.itemsCluster = result;
              this.valueCategories = [];
            } else {
              this.itemsCluster = result;
              this.valueCategories = [];
            }

            // Update loading state
            this.loadingProgress = 100;
            this.loading = false;

            // Set active cluster for table display
            this.$nextTick(() => {
              this.setActiveCluster();
            });
            return;
          }

          if (status === 'failed') {
            throw new Error(responseData.error || 'Clustering job failed');
          }

          // Still running, poll again
          if (attempts < maxAttempts) {
            const retryAfter = parseInt(statusResponse.headers['retry-after'] || '5', 10) * 1000;
            setTimeout(poll, retryAfter);
          } else {
            throw new Error('Job timed out after 5 minutes');
          }
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
          this.loading = false;
        }
      };

      await poll();
    },

    /**
     * Fallback: Synchronous data loading (for when async fails)
     */
    async loadClusterDataSync() {
      this.loadingStage = 'loading_data';
      this.loadingProgress = 50;

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/analysis/functional_clustering?algorithm=${this.algorithm}`;
      try {
        const response = await this.axios.get(apiUrl);
        this.itemsCluster = response.data.clusters;
        this.valueCategories = response.data.categories;
        this.setActiveCluster();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loading = false;
      }
    },

    /**
     * Reload with different algorithm
     * Note: v-model already updates this.algorithm before @change fires,
     * so we just trigger a reload with the current (already updated) algorithm
     */
    async reloadWithAlgorithm() {
      // Set loading first - Vue will hide D3 container and show loading spinner
      this.loading = true;
      this.loadingProgress = 0;
      this.loadingStage = 'submitting';

      // Wait for Vue to swap from D3 container to loading spinner
      await this.$nextTick();

      // v-model already updated this.algorithm, and :key="'graph-' + algorithm"
      // will force container recreation when loading finishes

      // Load new data with updated algorithm
      await this.loadClusterData();
    },

    setActiveCluster() {
      let match;
      let subClusters;

      if (this.selectType === 'clusters') {
        match = this.itemsCluster.find((item) => item.cluster === this.activeParentCluster);
        this.selectedCluster = match || { term_enrichment: [], identifiers: [] };
      } else {
        // subclusters
        subClusters = this.itemsCluster.find((item) => item.cluster === this.activeParentCluster);
        if (subClusters) {
          match = subClusters.subclusters.find((sub) => sub.cluster === this.activeSubCluster);
        }
        this.selectedCluster = match || { term_enrichment: [], identifiers: [] };
      }

      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
    },

    resetCluster() {
      this.activeParentCluster = 1;
      this.activeSubCluster = 1;
      this.setActiveCluster();
    },

    /* --------------------------------------
     * Filtering logic
     * ------------------------------------ */
    applyFilters(items) {
      const anyVal = (this.filter.any.content || '').toLowerCase();

      return items.filter((row) => {
        // 1) "any" filter
        if (anyVal) {
          const rowString = Object.values(row).join(' ').toLowerCase();
          if (!rowString.includes(anyVal)) {
            return false;
          }
        }
        // 2) column-specific filters
        const filterKeys = Object.keys(this.filter).filter((k) => k !== 'any');
        let keep = true;
        filterKeys.forEach((fieldKey) => {
          const colVal = (this.filter[fieldKey].content || '').toLowerCase();
          if (colVal) {
            const rowVal = String(row[fieldKey] || '').toLowerCase();
            if (!rowVal.includes(colVal)) {
              keep = false;
            }
          }
        });
        return keep;
      });
    },
    onFilterChange() {
      this.currentPage = 1;
    },

    /* --------------------------------------
     * Pagination
     * ------------------------------------ */
    handlePageChange(newPage) {
      this.currentPage = newPage;
    },
    handlePerPageChange(newPerPage) {
      this.perPage = newPerPage;
      this.currentPage = 1;
    },

    /* --------------------------------------
     * Sorting
     * ------------------------------------ */
    handleSortUpdate({ sortBy, sortDesc }) {
      this.sortBy = sortBy;
      this.sortDesc = sortDesc;
    },

    /* --------------------------------------
     * Network visualization event handlers
     * ------------------------------------ */
    handleClusterSelected(hgncId) {
      // Handle node click from NetworkVisualization
      // This can be used for table synchronization or other interactions
      console.log('Gene selected from network:', hgncId);
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
