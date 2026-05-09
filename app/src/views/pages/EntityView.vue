<!-- app/src/views/pages/EntityView.vue (v11.3 W3 rewrite) -->
<!--
  Mount order:
    1. useEntityRecord(entityId) fires on tick 0; header card renders skeleton.
    2. useEntityStatus / Review / Publications / Phenotypes / Variation fire in
       parallel on the same tick; each owns its <SectionCard>.
    3. Once the entity record resolves, useGeneRecord(entity.hgnc_id) hydrates
       the linked-gene block.

  Removes the legacy sequential-await bug in the original loader — see spec
  §2.3 finding 6. The page-level BSpinner gate is gone; each subsection owns
  its own skeleton via <SectionCard>.
-->
<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <!-- 1. Entity overview card -->
          <SectionCard
            :loading="entity.loading.value"
            :empty="!entity.loading.value && entity.data.value === null && !entity.error.value"
            :error="entity.error.value ? entity.error.value.message : null"
            :title="entityIdStr ? `Entity: ${entityIdStr}` : 'Entity'"
            min-height="6rem"
          >
            <template #header>
              <h3 class="mb-1 text-start font-weight-bold d-flex align-items-center gap-2 p-1">
                Entity:
                <EntityBadge
                  :entity-id="entityIdStr"
                  :link-to="`/Entities/${entityIdStr}`"
                  size="lg"
                />
              </h3>
            </template>
            <BTable
              v-if="entity.data.value"
              :items="entityItems"
              :fields="entityFields"
              stacked
              small
              fixed
              style="width: 100%; white-space: nowrap"
            >
              <template #cell(symbol)="data">
                <GeneBadge
                  :symbol="String((data.item as EntityRowMap).symbol ?? '')"
                  :hgnc-id="String((data.item as EntityRowMap).hgnc_id ?? '')"
                  :link-to="`/Genes/${String((data.item as EntityRowMap).hgnc_id ?? '')}`"
                />
              </template>

              <template #cell(disease_ontology_name)="data">
                <div class="d-flex align-items-center flex-wrap gap-2">
                  <DiseaseBadge
                    :name="String((data.item as EntityRowMap).disease_ontology_name ?? '')"
                    :ontology-id="
                      String((data.item as EntityRowMap).disease_ontology_id_version ?? '')
                    "
                    :link-to="
                      '/Ontology/' +
                      String((data.item as EntityRowMap).disease_ontology_id_version ?? '').replace(
                        /_.+/g,
                        ''
                      )
                    "
                    :max-length="0"
                  />

                  <BButton
                    v-if="
                      String(
                        (data.item as EntityRowMap).disease_ontology_id_version ?? ''
                      ).includes('OMIM')
                    "
                    class="btn-xs"
                    variant="outline-primary"
                    :href="
                      'https://www.omim.org/entry/' +
                      String((data.item as EntityRowMap).disease_ontology_id_version ?? '')
                        .replace('OMIM:', '')
                        .replace(/_.+/g, '')
                    "
                    target="_blank"
                  >
                    <i class="bi bi-box-arrow-up-right" />
                    {{
                      String((data.item as EntityRowMap).disease_ontology_id_version ?? '').replace(
                        /_.+/g,
                        ''
                      )
                    }}
                  </BButton>

                  <BButton
                    v-if="
                      String(
                        (data.item as EntityRowMap).disease_ontology_id_version ?? ''
                      ).includes('MONDO')
                    "
                    class="btn-xs"
                    variant="outline-primary"
                    :href="
                      'http://purl.obolibrary.org/obo/' +
                      String((data.item as EntityRowMap).disease_ontology_id_version ?? '').replace(
                        ':',
                        '_'
                      )
                    "
                    target="_blank"
                  >
                    <i class="bi bi-box-arrow-up-right" />
                    {{ (data.item as EntityRowMap).disease_ontology_id_version }}
                  </BButton>
                </div>
              </template>

              <template #cell(mondo_equivalent)="data">
                <template v-if="(data.item as EntityRowMap).MONDO">
                  <template v-if="String((data.item as EntityRowMap).MONDO ?? '').includes(';')">
                    <!-- Multiple MONDO mappings -->
                    <span
                      v-for="(mondoId, index) in String(
                        (data.item as EntityRowMap).MONDO ?? ''
                      ).split(';')"
                      :key="mondoId"
                    >
                      <a
                        :href="`https://monarchinitiative.org/disease/${mondoId.trim()}`"
                        target="_blank"
                        rel="noopener"
                      >
                        {{ mondoId.trim() }}
                      </a>
                      <span
                        v-if="
                          index <
                          String((data.item as EntityRowMap).MONDO ?? '').split(';').length - 1
                        "
                        >,
                      </span>
                    </span>
                  </template>
                  <template v-else>
                    <a
                      :href="`https://monarchinitiative.org/disease/${(data.item as EntityRowMap).MONDO}`"
                      target="_blank"
                      rel="noopener"
                    >
                      {{ (data.item as EntityRowMap).MONDO }}
                    </a>
                  </template>
                </template>
                <span
                  v-else-if="(data.item as EntityRowMap).disease_ontology_source === 'mim2gene'"
                  class="text-muted fst-italic"
                >
                  No mapping available
                </span>
                <span v-else />
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <InheritanceBadge
                  :full-name="
                    String((data.item as EntityRowMap).hpo_mode_of_inheritance_term_name ?? '')
                  "
                  :hpo-term="String((data.item as EntityRowMap).hpo_mode_of_inheritance_term ?? '')"
                />
              </template>

              <template #cell(ndd_phenotype_word)="data">
                <span
                  v-b-tooltip.hover.left
                  :title="
                    ndd_icon_text[String((data.item as EntityRowMap).ndd_phenotype_word ?? '')]
                  "
                >
                  <NddIcon
                    :status="String((data.item as EntityRowMap).ndd_phenotype_word ?? '')"
                    :show-title="false"
                  />
                </span>
              </template>
            </BTable>
          </SectionCard>

          <!-- 2. Status -->
          <SectionCard
            :loading="status.loading.value"
            :empty="!status.loading.value && statusRows.length === 0 && !status.error.value"
            :error="status.error.value ? status.error.value.message : null"
            title="Association Category"
          >
            <BTable :items="statusRows" :fields="status_fields" stacked small>
              <template #cell(category)="data">
                <span
                  v-b-tooltip.hover.left
                  :title="String((data.item as EntityRowMap).category ?? '')"
                >
                  <CategoryIcon
                    :category="String((data.item as EntityRowMap).category ?? '')"
                    :show-title="false"
                  />
                </span>
              </template>
            </BTable>
          </SectionCard>

          <!-- 3. Review / clinical synopsis -->
          <SectionCard
            :loading="review.loading.value"
            :empty="!review.loading.value && reviewIsEmpty && !review.error.value"
            :error="review.error.value ? review.error.value.message : null"
            title="Clinical Synopsis"
          >
            <BTable :items="reviewRows" :fields="review_fields" stacked small>
              <template #cell(synopsis)="data">
                <BCard border-variant="dark" align="start">
                  <div class="card-text">
                    {{ (data.item as EntityRowMap).synopsis }}
                  </div>
                </BCard>
              </template>
            </BTable>
          </SectionCard>

          <!-- 4. Publications (additional_references) -->
          <SectionCard
            :loading="publications.loading.value"
            :empty="
              !publications.loading.value &&
              additionalRefs.length === 0 &&
              !publications.error.value
            "
            :error="publications.error.value ? publications.error.value.message : null"
            title="Publications"
          >
            <BTable :items="publications_table" stacked small>
              <template #cell(publications)>
                <BRow>
                  <BRow
                    v-for="publication in additionalRefs"
                    :key="String(publication.publication_id)"
                  >
                    <BCol>
                      <BButton
                        v-b-tooltip.hover.bottom
                        class="btn-xs mx-2"
                        :variant="
                          (publication_style[String(publication.publication_type ?? '')] ??
                            'outline-primary') as ButtonVariant
                        "
                        :href="
                          'https://pubmed.ncbi.nlm.nih.gov/' +
                          String(publication.publication_id).replace(/^PMID:\s*/, '')
                        "
                        target="_blank"
                        :title="publication_hover_text[String(publication.publication_type ?? '')]"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ publication.publication_id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>
          </SectionCard>

          <!-- 5. Gene Reviews (filtered from same publications call) -->
          <SectionCard
            :loading="publications.loading.value"
            :empty="
              !publications.loading.value && geneReviews.length === 0 && !publications.error.value
            "
            :error="publications.error.value ? publications.error.value.message : null"
            title="Gene Reviews"
          >
            <BTable :items="genereviews_table" stacked small>
              <template #cell(genereviews)>
                <BRow>
                  <BRow
                    v-for="publication in geneReviews"
                    :key="String(publication.publication_id)"
                  >
                    <BCol>
                      <BButton
                        v-b-tooltip.hover.bottom
                        class="btn-xs mx-2"
                        :variant="
                          (publication_style[String(publication.publication_type ?? '')] ??
                            'outline-primary') as ButtonVariant
                        "
                        :href="
                          'https://pubmed.ncbi.nlm.nih.gov/' +
                          String(publication.publication_id).replace(/^PMID:\s*/, '')
                        "
                        target="_blank"
                        :title="publication_hover_text[String(publication.publication_type ?? '')]"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ publication.publication_id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>
          </SectionCard>

          <!-- 6. Phenotypes -->
          <SectionCard
            :loading="phenotypes.loading.value"
            :empty="
              !phenotypes.loading.value && phenotypesList.length === 0 && !phenotypes.error.value
            "
            :error="phenotypes.error.value ? phenotypes.error.value.message : null"
            title="Phenotypes"
          >
            <BTable :items="phenotypes_table" stacked small>
              <template #cell(phenotypes)>
                <BRow>
                  <BRow v-for="phenotype in phenotypesList" :key="String(phenotype.phenotype_id)">
                    <BCol>
                      <BButton
                        v-b-tooltip.hover.bottom
                        class="btn-xs mx-2"
                        :variant="
                          (modifier_style[Number(phenotype.modifier_id)] ??
                            'outline-primary') as ButtonVariant
                        "
                        :href="
                          'https://hpo.jax.org/app/browse/term/' +
                          String(phenotype.phenotype_id ?? '')
                        "
                        target="_blank"
                        :title="
                          (modifier_text[Number(phenotype.modifier_id)] ?? '') +
                          '; ' +
                          String(phenotype.phenotype_id ?? '')
                        "
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ phenotype.HPO_term }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>
          </SectionCard>

          <!-- 7. Variation -->
          <SectionCard
            :loading="variation.loading.value"
            :empty="
              !variation.loading.value && variationList.length === 0 && !variation.error.value
            "
            :error="variation.error.value ? variation.error.value.message : null"
            title="Variation Ontology"
          >
            <BTable :items="variation_table" stacked small>
              <template #cell(variation)>
                <BRow>
                  <BRow v-for="variant in variationList" :key="String(variant.vario_id)">
                    <BCol>
                      <BButton
                        v-b-tooltip.hover.bottom
                        class="btn-xs mx-2"
                        :variant="
                          (modifier_style[Number(variant.modifier_id)] ??
                            'outline-primary') as ButtonVariant
                        "
                        :href="
                          'http://aber-owl.net/ontology/VARIO/#/Browse/%3Chttp%3A%2F%2Fpurl.obolibrary.org%2Fobo%2F' +
                          String(variant.vario_id ?? '').replace(':', '_') +
                          '%3E'
                        "
                        target="_blank"
                        :title="
                          (modifier_text[Number(variant.modifier_id)] ?? '') +
                          '; ' +
                          String(variant.vario_id ?? '')
                        "
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ variant.vario_name }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>
          </SectionCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useHead } from '@unhead/vue';
