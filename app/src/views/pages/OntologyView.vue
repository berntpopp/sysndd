<!-- app/src/views/pages/OntologyView.vue -->
<!--
  Disease Ontology view — clinical hero with primary identifier, scope,
  inheritance, cross-ontology mappings & external references card, and
  associated entities table. Unified with GeneView and EntityView design standards.
-->
<template>
  <div class="container-fluid bg-gradient ontology-page">
    <BContainer fluid>
      <!-- 1. Disease Hero Section -->
      <OntologyHero :model="heroModel" />

      <!-- 2. Cross-Ontology Mappings & External References -->
      <BRow v-if="!loading && hasCrossMappings" class="justify-content-md-center py-2">
        <BCol cols="12">
          <BCard class="border-subtle" body-class="p-2" header-class="p-2 bg-light">
            <template #header>
              <div class="d-flex align-items-center justify-content-between flex-wrap gap-2">
                <span class="fw-semibold text-secondary small text-uppercase tracking-wider">
                  <i class="bi bi-diagram-2 me-1" aria-hidden="true" />
                  Cross-Ontology Mappings & External Databases
                </span>
                <span v-if="heroModel.mappingRelease" class="badge text-bg-light border text-muted">
                  Release {{ heroModel.mappingRelease }}
                </span>
              </div>
            </template>
            <div class="d-flex flex-wrap align-items-center gap-2">
              <IdentifierRow
                v-for="mapping in crossMappings"
                :key="`${mapping.prefix}-${mapping.id}`"
                compact
                label=""
                :value="mapping.id"
                :external-url="mapping.url"
                :external-label="mapping.prefix"
                :show-copy="true"
              />
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- 3. Associated Entities Table -->
      <div v-if="entityFilter" id="associated-entities-table" class="pt-2">
        <TablesEntities
          :show-filter-controls="true"
          :show-search-input="true"
          :show-pagination-controls="true"
          header-label="Associated "
          :filter-input="entityFilter"
          :disable-url-sync="false"
          :skeleton-rows="5"
        />
      </div>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useHead } from '@unhead/vue';
import { BContainer, BRow, BCol, BCard } from 'bootstrap-vue-next';
import { getOntology, type OntologyTerm } from '@/api/ontology';
import { ontologyOutlink, type OntologyPrefix } from '@/assets/js/constants/ontology_links';
import { returnToFromRoute } from '@/utils/returnNavigation';
import useToast from '@/composables/useToast';
import TablesEntities from '@/components/tables/TablesEntities.vue';
import IdentifierRow from '@/components/gene/IdentifierRow.vue';
import OntologyHero, { type OntologyHeroModel } from './components/OntologyHero.vue';

const route = useRoute();
const router = useRouter();
const { makeToast } = useToast();

const backToResults = computed(() => returnToFromRoute(route, ''));
const diseaseTermParam = computed(() => String(route.params.disease_term || '').trim());

const loading = ref(true);
const error = ref<string | null>(null);
const ontologyRecord = ref<OntologyTerm | null>(null);

const asString = (val: unknown): string => (val == null ? '' : String(val).trim());
const asArray = (val: unknown): string[] =>
  Array.isArray(val)
    ? val.map(asString).filter((s) => s && s !== 'null')
    : typeof val === 'string' && val && val !== 'null'
      ? [val.trim()]
      : [];

const primaryId = computed(() => {
  const rec = ontologyRecord.value;
  const ids = asArray(rec?.disease_ontology_id);
  if (ids.length > 0) return ids[0];
  const versions = asArray(rec?.disease_ontology_id_version);
  if (versions.length > 0) return versions[0].replace(/_.+/g, '');
  return diseaseTermParam.value;
});

const primaryPrefix = computed(() => {
  const id = primaryId.value;
  const match = id.match(/^([A-Za-z]+):/);
  return match ? match[1] : 'MONDO';
});

const primaryOutlink = computed(() => {
  return ontologyOutlink(primaryPrefix.value, primaryId.value);
});

const displayName = computed(() => {
  const names = asArray(ontologyRecord.value?.disease_ontology_name);
  if (names.length > 0) return names[0];
  return primaryId.value;
});

const synonyms = computed(() => {
  return asArray(ontologyRecord.value?.disease_ontology_name);
});

const versions = computed(() => {
  return asArray(ontologyRecord.value?.disease_ontology_id_version);
});

