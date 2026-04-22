# Phase 30: Statistics Dashboard - Research

**Researched:** 2026-01-25
**Domain:** Chart.js data visualization with vue-chartjs in Vue 3 + Bootstrap
**Confidence:** HIGH

## Summary

Chart.js is the industry-standard JavaScript charting library, and vue-chartjs v5+ provides official Vue 3 wrapper components. The combination is mature, well-documented, and follows tree-shaking principles for optimal bundle size. For scientific dashboards displaying entity statistics and contributor leaderboards, the standard stack includes Chart.js v4+ with vue-chartjs v5+, using colorblind-friendly palettes (Okabe-Ito or Paul Tol Muted), and following dashboard best practices of 5-10 KPI cards positioned at the top with charts below in a responsive grid.

The critical finding: Chart.js has known responsive behavior issues with Bootstrap card/collapse layouts that require specific `maintainAspectRatio: false` configuration and proper container wrapping with explicit height constraints. The TablesEntities pattern in this codebase (using BSpinner for loading, BFormInput type="date" for date pickers, and composition API structure) provides the architectural foundation for the statistics dashboard.

**Primary recommendation:** Use Chart.js v4 + vue-chartjs v5 with tree-shaken component registration, Paul Tol Muted palette for scientific credibility, simple 3-period moving average calculation (not a library), and Bootstrap card layout with `maintainAspectRatio: false` to avoid responsive rendering bugs.

## Standard Stack

The established libraries/tools for Chart.js visualization in Vue 3:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| chart.js | ^4.4.x | Canvas-based charting engine | Industry standard, 68k+ GitHub stars, supports all common chart types |
| vue-chartjs | ^5.3.x | Vue 3 wrapper components | Official Chart.js integration for Vue 3, provides reactive components |
| @vueuse/core | ^14.1.0 | Composition utilities | Already in project, provides URL sync patterns (useUrlSearchParams) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bootstrap-vue-next | ^0.42.0 | UI components | Already in project - BCard, BSpinner, BFormInput for layout |
| @vuepic/vue-datepicker | ^9.x (optional) | Advanced date picker | Only if native `<input type="date">` proves insufficient |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| vue-chartjs | vue-chart-3 | vue-chart-3 targets Composition API but lacks official Chart.js backing |
| Chart.js | ApexCharts, ECharts | ApexCharts/ECharts bundle larger, Chart.js more established for scientific viz |
| Custom moving average lib | Built-in calculation | Simple 3-period MA doesn't warrant a dependency |

**Installation:**
```bash
npm install chart.js vue-chartjs
# chart.js is a peerDependency, must be explicitly installed
```

## Architecture Patterns

### Recommended Project Structure
```
src/views/admin/
├── AdminStatistics.vue     # Main dashboard component
└── components/
    ├── charts/
    │   ├── EntityTrendChart.vue      # Line chart for entities over time
    │   └── ContributorBarChart.vue   # Bar chart for leaderboard
    └── statistics/
        └── StatCard.vue              # Reusable KPI card component
```

### Pattern 1: Tree-Shaken Chart Registration
**What:** Chart.js v3+ requires explicit registration of controllers, elements, scales, and plugins to enable tree-shaking.
**When to use:** Every vue-chartjs component (reduces bundle size by ~30-40% vs auto-registration).
**Example:**
```typescript
// Source: https://vue-chartjs.org/guide/
import { Line } from 'vue-chartjs'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
} from 'chart.js'

// Register only what you need
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
)

export default {
  components: { Line }
}
```

**Note:** Typed chart components (Line, Bar) auto-register their controllers, so you DON'T need to register LineController or BarController manually.

### Pattern 2: Responsive Chart in Bootstrap Card
**What:** Chart.js canvas sizing with Bootstrap grid/card layout.
**When to use:** Any chart inside BCard component.
**Example:**
```vue
<!-- Source: https://www.chartjs.org/docs/latest/configuration/responsive.html -->
<template>
  <BCard>
    <div class="chart-container" style="position: relative; height: 40vh;">
      <Line :data="chartData" :options="chartOptions" />
    </div>
  </BCard>
</template>

<script setup lang="ts">
const chartOptions = {
  responsive: true,
  maintainAspectRatio: false, // CRITICAL: prevents aspect ratio bugs in cards
  plugins: {
    legend: { display: true }
  }
}
</script>
```

