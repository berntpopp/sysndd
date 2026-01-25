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

// Paul Tol Muted palette for scientific credibility
const COLORS = {
  primary: '#6699CC', // Muted blue
  secondary: '#004488', // Dark blue for MA line
};

interface EntityDataPoint {
  date: string;
  count: number;
}

interface Props {
  entityData: EntityDataPoint[];
  loading?: boolean;
  showMovingAverage?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  showMovingAverage: false,
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
  const labels = props.entityData.map((d) => d.date);
  const rawData = props.entityData.map((d) => d.count);

  const datasets = [
    {
      label: 'Entities',
      data: rawData,
      borderColor: COLORS.primary,
      backgroundColor: COLORS.primary + '20', // 12% opacity
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
      borderColor: COLORS.secondary,
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

const chartOptions: ChartOptions<'line'> = {
  responsive: true,
  maintainAspectRatio: false, // Critical for Bootstrap card compatibility
  plugins: {
    legend: {
      display: true,
      position: 'top',
    },
    tooltip: {
      callbacks: {
        label: (context) => `${context.parsed.y} entities`,
      },
    },
  },
  scales: {
    y: {
      beginAtZero: true,
      ticks: {
        precision: 0, // Integer counts only
      },
    },
  },
};
</script>