const source = computed(() => {
  const sources = asArray(ontologyRecord.value?.disease_ontology_source);
  return sources.length > 0 ? sources[0] : '';
});

const isSpecific = computed(() => {
  const specs = asArray(ontologyRecord.value?.disease_ontology_is_specific);
  return specs.length > 0 ? specs[0] : '0';
});

const inheritanceName = computed(() => {
  const inhs = asArray(ontologyRecord.value?.hpo_mode_of_inheritance_term_name);
  return inhs.length > 0 ? inhs[0] : '';
});

const inheritanceTerm = computed(() => {
  const terms = asArray(ontologyRecord.value?.hpo_mode_of_inheritance_term);
  return terms.length > 0 ? terms[0] : '';
});

const mappingRelease = computed(() => {
  const rels = asArray(ontologyRecord.value?.ontology_mapping_release);
  return rels.length > 0 ? rels[0] : '';
});

const heroModel = computed<OntologyHeroModel>(() => ({
  diseaseTerm: diseaseTermParam.value,
  primaryId: primaryId.value,
  primaryPrefix: primaryPrefix.value,
  displayName: displayName.value,
  primaryOutlink: primaryOutlink.value,
  source: source.value,
  isSpecific: isSpecific.value,
  inheritanceName: inheritanceName.value,
  inheritanceTerm: inheritanceTerm.value,
  mappingRelease: mappingRelease.value,
  versions: versions.value,
  synonyms: synonyms.value,
  backToResults: backToResults.value,
  loading: loading.value,
  empty: !loading.value && ontologyRecord.value === null && !error.value,
  error: error.value,
  hasRecord: ontologyRecord.value !== null,
}));

const ALLOWED_CROSS_PREFIXES: OntologyPrefix[] = [
  'MONDO',
  'OMIM',
  'Orphanet',
  'DOID',
  'UMLS',
  'MedGen',
  'NCIT',
  'GARD',
  'EFO',
];

interface CrossMappingEntry {
  prefix: string;
  id: string;
  url?: string;
}

const crossMappings = computed<CrossMappingEntry[]>(() => {
  if (!ontologyRecord.value) return [];
  const rec = ontologyRecord.value;
  const list: CrossMappingEntry[] = [];
  const primary = primaryId.value;

  for (const prefix of ALLOWED_CROSS_PREFIXES) {
    const raw = rec[prefix as keyof OntologyTerm];
    const ids = asArray(raw);
    for (const id of ids) {
      if (id === primary || id.replace(/_.+/g, '') === primary.replace(/_.+/g, '')) continue;
      const outlink = ontologyOutlink(prefix, id);
      list.push({
        prefix,
        id,
        url: outlink.url ?? undefined,
      });
    }
  }
  return list;
});

const hasCrossMappings = computed(() => crossMappings.value.length > 0);

const entityFilter = computed(() => {
  const vers = versions.value;
  if (vers.length > 0) {
    return `any(disease_ontology_id_version,${vers.join(',')})`;
  }
  const term = diseaseTermParam.value;
  return term ? `any(disease_ontology_id_version,${term})` : '';
});

async function fetchOntologyData(term: string) {
  if (!term) return;
  loading.value = true;
  error.value = null;

  try {
    const [ontologyData, nameData] = await Promise.all([
      getOntology(term, { input_type: 'ontology_id' }).catch(() => [] as OntologyTerm[]),
      getOntology(term, { input_type: 'ontology_name' }).catch(() => [] as OntologyTerm[]),
    ]);

    if (ontologyData.length === 0 && nameData.length === 0) {
      router.push('/PageNotFound');
      return;
    }

    ontologyRecord.value = ontologyData.length > 0 ? ontologyData[0] : nameData[0];
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Error loading disease ontology';
    error.value = message;
    makeToast(message, 'Error', 'danger');
  } finally {
    loading.value = false;
  }
}

watch(
  diseaseTermParam,
  (term) => {
    fetchOntologyData(term);
  },
  { immediate: true }
);

useHead({
  title: computed(() => (displayName.value ? `${displayName.value} - Ontology` : 'Ontology')),
  meta: [
    {
      name: 'description',
      content: computed(() =>
        displayName.value
          ? `SysNDD disease ontology details and associated curated entities for ${displayName.value}.`
          : 'SysNDD disease ontology details.'
      ),
    },
  ],
});
</script>

<style scoped>
.ontology-page {
  padding-bottom: 2rem;
}
.tracking-wider {
  letter-spacing: 0.05em;
}
</style>
