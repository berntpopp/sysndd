<!-- app/src/views/pages/EntityView.vue (v11.3 W3 rewrite, compact clinical UX) -->
<!--
  Mount order:
    1. useEntityRecord(entityId) fires on tick 0; header card renders skeleton.
    2. useEntityStatus / Review / Publications / Phenotypes / Variation fire in
       parallel on the same tick; each owns its <SectionCard>.
    3. Once the entity record resolves, useGeneRecord(entity.hgnc_id) hydrates
       the linked-gene block.

  The request timing contract is intentionally unchanged: this component only
  changes presentation of the already-fetched entity resources.
-->
<template>
  <div class="container-fluid bg-gradient entity-detail-page">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol cols="12">
          <SectionCard
            :loading="entity.loading.value"
            :empty="!entity.loading.value && entity.data.value === null && !entity.error.value"
            :error="entity.error.value ? entity.error.value.message : null"
            :title="entityIdStr ? `Entity: ${entityIdStr}` : 'Entity'"
            min-height="9rem"
          >
            <template #header>
              <div class="entity-hero-title">
                <h1 class="entity-page-title mb-0">
                  <span>Entity</span>
                  <EntityBadge
                    :entity-id="entityIdStr"
                    :link-to="`/Entities/${entityIdStr}`"
                    size="lg"
                  />
                </h1>
                <RouterLink
                  v-if="backToResults"
                  class="btn btn-sm btn-outline-secondary"
                  :to="backToResults"
                >
                  Back to results
                </RouterLink>
              </div>
            </template>

            <div v-if="entityRow" class="entity-hero-body" data-testid="entity-hero">
              <div class="entity-unit-grid" data-testid="entity-unit">
                <div class="entity-unit-cell entity-unit-gene">
                  <div class="entity-unit-label" data-testid="entity-unit-label">Gene</div>
                  <GeneBadge :symbol="geneSymbol" :hgnc-id="hgncId" :link-to="geneLink" size="lg" />
                </div>
                <div class="entity-unit-cell entity-unit-inheritance">
                  <div class="entity-unit-label" data-testid="entity-unit-label">Inheritance</div>
                  <InheritanceBadge :full-name="inheritanceName" :hpo-term="inheritanceTerm" />
                </div>
                <div class="entity-unit-cell entity-unit-disease">
                  <div class="entity-unit-label" data-testid="entity-unit-label">Disease</div>
                  <DiseaseBadge
                    :name="diseaseName"
                    :ontology-id="diseaseOntologyId"
                    :link-to="diseaseLink"
                    :max-length="0"
                  />
                </div>
              </div>
              <div class="entity-metadata-row">
                <span v-if="categoryLabel" class="entity-classification-pill">
                  <span class="entity-classification-label">Classification</span>
                  <CategoryIcon :category="categoryLabel" :show-title="false" size="sm" />
                  <span>{{ categoryLabel }}</span>
                </span>
                <span v-if="diseaseSourceId" class="entity-meta-pill">
                  <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
                  <a :href="diseaseSourceUrl" target="_blank" rel="noopener">
                    {{ diseaseSourceId }}
                  </a>
                </span>
                <span class="entity-meta-pill entity-meta-icon">
                  <NddIcon :status="nddStatus" :show-title="false" size="sm" />
                  <span>NDD {{ nddStatus || 'unknown' }}</span>
                </span>
                <EntityFreshnessPills
                  :entry-date="entityRow?.entry_date"
                  :last-update="entityRow?.last_update"
                />
              </div>
            </div>
          </SectionCard>
        </BCol>
      </BRow>

      <BRow class="entity-ontology-grid">
        <BCol cols="12" class="mb-2">
          <SectionCard
            :loading="mappings.loading.value"
            :empty="
              !mappings.loading.value && !mappings.error.value && mappings.data.value === null
            "
            :error="mappings.error.value ? mappings.error.value.message : null"
            title="Linked disease ontologies"
            min-height="4rem"
          >
            <div class="entity-ontology-panel">
              <LinkedOntologies
                layout="card"
                :data="mappings.data.value"
                :loading="mappings.loading.value"
              />
            </div>
          </SectionCard>
        </BCol>
      </BRow>

      <BRow class="entity-clinical-grid">
        <BCol cols="12" class="mb-2">
          <SectionCard
            :loading="review.loading.value"
            :empty="false"
            :error="review.error.value ? review.error.value.message : null"
            title="Clinical Synopsis"
            min-height="18rem"
          >
            <template #header>
              <div class="clinical-card-header" data-testid="clinical-synopsis-header">
                <span>Clinical Synopsis</span>
                <span class="clinical-card-actions">
                  <span v-if="reviewDate" class="clinical-panel-meta">
                    Last reviewed {{ reviewDate }}
                  </span>
                  <BButton
                    data-testid="copy-synopsis-button"
                    size="sm"
                    variant="outline-primary"
                    class="copy-synopsis-button"
                    :disabled="!synopsisText"
                    @click="copySynopsis"
                  >
                    <i class="bi bi-clipboard" aria-hidden="true" />
                    {{ copyButtonLabel }}
                  </BButton>
                </span>
              </div>
            </template>
            <section
              class="clinical-synopsis-panel"
              data-testid="clinical-synopsis-panel"
              aria-label="Clinical Synopsis"
            >
              <p class="clinical-synopsis-text" data-testid="clinical-synopsis-text">
                <span v-if="synopsisText">{{ synopsisText }}</span>
                <span v-else class="entity-empty-state">No clinical synopsis available.</span>
              </p>
            </section>
          </SectionCard>
        </BCol>
      </BRow>

      <BRow class="entity-evidence-grid">
        <BCol cols="12" lg="6" xl="3" class="mb-2">
          <SectionCard
            :loading="publications.loading.value"
            :empty="false"
            :error="publications.error.value ? publications.error.value.message : null"
            title="Publications"
            min-height="9rem"
          >
            <div class="entity-chip-panel">
              <a
                v-for="publication in additionalRefs"
                :key="String(publication.publication_id)"
                class="entity-chip entity-chip-publication"
                :href="pubmedUrl(publication)"
                target="_blank"
                rel="noopener"
                :aria-label="publicationAriaLabel(publication)"
                :data-testid="`publication-chip-${asString(publication.publication_id)}`"
                :data-tooltip="publicationTitle(publication)"
              >
                <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
                {{ publication.publication_id }}
              </a>
              <span v-if="additionalRefs.length === 0" class="entity-empty-state">
                No publications linked.
              </span>
            </div>
          </SectionCard>
        </BCol>

        <BCol cols="12" lg="6" xl="2" class="mb-2">
          <SectionCard
            :loading="publications.loading.value"
            :empty="false"
            :error="publications.error.value ? publications.error.value.message : null"
            title="Gene Reviews"
            min-height="6rem"
          >
            <div class="entity-chip-panel">
              <a
                v-for="publication in geneReviews"
                :key="String(publication.publication_id)"
                class="entity-chip entity-chip-genereview"
                :href="pubmedUrl(publication)"
                target="_blank"
                rel="noopener"
                :aria-label="publicationAriaLabel(publication)"
                :data-testid="`publication-chip-${asString(publication.publication_id)}`"
                :data-tooltip="publicationTitle(publication)"
              >
                <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
                {{ publication.publication_id }}
              </a>
              <span v-if="geneReviews.length === 0" class="entity-empty-state">
                No GeneReviews linked.
              </span>
            </div>
          </SectionCard>
        </BCol>

        <BCol cols="12" lg="6" xl="5" class="mb-2">
          <SectionCard
            :loading="phenotypes.loading.value"
            :empty="false"
            :error="phenotypes.error.value ? phenotypes.error.value.message : null"
            title="Phenotypes"
            min-height="18rem"
          >
            <div class="entity-chip-panel">
              <a
                v-for="phenotype in phenotypesList"
                :key="String(phenotype.phenotype_id)"
                class="entity-chip entity-chip-phenotype"
                :class="modifierChipClass(phenotype)"
                :href="hpoUrl(phenotype)"
                target="_blank"
                rel="noopener"
                :aria-label="termAriaLabel(phenotype, 'phenotype_id', 'HPO term')"
                :data-testid="`phenotype-chip-${asString(phenotype.phenotype_id)}`"
                :data-tooltip="termTitle(phenotype, 'phenotype_id')"
              >
                <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
                {{ phenotype.HPO_term }}
              </a>
              <span v-if="phenotypesList.length === 0" class="entity-empty-state">
                No phenotype terms linked.
              </span>
            </div>
          </SectionCard>
        </BCol>

        <BCol cols="12" lg="6" xl="2" class="mb-2">
          <SectionCard
            :loading="variation.loading.value"
            :empty="false"
            :error="variation.error.value ? variation.error.value.message : null"
            title="Variation Ontology"
            min-height="9rem"
          >
            <div class="entity-chip-panel">
              <a
                v-for="variant in variationList"
                :key="String(variant.vario_id)"
                class="entity-chip entity-chip-variation"
                :class="modifierChipClass(variant)"
                :href="varioUrl(variant)"
                target="_blank"
                rel="noopener"
                :aria-label="termAriaLabel(variant, 'vario_id', 'Variation ontology term')"
                :data-testid="`variation-chip-${asString(variant.vario_id)}`"
                :data-tooltip="termTitle(variant, 'vario_id')"
              >
                <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
                {{ variant.vario_name }}
              </a>
              <span v-if="variationList.length === 0" class="entity-empty-state">
                No variation ontology terms linked.
              </span>
            </div>
          </SectionCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useHead } from '@unhead/vue';
