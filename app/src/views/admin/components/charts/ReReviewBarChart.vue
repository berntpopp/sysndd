<template>
  <div class="chart-wrapper" style="position: relative; height: 350px">
    <BSpinner
      v-if="loading"
      label="Loading chart..."
      class="position-absolute top-50 start-50 translate-middle"
    />
    <p
      v-else-if="isEmpty"
      class="text-muted text-center position-absolute top-50 start-50 translate-middle mb-0"
      data-testid="rereview-bar-empty"
    >
      No re-review data for the selected period.
    </p>
    <Bar v-else :data="chartData" :options="chartOptions" role="img" :aria-label="ariaLabel" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Bar } from 'vue-chartjs';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  type ChartOptions,
} from 'chart.js';
import { BSpinner } from 'bootstrap-vue-next';
import { REVIEW_STATUS_COLORS } from '@/utils/chartColors';

// Tree-shaken Chart.js registration
ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

interface Reviewer {
  user_name: string;
  total_assigned: number;
  submitted_count: number;
  approved_count: number;
}

interface Props {
  reviewers: Reviewer[];
  loading?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
});

const isEmpty = computed(() => props.reviewers.length === 0);

const ariaLabel = computed(() => {
  const top = props.reviewers[0];
  return top
    ? `Top re-reviewers by submitted re-reviews, ${props.reviewers.length} reviewers, leader ${top.user_name} with ${top.approved_count} approved of ${top.submitted_count} submitted.`
    : 'Top re-reviewers by submitted re-reviews, no data.';
});

const chartData = computed(() => ({
  labels: props.reviewers.map((r) => r.user_name),
  datasets: [
    {
      label: 'Approved',
      data: props.reviewers.map((r) => r.approved_count),
      backgroundColor: REVIEW_STATUS_COLORS.approved,
      borderColor: REVIEW_STATUS_COLORS.approved,
      borderWidth: 1,
    },
    {
      label: 'Pending Review',
      data: props.reviewers.map((r) => Math.max(0, r.submitted_count - r.approved_count)),
      backgroundColor: REVIEW_STATUS_COLORS.submitted,
      borderColor: REVIEW_STATUS_COLORS.submitted,
      borderWidth: 1,
    },
    {
      label: 'Not Yet Submitted',
      data: props.reviewers.map((r) => Math.max(0, r.total_assigned - r.submitted_count)),
      backgroundColor: REVIEW_STATUS_COLORS.notSubmitted,
      borderColor: REVIEW_STATUS_COLORS.notSubmitted,
      borderWidth: 1,
    },
  ],
}));

const chartOptions: ChartOptions<'bar'> = {
  responsive: true,
  maintainAspectRatio: false,
  indexAxis: 'y', // Horizontal bars for easier name reading
  plugins: {
    legend: {
      display: true,
      position: 'bottom',
    },
    tooltip: {
      callbacks: {
        label: (context) => `${context.dataset.label}: ${context.parsed.x} re-reviews`,
      },
    },
  },
  scales: {
    x: {
      stacked: true,
      beginAtZero: true,
      ticks: {
        precision: 0,
      },
    },
    y: {
      stacked: true,
    },
  },
};
</script>
