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

  Presentation split (#346): the hero, clinical synopsis, and evidence-grid
  markup/styles live in EntityViewHero / ClinicalSynopsisCard /
  EntityEvidenceGrid (app/src/views/pages/components/). This file keeps all
  seven resource composables, the parallel fetch fan-out, the 404 redirect,
  useHead, and the clipboard-copy implementation — each child receives one
  focused display model computed here, plus (for the copy button) a `copy`
  emit routed back to `copySynopsis`.
-->
<template>
  <div class="container-fluid bg-gradient entity-detail-page">
    <BContainer fluid>
      <EntityViewHero :model="heroModel" />

      <EntityOntologiesCard :entity-id="entityIdStr" />

      <ClinicalSynopsisCard :model="synopsisModel" @copy="copySynopsis" />

      <EntityEvidenceGrid :model="evidenceModel" />
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useHead } from '@unhead/vue';
import { BContainer } from 'bootstrap-vue-next';
import { useEntityRecord } from '@/composables/useEntityRecord';
import { useEntityStatus } from '@/composables/useEntityStatus';
import { useEntityReview } from '@/composables/useEntityReview';
import { useEntityPublications } from '@/composables/useEntityPublications';
import { useEntityPhenotypes } from '@/composables/useEntityPhenotypes';
import { useEntityVariation } from '@/composables/useEntityVariation';
import { useGeneRecord } from '@/composables/useGeneRecord';
import EntityOntologiesCard from '@/components/disease/EntityOntologiesCard.vue';
import EntityViewHero, { type EntityHeroModel } from './components/EntityViewHero.vue';
import ClinicalSynopsisCard, {
  type ClinicalSynopsisModel,
} from './components/ClinicalSynopsisCard.vue';
import EntityEvidenceGrid, { type EntityEvidenceModel } from './components/EntityEvidenceGrid.vue';
import { returnToFromRoute } from '@/utils/returnNavigation';

const route = useRoute();
const router = useRouter();
const backToResults = computed(() => returnToFromRoute(route, ''));

type EntityRowMap = Record<string, unknown>;

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

const heroModel = computed<EntityHeroModel>(() => ({
  entityIdStr: entityIdStr.value,
  backToResults: backToResults.value,
  loading: entity.loading.value,
  empty: !entity.loading.value && entity.data.value === null && !entity.error.value,
  error: entity.error.value ? entity.error.value.message : null,
  hasRecord: entityRow.value !== null,
  geneSymbol: geneSymbol.value,
  hgncId: hgncId.value,
  geneLink: geneLink.value,
  inheritanceName: inheritanceName.value,
  inheritanceTerm: inheritanceTerm.value,
  diseaseName: diseaseName.value,
  diseaseOntologyId: diseaseOntologyId.value,
  diseaseLink: diseaseLink.value,
  categoryLabel: categoryLabel.value,
  diseaseSourceId: diseaseSourceId.value,
  diseaseSourceUrl: diseaseSourceUrl.value,
  nddStatus: nddStatus.value,
  entryDate: entityRow.value?.entry_date,
  lastUpdate: entityRow.value?.last_update,
}));

const synopsisModel = computed<ClinicalSynopsisModel>(() => ({
  loading: review.loading.value,
  error: review.error.value ? review.error.value.message : null,
  reviewDate: reviewDate.value,
  synopsisText: synopsisText.value,
  copyButtonLabel: copyButtonLabel.value,
}));

const evidenceModel = computed<EntityEvidenceModel>(() => ({
  publications: {
    loading: publications.loading.value,
    error: publications.error.value ? publications.error.value.message : null,
    additionalRefs: additionalRefs.value,
    geneReviews: geneReviews.value,
  },
  phenotypes: {
    loading: phenotypes.loading.value,
    error: phenotypes.error.value ? phenotypes.error.value.message : null,
    list: phenotypesList.value,
  },
  variation: {
    loading: variation.loading.value,
    error: variation.error.value ? variation.error.value.message : null,
    list: variationList.value,
  },
}));

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
</style>