import { BContainer, BRow, BCol, BButton } from 'bootstrap-vue-next';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import EntityFreshnessPills from '@/components/ui/EntityFreshnessPills.vue';
import SectionCard from '@/components/ui/SectionCard.vue';
import { useText } from '@/composables';
import { useEntityRecord } from '@/composables/useEntityRecord';
import { useEntityStatus } from '@/composables/useEntityStatus';
import { useEntityReview } from '@/composables/useEntityReview';
import { useEntityPublications } from '@/composables/useEntityPublications';
import { useEntityPhenotypes } from '@/composables/useEntityPhenotypes';
import { useEntityVariation } from '@/composables/useEntityVariation';
import { useEntityMappings } from '@/composables/useEntityMappings';
import { useGeneRecord } from '@/composables/useGeneRecord';
import LinkedOntologies from '@/components/disease/LinkedOntologies.vue';
import { returnToFromRoute } from '@/utils/returnNavigation';
import { varioTermUrl } from '@/assets/js/constants/ontology_links';

const route = useRoute();
const router = useRouter();
const backToResults = computed(() => returnToFromRoute(route, ''));

type EntityRowMap = Record<string, unknown>;

const { publication_hover_text, modifier_text } = useText();
const copyButtonLabel = ref('Copy');
let copyResetTimer: number | NodeJS.Timeout | null = null;

