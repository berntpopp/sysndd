<!-- src/components/analyses/AnalyseGeneClusters.vue -->
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
          <h6 class="mb-1 text-start font-weight-bold">
            Functionally enriched
            <mark
              v-b-tooltip.hover.leftbottom
              title="This section displays gene clusters that are enriched based on functional annotations. It allows users to explore and analyze the clusters."
            >
              gene clusters
            </mark>.
            <b-badge
              id="popover-badge-help-geneclusters"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>
            <b-popover
              target="popover-badge-help-geneclusters"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Gene Clusters Information
              </template>
              This section provides insights into gene clusters that are enriched based on their functional annotations.
              Users can explore various clusters/subclusters, and analyze the associated genes and their properties.
            </b-popover>
          </h6>
          <DownloadImageButtons
            :svg-id="'gene_cluster_dataviz-svg'"
            :file-name="'gene_cluster_plot'"
          />
        </div>
      </template>

      <!-- ROW: LEFT = Graph, RIGHT = Table -->
      <b-row>
        <!-- LEFT COLUMN (Graph) -->
        <b-col md="4">
          <b-card
            header-tag="header"
            class="my-3 mx-2 text-start"
            body-class="p-0"
            header-class="p-1"
            footer-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <b-row>
                <b-col>
                  <h6 class="mb-0 font-weight-bold">
                    Selected
                    {{ selectType === 'clusters' ? 'cluster' : 'subcluster' }}
                    {{
                      selectType === 'clusters'
                        ? selectedCluster.cluster
                        : selectedCluster.parent_cluster + '.' + selectedCluster.cluster
                    }}
                    with
                    <b-badge variant="success">
                      {{ selectedCluster.cluster_size }} genes
                    </b-badge>
                  </h6>
                </b-col>
                <b-col>
                  <b-input-group
                    prepend="Select"
                    class="mb-1 text-end"
                    size="sm"
                  >
                    <b-form-select
                      v-model="selectType"
                      :options="selectOptions"
                      type="search"
                      size="sm"
                    />
                  </b-input-group>
                </b-col>
              </b-row>
            </template>

            <div
              id="gene_cluster_dataviz"
              class="svg-container"
            >
              <b-spinner
                v-if="loading"
                label="Loading..."
                class="spinner"
              />
              <div v-else>
                <!-- Graph rendered by D3 here -->
              </div>
            </div>

            <template #footer>
              <b-link :href="'/Entities/?filter=' + selectedCluster.hash_filter">
                Genes for cluster {{ selectedCluster.cluster }}
              </b-link>
            </template>
          </b-card>
        </b-col>

        <!-- RIGHT COLUMN (Table) -->
        <b-col md="8">
          <b-card
            header-tag="header"
            class="my-3 mx-2 text-start"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <!-- TABLE HEADER (Table type, Search input, etc.) -->
            <template #header>
              <div class="mb-0 font-weight-bold">
                <b-row>
                  <b-col
                    sm="6"
                    class="mb-1"
                  >
                    <!-- Table type selector (term_enrichment vs. identifiers) -->
                    <b-input-group
                      prepend="Table type"
                      size="sm"
                    >
                      <b-form-select
                        v-model="tableType"
                        :options="tableOptions"
                        type="search"
                        size="sm"
                      />
                    </b-input-group>
                  </b-col>

                  <b-col
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
                  </b-col>
                </b-row>
              </div>
            </template>

            <b-card-text class="text-start">
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
                    <b-form-input
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
                    <b-badge
                      v-b-tooltip.hover.rightbottom
                      variant="light"
                      :style="'border-color: ' + (category_style[row.category] || category_style.default) + '; border-width: medium;'"
                      :title="row.category"
                    >
                      {{ findCategoryText(row.category) }}
                    </b-badge>
                  </div>
                </template>

                <template #cell-number_of_genes="{ row }">
                  <b-badge variant="info">
                    {{ row['number_of_genes'] }}
                  </b-badge>
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
                    <b-badge variant="warning">
                      {{ row.fdr }}
                    </b-badge>
                  </div>
                </template>

                <!-- description cell -->
                <template #cell-description="{ row }">
                  <!-- Render only if tableType === 'term_enrichment' -->
                  <div v-if="tableType === 'term_enrichment'">
                    <b-button
                      v-b-tooltip.hover.leftbottom
                      class="btn-xs mx-2"
                      variant="outline-primary"
                      :href="findCategoryLink(row.category, row.term)"
                      :title="row.term"
                      target="_blank"
                    >
                      <b-icon
                        icon="box-arrow-up-right"
                        font-scale="0.8"
                      />
                      {{ row.description }}
                    </b-button>
                  </div>
                </template>

                <!-- symbol cell -->
                <template #cell-symbol="{ row }">
                  <!-- Render only if tableType === 'identifiers' -->
                  <div
                    v-if="tableType === 'identifiers'"
                    class="font-italic"
                  >
                    <b-link :href="'/Genes/' + row.hgnc_id">
                      <b-badge
                        v-b-tooltip.hover.leftbottom
                        pill
                        variant="success"
                        :title="row.hgnc_id"
                      >
                        {{ row.symbol }}
                      </b-badge>
                    </b-link>
                  </div>
                </template>

                <!-- STRING_id cell -->
                <template #cell-STRING_id="{ row }">
                  <!-- Render only if tableType === 'identifiers' -->
                  <div
                    v-if="tableType === 'identifiers'"
                    class="overflow-hidden text-truncate"
                  >
                    <b-button
                      class="btn-xs mx-2"
                      variant="outline-primary"
                      :href="'https://string-db.org/network/' + row.STRING_id"
                      target="_blank"
                    >
                      <b-icon
                        icon="box-arrow-up-right"
                        font-scale="0.8"
                      />
                      {{ row.STRING_id }}
                    </b-button>
                  </div>
                </template>
              </GenericTable>

              <!-- OPTIONAL bottom pagination controls -->
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
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';

