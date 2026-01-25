<!-- src/components/analyses/AnalysesPhenotypeCorrelogram.vue -->
<template>
  <BContainer fluid>
    <!-- User Interface controls -->
    <BCard
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            Matrix of
            <mark
              v-b-tooltip.hover.leftbottom
              title="This plot shows the correlation coefficients between various phenotypes."
            >phenotype correlations</mark>.
            <BBadge
              id="popover-badge-help-phenotype"
              pill
              href="#"
              variant="info"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover
              target="popover-badge-help-phenotype"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Phenotype Correlations
              </template>
              This plot displays the Pearson correlation coefficients between different phenotypes.
              The color intensity represents the strength of the correlation:
              <ul>
                <li><strong>Red:</strong> Positive correlation</li>
                <li><strong>Blue:</strong> Negative correlation</li>
                <li><strong>White:</strong> No correlation</li>
              </ul>
              Click on the cells to explore the detailed phenotype relationships.
            </BPopover>
          </h6>
          <DownloadImageButtons
            :svg-id="'matrix-svg'"
            :file-name="'phenotype_correlation_matrix'"
          />
        </div>
      </template>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <!-- Error state with retry -->
        <div
          v-if="error"
          class="error-state text-center p-4"
        >
          <i class="bi bi-exclamation-triangle-fill text-danger fs-1 mb-3 d-block" />
          <p class="text-muted mb-3">
            {{ error }}
          </p>
          <BButton
            variant="primary"
            @click="retryLoad"
          >
            <i class="bi bi-arrow-clockwise me-1" />
            Retry
          </BButton>
        </div>

        <!-- Loading spinner -->
        <BSpinner
          v-else-if="loadingMatrix"
          label="Loading..."
          class="spinner"
        />

        <!-- Visualization container -->
        <template v-else>
          <div
            id="matrix_dataviz"
            class="svg-container"
          />
          <!-- Color legend -->
          <div class="d-flex justify-content-center mt-2 mb-3">
            <ColorLegend
              :min="-1"
              :max="1"
              :colors="['#000080', '#fff', '#B22222']"
              title="Correlation Coefficient (R)"
              :labels="correlationLabels"
            />
          </div>
        </template>
      </div>
    </BCard>
  </BContainer>
</template>

<script>
import { useRouter } from 'vue-router';
import useToast from '@/composables/useToast';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import ColorLegend from '@/components/analyses/ColorLegend.vue';
import * as d3 from 'd3';

/**
 * Get human-readable interpretation of a correlation coefficient
 * @param {number} r - Correlation coefficient (-1 to 1)
 * @returns {string} Human-readable interpretation
 */
function getCorrelationInterpretation(r) {
  const absR = Math.abs(r);
  const direction = r >= 0 ? 'positive' : 'negative';

  if (absR >= 0.7) return `Strong ${direction} correlation`;
  if (absR >= 0.4) return `Moderate ${direction} correlation`;
  if (absR >= 0.2) return `Weak ${direction} correlation`;
  return 'No significant correlation';
}

