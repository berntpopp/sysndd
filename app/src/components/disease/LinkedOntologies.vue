<template>
  <div class="linked-ontologies" :class="`linked-ontologies--${layout}`">
    <!-- Loading state -->
    <div v-if="loading" class="linked-ontologies__loading" aria-live="polite" aria-busy="true">
      <span class="linked-ontologies__loading-text">Loading ontology mappings…</span>
    </div>

    <!-- Missing status note -->
    <p
      v-else-if="data?.status === 'missing'"
      class="linked-ontologies__missing"
      role="status"
    >
      Mappings are being prepared.
    </p>

    <!-- Mapping groups (allowlist order, hide empty groups) -->
    <template v-else-if="data">
      <div
        v-for="group in resolvedGroups"
        :key="group.prefix"
        class="linked-ontologies__group"
        :class="`linked-ontologies__group--${layout}`"
      >
        <!-- ResourceLink badge for each entry in the group.
             No prefix label: each chip already shows the full CURIE (e.g.
             "MONDO:0032745"), so a separate label would be redundant and
             forces a row per prefix. Chips flow inline and wrap instead. -->
        <ResourceLink
          v-for="item in group.items"
          :key="item.entry.id"
          compact
          :name="item.entry.id"
          :url="item.url ?? undefined"
          :available="item.url !== null"
          icon="bi-box-arrow-up-right"
        />
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { DiseaseMappingResponse } from '@/api/disease-mappings';
import { ontologyOutlink } from '@/assets/js/constants/ontology_links';
import ResourceLink from '@/components/gene/ResourceLink.vue';

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface Props {
  data: DiseaseMappingResponse | null;
  loading?: boolean;
  layout?: 'strip' | 'card';
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  layout: 'strip',
});

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const ALLOWLIST_ORDER = ['MONDO', 'Orphanet', 'OMIM', 'DOID', 'UMLS', 'MedGen', 'NCIT', 'GARD', 'EFO'] as const;

// ---------------------------------------------------------------------------
// Computed
// ---------------------------------------------------------------------------

/**
 * Resolved groups: only prefixes with at least one entry, in display order.
 * Each item has the mapping entry plus the resolved url (computed once per entry).
 */
const resolvedGroups = computed(() => {
  if (!props.data?.mappings) return [];
  return ALLOWLIST_ORDER
    .filter(
      (prefix) =>
        props.data!.mappings[prefix] && props.data!.mappings[prefix].length > 0
    )
    .map((prefix) => ({
      prefix,
      items: props.data!.mappings[prefix].map((entry) => {
        const resolved = ontologyOutlink(prefix, entry.id);
        return { entry, url: resolved.url };
      }),
    }));
});
</script>

<style scoped>
.linked-ontologies {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

/* Strip layout: all badges inline, wrapping */
.linked-ontologies--strip {
  flex-direction: row;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.375rem;
}

.linked-ontologies--strip .linked-ontologies__group {
  display: contents; /* badges flow directly into the parent flex container */
}

/* Card layout: same inline-wrapping chip cloud as strip, with a slightly
   roomier gap to suit the detail-page card. Chips flow and wrap rather than
   stacking one prefix per row. */
.linked-ontologies--card {
  flex-direction: row;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.linked-ontologies--card .linked-ontologies__group {
  display: contents; /* badges flow directly into the parent flex container */
}

/* Loading / missing states */
.linked-ontologies__loading {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #6c757d;
  font-size: 0.875rem;
}

.linked-ontologies__missing {
  font-size: 0.8125rem;
  color: #6c757d;
  font-style: italic;
  margin: 0;
}
</style>
