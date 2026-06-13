<!-- src/components/analyses/AnalysesTimePlot.vue -->
<template>
  <AnalysisPanel
    title="Curated Counts Timeline"
    description="Cumulative count of curated NDD entities or genes over time, grouped by category or inheritance mode. Click a data point to explore the entities from that date."
  >
    <template #actions>
      <InlineHelpBadge
        id="popover-badge-help-timeplot"
        aria-label="Explain entities over time plot"
      />
      <BPopover target="popover-badge-help-timeplot" variant="info" triggers="focus">
        <template #title> Time Plot Details </template>
        This section provides a dynamic visualization of the number of neurodevelopmental disorder
        (NDD) entities and genes over time. The plot can be customized by aggregation type and
        grouping criteria. Hover over the points to see detailed information, and use the legend
        buttons to show or hide individual series.
      </BPopover>
      <DownloadImageButtons :svg-id="'timeplot-svg'" :file-name="'entities_over_time'" />
    </template>

    <BRow>
      <BCol class="my-1">
        <!-- Aggregation select — labeled for screen readers -->
        <BInputGroup size="sm" class="mb-1">
          <label for="aggregate-select" class="input-group-text">Aggregation</label>
          <BFormSelect
            v-model="selected_aggregate"
            input-id="aggregate-select"
            :options="aggregate_list"
            text-field="text"
            size="sm"
            aria-label="Select aggregation type"
          />
        </BInputGroup>

        <!-- Grouping select — labeled for screen readers -->
        <BInputGroup size="sm" class="mb-1">
          <label for="group-select" class="input-group-text">Grouping</label>
          <BFormSelect
            v-model="selected_group"
            input-id="group-select"
            :options="filteredGroupList"
            text-field="text"
            size="sm"
            aria-label="Select grouping dimension"
          />
        </BInputGroup>
      </BCol>
    </BRow>

    <!-- Content with overlay spinner / error / chart -->
    <div class="position-relative">
      <!-- Loading skeleton -->
      <div v-if="loadingData" class="loading-skeleton" aria-live="polite" aria-busy="true">
        <div class="skeleton-chart" />
        <span class="visually-hidden">Loading timeline data…</span>
      </div>

      <!-- Error state -->
      <div v-else-if="loadError" class="state-card error-state text-center p-4" role="alert">
        <i class="bi bi-exclamation-triangle-fill fs-2 mb-2 d-block" style="color: var(--status-danger, #c62828)" />
        <p class="text-muted mb-3">{{ loadError }}</p>
        <BButton variant="primary" size="sm" @click="retryLoad">
          <i class="bi bi-arrow-clockwise me-1" />Retry
        </BButton>
      </div>

      <!-- Empty state -->
      <div v-else-if="items.length === 0" class="state-card empty-state text-center p-4">
        <i class="bi bi-graph-up fs-2 mb-2 d-block text-muted" />
        <p class="text-muted mb-0">No timeline data available for the selected filters.</p>
      </div>

      <!-- Chart -->
      <template v-else>
        <div id="my_dataviz" ref="svgWrapper" class="svg-container" />

        <!-- Keyboard-accessible legend chips with aria-pressed -->
        <div class="legend-chips" role="group" aria-label="Toggle series visibility">
          <button
            v-for="item in legendItems"
            :key="item.group"
            class="legend-chip"
            :class="{ 'legend-chip--hidden': item.hidden }"
            :aria-pressed="!item.hidden"
            :aria-label="`${item.hidden ? 'Show' : 'Hide'} ${item.group} series`"
            :style="{ '--chip-color': item.color }"
            @click="toggleLegendItem(item)"
          >
            <span class="legend-chip-dot" aria-hidden="true" />
            {{ item.group }}
          </button>
        </div>
        <p class="chart-caption">Click a legend chip or data point to filter the view.</p>
      </template>
    </div>
  </AnalysisPanel>
</template>

<script>
import { ref } from 'vue';
import { useToast, useText } from '@/composables';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import * as d3 from 'd3';

// Typed API client (W5)
import { getEntitiesOverTime } from '@/api/statistics';