const entityIdStr = computed(() => String(route.params.entity_id ?? ''));

// All entity-side hooks fire on tick 0 — no sequential awaits.
const entity = useEntityRecord(entityIdStr);
const status = useEntityStatus(entityIdStr);
const review = useEntityReview(entityIdStr);
const publications = useEntityPublications(entityIdStr);
const phenotypes = useEntityPhenotypes(entityIdStr);
const variation = useEntityVariation(entityIdStr);
const mappings = useEntityMappings(entityIdStr);

const entityRow = computed(() => entity.data.value as EntityRowMap | null);

// Linked gene fires when the entity record resolves with a hgnc_id.
const hgncIdRef = computed<string | null>(() => {
  const v = entityRow.value?.hgnc_id;
  return typeof v === 'string' && v ? v : null;
});
// Mounted unconditionally; the hook becomes inert when the ref is null.
useGeneRecord(hgncIdRef);

const asString = (value: unknown): string => (value == null ? '' : String(value));
const compactId = (value: unknown): string => asString(value).replace(/_.+/g, '').trim();

const statusRows = computed(() => {
  const data = status.data.value as unknown;
  return Array.isArray(data) ? (data as EntityRowMap[]) : data ? [data as EntityRowMap] : [];
});
const reviewRows = computed(() => {
  const data = review.data.value as unknown;
  return Array.isArray(data) ? (data as EntityRowMap[]) : data ? [data as EntityRowMap] : [];
});
const publicationsList = computed<Array<EntityRowMap>>(() => {
  const data = publications.data.value as unknown;
  return Array.isArray(data) ? (data as Array<EntityRowMap>) : [];
});
const phenotypesList = computed<Array<EntityRowMap>>(() => {
  const data = phenotypes.data.value as unknown;
  return Array.isArray(data) ? (data as Array<EntityRowMap>) : [];
});
const variationList = computed<Array<EntityRowMap>>(() => {
  const data = variation.data.value as unknown;
  return Array.isArray(data) ? (data as Array<EntityRowMap>) : [];
});