**Key insight:** Set `maintainAspectRatio: false` and wrap canvas in a relatively-positioned div with explicit height (vh units or pixel height). This prevents Chart.js from miscalculating dimensions inside Bootstrap flex/grid containers.

### Pattern 3: Minimal Tooltip Configuration
**What:** Simplified tooltips showing just the value for scientific clarity.
**When to use:** When user decision specifies "minimal tooltips — just the value".
**Example:**
```javascript
// Source: https://www.chartjs.org/docs/latest/configuration/tooltip.html
const options = {
  plugins: {
    tooltip: {
      callbacks: {
        label: function(context) {
          return context.parsed.y + ' entities'; // Just value + unit
        },
        title: function() {
          return ''; // Remove title if not needed
        }
      }
    }
  }
}
```

### Pattern 4: Smooth Bezier Curves
**What:** Line chart tension parameter for smooth curves.
**When to use:** Line charts where user specifies "smooth curves (Bezier)" aesthetic.
**Example:**
```javascript
// Source: https://www.chartjs3.com/blog/2024/05/18/making-your-lines-smooth-understanding-tension-in-chart-js/
const data = {
  datasets: [{
    label: 'Entity Submissions',
    data: [/* data points */],
    tension: 0.4, // 0 = straight lines, 1 = very sharp curves, 0.3-0.4 recommended
    borderColor: '#6699CC',
    fill: false
  }]
}
```

**Tension sweet spot:** 0.3-0.4 creates pleasant curves without overshooting data points.

### Pattern 5: Dashboard Layout with KPI Cards
**What:** Summary statistics cards above charts in responsive grid.
**When to use:** Admin dashboards following best practices (5-10 KPIs at top, charts below).
**Example:**
```vue
<!-- Source: Best practices synthesis from DataCamp, Tableau, Domo -->
<template>
  <BContainer fluid>
    <!-- KPI Cards Row -->
    <BRow class="mb-4">
      <BCol md="4" v-for="stat in summaryStats" :key="stat.label">
        <StatCard
          :label="stat.label"
          :value="stat.value"
          :delta="stat.delta"
          :trend="stat.trend"
        />
      </BCol>
    </BRow>

    <!-- Charts Row (stacks on mobile) -->
    <BRow>
      <BCol lg="12">
        <BCard>
          <template #header>
            <h5>Entity Submissions Over Time</h5>
          </template>
          <EntityTrendChart :data="entityData" />
        </BCard>
      </BCol>
    </BRow>

    <BRow>
      <BCol lg="12">
        <BCard>
          <template #header>
            <h5>Top Contributors</h5>
          </template>
          <ContributorBarChart :data="contributorData" />
        </BCard>
      </BCol>
    </BRow>
  </BContainer>
</template>
```

**Layout principle:** KPIs top-left (natural eye flow), charts stack vertically on small screens, 12-column on large screens for full-width visualizations.

### Pattern 6: Simple Moving Average Calculation
**What:** Client-side 3-period moving average for trend smoothing.
**When to use:** Overlaying smoothed trend line on raw data.
**Example:**
```typescript
// Simple 3-period moving average (no library needed)
function calculateMovingAverage(data: number[], period: number = 3): number[] {
  const result: number[] = [];
  for (let i = 0; i < data.length; i++) {
    if (i < period - 1) {
      result.push(null); // Not enough data for average
    } else {
      const sum = data.slice(i - period + 1, i + 1).reduce((a, b) => a + b, 0);
      result.push(sum / period);
    }
  }
  return result;
}

// Usage in chart data
const rawData = [10, 15, 13, 17, 22, 19, 25];
const smoothData = calculateMovingAverage(rawData, 3);

const chartData = {
  datasets: [
    { label: 'Actual', data: rawData, borderColor: '#6699CC' },
    { label: '3-Month MA', data: smoothData, borderColor: '#004488', borderDash: [5, 5] }
  ]
};
```

