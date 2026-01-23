<!-- src/components/analyses/AnalysesPhenotypeClusters.vue -->
<template>
  <BContainer fluid>
    <!-- The main card -->
    <BCard
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            Entities
            <mark
              v-b-tooltip.hover.leftbottom
              title="Entities clustered based on their phenotype annotations to identify groups with similar characteristics. Interactive visualization allows exploration of cluster details."
            >
              clustered using phenotype
            </mark>
            annotation.
            <BBadge
              id="popover-badge-help-clusters"
              pill
              href="#"
              variant="info"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover
              target="popover-badge-help-clusters"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Cluster Analysis Details
              </template>
              This section provides an interactive visualization of entities grouped by phenotype annotations.
              The graphical part allows you to explore the clusters by clicking on the nodes, and the table
              displays detailed information about the variables within each cluster.
            </BPopover>
          </h6>
          <!-- Add download button for the cluster plot -->
          <DownloadImageButtons
            :svg-id="'cluster_dataviz-svg'"
            :file-name="'cluster_plot'"
          />
        </div>
      </template>

      <!-- Put both graph and table in ONE row -->
      <BRow>
        <!-- LEFT COLUMN (Graph) -->
        <BCol
          md="4"
        >
          <BCard
            header-tag="header"
            class="my-3 mx-2 text-start"
            body-class="p-0"
            header-class="p-1"
            footer-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-0 font-weight-bold">
                Selected cluster {{ selectedCluster.cluster }}
                with
                <BBadge variant="primary">
                  {{ selectedCluster.cluster_size }}
                </BBadge>
                entities
              </h6>
            </template>

            <div
              id="cluster_dataviz"
              class="svg-container"
            >
              <BSpinner
                v-if="loading"
                label="Loading..."
                class="spinner"
              />
              <div v-else>
                <!-- Cluster graph is rendered here by D3 -->
              </div>
            </div>

            <template #footer>
              <BLink :href="'/Entities/?filter=' + selectedCluster.hash_filter">
                Entities for cluster {{ selectedCluster.cluster }}
              </BLink>
            </template>
          </BCard>
        </BCol>

        <!-- RIGHT COLUMN (Table) -->
        <BCol
          md="8"
        >
          <BCard
            header-tag="header"
            class="my-3 mx-2 text-start"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <!-- TABLE HEADER CONTROLS (table type selector, search bar, pagination) -->
            <template #header>
              <div class="mb-0 font-weight-bold">
                <BRow>
                  <BCol
                    sm="6"
                    class="mb-1"
                  >
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
                    <!-- A search input controlling the 'any' filter -->
                    <TableSearchInput
                      v-model="filter.any.content"
                      :placeholder="'Search variables here...'"
                      :debounce-time="500"
                      @input="onFilterChange"
                    />
                  </BCol>
                </BRow>
              </div>
            </template>

            <!-- MAIN TABLE -->
            <BCardText class="text-start">
              <GenericTable
                :items="displayedItems"
                :fields="fields"
                :sort-by="sortBy"
                :sort-desc="sortDesc"
                @update-sort="handleSortUpdate"
              >
                <!-- Column-level filter slot (optional) -->
                <template v-slot:filter-controls>
                  <td
                    v-for="field in fields"
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

                <!-- Optionally define custom column slots -->
                <template #cell-variable="{ row }">
                  <BBadge variant="primary">
                    {{ row.variable }}
                  </BBadge>
                </template>

                <template #cell-p.value="{ row }">
                  <BBadge variant="info">
                    {{ row['p.value'] }}
                  </BBadge>
                </template>

                <template #cell-v.test="{ row }">
                  <BBadge variant="warning">
                    {{ row['v.test'] }}
                  </BBadge>
                </template>
              </GenericTable>

              <!-- Bottom pagination controls (optional) -->
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
import * as d3 from 'd3';
import toastMixin from '@/assets/js/mixins/toastMixin';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';

// Import your small table components:
import GenericTable from '@/components/small/GenericTable.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

