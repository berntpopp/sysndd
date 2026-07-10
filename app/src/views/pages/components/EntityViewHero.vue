<!-- app/src/views/pages/components/EntityViewHero.vue -->
<!--
  Entity detail hero card — the Gene / Inheritance / Disease unit,
  classification pill, disease source link, NDD status, and freshness pills.
  Pure presentation: extracted from EntityView.vue (#346) so the >600-line
  page owns only fetching/orchestration. The parent keeps ownership of
  useEntityRecord/useEntityStatus and all field derivation; this component
  renders the already-computed fields bundled into a single `model` prop
  (a focused display model, not a wide collection of independent props).
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
          <div class="entity-hero-title">
            <h1 class="entity-page-title mb-0">
              <span>Entity</span>
              <EntityBadge
                :entity-id="model.entityIdStr"
                :link-to="`/Entities/${model.entityIdStr}`"
                size="lg"
              />
            </h1>
            <RouterLink
              v-if="model.backToResults"
              class="btn btn-sm btn-outline-secondary"
              :to="model.backToResults"
            >
              Back to results
            </RouterLink>
          </div>
        </template>

        <div v-if="model.hasRecord" class="entity-hero-body" data-testid="entity-hero">
          <div class="entity-unit-grid" data-testid="entity-unit">
            <div class="entity-unit-cell entity-unit-gene">
              <div class="entity-unit-label" data-testid="entity-unit-label">Gene</div>
              <GeneBadge
                :symbol="model.geneSymbol"
                :hgnc-id="model.hgncId"
                :link-to="model.geneLink"
                size="lg"
              />
            </div>
            <div class="entity-unit-cell entity-unit-inheritance">
              <div class="entity-unit-label" data-testid="entity-unit-label">Inheritance</div>
              <InheritanceBadge
                :full-name="model.inheritanceName"
                :hpo-term="model.inheritanceTerm"
              />
            </div>
            <div class="entity-unit-cell entity-unit-disease">
              <div class="entity-unit-label" data-testid="entity-unit-label">Disease</div>
              <DiseaseBadge
                :name="model.diseaseName"
                :ontology-id="model.diseaseOntologyId"
                :link-to="model.diseaseLink"
                :max-length="0"
              />
            </div>
          </div>
          <div class="entity-metadata-row">
            <span v-if="model.categoryLabel" class="entity-classification-pill">
              <span class="entity-classification-label">Classification</span>
              <CategoryIcon :category="model.categoryLabel" :show-title="false" size="sm" />
              <span>{{ model.categoryLabel }}</span>
            </span>
            <span v-if="model.diseaseSourceId" class="entity-meta-pill">
              <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
              <a :href="model.diseaseSourceUrl" target="_blank" rel="noopener">
                {{ model.diseaseSourceId }}
              </a>
            </span>
            <span class="entity-meta-pill entity-meta-icon">
              <NddIcon :status="model.nddStatus" :show-title="false" size="sm" />
              <span>NDD {{ model.nddStatus || 'unknown' }}</span>
            </span>
            <EntityFreshnessPills :entry-date="model.entryDate" :last-update="model.lastUpdate" />
          </div>
        </div>
      </SectionCard>
    </BCol>
  </BRow>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BRow, BCol } from 'bootstrap-vue-next';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import EntityFreshnessPills from '@/components/ui/EntityFreshnessPills.vue';
import SectionCard from '@/components/ui/SectionCard.vue';

export interface EntityHeroModel {
  entityIdStr: string;
  backToResults: string | null;
  loading: boolean;
  empty: boolean;
  error: string | null;
  hasRecord: boolean;
  geneSymbol: string;
  hgncId: string;
  geneLink: string;
  inheritanceName: string;
  inheritanceTerm: string;
  diseaseName: string;
  diseaseOntologyId: string;
  diseaseLink: string;
  categoryLabel: string;
  diseaseSourceId: string;
  diseaseSourceUrl: string;
  nddStatus: string;
  entryDate: unknown;
  lastUpdate: unknown;
}

const props = defineProps<{ model: EntityHeroModel }>();

const heroTitle = computed(() =>
  props.model.entityIdStr ? `Entity: ${props.model.entityIdStr}` : 'Entity'
);
</script>

<style scoped>
.entity-hero-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  flex-wrap: wrap;
}
.entity-page-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1.25rem;
  line-height: 1.15;
  font-weight: 700;
}
.entity-hero-body {
  padding: 0.65rem 0.75rem;
}
.entity-unit-grid {
  display: grid;
  grid-template-columns: minmax(11rem, 0.9fr) minmax(10rem, 0.7fr) minmax(16rem, 1.4fr);
  gap: 0.5rem;
  width: 100%;
  margin-bottom: 0.55rem;
}
.entity-unit-cell {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 0.45rem;
  padding: 0.45rem 0.55rem;
  border: 1px solid var(--border-subtle, #dbe2ea);
  border-radius: var(--radius-md, 0.45rem);
  background: #f8fafc;
}
.entity-unit-gene {
  border-left: 0.25rem solid #0f8f51;
}
.entity-unit-inheritance {
  border-left: 0.25rem solid #09a9c9;
}
.entity-unit-disease {
  border-left: 0.25rem solid #65717d;
}
.entity-unit-label {
  color: var(--neutral-600, #667085);
  font-size: 0.7rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.entity-metadata-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.45rem;
}
.entity-meta-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  box-sizing: border-box;
  height: 1.8rem;
  padding: 0.18rem 0.48rem;
  border: 1px solid var(--border-subtle, #d5dbe3);
  border-radius: 999px;
  background: #f8fafc;
  color: var(--neutral-900, #344054);
  font-size: 0.78rem;
  font-weight: 650;
  line-height: 1;
  white-space: nowrap;
}
.entity-classification-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  box-sizing: border-box;
  height: 1.8rem;
  padding: 0.2rem 0.6rem 0.2rem 0.35rem;
  border: 1px solid #9fd7c4;
  border-radius: 999px;
  background: #e8f8f1;
  color: #064e3b;
  font-size: 0.84rem;
  font-weight: 800;
  line-height: 1;
  white-space: nowrap;
}
.entity-classification-label {
  color: #047857;
  font-size: 0.68rem;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.entity-meta-pill a {
  color: var(--medical-blue-700, #0d47a1);
  text-decoration: none;
}
.entity-meta-icon {
  padding-left: 0.28rem;
}
@media (max-width: 575.98px) {
  .entity-page-title {
    font-size: 1.1rem;
  }
  .entity-hero-body {
    padding: 0.65rem;
  }
  .entity-unit-grid {
    grid-template-columns: 1fr;
  }
}
</style>