// Publications client-side split — the existing endpoint feeds both cards.
const additionalRefs = computed(() =>
  publicationsList.value.filter((p) => p.publication_type === 'additional_references')
);
const geneReviews = computed(() =>
  publicationsList.value.filter((p) => p.publication_type === 'gene_review')
);

const primaryStatus = computed(() => statusRows.value[0] ?? null);
const primaryReview = computed(() => reviewRows.value[0] ?? null);

const geneSymbol = computed(() => asString(entityRow.value?.symbol));
const hgncId = computed(() => asString(entityRow.value?.hgnc_id));
const geneLink = computed(() => `/Genes/${hgncId.value || geneSymbol.value}`);
const diseaseName = computed(() => asString(entityRow.value?.disease_ontology_name));
const diseaseOntologyId = computed(() => asString(entityRow.value?.disease_ontology_id_version));
const diseaseSourceId = computed(() => compactId(diseaseOntologyId.value));
const diseaseLink = computed(() =>
  diseaseSourceId.value ? `/Ontology/${diseaseSourceId.value}` : ''
);
const diseaseSourceUrl = computed(() => {
  if (diseaseSourceId.value.startsWith('OMIM:')) {
    return `https://www.omim.org/entry/${diseaseSourceId.value.replace('OMIM:', '')}`;
  }
  if (diseaseSourceId.value.startsWith('MONDO:')) {
    return `http://purl.obolibrary.org/obo/${diseaseSourceId.value.replace(':', '_')}`;
  }
  return diseaseLink.value;
});
const inheritanceName = computed(() =>
  asString(entityRow.value?.hpo_mode_of_inheritance_term_name)
);
const inheritanceTerm = computed(() => asString(entityRow.value?.hpo_mode_of_inheritance_term));
const nddStatus = computed(() => asString(entityRow.value?.ndd_phenotype_word));
const categoryLabel = computed(() =>
  asString(primaryStatus.value?.category ?? entityRow.value?.category)
);
const reviewDate = computed(() => asString(primaryReview.value?.review_date));
const synopsisText = computed(() =>
  asString(primaryReview.value?.synopsis ?? entityRow.value?.synopsis).trim()
);

async function copySynopsis(): Promise<void> {
  if (!synopsisText.value) return;
  const writeText = navigator?.clipboard?.writeText;
  if (!writeText) {
    copyButtonLabel.value = 'Copy';
    return;
  }

  try {
    await writeText(synopsisText.value);
    copyButtonLabel.value = 'Copied';
    if (copyResetTimer) {
      window.clearTimeout(copyResetTimer);
    }
    copyResetTimer = window.setTimeout(() => {
      copyButtonLabel.value = 'Copy';
      copyResetTimer = null;
    }, 1600);
  } catch {
    copyButtonLabel.value = 'Copy';
  }
}
onBeforeUnmount(() => {
  if (copyResetTimer) {
    window.clearTimeout(copyResetTimer);
    copyResetTimer = null;
  }
});

