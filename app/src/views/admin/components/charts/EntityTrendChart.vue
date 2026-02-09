<template>
  <div class="chart-wrapper" style="position: relative; height: 400px">
    <BSpinner
      v-if="loading"
      label="Loading chart..."
      class="position-absolute top-50 start-50 translate-middle"
    />
    <Line v-else :data="chartData" :options="chartOptions" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Line } from 'vue-chartjs';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
  type ChartOptions,
} from 'chart.js';
import { BSpinner } from 'bootstrap-vue-next';
import { CHART_PRIMARY, CHART_SECONDARY, CATEGORY_COLORS } from '@/utils/chartColors';

// Tree-shaken Chart.js registration
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

interface EntityDataPoint {
  date: string;
  count: number;
}

interface CategorySeriesData {
  dates: string[];
  series: Record<string, number[]>;
}

interface Props {
  entityData: EntityDataPoint[];
  categoryData?: CategorySeriesData;
  displayMode?: 'combined' | 'by_category';
  loading?: boolean;
  showMovingAverage?: boolean;
  yMax?: number;
}

const props = withDefaults(defineProps<Props>(), {
  categoryData: undefined,
  displayMode: 'combined',
  loading: false,
  showMovingAverage: false,
  yMax: undefined,
});

/**
 * Calculate Simple Moving Average (SMA)
 * Returns null for positions with insufficient data
 */
function calculateSMA(data: number[], period: number = 3): (number | null)[] {
  return data.map((_, idx, arr) => {
    if (idx < period - 1) return null;
    const window = arr.slice(idx - period + 1, idx + 1);
    return window.reduce((sum, val) => sum + val, 0) / period;
  });
}

const chartData = computed(() => {
  if (
    props.displayMode === 'by_category' &&
    props.categoryData &&
    props.categoryData.dates.length > 0
  ) {
    const labels = props.categoryData.dates;
    const datasets = Object.entries(props.categoryData.series).map(([group, values]) => {
      const color = CATEGORY_COLORS[group] ?? CHART_PRIMARY;
      return {
        label: group,
        data: values,
        borderColor: color,
        backgroundColor: color + '20',
        tension: 0.4,
        fill: false,
        pointRadius: 3,
        pointHoverRadius: 5,
      };
    });

    return { labels, datasets };
  }

  // Combined mode (default)
  const labels = props.entityData.map((d) => d.date);
  const rawData = props.entityData.map((d) => d.count);

  const datasets = [
    {
      label: 'Entities',
      data: rawData,
      borderColor: CHART_PRIMARY,
      backgroundColor: CHART_PRIMARY + '20', // 12% opacity
      tension: 0.4, // Smooth Bezier curves
      fill: true,
      pointRadius: 3,
      pointHoverRadius: 5,
    },
  ];

  // Add moving average line if enabled
  if (props.showMovingAverage && rawData.length >= 3) {
    datasets.push({
      label: '3-Period Moving Avg',
      data: calculateSMA(rawData, 3) as number[],
      borderColor: CHART_SECONDARY,
      backgroundColor: 'transparent',
      tension: 0.4,
      fill: false,
      pointRadius: 0, // No points for trend line
      pointHoverRadius: 0,
      borderDash: [5, 5],
    } as (typeof datasets)[0]);
  }

  return { labels, datasets };
});

const chartOptions = computed<ChartOptions<'line'>>(() => ({
  responsive: true,
  maintainAspectRatio: false, // Critical for Bootstrap card compatibility
  plugins: {
    legend: {
      display: true,
      position: 'top',
    },
    tooltip: {
      callbacks: {
        label: (context) => `${context.dataset.label}: ${context.parsed.y} entities`,
      },
    },
  },
  scales: {
    y: {
      beginAtZero: true,
      suggestedMax: props.yMax,
      ticks: {
        precision: 0, // Integer counts only
      },
    },
  },
}));
</script>