/**
 * SysNDD category color tokens — aligned with status tokens used across the app.
 * Replaces d3.schemeSet2 pastels that conflicted with badge/icon colors elsewhere.
 *
 * Token derivation:
 *   Definitive  → --status-success  → teal/green #2e7d32
 *   Limited     → --status-warning  → amber      #f57c00
 *   Moderate    → --status-info     → blue       #0277bd
 *   Refuted     → --status-danger   → red        #c62828
 *   not applicable → neutral grey   → #78909c
 *
 * For inheritance grouping we derive from the medical-blue family.
 */
const CATEGORY_COLOR_MAP = {
  Definitive: '#2e7d32',       // status-success green
  Limited: '#f57c00',           // status-warning amber
  Moderate: '#0277bd',          // status-info blue
  Refuted: '#c62828',           // status-danger red
  'not applicable': '#78909c',  // neutral blue-grey
};

/** Get a token-aligned color for a series group name. */
function getGroupColor(group, fallbackScale) {
  return CATEGORY_COLOR_MAP[group] || fallbackScale(group);
}

export default {
  name: 'AnalysesTimePlot',
  components: {
    AnalysisPanel,
    DownloadImageButtons,
    InlineHelpBadge,
  },
  setup() {
    const { makeToast } = useToast();
    const text = useText();
    const svgWrapper = ref(null);
    return {
      makeToast,
      svgWrapper,
      ...text,
    };
  },
  data() {
    return {
      aggregate_list: [
        { value: 'entity_id', text: 'Entity ID' },
        { value: 'symbol', text: 'Symbol' },
      ],
      selected_aggregate: 'entity_id',
      group_list: [
        { value: 'category', text: 'Category' },
        { value: 'inheritance_filter', text: 'Inheritance Filter' },
        { value: 'inheritance_multiple', text: 'Inheritance Multiple' },
      ],
      selected_group: 'category',
      filter_string: 'contains(ndd_phenotype_word,Yes)',
      items: [],
      itemsMeta: [],
      loadingData: true,
      loadError: null,
      // Legend state driven by Vue so toggling re-renders
      legendItems: [],
    };
  },
  computed: {
    filteredGroupList() {
      if (this.selected_aggregate === 'entity_id') {
        return this.group_list.filter((group) => group.value !== 'inheritance_multiple');
      }
      return this.group_list;
    },
  },
  watch: {
    selected_aggregate(newVal, oldVal) {
      if (newVal !== oldVal) {
        this.selected_group = 'category';
        this.loadData();
      }
    },
    selected_group() {
      this.loadData();
    },
  },
  mounted() {
    this.loadData();
  },
  methods: {
    async loadData() {
      this.loadingData = true;
      this.loadError = null;

      try {
        const data = await getEntitiesOverTime({
          aggregate: this.selected_aggregate,
          group: this.selected_group,
          filter: this.filter_string,
        });

        this.items = data.data;
        this.itemsMeta = data.meta;

        this.$nextTick(() => {
          this.generateGraph();
        });
      } catch (e) {
        this.loadError = e.message || 'Failed to load timeline data. Please try again.';
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingData = false;
      }
    },

    retryLoad() {
      this.loadData();
    },

    getNextMonthFirstDay(dateStr) {
      const date = new Date(dateStr);
      date.setMonth(date.getMonth() + 1);
      date.setDate(1);
      return date.toISOString().split('T')[0];
    },

    generateLink(d) {
      let baseUrl = '/Entities/?sort=entity_id&filter=';
      if (this.selected_aggregate === 'symbol') {
        baseUrl = '/Genes/?sort=symbol&filter=';
      }
      const nextMonthFirstDay = this.getNextMonthFirstDay(d.entry_date_text);
      const dateFilter = `lessThan(entry_date,${nextMonthFirstDay})`;
      let groupFilter = '';
      if (this.selected_group === 'category') {
        groupFilter = `any(category,${d.group})`;
      } else if (
        this.selected_group === 'inheritance_filter' ||
        this.selected_group === 'inheritance_multiple'
      ) {
        const groupText = d.group
          .split(' | ')
          .map((term) => `${term} inheritance`)
          .join(',');
        groupFilter =
          this.selected_group === 'inheritance_multiple'
            ? `all(hpo_mode_of_inheritance_term_name,${groupText})`
            : `any(hpo_mode_of_inheritance_term_name,${groupText})`;
      }
      return `${baseUrl}${this.filter_string},${groupFilter},${dateFilter}`;
    },

    toggleLegendItem(item) {
      item.hidden = !item.hidden;
      const cls = item.group.replace(/[ |]/g, '_');
      d3.selectAll(`#my_dataviz .${cls}`)
        .transition()
        .duration(window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 200)
        .style('opacity', item.hidden ? '0' : '1');
    },

    generateGraph() {
      const container = document.getElementById('my_dataviz');
      if (!container) return;

      // Responsive: fill the container width
      const availableWidth = container.clientWidth || 600;

      const margin = {
        top: 20,
        right: 30,
        bottom: 50,
        left: 60,
      };
      const width = availableWidth - margin.left - margin.right;
      const height = Math.max(280, Math.min(380, availableWidth * 0.55)) - margin.top - margin.bottom;

      d3.select('#my_dataviz').select('svg').remove();
      d3.select('#my_dataviz').selectAll('.time-tooltip').remove();

      const svg = d3
        .select('#my_dataviz')
        .append('svg')
        .attr('id', 'timeplot-svg')
        .attr('viewBox', `0 0 ${width + margin.left + margin.right} ${height + margin.top + margin.bottom}`)
        .attr('preserveAspectRatio', 'xMidYMid meet')
        .style('width', '100%')
        .style('height', 'auto')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      const data = this.items.map((item) => ({
        group: item.group,
        class: item.group.replace(/[ |]/g, '_'),
        values: item.values.map((value) => ({
          group: item.group,
          cumulative_count: value.cumulative_count,
          entry_date_text: value.entry_date,
          entry_date: d3.timeParse('%Y-%m-%d')(value.entry_date),
        })),
      }));

      const allCategories = this.items.map((item) => item.group);
      const maxCount = this.itemsMeta[0]?.max_cumulative_count || 0;

      // Token-aligned ordinal scale — fallback for non-category groupings
      const fallbackScale = d3
        .scaleOrdinal()
        .domain(allCategories)
        // Use medical-blue family for inheritance groupings
        .range(['#0d47a1', '#1565c0', '#1976d2', '#2196f3', '#64b5f6', '#bbdefb']);

      const myColor = (group) => getGroupColor(group, fallbackScale);

      // Build legend items (Vue-reactive)
      this.legendItems = data.map((d) => ({
        group: d.group,
        color: myColor(d.group),
        hidden: false,
        class: d.class,
      }));

      // Y axis label
      svg
        .append('text')
        .attr('transform', 'rotate(-90)')
        .attr('y', -margin.left + 14)
        .attr('x', -height / 2)
        .attr('text-anchor', 'middle')
        .style('font-size', '12px')
        .style('fill', '#526070')
        .text(this.selected_aggregate === 'symbol' ? 'Genes (cumulative)' : 'Entities (cumulative)');

      const x = d3
        .scaleTime()
        .domain(d3.extent(data[0].values, (d) => d.entry_date))
        .range([0, width]);

      const y = d3.scaleLinear().domain([0, maxCount]).range([height, 0]);

      // X axis
      svg
        .append('g')
        .attr('transform', `translate(0,${height})`)
        .call(d3.axisBottom(x).ticks(6))
        .selectAll('text')
        .style('font-size', '12px')
        .style('fill', '#27364a');

      // Y axis
      svg
        .append('g')
        .call(d3.axisLeft(y).ticks(5))
        .selectAll('text')
        .style('font-size', '12px')
        .style('fill', '#27364a');

      // Lines
      const line = d3
        .line()
        .x((d) => x(+d.entry_date))
        .y((d) => y(+d.cumulative_count));

      svg
        .selectAll('myLines')
        .data(data)
        .join('path')
        .attr('class', (d) => d.class)
        .attr('d', (d) => line(d.values))
        .attr('stroke', (d) => myColor(d.group))
        .style('stroke-width', 2.5)
        .style('fill', 'none');

      // Styled tooltip
      const tooltip = d3
        .select('#my_dataviz')
        .append('div')
        .attr('class', 'time-tooltip')
        .style('opacity', 0)
        .style('position', 'absolute')
        .style('pointer-events', 'none')
        .style('background', '#fff')
        .style('border', '1px solid var(--border-subtle, #d9e0ea)')
        .style('border-radius', '6px')
        .style('padding', '6px 10px')
        .style('font-size', '0.8rem')
        .style('box-shadow', '0 2px 6px rgba(15,23,42,0.10)')
        .style('z-index', '20');

      const mouseover = function mouseover(_event, _d) {
        tooltip.style('opacity', 1);
        d3.select(this).attr('r', 7).style('stroke', '#172033').style('stroke-width', 2);
      };

      const mousemove = function mousemove(event, d) {
        tooltip
          .html(
            `<strong style="color:${myColor(d.group)}">${d.group}</strong><br>` +
            `<span style="font-family:var(--font-family-mono,'ui-monospace',monospace)">${d.cumulative_count.toLocaleString()}</span>` +
            ` <span style="color:#526070">as of ${d.entry_date_text}</span>`
          )
          .style('left', `${event.clientX + 14}px`)
          .style('top', `${event.clientY + 14}px`);
      };

      const mouseleave = function mouseleave(_event, _d) {
        tooltip.style('opacity', 0);
        d3.select(this).attr('r', 4).style('stroke', 'white').style('stroke-width', 1);
      };

      // Data points
      svg
        .selectAll('myDots')
        .data(data)
        .enter()
        .append('g')
        .style('fill', (d) => myColor(d.group))
        .attr('class', (d) => d.class)
        .selectAll('myPoints')
        .data((d) => d.values)
        .enter()
        .append('a')
        .attr('xlink:href', (d) => this.generateLink(d))
        .attr(
          'aria-label',
          (d) => `${d.group}: ${d.cumulative_count} entries as of ${d.entry_date_text}`
        )
        .style('text-decoration', 'none')
        .append('circle')
        .attr('cx', (d) => x(d.entry_date))
        .attr('cy', (d) => y(d.cumulative_count))
        .attr('r', 4)
        .attr('stroke', 'white')
        .style('stroke-width', 1)
        .style('fill', (d) => myColor(d.group))
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave);
    },
  },
};
</script>

