<!-- src/components/analyses/PublicationsNDDStats.vue -->
<template>
  <BContainer fluid>
    <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            NDD Publications Statistics
            <mark
              v-b-tooltip.hover.leftbottom
              title="Shows aggregated counts for journals, authors, or keywords, from the publication_stats endpoint."
            >
              (Bar Plots)
            </mark>
            <BBadge id="popover-badge-help-publications-stats" pill href="#" variant="info">
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover
              target="popover-badge-help-publications-stats"
              variant="info"
              triggers="focus"
            >
              <template #title> Publications Statistics </template>
              This bar chart displays counts for selected categories (journal, author/lastname, or
              keywords).
            </BPopover>
          </h6>
        </div>
      </template>

      <!-- Metrics Cards Row - Loading skeleton -->
      <BRow v-if="loadingCount" class="mb-3 px-2">
        <BCol v-for="n in 4" :key="n" sm="6" md="3" class="mb-2">
          <BCard class="h-100 text-center">
            <BSpinner small label="Loading..." />
          </BCard>
        </BCol>
      </BRow>

      <!-- Metrics Cards Row - Loaded -->
      <BRow v-if="!loadingCount && statsData" class="mb-3 px-2">
        <BCol v-for="(card, index) in metricsCards" :key="index" sm="6" md="3" class="mb-2">
          <BCard :border-variant="card.variant" class="h-100 text-center metrics-card">
            <div class="d-flex flex-column align-items-center">
              <i :class="['bi', card.icon, 'fs-3', `text-${card.variant}`]" />
              <h6 class="mt-2 mb-1 text-muted">{{ card.title }}</h6>
              <h4 class="mb-0">{{ card.value }}</h4>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- User Interface controls: category selection and min count filter -->
      <BRow>
        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Category" class="mb-1" size="sm">
            <BFormSelect
              v-model="selectedCategory"
              :options="categoryOptions"
              size="sm"
              @change="generateBarPlot"
            />
          </BInputGroup>
        </BCol>

        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Min Count" class="mb-1" size="sm">
            <BFormInput
              v-model.number="minCount"
              type="number"
              min="1"
              step="1"
              debounce="300"
              @update:model-value="generateBarPlot"
            />
          </BInputGroup>
        </BCol>

        <BCol class="my-1" sm="4">
          <small class="text-muted">
            Showing {{ filteredItemCount }} items ({{ filteredPublicationCount.toLocaleString() }} pubs)
          </small>
        </BCol>
      </BRow>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <BSpinner v-if="loadingCount" label="Loading..." class="spinner" />
        <div v-show="!loadingCount" id="stats_dataviz" class="svg-container" />
      </div>
    </BCard>
  </BContainer>
</template>

<script>
import * as d3 from 'd3';
import useToast from '@/composables/useToast';