// Import small table components
import GenericTable from '@/components/small/GenericTable.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

export default {
  name: 'AnalyseGeneClusters',
  components: {
    DownloadImageButtons,
    GenericTable,
    TableSearchInput,
    TablePaginationControls,
  },
  mixins: [toastMixin, colorAndSymbolsMixin],
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
       * If you color badges by category, define category_style object here
       * with fallback "default" color
       */
      category_style: {
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

      // If you rely on GenericTable for sorting, skip local sorting here
      const start = (this.currentPage - 1) * this.perPage;
      const end = start + this.perPage;
      return dataArray.slice(start, end);
    },
  },
  watch: {
    activeParentCluster() {
      if (this.selectType === 'clusters') {
        this.setActiveCluster();
        this.generateClusterGraph();
      }
    },
    activeSubCluster() {
      if (this.selectType === 'subclusters') {
        this.setActiveCluster();
        this.generateClusterGraph();
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
     * Load cluster data from API
     * ------------------------------------ */
    async loadClusterData() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/analysis/functional_clustering`;
      try {
        const response = await this.axios.get(apiUrl);
        this.itemsCluster = response.data.clusters;
        this.valueCategories = response.data.categories;
        this.setActiveCluster();
        this.generateClusterGraph();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loading = false;
      }
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
     * Graph code for cluster viz
     * ------------------------------------ */
    generateClusterGraph() {
      const margin = {
        top: 10, right: 10, bottom: 10, left: 10,
      };
      const width = 400 - margin.left - margin.right;
      const height = 400 - margin.top - margin.bottom;

      d3.select('#gene_cluster_dataviz').select('svg').remove();
      d3.select('#gene_cluster_dataviz').select('div').remove();

      const svg = d3
        .select('#gene_cluster_dataviz')
        .append('svg')
        .attr('id', 'gene_cluster_dataviz-svg')
        .attr('width', width)
        .attr('height', height);

      // Flatten subclusters
      const data = this.itemsCluster
        .map(({ subclusters }) => subclusters)
        .flat();

      const color = d3
        .scaleOrdinal()
        .domain([1, 2, 3, 4, 5, 6, 7])
        .range(d3.schemeSet1);

      const size = d3
        .scaleLinear()
        .domain([0, 1000])
        .range([7, 55]);

      const uniqueClusters = [...new Set(data.map((d) => d.parent_cluster))];
      const x = d3
        .scaleOrdinal()
        .domain(uniqueClusters)
        .range(uniqueClusters.map((c) => c * 30));

      const Tooltip = d3
        .select('#gene_cluster_dataviz')
        .append('div')
        .style('opacity', 0)
        .attr('class', 'tooltip')
        .style('background-color', 'white')
        .style('border', 'solid 2px')
        .style('border-radius', '5px')
        .style('padding', '5px');

      function mouseover(event, d) {
        Tooltip.style('opacity', 1);
        d3.select(this).style('stroke-width', 3);
      }
      function mousemove(event, d) {
        Tooltip.html(
          `<u>Cluster: ${d.parent_cluster}.${d.cluster}</u><br>${d.cluster_size} genes`,
        )
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      }
      function mouseleave() {
        Tooltip.style('opacity', 0);
        d3.select(this).style('stroke-width', 1);
      }

      const simulation = d3.forceSimulation()
        .force('center', d3.forceCenter().x(width / 2).y(height / 2))
        .force('charge', d3.forceManyBody().strength(0.1))
        .force('collide', d3.forceCollide()
          .strength(0.2)
          .radius((d) => size(d.cluster_size) + 3)
          .iterations(1))
        .force('forceX', d3.forceX()
          .strength(0.5)
          .x((d) => x(d.parent_cluster)))
        .force('forceY', d3.forceY()
          .strength(0.1)
          .y(height * 0.5));

      function dragstartHandler(event, datum) {
        if (!event.active) simulation.alphaTarget(0.03).restart();
        datum.fx = datum.x;
        datum.fy = datum.y;
      }
      function dragHandler(event, datum) {
        datum.fx = event.x;
        datum.fy = event.y;
      }
      function dragendHandler(event, datum) {
        if (!event.active) simulation.alphaTarget(0.03);
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
        .style('fill', (d) => color(d.parent_cluster))
        .style('fill-opacity', 0.8)
        .attr('stroke', '#696969')
        .style('stroke-width', (d) => {
          if (this.selectType === 'clusters' && d.parent_cluster === this.activeParentCluster) {
            return 4;
          }
          if (
            this.selectType === 'subclusters'
            && d.parent_cluster === this.activeParentCluster
            && d.cluster === this.activeSubCluster
          ) {
            return 4;
          }
          return 1;
        })
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave)
        .on('click', (event, datum) => {
          this.activeParentCluster = datum.parent_cluster;
          this.activeSubCluster = datum.cluster;
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

.svg-content {
  display: inline-block;
  position: absolute;
  top: 0;
  left: 0;
}

.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
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
