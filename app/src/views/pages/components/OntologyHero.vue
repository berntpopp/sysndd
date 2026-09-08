<!-- app/src/views/pages/components/OntologyHero.vue -->
<!--
  Disease ontology detail hero card — primary term identifier, ontology scope &
  specificity, mode of inheritance, primary label, mapping release, and synonyms.
  Pure presentation component matching EntityViewHero and GeneHero standards.
-->
<template>
  <BRow class="justify-content-md-center py-2">
    <BCol cols="12">
      <SectionCard
        :loading="model.loading"
        :empty="model.empty"
        :error="model.error"
        :title="heroTitle"
        min-height="9rem"
      >
        <template #header>
          <div class="ontology-hero-title">
            <div class="d-flex align-items-center gap-2 flex-wrap">
              <span class="text-secondary small fw-semibold text-uppercase tracking-wider">
                Disease
              </span>
              <h1 class="ontology-page-title mb-0">
                <span v-if="model.displayName">{{ model.displayName }}</span>
                <span v-else>{{ model.primaryId || 'Disease Ontology' }}</span>
              </h1>
              <DiseaseBadge
                v-if="model.primaryId"
                :name="model.primaryId"
                :ontology-id="model.primaryId"
                :link-to="undefined"
                size="sm"
                :max-length="0"
                :show-title="false"
              />
            </div>
            <RouterLink
              v-if="model.backToResults"
              class="btn btn-sm btn-outline-secondary ms-auto"
              :to="model.backToResults"
            >
              Back to results
            </RouterLink>
          </div>
        </template>

        <div v-if="model.hasRecord" class="ontology-hero-body" data-testid="ontology-hero">
          <div class="ontology-unit-grid" data-testid="ontology-unit">
            <!-- Cell 1: Term ID -->
            <div class="ontology-unit-cell">
              <div class="ontology-unit-label">Term ID</div>
              <div class="d-flex align-items-center gap-1">
                <span class="font-monospace fw-bold text-dark fs-6">{{ model.primaryId }}</span>
                <button
                  type="button"
                  class="btn btn-link btn-sm p-0 text-secondary ontology-action-icon"
                  title="Copy term ID"
                  :aria-label="`Copy ${model.primaryId} to clipboard`"
                  @click="copyId(model.primaryId)"
                >
                  <i
                    :class="copied ? 'bi bi-check-lg text-success' : 'bi bi-clipboard'"
                    aria-hidden="true"
                  />
                </button>
                <a
                  v-if="model.primaryOutlink?.url"
                  :href="model.primaryOutlink.url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="btn btn-link btn-sm p-0 text-secondary ontology-action-icon"
                  :title="`Open in ${model.primaryPrefix} browser`"
                  :aria-label="`Open in ${model.primaryPrefix} browser (opens in new tab)`"
                >
                  <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
                </a>
              </div>
            </div>

            <!-- Cell 2: Scope & Source -->
            <div class="ontology-unit-cell">
              <div class="ontology-unit-label">Scope & Source</div>
              <div class="d-flex align-items-center gap-1 flex-wrap">
                <span class="badge text-bg-light border text-dark font-monospace text-uppercase">
                  {{ model.source || model.primaryPrefix }}
                </span>
                <span
                  v-if="model.isSpecific === '1'"
                  class="badge text-bg-success-subtle text-success border border-success-subtle"
                  title="Curated as a specific disorder"
                >
                  <i class="bi bi-check-circle me-1" aria-hidden="true" />Specific disorder
                </span>
                <span
                  v-else
                  class="badge text-bg-secondary-subtle text-secondary border border-secondary-subtle"
                  title="Curated as a broad clinical term or grouping category"
                >
                  <i class="bi bi-diagram-3 me-1" aria-hidden="true" />Broad term
                </span>
              </div>
            </div>

            <!-- Cell 3: Inheritance -->
            <div class="ontology-unit-cell">
              <div class="ontology-unit-label">Inheritance</div>
              <InheritanceBadge
                v-if="model.inheritanceName"
                :full-name="model.inheritanceName"
                :hpo-term="model.inheritanceTerm"
                size="sm"
              />
              <span v-else class="text-secondary small fst-italic">
                Not restricted in ontology
              </span>
            </div>

            <!-- Cell 4: Primary Label -->
            <div class="ontology-unit-cell">
              <div class="ontology-unit-label">Primary Label</div>
              <span class="text-dark fw-semibold text-truncate" :title="model.displayName">
                {{ model.displayName }}
              </span>
            </div>
          </div>

          <!-- Metadata row -->
          <div class="ontology-metadata-row">
            <span v-if="model.mappingRelease" class="ontology-meta-pill">
              <i class="bi bi-calendar-check" aria-hidden="true" />
              <span>Mapping release: {{ model.mappingRelease }}</span>
            </span>
            <span v-if="model.versions && model.versions.length > 1" class="ontology-meta-pill">
              <i class="bi bi-layers" aria-hidden="true" />
              <span>Versions: {{ model.versions.join(', ') }}</span>
            </span>
            <span
              v-if="model.synonyms && model.synonyms.length > 1"
              class="ontology-meta-pill"
              :title="model.synonyms.join('; ')"
            >
              <i class="bi bi-tags" aria-hidden="true" />
              <span>Synonyms: {{ model.synonyms.slice(1, 3).join('; ') }}</span>
              <span v-if="model.synonyms.length > 3"> (+{{ model.synonyms.length - 3 }} more)</span>
            </span>
          </div>
        </div>
      </SectionCard>
    </BCol>
  </BRow>