import { BContainer, BRow, BCol, BCard, BTable, BButton } from 'bootstrap-vue-next';
import type { ButtonVariant } from 'bootstrap-vue-next';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import SectionCard from '@/components/ui/SectionCard.vue';
import { useColorAndSymbols, useText } from '@/composables';
import { useEntityRecord } from '@/composables/useEntityRecord';
import { useEntityStatus } from '@/composables/useEntityStatus';
import { useEntityReview } from '@/composables/useEntityReview';
import { useEntityPublications } from '@/composables/useEntityPublications';
import { useEntityPhenotypes } from '@/composables/useEntityPhenotypes';
import { useEntityVariation } from '@/composables/useEntityVariation';
import { useGeneRecord } from '@/composables/useGeneRecord';

const route = useRoute();
const router = useRouter();

type EntityRowMap = Record<string, unknown>;

const { publication_style, modifier_style } = useColorAndSymbols();
const { ndd_icon_text, publication_hover_text, modifier_text } = useText();

const entityIdStr = computed(() => String(route.params.entity_id ?? ''));

// All six entity-side hooks fire on tick 0 — no sequential awaits.
const entity = useEntityRecord(entityIdStr);
const status = useEntityStatus(entityIdStr);
const review = useEntityReview(entityIdStr);
const publications = useEntityPublications(entityIdStr);
const phenotypes = useEntityPhenotypes(entityIdStr);
const variation = useEntityVariation(entityIdStr);