### Anti-Patterns to Avoid
- **Global Chart.js registration:** Don't use `import { registerables } from 'chart.js'; ChartJS.register(...registerables);` — bloats bundle by 30-40%.
- **Aspect ratio in cards:** Don't keep `maintainAspectRatio: true` (default) when charts are inside Bootstrap cards — causes sizing bugs.
- **Inline styles on canvas:** Don't set width/height directly on `<canvas>` — use wrapper div with relative positioning.
- **Heavy animation on large datasets:** Don't animate charts with >500 data points — set `animation: false`.
- **Too many KPIs:** Don't exceed 10 summary cards — causes cognitive overload (best practice: 5-7).

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date range validation | Custom min/max logic | HTML5 `<input type="date" min="..." max="...">` | Native validation, browser date picker, accessibility built-in |
| Chart responsiveness | Window resize listeners | Chart.js `responsive: true` + container div | Chart.js handles debouncing, canvas redraw optimization |
| Tooltip positioning | Custom hover logic | Chart.js tooltip plugin | Handles viewport edges, multi-dataset tooltips, accessibility |
| Color palette generation | Handpicked colors | Okabe-Ito or Paul Tol Muted hex codes | Scientifically validated for colorblindness (protanopia, deuteranopia, tritanopia) |
| Moving average smoothing | Complex algorithms | Simple loop with window slice | 3-period MA is 5 lines of code, libraries add unnecessary complexity |
| Chart data reactivity | Manual watchers | vue-chartjs `:data` prop | Automatically updates chart on data changes |

**Key insight:** Chart.js is a mature library (v1 released 2013, v4 in 2022) with edge cases handled. Custom chart wrappers will miss accessibility, responsiveness, and tooltip positioning logic.

## Common Pitfalls

### Pitfall 1: Chart Not Rendering in Bootstrap Card
**What goes wrong:** Chart renders as 0x0 or doesn't appear at all when placed inside `<BCard>` or `<BCol>`.
**Why it happens:** Chart.js calculates size from parent container. Bootstrap cards use flexbox which can collapse to 0 height if canvas has no intrinsic size.
**How to avoid:**
```vue
<!-- WRONG -->
<BCard>
  <Line :data="data" :options="options" />
</BCard>

<!-- CORRECT -->
<BCard>
  <div style="position: relative; height: 300px;">
    <Line :data="data" :options="{ ...options, maintainAspectRatio: false }" />
  </div>
</BCard>
```
**Warning signs:** Chart appears only after window resize, or chart has 0 height in DevTools.

**Sources:**
- https://github.com/chartjs/Chart.js/issues/11243
- https://github.com/chartjs/Chart.js/issues/6145

### Pitfall 2: Tree-Shaking Breaks Charts
**What goes wrong:** Chart renders but has no axes, tooltips don't work, or legend is missing.
**Why it happens:** Chart.js v3+ requires manual registration of all components. Forgetting to register `CategoryScale`, `LinearScale`, `Tooltip`, or `Legend` causes silent failures.
**How to avoid:** Follow checklist for each chart type:
- **Line chart:** CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend
- **Bar chart:** CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend
- **Both:** Filler if using `fill: true` for area charts

**Warning signs:** Console warning: "Category scale not registered" or tooltips don't appear on hover.

**Sources:**
- https://vue-chartjs.org/migration-guides/v4.html
- https://github.com/apertureless/vue-chartjs/issues/917

### Pitfall 3: Date Picker Confusion (Bootstrap-Vue-Next)
**What goes wrong:** Expecting `<b-form-datepicker>` from original BootstrapVue, but it doesn't exist in Bootstrap-Vue-Next.
**Why it happens:** Bootstrap-Vue-Next (Vue 3 port) hasn't implemented the datepicker component yet (as of Jan 2026).
**How to avoid:** Use native HTML5 `<BFormInput type="date">` which Bootstrap-Vue-Next supports and already used in AdminStatistics.vue:
```vue
<BFormInput v-model="startDate" type="date" />
```
For advanced needs (week picker, inline calendar), use `@vuepic/vue-datepicker` as third-party solution.

**Warning signs:** Searching docs for `b-form-datepicker` and not finding it.