export default {
  name: 'PublicationsNDDStats',
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
  data() {
    return {
      // user selections
      selectedCategory: 'journal', // 'journal' | 'author' | 'keyword'
      categoryOptions: [
        { value: 'journal', text: 'Journal' },
        { value: 'author', text: 'Author (Lastname)' },
        { value: 'keyword', text: 'Keywords' },
      ],

      // Client-side minimum count filter (applies to bar chart)
      minCount: 20,

      // API-level filters (set low to fetch more data, filter client-side)
      min_journal_count: 5,
      min_lastname_count: 2,
      min_keyword_count: 10,

      // data from the stats endpoint
      statsData: null,

      // actual newest publication date (fetched separately)
      newestPublicationDate: null,

      // chart loading state
      loadingCount: true,
    };
  },
  computed: {
    /**
     * metricsCards
     * Computes summary metrics for display in cards above the chart
     * @returns {Array} - Array of card configuration objects
     */
    metricsCards() {
      if (!this.statsData) return [];

      const pubDates = this.statsData.publication_date_aggregated || [];
      const currentYear = new Date().getFullYear();

      // Publications this year (YTD)
      const thisYearPubs = pubDates
        .filter((d) => d.Publication_date && d.Publication_date.startsWith(String(currentYear)))
        .reduce((sum, d) => sum + d.count, 0);

      // 5-Year Average (last 5 complete years: currentYear-6 to currentYear-2)
      // More meaningful than YoY which shows -100% at start of year
      // Excludes current year AND previous year (which may be incomplete if early in year)
      const lastCompleteYear = currentYear - 1;
      const fiveYearData = pubDates.filter((d) => {
        if (!d.Publication_date) return false;
        const year = parseInt(d.Publication_date.substring(0, 4), 10);
        return year >= lastCompleteYear - 4 && year <= lastCompleteYear;
      });
      const yearsWithData = fiveYearData.length;
      const fiveYearTotal = fiveYearData.reduce((sum, d) => sum + d.count, 0);
      const fiveYearAvg = yearsWithData > 0 ? Math.round(fiveYearTotal / yearsWithData) : 0;

      // Total publications
      const totalPubs = pubDates.reduce((sum, d) => sum + d.count, 0);

      // Newest publication date (from separate API call, not aggregated data)
      const newestDate = this.newestPublicationDate || 'N/A';

      return [
        {
          title: 'Total Publications',
          value: totalPubs.toLocaleString(),
          icon: 'bi-journal-text',
          variant: 'primary',
        },
        {
          title: `Publications ${currentYear} (YTD)`,
          value: thisYearPubs.toLocaleString(),
          icon: 'bi-calendar-event',
          variant: 'success',
        },
        {
          title: '5-Year Avg',
          value: fiveYearAvg > 0 ? `${fiveYearAvg}/yr` : 'N/A',
          icon: 'bi-bar-chart-line',
          variant: 'secondary',
        },
        {
          title: 'Newest Publication',
          value: newestDate,
          icon: 'bi-clock-history',
          variant: 'info',
        },
      ];
    },
    /**
     * Get the raw data array for the currently selected category
     */
    currentCategoryData() {
      if (!this.statsData) return [];
      if (this.selectedCategory === 'journal') {
        return this.statsData.journal_counts || [];
      } else if (this.selectedCategory === 'author') {
        return this.statsData.last_name_counts || [];
      } else if (this.selectedCategory === 'keyword') {
        return this.statsData.keyword_counts || [];
      }
      return [];
    },
    /**
     * Number of items shown after applying minCount filter
     */
    filteredItemCount() {
      return this.currentCategoryData.filter((d) => d.count >= this.minCount).length;
    },
    /**
     * Total publications in filtered items
     */
    filteredPublicationCount() {
      return this.currentCategoryData
        .filter((d) => d.count >= this.minCount)
        .reduce((sum, d) => sum + d.count, 0);
    },
  },
  async mounted() {
    // fetch stats and newest publication date on mount
    await Promise.all([this.fetchStats(), this.fetchNewestPublicationDate()]);
  },
  methods: {
    /**
     * fetchStats
     * Calls /api/statistics/publication_stats with the user’s selected min counts
     */
    async fetchStats() {
      this.loadingCount = true;

      // build query string
      const baseUrl = `${import.meta.env.VITE_API_URL}/api/statistics/publication_stats`;
      const params = new URLSearchParams();
      params.set('min_journal_count', this.min_journal_count);
      params.set('min_lastname_count', this.min_lastname_count);
      params.set('min_keyword_count', this.min_keyword_count);
      params.set('time_aggregate', 'year'); // or let them pick 'month' in future

      const apiUrl = `${baseUrl}?${params.toString()}`;

      try {
        const response = await this.axios.get(apiUrl);
        // store entire object in statsData
        this.statsData = response.data;
        // once loaded, generate bar chart
        this.generateBarPlot();
      } catch (error) {
        this.makeToast(error, 'Error fetching publication stats', 'danger');
      } finally {
        this.loadingCount = false;
      }
    },

    /**
     * fetchNewestPublicationDate
     * Fetches the actual newest publication date by querying publications sorted by date descending
     */
    async fetchNewestPublicationDate() {
      const baseUrl = `${import.meta.env.VITE_API_URL}/api/publication`;
      const params = new URLSearchParams();
      params.set('sort', '-Publication_date');
      params.set('page_size', '1');
      params.set('fields', 'publication_id,Publication_date');

      const apiUrl = `${baseUrl}?${params.toString()}`;

      try {
        const response = await this.axios.get(apiUrl);
        if (response.data?.data?.length > 0) {
          const pubDate = response.data.data[0].Publication_date;
          // Format the date for display (YYYY-MM-DD)
          this.newestPublicationDate = pubDate || 'N/A';
        }
      } catch (error) {
        // Silently fail - the card will show 'N/A'
        console.warn('Failed to fetch newest publication date:', error);
      }
    },

    /**
     * generateBarPlot
     * Builds a bar chart from either journal_counts, last_name_counts, or keyword_counts
     * depending on selectedCategory.
     */
    generateBarPlot() {
      // guard if statsData not loaded
      if (!this.statsData) return;

      // remove old svg, tooltips, and empty messages to prevent duplicates
      d3.select('#stats_dataviz').select('svg').remove();
      d3.select('#stats_dataviz').selectAll('.tooltip').remove();
      d3.select('#stats_dataviz').selectAll('div').remove();

      let data = [];
      let xKey = ''; // 'Journal', 'Lastname', or 'Keywords'

      if (this.selectedCategory === 'journal') {
        data = this.statsData.journal_counts || [];
        xKey = 'Journal';
      } else if (this.selectedCategory === 'author') {
        data = this.statsData.last_name_counts || [];
        xKey = 'Lastname';
      } else if (this.selectedCategory === 'keyword') {
        data = this.statsData.keyword_counts || [];
        xKey = 'Keywords';
      }

      // Apply client-side minimum count filter
      data = data.filter((d) => d.count >= this.minCount);

      // Handle empty data after filtering
      if (data.length === 0) {
        d3.select('#stats_dataviz')
          .append('div')
          .attr('class', 'text-center text-muted py-5')
          .html(`<i class="bi bi-info-circle me-2"></i>No items with count ≥ ${this.minCount}. Try lowering the minimum.`);
        return;
      }

      // set dimensions
      const margin = {
        top: 30,
        right: 30,
        bottom: 200,
        left: 130,
      };
      const width = 760 - margin.left - margin.right;
      const height = 500 - margin.top - margin.bottom;

      // append the SVG
      const svg = d3
        .select('#stats_dataviz')
        .append('svg')
        .attr('id', 'pubstats-svg') // optional for referencing in downloads
        .attr('viewBox', '0 0 760 500')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      // X axis
      const x = d3
        .scaleBand()
        .range([0, width])
        .domain(data.map((d) => d[xKey]))
        .padding(0.2);

      svg
        .append('g')
        .attr('transform', `translate(0,${height})`)
        .call(d3.axisBottom(x))
        .selectAll('text')
        .attr('transform', 'translate(-10,0)rotate(-45)')
        .style('text-anchor', 'end')
        .style('font-size', '12px');

      // max count
      const maxY = d3.max(data, (d) => d.count);
      const y = d3
        .scaleLinear()
        .domain([0, maxY * 1.1])
        .range([height, 0]);
      svg.append('g').call(d3.axisLeft(y));

      // Create a tooltip element with improved styling
      const tooltip = d3
        .select('#stats_dataviz')
        .append('div')
        .style('opacity', 0)
        .attr('class', 'tooltip')
        .style('background-color', 'white')
        .style('border', 'solid 1px #ccc')
        .style('border-radius', '5px')
        .style('padding', '8px')
        .style('position', 'absolute')
        .style('pointer-events', 'none')
        .style('font-size', '0.85rem')
        .style('box-shadow', '0 2px 4px rgba(0,0,0,0.1)');

      /**
       * Mouseover event handler to display tooltip.
       */
      const mouseover = function mouseover() {
        tooltip.style('opacity', 1);
        d3.select(this).style('stroke', 'black').style('opacity', 1);
      };

      /**
       * Mousemove event handler to move the tooltip with the mouse.
       */
      const mousemove = function mousemove(event, d) {
        // Using event.layerX and event.layerY to position near the cursor
        // offset by +20 so it doesn't overlap the cursor
        tooltip
          .html(
            `<strong>${d[xKey]}</strong><br/>` +
              `Count: <strong>${d.count.toLocaleString()}</strong>`
          )
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      };

      /**
       * Mouseleave event handler to hide the tooltip.
       */
      const mouseleave = function mouseleave() {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'none');
      };

      // bars
      svg
        .selectAll('mybar')
        .data(data)
        .enter()
        .append('rect')
        .attr('x', (d) => x(d[xKey]))
        .attr('y', (d) => y(d.count))
        .attr('width', x.bandwidth())
        .attr('height', (d) => height - y(d.count))
        .attr('fill', '#69b3a2')
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave);
    },
  },
};
</script>

<style scoped>
.svg-container {
  display: inline-block;
  position: relative;
  width: 100%;
  max-width: 900px;
  vertical-align: top;
  overflow: hidden;
}
.svg-container svg {
  display: inline-block;
  position: absolute;
  top: 0;
  left: 0;
}
.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}
/* tooltip style consistent with your AnalysesPhenotypeCounts.vue */
.tooltip {
  pointer-events: none;
  font-size: 0.9rem;
}
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
/* Metrics card styling */
.metrics-card {
  transition: transform 0.2s ease;
}
.metrics-card:hover {
  transform: translateY(-2px);
}
</style>