function pubmedUrl(publication: EntityRowMap): string {
  return `https://pubmed.ncbi.nlm.nih.gov/${asString(publication.publication_id).replace(/^PMID:\s*/, '')}`;
}

function publicationTitle(publication: EntityRowMap): string {
  return (publication_hover_text[asString(publication.publication_type)] ?? 'Publication').trim();
}

function publicationAriaLabel(publication: EntityRowMap): string {
  return `${publicationTitle(publication)} ${asString(publication.publication_id)}`.trim();
}

function hpoUrl(phenotype: EntityRowMap): string {
  return `https://hpo.jax.org/app/browse/term/${asString(phenotype.phenotype_id)}`;
}

// VariO links are built from the configurable EBI OLS4 base (the previous
// aber-owl.net target no longer reliably resolves to a term page). The base is
// overridable via VITE_VARIO_BASE_URL — see assets/js/constants/ontology_links.ts.
function varioUrl(variant: EntityRowMap): string {
  return varioTermUrl(variant.vario_id);
}

function termTitle(item: EntityRowMap, idKey: string): string {
  const modifier = modifier_text[Number(item.modifier_id)] ?? 'Evidence term';
  return `${modifier} | ${asString(item[idKey])}`;
}

function termAriaLabel(item: EntityRowMap, idKey: string, kind: string): string {
  return `${kind}: ${termTitle(item, idKey)}`;
}

function modifierChipClass(item: EntityRowMap): string {
  const modifier = modifier_text[Number(item.modifier_id)] ?? 'evidence';
  return `entity-chip--${modifier.replace(/\s+/g, '-').toLowerCase()}`;
}

// 404 redirect: fire once the record resolves to null without an error. Watch
// both the loading and data refs so cold null→null transitions still trigger.
watch([entity.loading, entity.data], () => {
  if (
    !entity.loading.value &&
    entity.data.value === null &&
    !entity.error.value &&
    entityIdStr.value
  ) {
    router.push('/PageNotFound');
  }
});

useHead({
  title: computed(() => (entityIdStr.value ? `Entity: ${entityIdStr.value}` : 'Entity')),
  meta: [
    {
      name: 'description',
      content: computed(() =>
        entityIdStr.value
          ? `Entity ${entityIdStr.value} — gene-disease association in SysNDD.`
          : 'This Entity view shows specific information for a SysNDD entity.'
      ),
    },
  ],
});
</script>

