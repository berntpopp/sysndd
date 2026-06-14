<!-- src/components/analyses/PubtatorPublicationDetail.vue -->
<!--
  One publication's expanded detail card for the PubtatorNDD gene table.

  Extracted from PubtatorNDDGenes.vue so the gene component stays under the
  file-size ceiling and the per-publication markup (PMID/DOI/date/journal/score
  meta + annotated text + gene chips) lives in one focused, testable place.
-->
<template>
  <div class="details-section">
    <!-- Title -->
    <div v-if="publication.title" class="details-title">
      {{ publication.title }}
    </div>

    <div class="details-row">
      <!-- PMID, DOI, Date, Journal, Score -->
      <div class="details-meta">
        <a
          :href="'https://pubmed.ncbi.nlm.nih.gov/' + publication.pmid"
          target="_blank"
          rel="noopener noreferrer"
          class="details-pmid"
        >
          <i class="bi bi-journal-medical me-1" />
          PMID:{{ publication.pmid }}
          <i class="bi bi-box-arrow-up-right ms-1" />
        </a>
        <a
          v-if="publication.doi"
          :href="'https://doi.org/' + publication.doi"
          target="_blank"
          rel="noopener noreferrer"
          class="details-doi"
        >
          <i class="bi bi-link-45deg me-1" />
          {{ publication.doi }}
        </a>
        <span v-if="publication.date" class="details-date">
          <i class="bi bi-calendar3 me-1" />
          {{ publication.date }}
        </span>
        <span v-if="publication.journal" class="details-journal">
          <i class="bi bi-book me-1" />
          {{ publication.journal }}
        </span>
        <BBadge
          v-if="publication.score != null"
          :variant="
            publication.score >= 500 ? 'success' : publication.score >= 100 ? 'warning' : 'secondary'
          "
          pill
        >
          Score: {{ publication.score }}
        </BBadge>
      </div>
    </div>

    <!-- Annotated Text Section (shared renderer, memoized parse) -->
    <PubtatorAnnotatedText
      v-if="publication.text_hl"
      :text="publication.text_hl"
      section-class="mt-2"
    />

    <!-- Gene symbols as badges -->
    <div v-if="publication.gene_symbols" class="gene-symbols-section mt-2">
      <div class="gene-chips">
        <span v-for="sym in geneSymbols" :key="sym" class="gene-chip">
          {{ sym }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import PubtatorAnnotatedText from '@/components/analyses/PubtatorAnnotatedText.vue';
import type { PubtatorPublicationData } from '@/composables/usePubtatorGenePublications';

const props = defineProps<{
  publication: PubtatorPublicationData;
}>();

// Split gene_symbols once per publication (template iterates the result).
const geneSymbols = computed(() =>
  (props.publication.gene_symbols ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s !== '')
);
</script>

<style scoped>
.details-section {
  margin-bottom: 1rem;
}

.details-section:last-child {
  margin-bottom: 0;
}

.details-title {
  font-weight: 600;
  font-size: 0.95rem;
  color: #212529;
  margin-bottom: 0.5rem;
  line-height: 1.4;
  text-align: left;
}

.details-row {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  margin-bottom: 0.75rem;
}

.details-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 1rem;
}

.details-pmid {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  font-size: 0.8em;
  font-weight: 500;
  background-color: #e7f1ff;
  color: #0d6efd;
  border-radius: 0.3rem;
  text-decoration: none;
  transition: all 0.15s ease-in-out;
}

.details-pmid:hover {
  background-color: #0d6efd;
  color: white;
}

.details-date {
  display: inline-flex;
  align-items: center;
  padding: 0.2em 0.5em;
  font-size: 0.8em;
  background-color: #e8f5e9;
  color: #2e7d32;
  border-radius: 0.25rem;
}

.details-journal {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  font-size: 0.8em;
  background-color: #f8f9fa;
  color: #495057;
  border-radius: 0.25rem;
  border: 1px solid #dee2e6;
}

.details-doi {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  font-size: 0.8em;
  font-weight: 500;
  background-color: #f0f0f0;
  color: #495057;
  border-radius: 0.3rem;
  text-decoration: none;
  transition: all 0.15s ease-in-out;
}

.details-doi:hover {
  background-color: #495057;
  color: white;
}

/* Gene symbol chips */
.gene-symbols-section {
  border-top: 1px solid #dee2e6;
  padding-top: 0.5rem;
}

.gene-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
  align-items: center;
}

.gene-chip {
  display: inline-block;
  padding: 0.15em 0.4em;
  font-size: 0.75rem;
  font-weight: 500;
  background-color: #b4e3f9;
  color: #0d6efd;
  border-radius: 0.25rem;
  white-space: nowrap;
}
</style>