export default {
  name: 'AnalysesPhenotypeClusters',
  components: {
    DownloadImageButtons,
    GenericTable,
    TableSearchInput,
    TablePaginationControls,
  },
  mixins: [toastMixin],
  data() {
    return {
      /* --------------------------------------
       * Clustering + Graph data
       * ------------------------------------ */
      itemsCluster: [],
      selectedCluster: {
        quali_inp_var: [],
        quali_sup_var: [],
        quanti_sup_var: [],
      },
      activeCluster: '1',
      loading: false,

      /* --------------------------------------
       * Table logic / fields
       * ------------------------------------ */
      fields: [
        {
          key: 'variable',
          label: 'Variable',
          class: 'text-start',
          sortable: true,
        },
        {
          key: 'p.value',
          label: 'p-value',
          class: 'text-start',
          sortable: true,
        },
        {
          key: 'v.test',
          label: 'v-test',
          class: 'text-start',
          sortable: true,
        },
      ],
      tableOptions: [
        {
          value: 'quali_inp_var',
          text: 'Qualitative input variables (phenotypes)',
        },
        {
          value: 'quali_sup_var',
          text: 'Qualitative supplementary variables (inheritance)',
        },
        {
          value: 'quanti_sup_var',
          text: 'Quantitative supplementary variables (phenotype counts)',
        },
      ],
      tableType: 'quali_inp_var',

      /* --------------------------------------
       * Pagination / Sorting / Filtering
       * ------------------------------------ */
      perPage: 10,
      totalRows: 1,
      currentPage: 1,
      sortBy: 'variable',
      sortDesc: false,
      filter: {
        any: { content: null, join_char: null, operator: 'contains' },
        variable: { content: null, join_char: null, operator: 'contains' },
        'p.value': { content: null, join_char: null, operator: 'contains' },
        'v.test': { content: null, join_char: null, operator: 'contains' },
      },
    };
  },
  computed: {
    /**
     * The items currently being displayed in the table (filtered + paginated).
     * If you're hooking up to a back-end with query parameters, you may do so in
     * a loadData() function. Here, we do a local filter as an example.
     */
    displayedItems() {
      // 1. Start from the relevant cluster data
      let dataArray = this.selectedCluster[this.tableType] || [];

      // 2. Apply filtering
      dataArray = this.applyFilters(dataArray);

      // 3. (Optional) Real-time sorting is handled by <GenericTable>

      // 4. Paginate (client-side)
      const start = (this.currentPage - 1) * this.perPage;
      const end = start + this.perPage;
      return dataArray.slice(start, end);
    },
  },
  watch: {
    // Update data whenever the user picks a new cluster
    activeCluster() {
      this.setActiveCluster();
      this.generateClusterGraph();
    },
    // Watch the tableType so we can update totalRows based on new array
    tableType() {
      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
      this.currentPage = 1; // Reset to first page
    },
  },
  mounted() {
    this.loadClusterData();
  },
  methods: {
    /* --------------------------------------
     * Load cluster data from API
     * ------------------------------------ */
    async loadClusterData() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/analysis/phenotype_clustering`;
      this.loading = true;
      try {
        const response = await this.axios.get(apiUrl);
        this.itemsCluster = response.data;
        this.setActiveCluster();
        this.generateClusterGraph();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loading = false;
      }
    },
    setActiveCluster() {
      // Filter out the cluster matching activeCluster
      const match = this.itemsCluster.find(
        (item) => item.cluster === this.activeCluster,
      );
      this.selectedCluster = match || {
        quali_inp_var: [],
        quali_sup_var: [],
        quanti_sup_var: [],
      };
      // Update total rows
      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
    },

    /* --------------------------------------
     * Searching + Filtering (client-side example)
     * ------------------------------------ */
    applyFilters(items) {
      const anyFilterValue = (this.filter.any.content || '').toLowerCase();

      // Return items that match the global "any" filter AND column-specific filters
      return items.filter((row) => {
        // 1. Global "any" filter
        if (anyFilterValue) {
          const rowString = Object.values(row).join(' ').toLowerCase();
          if (!rowString.includes(anyFilterValue)) {
            return false;
          }
        }
        // 2. Column-specific filters
        const filterKeys = Object.keys(this.filter).filter((f) => f !== 'any');
        let keepRow = true;
        filterKeys.forEach((fieldKey) => {
          const colFilterVal = (this.filter[fieldKey].content || '').toLowerCase();
          if (colFilterVal) {
            const rowVal = String(row[fieldKey] || '').toLowerCase();
            if (!rowVal.includes(colFilterVal)) {
              keepRow = false;
            }
          }
        });
        return keepRow;
      });
    },
    onFilterChange() {
      // Reset page to 1 to see the updated first page
      this.currentPage = 1;
    },

    /* --------------------------------------
     * Pagination controls
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
    handleSortUpdate(ctx) {
      this.sortBy = ctx.sortBy;
      this.sortDesc = ctx.sortDesc;
    },

    /* --------------------------------------
     * Graph code for cluster viz
     * ------------------------------------ */
    generateClusterGraph() {
      // Graph dimension
      const margin = {
        top: 10,
        right: 10,
        bottom: 10,
        left: 10,
      };
      const width = 400 - margin.left - margin.right;
      const height = 400 - margin.top - margin.bottom;

      // Remove existing svg and div
      d3.select('#cluster_dataviz').select('svg').remove();
      d3.select('#cluster_dataviz').select('div').remove();

      // Create the svg area
      const svg = d3
        .select('#cluster_dataviz')
        .append('svg')
        .attr('id', 'cluster_dataviz-svg')
        .attr('width', width)
        .attr('height', height);

      // Data from API call
      const data = this.itemsCluster;

      // Color palette for clusters
      const color = d3
        .scaleOrdinal()
        .domain([1, 2, 3, 4, 5, 6])
        .range(d3.schemeSet1);

      // Size scale for clusters
      const size = d3
        .scaleLinear()
        .domain([0, 1000])
        .range([7, 55]);

      // Unique cluster IDs
      const uniqueClusters = [...new Set(data.map((d) => d.cluster))];

      // X scale by cluster
      const x = d3
        .scaleOrdinal()
        .domain(uniqueClusters)
        .range(uniqueClusters.map((c) => c * 30));

      // Tooltip
      const Tooltip = d3
        .select('#cluster_dataviz')
        .append('div')
        .style('opacity', 0)
        .attr('class', 'tooltip')
        .style('background-color', 'white')
        .style('border', 'solid')
        .style('border-width', '2px')
        .style('border-radius', '5px')
        .style('padding', '5px');

      // Mouse event handlers
      const mouseoverHandler = function mouseoverHandler() {
        d3.select(this).style('cursor', 'pointer');
        Tooltip.style('opacity', 1);
        d3.select(this).style('stroke', 'black');
      };
      const mousemoveHandler = function mousemoveHandler(event, d) {
        Tooltip.html(`<u>Cluster: ${d.cluster}</u><br>${d.cluster_size} entities`)
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      };
      const mouseleaveHandler = function mouseleaveHandler() {
        d3.select(this).style('cursor', 'default');
        Tooltip.style('opacity', 0);
        d3.select(this).style('stroke', '#696969');
      };

      // Force simulation
      const simulation = d3
        .forceSimulation()
        .force('center', d3.forceCenter().x(width / 2).y(height / 2))
        .force('charge', d3.forceManyBody().strength(0.1))
        .force(
          'collide',
          d3
            .forceCollide()
            .strength(0.2)
            .radius((d) => size(d.cluster_size) + 3)
            .iterations(1),
        )
        .force(
          'forceX',
          d3
            .forceX()
            .strength(0.5)
            .x((d) => x(d.cluster)),
        )
        .force(
          'forceY',
          d3
            .forceY()
            .strength(0.1)
            .y(height * 0.5),
        );

      // Drag handlers
      function dragstartHandler(event, d) {
        if (!event.active) {
          simulation.alphaTarget(0.03).restart();
        }
        d.fx = d.x;
        d.fy = d.y;
      }
      function dragHandler(event, d) {
        d.fx = event.x;
        d.fy = event.y;
      }
      function dragendHandler(event, d) {
        if (!event.active) {
          simulation.alphaTarget(0.03);
        }
        d.fx = null;
        d.fy = null;
      }

      // Create circles
      const node = svg
        .append('g')
        .selectAll('circle')
        .data(data)
        .enter()
        .append('a')
        .append('circle')
        .attr('class', 'node')
        .attr('r', (d) => size(d.cluster_size))
        .attr('cx', width / 2)
        .attr('cy', height / 2)
        .style('fill', (d) => color(d.cluster))
        .style('fill-opacity', 0.8)
        .attr('stroke', '#696969')
        .style('stroke-width', (d) => (
          d.cluster === this.activeCluster ? 4 : 1
        ))
        .on('mouseover', mouseoverHandler)
        .on('mousemove', mousemoveHandler)
        .on('mouseleave', mouseleaveHandler)
        .on('click', (event, datum) => {
          this.activeCluster = datum.cluster;
          Tooltip.style('opacity', 0); // Hide tooltip on click
        })
        .call(
          d3
            .drag()
            .on('start', dragstartHandler)
            .on('drag', dragHandler)
            .on('end', dragendHandler),
        );

      // Update positions each tick
      simulation.nodes(data).on('tick', () => {
        node
          .attr('cx', (d) => d.x)
          .attr('cy', (d) => d.y);
      });
    },
  },
};
</script>

<style scoped>
.svg-container {
  display: inline-block;
  position: relative;
  width: 100%;
  max-width: 800px;
  vertical-align: top;
  overflow: hidden;
}

.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}

mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>