**Sources:**
- https://github.com/bootstrap-vue-next/bootstrap-vue-next/issues/1860
- Existing code: app/src/views/admin/AdminStatistics.vue lines 22-25

### Pitfall 4: Performance Degradation with Large Datasets
**What goes wrong:** Charts become laggy or unresponsive with >1000 data points.
**Why it happens:** Chart.js renders every point and animates by default. For 12 months of daily data (365 points), this is fine. For 5 years of daily data (1825 points), animation + point rendering slows UI.
**How to avoid:**
```javascript
const options = {
  animation: false, // Disable for >500 points
  elements: {
    point: {
      radius: 0 // Don't render individual points on line charts
    }
  },
  parsing: false, // Provide data in internal format
  normalized: true // Indicate data is sorted and unique
}
```
For this phase (12 months, ~365 points or weekly aggregation ~52 points), performance optimizations are NOT needed.

**Warning signs:** Laggy interactions, >100ms render times in Performance tab.

**Sources:**
- https://www.chartjs.org/docs/latest/general/performance.html

### Pitfall 5: Colorblind Palette Violations
**What goes wrong:** Using red/green for trend indicators (up/down) without additional visual cues.
**Why it happens:** Designer intuition says red=bad, green=good, but 8% of males have red-green colorblindness.
**How to avoid:** Pair color with symbols:
```vue
<span :style="{ color: delta > 0 ? '#009E73' : '#D55E00' }">
  {{ delta > 0 ? '↑' : '↓' }} {{ Math.abs(delta) }}%
</span>
```
Use Okabe-Ito green (#009E73) and vermillion (#D55E00) instead of pure red/green.

**Warning signs:** Designer requests "green for up, red for down" without arrows or other visual distinction.

**Sources:**
- https://thenode.biologists.com/data-visualization-with-flying-colors/research/
- https://venngage.com/blog/color-blind-friendly-palette/

## Code Examples

Verified patterns from official sources:

### Complete Line Chart Component (Entity Trend)
```vue
<!-- Source: https://vue-chartjs.org/guide/ + CONTEXT decisions -->
<template>
  <div class="chart-wrapper" style="position: relative; height: 400px;">
    <BSpinner v-if="loading" label="Loading chart..." class="position-absolute top-50 start-50" />
    <Line v-else :data="chartData" :options="chartOptions" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
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
  Filler
} from 'chart.js';

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

interface Props {
  entityData: Array<{ date: string; count: number }>;
  loading?: boolean;
}

const props = defineProps<Props>();

// Paul Tol Muted palette
const COLORS = {
  primary: '#6699CC',   // Muted blue
  secondary: '#004488', // Dark blue
  accent: '#EECC66'     // Muted yellow
};

const chartData = computed(() => ({
  labels: props.entityData.map(d => d.date),
  datasets: [
    {
      label: 'Entities',
      data: props.entityData.map(d => d.count),
      borderColor: COLORS.primary,
      backgroundColor: COLORS.primary + '20', // 20 = 12% opacity
      tension: 0.4, // Smooth Bezier curves
      fill: true,
      pointRadius: 3,
      pointHoverRadius: 5
    }
  ]
}));

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false }, // Hide if single dataset
    tooltip: {
      callbacks: {
        label: (context) => `${context.parsed.y} entities`
      }
    }
  },
  scales: {
    y: {
      beginAtZero: true,
      ticks: { precision: 0 } // Integer counts only
    }
  }
};
</script>
```

### Complete Bar Chart Component (Contributor Leaderboard)
```vue
<!-- Source: https://vue-chartjs.org/guide/ + CONTEXT decisions -->
<template>
  <div class="chart-wrapper" style="position: relative; height: 350px;">
    <BSpinner v-if="loading" label="Loading chart..." class="position-absolute top-50 start-50" />
    <Bar v-else :data="chartData" :options="chartOptions" />
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
  Legend
} from 'chart.js';

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

interface Contributor {
  user_name: string;
  entity_count: number;
}

interface Props {
  contributors: Contributor[];
  loading?: boolean;
}

const props = defineProps<Props>();

const COLORS = {
  bar: '#6699CC', // Paul Tol Muted blue
};

const chartData = computed(() => ({
  labels: props.contributors.map(c => c.user_name),
  datasets: [
    {
      label: 'Entities',
      data: props.contributors.map(c => c.entity_count),
      backgroundColor: COLORS.bar,
      borderColor: COLORS.bar,
      borderWidth: 1
    }
  ]
}));

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  indexAxis: 'y', // Horizontal bars for easier name reading
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (context) => `${context.parsed.x} entities`
      }
    }
  },
  scales: {
    x: {
      beginAtZero: true,
      ticks: { precision: 0 }
    }
  }
};
</script>
```

### KPI Stat Card Component
```vue
<!-- Source: Dashboard best practices synthesis -->
<template>
  <BCard class="stat-card h-100">
    <div class="d-flex justify-content-between align-items-start">
      <div>
        <div class="text-muted small">{{ label }}</div>
        <div class="display-6 fw-bold">{{ formattedValue }}</div>
      </div>
      <div v-if="delta !== undefined" class="text-end">
        <span :style="{ color: trendColor }">
          {{ trendIcon }} {{ Math.abs(delta) }}%
        </span>
      </div>
    </div>
    <div v-if="context" class="small text-muted mt-2">{{ context }}</div>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';

interface Props {
  label: string;
  value: number;
  delta?: number; // Percentage change vs previous period
  context?: string; // "vs last month"
  unit?: string;
}

const props = defineProps<Props>();

// Okabe-Ito colorblind-safe colors
const TREND_COLORS = {
  up: '#009E73',    // Bluish green
  down: '#D55E00',  // Vermillion
  neutral: '#666666'
};

const formattedValue = computed(() => {
  return props.unit
    ? `${props.value.toLocaleString()} ${props.unit}`
    : props.value.toLocaleString();
});

const trendIcon = computed(() => {
  if (props.delta === undefined) return '';
  return props.delta > 0 ? '↑' : props.delta < 0 ? '↓' : '→';
});

const trendColor = computed(() => {
  if (props.delta === undefined) return TREND_COLORS.neutral;
  return props.delta > 0 ? TREND_COLORS.up : TREND_COLORS.down;
});
</script>

<style scoped>
.stat-card {
  border-left: 4px solid #6699CC;
}
</style>
```

### Moving Average with Dual Dataset
```typescript
// Source: Simple algorithm, no library needed
function calculateSMA(data: number[], period: number = 3): (number | null)[] {
  return data.map((_, idx, arr) => {
    if (idx < period - 1) return null;
    const window = arr.slice(idx - period + 1, idx + 1);
    return window.reduce((sum, val) => sum + val, 0) / period;
  });
}

// Usage in chart data
const rawCounts = [45, 52, 48, 60, 55, 63, 58, 67, 71, 68, 75, 72];
const smoothCounts = calculateSMA(rawCounts, 3);

const chartData = {
  labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  datasets: [
    {
      label: 'Monthly Entities',
      data: rawCounts,
      borderColor: '#6699CC',
      backgroundColor: '#6699CC20',
      fill: true,
      tension: 0.4
    },
    {
      label: '3-Month Moving Avg',
      data: smoothCounts,
      borderColor: '#004488',
      borderDash: [5, 5],
      fill: false,
      pointRadius: 0, // No points for trend line
      tension: 0.4
    }
  ]
};
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global Chart.js import | Tree-shaken registration | Chart.js v3 (2021) | Bundle size reduction: ~120KB → ~50KB gzipped |
| vue-chartjs v3 mixins | vue-chartjs v4+ components | v4 release (2021) | Composition API support, better TypeScript |
| BootstrapVue `<b-form-datepicker>` | HTML5 `<input type="date">` | Bootstrap-Vue-Next (Vue 3 port) | Native date picker, no component library needed |
| Aspect ratio auto-adjust | `maintainAspectRatio: false` in cards | Ongoing bug reports | Required for Bootstrap grid compatibility |
| Red/green trend colors | Okabe-Ito palette + symbols | Accessibility focus (2020+) | 8% male population can now distinguish trends |

**Deprecated/outdated:**
- **vue-chartjs v3 mixins:** Replaced by v4+ component-based API in 2021. Don't use `extends` pattern.
- **Chart.registerables auto-import:** Bloats bundle. Use tree-shaken imports since Chart.js v3.
- **`<b-form-datepicker>` (BootstrapVue):** Not available in Bootstrap-Vue-Next. Use `<BFormInput type="date">`.

## Open Questions

Things that couldn't be fully resolved:

1. **API endpoint structure for statistics data**
   - What we know: Existing endpoints at `/api/statistics/updates`, `/api/statistics/rereview` return date-ranged data
   - What's unclear: Whether new endpoints for entity timeseries and contributor leaderboard follow same pattern or are already implemented
   - Recommendation: Check backend API docs during planning, assume similar structure: `/api/statistics/entity_timeline?start_date=X&end_date=Y&granularity=monthly`

2. **Comparison period for trend percentage**
   - What we know: User wants "↑ 12% vs last period" with configurable comparison period
   - What's unclear: Whether "last period" means previous time range of equal length (if viewing Jan-Mar, compare to Oct-Dec) or previous calendar period (Q1 vs Q4)
   - Recommendation: Default to equal-length comparison (simpler logic), add toggle for "vs previous month/quarter/year" if time allows

3. **Date picker library necessity**
   - What we know: Native `<input type="date">` works and is already used in AdminStatistics.vue
   - What's unclear: Whether custom date range (user decision: "full date picker") implies advanced features (preset ranges, inline calendar) that native picker can't provide
   - Recommendation: Start with native HTML5 date inputs (0 dependencies), upgrade to @vuepic/vue-datepicker only if user feedback requests preset ranges

4. **Leaderboard clickable links implementation**
   - What we know: User wants "leaderboard names link to user profile"
   - What's unclear: Whether user profile pages exist in current app, and what route structure to use
   - Recommendation: During planning, grep for existing user profile routes; if none exist, defer clickable links to future phase

## Sources

### Primary (HIGH confidence)
- **vue-chartjs official docs** - https://vue-chartjs.org/guide/ - Installation, component usage, tree-shaking
- **Chart.js official docs** - https://www.chartjs.org/docs/latest/ - Responsive config, tooltips, performance
- **Chart.js responsive config** - https://www.chartjs.org/docs/latest/configuration/responsive.html - maintainAspectRatio, container setup
- **Paul Tol color schemes** - https://personal.sron.nl/~pault/ - Muted palette hex codes
- **Okabe-Ito palette** - Multiple academic sources - Standard colorblind-safe palette

### Secondary (MEDIUM confidence)
- **vue-chartjs npm** - https://www.npmjs.com/package/vue-chartjs - Latest version 5.3.3 confirmed
- **Dashboard design best practices** - DataCamp, Tableau, Domo articles (2026) - KPI card layout, 5-10 metric limit
- **Bootstrap-Vue-Next datepicker status** - https://github.com/bootstrap-vue-next/bootstrap-vue-next/issues/1860 - Component not yet implemented
- **Chart.js tension curves** - https://www.chartjs3.com/blog/2024/05/18/making-your-lines-smooth-understanding-tension-in-chart-js/ - Bezier curve smoothing

### Tertiary (LOW confidence)
- **Chart.js Bootstrap issues** - GitHub issues #11243, #6145 - Responsive behavior pitfalls (reported but not all resolved)
- **Moving average implementations** - Various GitHub gists and Medium articles - Simple algorithms validated through multiple sources

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - Chart.js + vue-chartjs is official, well-documented, widely adopted
- Architecture: **HIGH** - Official docs provide clear patterns, existing codebase (TablesEntities) establishes conventions
- Pitfalls: **MEDIUM** - Bootstrap card responsiveness issue well-documented but workarounds are community-driven
- Color palettes: **HIGH** - Okabe-Ito and Paul Tol are scientifically published and peer-reviewed
- Dashboard layout: **MEDIUM** - Best practices synthesized from multiple professional sources but not scientific consensus

**Research date:** 2026-01-25
**Valid until:** ~90 days (April 2026) - Chart.js is stable (v4 since 2022), vue-chartjs v5 mature, color science unlikely to change
