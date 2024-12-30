<!-- src/components/analyses/AnalysesPhenotypeClusters.vue -->
<template>
  <b-container fluid>
    <!-- Main card -->
    <b-card
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-left font-weight-bold">
            Entities
            <mark
              v-b-tooltip.hover.leftbottom
              title="Entities clustered based on their phenotype annotations to identify groups with similar characteristics. Interactive visualization allows exploration of cluster details."
            >
              clustered using phenotype
            </mark>
            annotation.
            <b-badge
              id="popover-badge-help-clusters"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>
            <b-popover
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
            </b-popover>
          </h6>
          <DownloadImageButtons
            :svg-id="'cluster_dataviz-svg'"
            :file-name="'cluster_plot'"
          />
        </div>
      </template>

      <!-- Row: left graph, right table -->
      <b-row>
        <!-- LEFT COLUMN (Graph) -->
        <b-col
          md="4"
        >
          <b-card
            header-tag="header"
            class="my-3 mx-2 text-left"
            body-class="p-0"
            header-class="p-1"
            footer-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-0 font-weight-bold">
                Selected cluster {{ selectedCluster.cluster }}
                with
                <b-badge variant="primary">
                  {{ selectedCluster.cluster_size }}
                </b-badge>
                entities
              </h6>
            </template>

            <div
              id="cluster_dataviz"
              class="svg-container"
            >
              <b-spinner
                v-if="loading"
                label="Loading..."
                class="spinner"
              />
              <div v-else>
                <!-- Cluster graph is rendered here by D3 -->
              </div>
            </div>

            <template #footer>
              <b-link :href="'/Entities/?filter=' + selectedCluster.hash_filter">
                Entities for cluster {{ selectedCluster.cluster }}
              </b-link>
            </template>
          </b-card>
        </b-col>

        <!-- RIGHT COLUMN (Table) -->
        <b-col
          md="8"
        >
          <b-card
            header-tag="header"
            class="my-3 mx-2 text-left"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <!-- TABLE HEADER CONTROLS -->
            <template #header>
              <div class="mb-0 font-weight-bold">
                <b-row>
                  <b-col
                    sm="6"
                    class="mb-1"
                  >
                    <b-input-group
                      prepend="Table type"
                      size="sm"
                    >
                      <b-form-select
                        v-model="tableType"
                        :options="tableOptions"
                        size="sm"
                      />
                    </b-input-group>
                  </b-col>

                  <b-col
                    sm="6"
                    class="mb-1 text-right"
                  >
                    <!-- A search input controlling the 'any' filter -->
                    <TableSearchInput
                      v-model="filter.any.content"
                      :placeholder="'Search variables here...'"
                      :debounce-time="500"
                      @input="onFilterChange"
                    />
                  </b-col>
                </b-row>
              </div>
            </template>

            <!-- MAIN TABLE -->
            <b-card-text class="text-left">
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
                    <b-form-input
                      v-if="field.key !== 'details'"
                      v-model="filter[field.key].content"
                      :placeholder="'Filter ' + field.label"
                      debounce="500"
                      @input="onFilterChange"
                    />
                  </td>
                </template>

                <!-- Custom column slots -->
                <template #cell-variable="{ row }">
                  <b-badge variant="primary">
                    {{ row.variable }}
                  </b-badge>
                </template>

                <template #cell-p_value="{ row }">
                  <b-badge variant="info">
                    {{ row.p_value }}
                  </b-badge>
                </template>

                <template #cell-v_test="{ row }">
                  <b-badge variant="warning">
                    {{ row.v_test }}
                  </b-badge>
                </template>
              </GenericTable>

              <!-- Bottom pagination controls (optional) -->
              <b-row class="justify-content-end">
                <b-col
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
                </b-col>
              </b-row>
            </b-card-text>
          </b-card>
        </b-col>
      </b-row>
    </b-card>
  </b-container>
</template>

