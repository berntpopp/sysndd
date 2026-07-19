<!-- src/components/analyses/EvidenceTierMappingHelp.vue -->
<!--
  Keyboard-accessible tier-mapping help affordance for the Curation Comparisons
  page (issue #586). Fetches GET /api/comparisons/crosswalk and renders the
  normalized four-tier scale, policy notes, and mapping version FROM the API
  payload — never hard-coded tier copy — so the display can never drift from the
  executable normalizer. The only local copy is the neutral failure message.

  The popover is click/keyboard-activated (BootstrapVueNext boolean trigger
  props + v-model, no `triggers` string); Escape closes it and restores focus to
  the badge, and the crosswalk link inside is Tab-reachable.
-->
<template>
  <span class="tier-mapping-help">
    <InlineHelpBadge
      id="popover-badge-tier-mapping"
      ref="badge"
      aria-label="Explain normalized evidence-tier mapping"
      aria-haspopup="dialog"
      :aria-expanded="open ? 'true' : 'false'"
      @click="activate"
    />
    <!-- BVN boolean trigger props (no `triggers` string prop); v-model-driven so
         we can close on Escape and restore focus deterministically. -->
    <BPopover
      v-model="open"
      target="popover-badge-tier-mapping"
      variant="info"
      :click="true"
      :focus="false"
      :hover="false"
    >
      <template #title>Normalized evidence tiers</template>
      <!-- role="dialog" (with a label) matches the badge's aria-haspopup="dialog"
           and gives the focusable crosswalk link a labeled interactive container,
           rather than BVN's default role="tooltip". -->
      <div
        role="dialog"
        aria-label="Normalized evidence-tier mapping"
        @keydown.esc.stop.prevent="close"
      >
        <div v-if="crosswalk">
          <ul class="mb-2 ps-3 small">
            <li v-for="t in crosswalk.tiers" :key="t.tier">
              <strong>{{ t.tier }}</strong>: {{ t.definition }}
            </li>
          </ul>
          <ul class="mb-2 ps-3 small text-muted">
            <li v-for="(n, i) in crosswalk.notes" :key="i">{{ n }}</li>
          </ul>
          <p class="mb-1 small">
            Mapping version: <code>{{ crosswalk.mapping_version }}</code>
          </p>
          <a
            class="crosswalk-link"
            :href="crosswalkUrl"
            target="_blank"
            rel="noopener noreferrer"
          >
            View the complete mapping crosswalk
          </a>
        </div>
        <div v-else-if="failed" class="small text-muted">
          Mapping information is unavailable.
        </div>
        <div v-else class="small text-muted">Loading&hellip;</div>
      </div>
    </BPopover>
  </span>
</template>

<script>
// The configured axios singleton (baseURL set by the plugin from VITE_BASE_URL).
// Imported via the plugin re-export rather than the raw 'axios' package so the
// typed-API-boundary lint rule (no default 'axios' import in components) holds;
// there is no API_URL export to read the base URL from. Only used to read
// `defaults.baseURL` for the external crosswalk link href (no HTTP verbs here).
import axios from '@/plugins/axios';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import { getComparisonsCrosswalk } from '@/api/comparisons';

export default {
  name: 'EvidenceTierMappingHelp',
  components: { InlineHelpBadge },
  data() {
    return { crosswalk: null, failed: false, open: false };
  },
  computed: {
    crosswalkUrl() {
      // Base URL from the axios singleton (set by @/plugins/axios from
      // VITE_BASE_URL); there is no API_URL export to reach for.
      const base = (axios.defaults.baseURL || '').replace(/\/$/, '');
      return `${base}/api/comparisons/crosswalk`;
    },
  },
  async mounted() {
    try {
      this.crosswalk = await getComparisonsCrosswalk();
    } catch {
      this.failed = true;
    }
  },
  methods: {
    // Open-only (idempotent) activation. BootstrapVueNext's `:click` trigger
    // owns the reclick-to-close and outside-click-close on the target, so this
    // handler must never toggle: on a reclick BVN cleanly hides while this
    // no-ops (guard), avoiding a race that would keep the popover stuck open.
    activate() {
      if (!this.open) this.open = true;
    },
    close() {
      this.open = false;
      // a11y: focus must return to the invoker when the popover closes.
      const el = this.$refs.badge?.$el ?? this.$refs.badge;
      if (el && typeof el.focus === 'function') el.focus();
    },
  },
};
</script>

<style scoped>
.tier-mapping-help {
  display: inline-flex;
  align-items: center;
}

.crosswalk-link {
  font-size: 0.8125rem;
}
</style>
