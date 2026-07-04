<!-- src/components/analyses/CurationSourcesPopover.vue -->
<!--
  Provenance panel for the curation-comparison table. Populated from
  /api/comparisons/sources (the live comparisons_config registry + the derived
  OMIM-NDD source) so the source URLs and last-updated dates stay in sync with
  the API instead of hardcoded, drift-prone text. Binds to the help badge in the
  parent via the shared `target` id.
-->
<template>
  <BPopover target="popover-badge-help-comparisons" variant="info" triggers="focus">
    <template #title>
      Comparisons selection
      <span v-if="lastUpdate">[last update {{ formatDate(lastUpdate) }}]</span>
    </template>
    <template v-if="sources.length">
      The NDD databases and lists for the comparison with SysNDD are:
      <br />
      <template v-for="(src, idx) in sources" :key="src.name">
        <strong>{{ idx + 1 }}) {{ src.label }}</strong>
        <template v-if="src.description"> {{ src.description }}</template>
        <template v-else-if="src.url">
          downloaded and normalized from
          <a :href="src.url" target="_blank" rel="noopener noreferrer">{{ src.url }}</a>
        </template>
        <span v-if="src.last_updated" class="text-muted">
          [updated {{ formatDate(src.last_updated) }}]</span
        >,
        <br />
      </template>
    </template>
    <template v-else> Loading comparison source information… </template>
  </BPopover>
</template>

<script>
import { getComparisonsSources } from '@/api/comparisons';

export default {
  name: 'CurationSourcesPopover',
  data() {
    return {
      sources: [],
      lastUpdate: null,
    };
  },
  async mounted() {
    try {
      const { sources, last_full_refresh: lastFullRefresh } = await getComparisonsSources();
      this.sources = sources;
      // Prefer the last full-refresh date; fall back to the newest per-source date.
      this.lastUpdate =
        lastFullRefresh ||
        sources
          .map((s) => s.last_updated)
          .filter((d) => Boolean(d))
          .sort()
          .pop() ||
        null;
    } catch {
      // Non-fatal: the provenance panel is informational.
      this.sources = [];
      this.lastUpdate = null;
    }
  },
  methods: {
    formatDate(value) {
      // Values are "YYYY-MM-DD" or "YYYY-MM-DD HH:MM:SS"; show the date part.
      return value ? value.slice(0, 10) : '';
    },
  },
};
</script>