// Linked gene fires when the entity record resolves with a hgnc_id.
const hgncIdRef = computed<string | null>(() => {
  const e = entity.data.value as Record<string, unknown> | null;
  const v = e?.hgnc_id;
  return typeof v === 'string' && v ? v : null;
});
// Mounted unconditionally; the hook becomes inert when the ref is null.
useGeneRecord(hgncIdRef);

// Wrap the single entity row in an array so BTable can render it stacked.
const entityItems = computed(() => {
  const row = entity.data.value as Record<string, unknown> | null;
  return row ? [row] : [];
});

// API returns arrays for each nested resource; coerce defensively.
const statusRows = computed(() => {
  const data = status.data.value as unknown;
  return Array.isArray(data) ? data : data ? [data] : [];
});
const reviewRows = computed(() => {
  const data = review.data.value as unknown;
  return Array.isArray(data) ? data : data ? [data] : [];
});
const publicationsList = computed<Array<Record<string, unknown>>>(() => {
  const data = publications.data.value as unknown;
  return Array.isArray(data) ? (data as Array<Record<string, unknown>>) : [];
});
const phenotypesList = computed<Array<Record<string, unknown>>>(() => {
  const data = phenotypes.data.value as unknown;
  return Array.isArray(data) ? (data as Array<Record<string, unknown>>) : [];
});
const variationList = computed<Array<Record<string, unknown>>>(() => {
  const data = variation.data.value as unknown;
  return Array.isArray(data) ? (data as Array<Record<string, unknown>>) : [];
});