<style scoped>
/* Responsive SVG */
.svg-container {
  display: block;
  width: 100%;
  overflow: visible;
}

/* Keyboard-accessible legend chips */
.legend-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 0.75rem;
  padding: 0 0.25rem;
}

.legend-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 10px 3px 6px;
  border: 1px solid var(--border-subtle, #d9e0ea);
  border-radius: 999px;
  background: #fff;
  font-size: 0.8rem;
  font-weight: 500;
  color: var(--neutral-700, #344054);
  cursor: pointer;
  transition: opacity 0.15s ease, box-shadow 0.15s ease;
  /* Use CSS custom property set per item */
  outline-offset: 2px;
}

@media (prefers-reduced-motion: reduce) {
  .legend-chip { transition: none; }
}

.legend-chip:hover {
  box-shadow: 0 1px 4px rgba(15, 23, 42, 0.12);
}

.legend-chip:focus-visible {
  outline: 2px solid var(--medical-blue-700, #0d47a1);
}

.legend-chip--hidden {
  opacity: 0.45;
  text-decoration: line-through;
}

.legend-chip-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--chip-color, #78909c);
  flex-shrink: 0;
}

/* Chart caption */
.chart-caption {
  margin: 0.4rem 0 0;
  font-size: 0.78rem;
  color: #526070;
  text-align: center;
  line-height: 1.35;
}

/* Loading skeleton */
.loading-skeleton {
  display: flex;
  flex-direction: column;
  align-items: stretch;
  padding: 0.5rem 0 1rem;
}

.skeleton-chart {
  width: 100%;
  height: 280px;
  background: linear-gradient(90deg, #f0f4f8 25%, #e2e8f0 50%, #f0f4f8 75%);
  background-size: 400% 100%;
  border-radius: 4px;
  animation: shimmer 1.5s ease-in-out infinite;
}

@media (prefers-reduced-motion: reduce) {
  .skeleton-chart {
    animation: none;
    background: #f0f4f8;
  }
}

@keyframes shimmer {
  0% { background-position: 100% 0; }
  100% { background-position: -100% 0; }
}

/* Shared state card */
.state-card {
  min-height: 180px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

/* Make BInputGroup label look like prepend text */
.input-group-text {
  background: #f4f7fa;
  border-color: var(--border-subtle, #d9e0ea);
  color: #344054;
  font-size: 0.8125rem;
  min-width: 7rem;
}

@media (max-width: 575.98px) {
  .legend-chips {
    gap: 4px;
  }

  .legend-chip {
    font-size: 0.75rem;
    padding: 2px 8px 2px 5px;
  }
}
</style>
