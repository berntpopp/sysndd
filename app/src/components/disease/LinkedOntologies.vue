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
        v-for="prefix in visiblePrefixes"
        :key="prefix"
        class="linked-ontologies__group"
        :class="`linked-ontologies__group--${layout}`"
      >
        <!-- Card layout: show labelled row header -->
        <span v-if="layout === 'card'" class="linked-ontologies__prefix-label">{{ prefix }}</span>

        <!-- Badges for each entry in the group -->
        <component
          :is="outlink(prefix, entry.id).url ? 'a' : 'span'"
          v-for="entry in data.mappings[prefix]"
          :key="entry.id"
          :href="outlink(prefix, entry.id).url ?? undefined"
          :target="outlink(prefix, entry.id).url ? '_blank' : undefined"
          :rel="outlink(prefix, entry.id).url ? 'noopener noreferrer' : undefined"
          :aria-label="
            outlink(prefix, entry.id).url
              ? `Open ${entry.id} in ${prefix} (opens in new tab)`
              : undefined
          "
          class="linked-ontologies__badge"
          :class="{
            'linked-ontologies__badge--link': !!outlink(prefix, entry.id).url,
            'linked-ontologies__badge--plain': !outlink(prefix, entry.id).url,
          }"
        >
          {{ entry.id }}
        </component>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { DiseaseMappingResponse } from '@/api/disease-mappings';
import { ontologyOutlink } from '@/assets/js/constants/ontology_links';

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

/** Prefixes that have at least one entry in the current mappings, in display order. */
const visiblePrefixes = computed(() => {
  if (!props.data?.mappings) return [];
  return ALLOWLIST_ORDER.filter(
    (prefix) =>
      props.data!.mappings[prefix] && props.data!.mappings[prefix].length > 0
  );
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function outlink(prefix: string, id: string) {
  return ontologyOutlink(prefix, id);
}
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

/* Card layout: labelled rows */
.linked-ontologies--card .linked-ontologies__group {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.linked-ontologies__prefix-label {
  font-size: 0.75rem;
  font-weight: 600;
  color: #6c757d;
  min-width: 5rem;
  flex-shrink: 0;
}

/* Shared badge styles */
.linked-ontologies__badge {
  display: inline-flex;
  align-items: center;
  padding: 0.15rem 0.5rem;
  border-radius: 1rem;
  font-size: 0.75rem;
  font-weight: 500;
  white-space: nowrap;
  border: 1px solid #dee2e6;
  text-decoration: none;
  line-height: 1.4;
}

.linked-ontologies__badge--link {
  background: #fff;
  color: #495057;
  cursor: pointer;
  transition:
    background-color 0.15s ease,
    border-color 0.15s ease;
}

.linked-ontologies__badge--link:hover {
  background-color: #e9ecef;
  border-color: #adb5bd;
  color: #212529;
  text-decoration: none;
}

.linked-ontologies__badge--plain {
  background: #f8f9fa;
  color: #6c757d;
  border-color: #dee2e6;
  cursor: default;
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

/* Respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .linked-ontologies__badge--link {
    transition: none;
  }
}
</style>