export default {
  name: 'AnalysesPhenotypeCorrelogram',
  components: {
    DownloadImageButtons,
    ColorLegend,
  },
  setup() {
    const { makeToast } = useToast();
    const router = useRouter();
    return { makeToast, router };
  },
  data() {
    return {
      itemsMatrix: [],
      loadingMatrix: true, // Added loading state
      error: null, // Error state for retry functionality
      // Labels for color legend
      correlationLabels: [
        { value: -1, text: '-1 (negative)' },
        { value: 0, text: '0' },
        { value: 1, text: '+1 (positive)' },
      ],
    };
  },
  mounted() {
    this.loadMatrixData();
  },
  methods: {
    async loadMatrixData() {
      this.loadingMatrix = true;
      this.error = null;

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/phenotype/correlation`;

      try {
        const response = await this.axios.get(apiUrl);
        this.itemsMatrix = response.data;
      } catch (e) {
        this.error = e.message || 'Failed to load correlation data. Please try again.';
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingMatrix = false;
        // Generate graph AFTER loadingMatrix is false so #matrix_dataviz exists in DOM
        this.$nextTick(() => {
          if (this.itemsMatrix.length > 0 && !this.error) {
            this.generateMatrixGraph();
          }
        });
      }
    },
    /**
     * Retry loading data after an error
     */
    retryLoad() {
      this.loadMatrixData();
    },
    generateMatrixGraph() {
      // Graph dimension
      const margin = {
        top: 20, right: 50, bottom: 150, left: 220,
      };
      const width = 650 - margin.left - margin.right;
      const height = 620 - margin.top - margin.bottom;

      // Remove any existing SVG
      d3.select('#matrix_dataviz').select('svg').remove();

      // Create the svg area
      const svg = d3
        .select('#matrix_dataviz')
        .append('svg')
        .attr('id', 'matrix-svg') // Added id for easier selection
        .attr('viewBox', '0 0 700 700')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      //
      const data = this.itemsMatrix;

      // List of all variables and number of them
      const domain = Array.from(
        new Set(
          data.map((d) => d.x),
        ),
      );

      // Build X scales and axis:
      const x = d3.scaleBand().range([0, width]).domain(domain).padding(0.01);

      svg
        .append('g')
        .attr('transform', `translate(0, ${height})`)
        .call(d3.axisBottom(x))
        .selectAll('text')
        .style('text-anchor', 'end')
        .attr('dx', '-.8em')
        .attr('dy', '.15em')
        .attr('transform', 'rotate(-90)');

      // Build Y scales and axis:
      const y = d3.scaleBand().range([height, 0]).domain(domain).padding(0.01);

      svg.append('g').call(d3.axisLeft(y));

      // Build color scale
      const myColor = d3
        .scaleLinear()
        .range(['#000080', '#fff', '#B22222'])
        .domain([-1, 0, 1]);

      // create a tooltip
      const tooltip = d3
        .select('#matrix_dataviz')
        .append('div')
        .style('opacity', 0)
        .attr('class', 'tooltip')
        .style('background-color', 'white')
        .style('border', 'solid')
        .style('border-width', '1px')
        .style('border-radius', '5px')
        .style('padding', '2px');

      // Three function that change the tooltip when user hover / move / leave a cell
      const mouseover = function mouseover(event, d) {
        tooltip.style('opacity', 1);

        d3.select(this).style('stroke', 'black').style('opacity', 1);
      };

      const mousemove = function mousemove(event, d) {
        const interpretation = getCorrelationInterpretation(d.value);
        tooltip
          .html(`
            <strong>R: ${Number(d.value).toFixed(3)}</strong><br>
            <em>${interpretation}</em><br>
            <small>${d.x} &amp; ${d.y}</small>
          `)
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      };

      const mouseleave = function mouseleave(event, d) {
        tooltip.style('opacity', 0);

        d3.select(this).style('stroke', 'none');
      };

      // add the squares with click navigation
      // NAVL-02: Click to navigate to phenotypes filtered by correlation pair
      // Note: cluster_id is not available from backend (see api/endpoints/phenotype_endpoints.R)
      // because phenotype pairs don't map directly to entity clusters.
      // This implementation provides clickable cells that navigate to filtered phenotype table.
      svg
        .selectAll()
        .data(data, (d) => `${d.x}:${d.y}`)
        .enter()
        .append('rect')
        .attr('x', (d) => x(d.x))
        .attr('y', (d) => y(d.y))
        .attr('width', x.bandwidth())
        .attr('height', y.bandwidth())
        .style('fill', (d) => myColor(d.value))
        .style('cursor', 'pointer')
        .attr('role', 'button')
        .attr('aria-label', (d) => `View phenotypes for ${d.x} and ${d.y} (correlation: ${d.value})`)
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave)
        .on('click', (event, d) => {
          // Navigate to Phenotypes page filtered by both phenotypes
          const filterQuery = `all(modifier_phenotype_id,${d.x_id},${d.y_id})`;
          const url = `/Phenotypes/?sort=entity_id&filter=${filterQuery}&page_after=0&page_size=10`;
          this.$router.push(url);
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
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}

.error-state {
  min-height: 200px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}
</style>