<style scoped>
.entity-detail-page {
  padding-bottom: 1rem;
}
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
.entity-ontology-grid,
.entity-clinical-grid,
.entity-evidence-grid {
  padding-top: 0.15rem;
}
.entity-ontology-panel {
  padding: 0.75rem;
}
.clinical-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding-left: 0.25rem;
  color: var(--neutral-700, #374151);
  font-size: 0.875rem;
  font-weight: var(--font-weight-semibold, 600);
  line-height: 1.2;
}
.clinical-card-actions {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  min-width: 0;
}
.clinical-synopsis-panel,
.entity-chip-panel {
  padding: 0.75rem;
}
.clinical-panel-meta {
  color: var(--neutral-600, #667085);
  font-size: 0.76rem;
  font-weight: 650;
}
.copy-synopsis-button {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  min-height: 1.45rem;
  padding: 0.08rem 0.4rem;
  border-color: var(--medical-blue-700, #0d47a1);
  color: var(--medical-blue-700, #0d47a1);
  font-size: 0.72rem;
  line-height: 1;
  white-space: nowrap;
}
.copy-synopsis-button:hover,
.copy-synopsis-button:focus {
  border-color: var(--medical-blue-700, #0d47a1);
  background-color: var(--medical-blue-700, #0d47a1);
  color: #fff;
}
.clinical-synopsis-text {
  width: 100%;
  margin: 0;
  color: var(--neutral-900, #111827);
  font-size: 0.95rem;
  line-height: 1.55;
  text-align: left;
}
.entity-chip-panel {
  display: flex;
  align-content: flex-start;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 0.35rem;
}
.entity-chip {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  max-width: 100%;
  min-height: 1.55rem;
  padding: 0.18rem 0.5rem;
  border: 1px solid transparent;
  border-radius: 999px;
  color: #0f172a;
  font-size: 0.78rem;
  font-weight: 700;
  line-height: 1.2;
  text-decoration: none;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.07);
  transition:
    transform 0.14s ease,
    border-color 0.14s ease,
    box-shadow 0.14s ease,
    background-color 0.14s ease;
}
.entity-chip::before,
.entity-chip::after {
  position: absolute;
  left: 50%;
  z-index: 20;
  opacity: 0;
  pointer-events: none;
  transform: translate(-50%, 0.25rem);
  transition:
    opacity 0.12s ease,
    transform 0.12s ease;
}
.entity-chip::before {
  bottom: calc(100% + 0.35rem);
  width: max-content;
  max-width: min(18rem, 85vw);
  padding: 0.38rem 0.5rem;
  border: 1px solid rgba(15, 23, 42, 0.14);
  border-radius: 0.4rem;
  background: rgba(15, 23, 42, 0.96);
  box-shadow: 0 0.5rem 1.2rem rgba(15, 23, 42, 0.18);
  color: #fff;
  content: attr(data-tooltip);
  font-size: 0.72rem;
  font-weight: 650;
  line-height: 1.25;
  text-align: center;
  white-space: normal;
}
.entity-chip::after {
  bottom: calc(100% + 0.12rem);
  border: 0.26rem solid transparent;
  border-top-color: rgba(15, 23, 42, 0.96);
  content: '';
}
.entity-chip-publication {
  border-color: #0891b2;
  background: #cffafe;
}
.entity-chip-genereview {
  border-color: #2563eb;
  background: #dbeafe;
}
.entity-chip-phenotype {
  border-color: #7c3aed;
  background: #ede9fe;
}
.entity-chip-variation {
  border-color: #16a34a;
  background: #dcfce7;
}
.entity-chip--present {
  border-color: #16a34a;
  background: #dcfce7;
}
.entity-chip--uncertain {
  border-color: #d97706;
  background: #fef3c7;
}
.entity-chip--variable {
  border-color: #2563eb;
  background: #dbeafe;
}
.entity-chip--rare {
  border-color: #7c3aed;
  background: #ede9fe;
}
.entity-chip--absent {
  border-color: #64748b;
  background: #f1f5f9;
  color: #334155;
}
.entity-chip:hover,
.entity-chip:focus {
  border-color: #0f172a;
  background-color: #fff;
  box-shadow: 0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
  color: #0f172a;
  outline: none;
  transform: translateY(-1px);
}
.entity-chip:hover::before,
.entity-chip:hover::after,
.entity-chip:focus::before,
.entity-chip:focus::after {
  opacity: 1;
  transform: translate(-50%, 0);
}
.entity-chip:focus-visible {
  box-shadow:
    0 0 0 0.16rem rgba(13, 110, 253, 0.22),
    0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
}
.entity-empty-state {
  color: var(--neutral-600, #667085);
  font-size: 0.84rem;
  font-weight: 650;
}
@media (prefers-reduced-motion: reduce) {
  .entity-chip {
    transition: none;
  }
  .entity-chip:hover,
  .entity-chip:focus {
    transform: none;
  }
  .entity-chip::before,
  .entity-chip::after {
    transition: none;
  }
}
@media (max-width: 575.98px) {
  .entity-page-title {
    font-size: 1.1rem;
  }
  .entity-hero-body,
  .clinical-synopsis-panel,
  .entity-chip-panel {
    padding: 0.65rem;
  }
  .entity-unit-grid {
    grid-template-columns: 1fr;
  }
  .clinical-card-header {
    align-items: flex-start;
    flex-direction: column;
    gap: 0.15rem;
  }
  .clinical-card-actions {
    align-items: flex-start;
    flex-direction: column;
    gap: 0.25rem;
  }
  .copy-synopsis-button {
    justify-content: center;
  }
  .clinical-synopsis-text {
    font-size: 0.92rem;
  }
}
</style>