<script>
import * as d3 from 'd3';
import toastMixin from '@/assets/js/mixins/toastMixin';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
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
       * Note that we changed 'p.value' to 'p_value' and 'v.test' to 'v_test'
       * to avoid property keys with dots.
       * If you want to keep them with dots, just revert them in both data + code.
       * Also note usage of thClass and tdClass if you want guaranteed styling on headers/cells.
       * ------------------------------------ */
      fields: [
        {
          key: 'variable',
          label: 'Variable',
          thClass: 'text-left bg-light', // optional for table header
          tdClass: 'text-left',
          sortable: true,
        },
        {
          key: 'p_value',
          label: 'p-value',
          thClass: 'text-left bg-light',
          tdClass: 'text-left',
          sortable: true,
        },
        {
          key: 'v_test',
          label: 'v-test',
          thClass: 'text-left bg-light',
          tdClass: 'text-left',
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
        p_value: { content: null, join_char: null, operator: 'contains' },
        v_test: { content: null, join_char: null, operator: 'contains' },
      },
    };
  },
  computed: {
    /**
     * displayedItems: local filtering + pagination
     */
    displayedItems() {
      let dataArray = this.selectedCluster[this.tableType] || [];

      // Filter
      dataArray = this.applyFilters(dataArray);

      // Paginate
      const start = (this.currentPage - 1) * this.perPage;
      const end = start + this.perPage;
      return dataArray.slice(start, end);
    },
  },
  watch: {
    activeCluster() {
      this.setActiveCluster();
      this.generateClusterGraph();
    },
    tableType() {
      // re-check totalRows
      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
      this.currentPage = 1;
    },
  },
  mounted() {
    this.loadClusterData();
  },
  methods: {
    /* --------------------------------------
     * Data load
     * ------------------------------------ */
    async loadClusterData() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/analysis/phenotype_clustering`;
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
      const match = this.itemsCluster.find(
        (item) => item.cluster === this.activeCluster,
      );
      this.selectedCluster = match || {
        quali_inp_var: [],
        quali_sup_var: [],
        quanti_sup_var: [],
      };
      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
    },

    /* --------------------------------------
     * Filtering
     * ------------------------------------ */
    applyFilters(items) {
      const anyFilterValue = (this.filter.any.content || '').toLowerCase();

      return items.filter((row) => {
        // Global 'any' filter
        if (anyFilterValue) {
          const rowString = Object.values(row).join(' ').toLowerCase();
          if (!rowString.includes(anyFilterValue)) {
            return false;
          }
        }
        // Column-specific filters
        const filterKeys = Object.keys(this.filter).filter((f) => f !== 'any');
        let keepRow = true;
        filterKeys.forEach((fieldKey) => {
          const colVal = (this.filter[fieldKey].content || '').toLowerCase();
          if (colVal) {
            const rowVal = String(row[fieldKey] || '').toLowerCase();
            if (!rowVal.includes(colVal)) {
              keepRow = false;
            }
          }
        });
        return keepRow;
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
    handleSortUpdate(ctx) {
      this.sortBy = ctx.sortBy;
      this.sortDesc = ctx.sortDesc;
    },

    /* --------------------------------------
     * Graph code
     * ------------------------------------ */
    generateClusterGraph() {
      const margin = {
        top: 10, right: 10, bottom: 10, left: 10,
      };
      const width = 400 - margin.left - margin.right;
      const height = 400 - margin.top - margin.bottom;

      d3.select('#cluster_dataviz').select('svg').remove();
      d3.select('#cluster_dataviz').select('div').remove();

      const svg = d3
        .select('#cluster_dataviz')
        .append('svg')
        .attr('id', 'cluster_dataviz-svg')
        .attr('width', width)
        .attr('height', height);

      // Data from the API
      const data = this.itemsCluster;

      const color = d3
        .scaleOrdinal()
        .domain([1, 2, 3, 4, 5, 6])
        .range(d3.schemeSet1);

      const size = d3
        .scaleLinear()
        .domain([0, 1000])
        .range([7, 55]);

      const uniqueClusters = [...new Set(data.map((d) => d.cluster))];
      const x = d3
        .scaleOrdinal()
        .domain(uniqueClusters)
        .range(uniqueClusters.map((c) => c * 30));

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

      function mouseoverHandler() {
        d3.select(this).style('cursor', 'pointer');
        Tooltip.style('opacity', 1);
        d3.select(this).style('stroke', 'black');
      }
      function mousemoveHandler(event, d) {
        Tooltip.html(
          `<u>Cluster: ${d.cluster}</u><br>${d.cluster_size} entities`,
        )
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      }
      function mouseleaveHandler() {
        d3.select(this).style('cursor', 'default');
        Tooltip.style('opacity', 0);
        d3.select(this).style('stroke', '#696969');
      }

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

      function dragstartHandler(event, datum) {
        if (!event.active) {
          simulation.alphaTarget(0.03).restart();
        }
        datum.fx = datum.x;
        datum.fy = datum.y;
      }
      function dragHandler(event, datum) {
        datum.fx = event.x;
        datum.fy = event.y;
      }
      function dragendHandler(event, datum) {
        if (!event.active) {
          simulation.alphaTarget(0.03);
        }
        datum.fx = null;
        datum.fy = null;
      }

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
        .style('stroke-width', (d) => (d.cluster === this.activeCluster ? 4 : 1))
        .on('mouseover', mouseoverHandler)
        .on('mousemove', mousemoveHandler)
        .on('mouseleave', mouseleaveHandler)
        .on('click', (event, datum) => {
          this.activeCluster = datum.cluster;
          Tooltip.style('opacity', 0);
        })
        .call(
          d3.drag()
            .on('start', dragstartHandler)
            .on('drag', dragHandler)
            .on('end', dragendHandler),
        );

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
