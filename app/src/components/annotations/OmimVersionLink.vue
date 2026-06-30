<!-- components/annotations/OmimVersionLink.vue -->
<!--
  Renders a disease-ontology version id (e.g. "OMIM:301058_1") as an external
  term-browser link. The version suffix ("_1") is stripped for the target URL
  but kept in the visible label so curators can still tell versions apart.

  Link building is delegated to the central ontologyOutlink() helper
  (assets/js/constants/ontology_links.ts) — the single source of truth for
  CURIE -> URL logic. Non-OMIM or unrecognised prefixes (where the helper
  returns url=null) degrade to plain monospace text rather than a broken link.
-->
<template>
  <a
    v-if="link.url"
    :href="link.url"
    target="_blank"
    rel="noopener noreferrer"
    class="font-monospace"
    >{{ link.label }}</a
  >
  <span v-else class="font-monospace">{{ link.label || '—' }}</span>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { ontologyOutlink } from '@/assets/js/constants/ontology_links';

const props = defineProps<{ version: unknown }>();

const link = computed<{ url: string | null; label: string }>(() => {
  const id = props.version == null ? '' : String(props.version).trim();
  if (!id) return { url: null, label: '' };
  const prefix = id.split(':')[0];
  const { url } = ontologyOutlink(prefix, id);
  return { url, label: id };
});
</script>