// Publications client-side split — the existing endpoint feeds both cards.
const additionalRefs = computed(() =>
  publicationsList.value.filter(
    (p) => (p as Record<string, unknown>).publication_type === 'additional_references'
  )
);
const geneReviews = computed(() =>
  publicationsList.value.filter(
    (p) => (p as Record<string, unknown>).publication_type === 'gene_review'
  )
);

// Review empty when no row carries a non-blank synopsis or comment.
const reviewIsEmpty = computed(() => {
  const rows = reviewRows.value as Array<Record<string, unknown>>;
  if (rows.length === 0) return true;
  return rows.every((r) => {
    const synopsisBlank = !r.synopsis || String(r.synopsis).trim() === '';
    const commentBlank = !r.comment || String(r.comment).trim() === '';
    return synopsisBlank && commentBlank;
  });
});

// 404 redirect: fire once the record resolves to null without an error. Watch
// both the loading and data refs so cold null→null transitions still trigger
// (matches the GeneView watcher pattern from W2).
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

const entityFields = [
  { key: 'symbol', label: 'Gene Symbol', sortable: true, class: 'text-start' },
  {
    key: 'disease_ontology_name',
    label: 'Disease',
    sortable: true,
    class: 'text-start',
    sortByFormatted: true,
    filterByFormatted: true,
  },
  {
    key: 'mondo_equivalent',
    label: 'MONDO Equivalent',
    sortable: false,
    class: 'text-start',
  },
  {
    key: 'hpo_mode_of_inheritance_term_name',
    label: 'Inheritance',
    sortable: true,
    class: 'text-start',
    sortByFormatted: true,
    filterByFormatted: true,
  },
  { key: 'ndd_phenotype_word', label: 'NDD', sortable: true, class: 'text-start' },
];
const status_fields = [{ key: 'category', label: 'Association Category', class: 'text-start' }];
const review_fields = [{ key: 'synopsis', label: 'Clinical Synopsis', class: 'text-start' }];

// Single-row stacked tables for the rich publication / phenotype / variation lists.
const publications_table = [{ publications: '' }];
const genereviews_table = [{ genereviews: '' }];
const phenotypes_table = [{ phenotypes: '' }];
const variation_table = [{ variation: '' }];

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
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
</style>