</template>

<script setup lang="ts">
import { computed, ref, onBeforeUnmount } from 'vue';
import { BRow, BCol } from 'bootstrap-vue-next';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import SectionCard from '@/components/ui/SectionCard.vue';
import type { OntologyOutlink } from '@/assets/js/constants/ontology_links';
import useToast from '@/composables/useToast';

export interface OntologyHeroModel {
  diseaseTerm: string;
  primaryId: string;
  primaryPrefix: string;
  displayName: string;
  primaryOutlink: OntologyOutlink | null;
  source: string;
  isSpecific: string;
  inheritanceName: string;
  inheritanceTerm: string;
  mappingRelease: string;
  versions: string[];
  synonyms: string[];
  backToResults: string | null;
  loading: boolean;
  empty: boolean;
  error: string | null;
  hasRecord: boolean;
}

const props = defineProps<{ model: OntologyHeroModel }>();

const heroTitle = computed(() =>
  props.model.primaryId ? `Disease: ${props.model.primaryId}` : 'Disease Ontology'
);

const copied = ref(false);
let copiedTimer: ReturnType<typeof setTimeout> | null = null;
const { makeToast } = useToast();

async function copyId(id: string) {
  if (!id) return;
  try {
    await navigator.clipboard.writeText(id);
    copied.value = true;
    if (copiedTimer) clearTimeout(copiedTimer);
    copiedTimer = setTimeout(() => {
      copied.value = false;
    }, 2000);
    makeToast(`${id} copied to clipboard`, 'Success', 'success');
  } catch {
    makeToast('Failed to copy to clipboard', 'Error', 'danger');
  }
}

onBeforeUnmount(() => {
  if (copiedTimer) clearTimeout(copiedTimer);
});
</script>

<style scoped>
.ontology-hero-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  flex-wrap: wrap;
}
.ontology-page-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1.25rem;
  line-height: 1.15;
  font-weight: 700;
}
.ontology-disease-name {
  color: var(--neutral-900, #212121);
  text-transform: capitalize;
}
.ontology-hero-body {
  padding: 0.65rem 0.75rem;
}
.ontology-unit-grid {
  display: grid;
  grid-template-columns: minmax(10rem, 1fr) minmax(11rem, 1.1fr) minmax(10rem, 1fr) minmax(
      13rem,
      1.3fr
    );
  gap: 0.5rem;
  width: 100%;
  margin-bottom: 0.55rem;
}
.ontology-unit-cell {
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-width: 0;
  gap: 0.25rem;
  padding: 0.45rem 0.55rem;
  border: 1px solid var(--border-subtle, #dbe2ea);
  border-radius: var(--radius-md, 0.45rem);
  background: #f8fafc;
}
.ontology-unit-label {
  color: var(--neutral-600, #667085);
  font-size: 0.7rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.ontology-action-icon {
  line-height: 1;
  opacity: 0.7;
  transition: opacity 0.15s ease;
}
.ontology-action-icon:hover {
  opacity: 1;
}
.ontology-metadata-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.45rem;
}
.ontology-meta-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  box-sizing: border-box;
  height: 1.8rem;
  padding: 0.18rem 0.55rem;
  border: 1px solid var(--border-subtle, #d5dbe3);
  border-radius: 999px;
  background: #f8fafc;
  color: var(--neutral-900, #344054);
  font-size: 0.78rem;
  font-weight: 600;
  line-height: 1;
  white-space: nowrap;
}
.ontology-meta-pill i {
  color: var(--neutral-600, #667085);
}
@media (max-width: 991.98px) {
  .ontology-unit-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
@media (max-width: 575.98px) {
  .ontology-page-title {
    font-size: 1.1rem;
  }
  .ontology-hero-body {
    padding: 0.65rem;
  }
  .ontology-unit-grid {
    grid-template-columns: 1fr;
  }
}
</style>
