<!-- views/curate/components/ReviewFormFields.vue -->
<template>
  <BOverlay :show="loading" rounded="sm">
    <BForm @submit.stop.prevent>
      <!-- Synopsis textarea -->
      <label class="mr-sm-2 font-weight-bold" for="review-textarea-synopsis">Synopsis</label>

      <BBadge id="popover-badge-help-synopsis" pill href="#" variant="info">
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover target="popover-badge-help-synopsis" variant="info" triggers="focus">
        <template #title> Synopsis instructions </template>
        Short summary for this disease entity. Please include information on: <br />
        <strong>a)</strong> approximate number of patients described in literature, <br />
        <strong>b)</strong> nature of reported variants, <br />
        <strong>c)</strong> severity of intellectual disability, <br />
        <strong>d)</strong> further phenotypic aspects (if possible with frequencies), <br />
        <strong>e)</strong> any valuable further information (e.g. genotype-phenotype
        correlations).<br />
      </BPopover>

      <BFormTextarea
        id="review-textarea-synopsis"
        v-model="localFormData.synopsis"
        rows="3"
        size="sm"
        :readonly="readonly"
      />
      <!-- Synopsis textarea -->

      <!-- Phenotype select -->
      <label class="mr-sm-2 font-weight-bold" for="review-phenotype-select">Phenotypes</label>

      <BBadge id="popover-badge-help-phenotypes" pill href="#" variant="info">
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover target="popover-badge-help-phenotypes" variant="info" triggers="focus">
        <template #title> Phenotypes instructions </template>
        Add or remove associated phenotypes. Only phenotypes that occur in 20% or more of affected
        individuals should be included. Please also include information on severity of ID.
      </BPopover>

      <TreeMultiSelect
        v-if="phenotypesOptions && phenotypesOptions.length > 0"
        id="review-phenotype-select"
        v-model="localFormData.phenotypes"
        :options="phenotypesOptions"
        placeholder="Select phenotypes..."
        search-placeholder="Search phenotypes (name or HP:ID)..."
        :disabled="readonly"
      />
      <!-- Phenotype select -->

      <!-- Variation ontology select -->
      <label class="mr-sm-2 font-weight-bold" for="review-variation-select"
        >Variation ontology</label
      >

      <BBadge id="popover-badge-help-variation" pill href="#" variant="info">
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover target="popover-badge-help-variation" variant="info" triggers="focus">
        <template #title> Variation instructions </template>
        Please select or deselect the types of variation associated with the disease entity.
        <br />
        Minimum information should include <strong>"protein truncating variation"</strong> and/or
        <strong>"non-synonymous variation"</strong>.
        <br />
        If known, please also select the functional impact of these variations, i.e. if there is a
        protein <strong>"loss-of-function"</strong> or <strong>"gain-of-function"</strong>.
        <br />
      </BPopover>

      <!--
        #608 — three-zone provenance picker.

        Rendered ONLY when there is something to decide (`hasZones`). With no
        machine-derived term and no suggestion the form is byte-for-byte the
        pre-#608 plain picker — which is production on day one, before the
        provenance backfill runs.
      -->
      <div v-if="zonesActive" class="vario-zones" data-testid="variation-provenance-zones">
        <section
          v-if="zoneConfirmed.length"
          class="vario-zones__zone"
          aria-labelledby="vario-zone-confirmed-heading"
          data-testid="variation-zone-confirmed"
        >
          <h6 id="vario-zone-confirmed-heading" class="vario-zones__heading">
            Confirmed
            <span class="vario-zones__count" data-testid="variation-zone-confirmed-count">
              {{ termCount(zoneConfirmed.length) }}
            </span>
          </h6>
          <ul class="vario-zones__chips">
            <li
              v-for="entry in zoneConfirmed"
              :key="entry.tag"
              data-testid="variation-confirmed-chip"
              :data-tag="entry.tag"
            >
              <span class="sysndd-chip sysndd-chip--neutral">
                <i class="bi bi-check2 me-1" aria-hidden="true" />
                {{ displayName(entry) }} ({{ entry.modifierLabel }})
              </span>
            </li>
          </ul>
        </section>

        <section
          v-if="zoneNeedsConfirmation.length"
          class="vario-zones__zone"
          aria-labelledby="vario-zone-needs-confirmation-heading"
          data-testid="variation-zone-needs-confirmation"
        >
          <h6 id="vario-zone-needs-confirmation-heading" class="vario-zones__heading">
            Needs confirmation
            <span class="vario-zones__count" data-testid="variation-zone-needs-confirmation-count">
              {{ termCount(zoneNeedsConfirmation.length) }}
            </span>
          </h6>
          <p class="vario-zones__hint">
            Machine-derived from the sources below. Saving leaves an unconfirmed term in place; only
            Confirm records that you agree with it.
          </p>
          <ul class="vario-zones__cards">
            <VariationProvenanceCard
              v-for="entry in zoneNeedsConfirmation"
              :key="entry.tag"
              :entry="entry"
              :display-name="displayName(entry)"
              primary-label="Confirm"
              secondary-label="Remove"
              primary-testid="variation-action-confirm"
              secondary-testid="variation-action-remove"
              :disabled="readonly"
              @primary="variationZones?.confirmTerm(entry.tag)"
              @secondary="variationZones?.removeTerm(entry.tag)"
            />
          </ul>
        </section>

        <section
          v-if="zoneSuggested.length"
          class="vario-zones__zone"
          aria-labelledby="vario-zone-suggested-heading"
          data-testid="variation-zone-suggested"
        >
          <h6 id="vario-zone-suggested-heading" class="vario-zones__heading">
            Suggested — not in the entity
            <span class="vario-zones__count" data-testid="variation-zone-suggested-count">
              {{ termCount(zoneSuggested.length) }}
            </span>
          </h6>
          <p class="vario-zones__hint">Candidate terms. Nothing is added until you accept it.</p>
          <ul class="vario-zones__cards">
            <VariationProvenanceCard
              v-for="entry in zoneSuggested"
              :key="entry.tag"
              :entry="entry"
              :display-name="displayName(entry)"
              primary-label="Accept"
              secondary-label="Dismiss"
              primary-testid="variation-action-accept"
              secondary-testid="variation-action-dismiss"
              :disabled="readonly"
              @primary="variationZones?.acceptSuggestion(entry.tag)"
              @secondary="variationZones?.dismissSuggestion(entry.tag)"
            />
          </ul>
        </section>
      </div>

      <TreeMultiSelect
        v-if="variationOptions && variationOptions.length > 0"
        id="review-variation-select"
        v-model="localFormData.variationOntology"
        :options="variationOptions"
        placeholder="Select variations..."
        search-placeholder="Search variation types..."
        :disabled="readonly"
      />
      <!-- Variation ontology select -->

      <!-- publications tag form with links out -->
      <label class="mr-sm-2 font-weight-bold" for="review-publications-select">Publications</label>

      <BBadge id="popover-badge-help-publications" pill href="#" variant="info">
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover target="popover-badge-help-publications" variant="info" triggers="focus">
        <template #title> Publications instructions </template>
        No complete catalog of entity-related literature required.
        <br />
        If information in the clinical synopsis is not only based on OMIM entries, please include
        PMID of the article(s) used as a source for the clinical synopsis. <br />
        - Input is only valid when starting with
        <strong>"PMID:"</strong> followed by a number
      </BPopover>

      <BFormTags
        v-model="localFormData.publications"
        input-id="review-literature-select"
        no-outer-focus
        class="my-0"
        separator=",;"
        :tag-validator="tagValidatorPMID"
        remove-on-delete
        :disabled="readonly"
      >
        <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
          <BInputGroup class="my-0">
            <BFormInput
              v-bind="inputAttrs"
              placeholder="Enter PMIDs separated by comma or semicolon"
              class="form-control"
              size="sm"
              :disabled="readonly"
              v-on="inputHandlers"
            />
            <BButton variant="secondary" size="sm" :disabled="readonly" @click="addTag()">
              Add
            </BButton>
          </BInputGroup>

          <div class="d-inline-block">
            <h6>
              <BFormTag
                v-for="tag in tags"
                :key="tag"
                :title="tag"
                variant="secondary"
                @remove="removeTag(tag)"
              >
                <BLink
                  :href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')"
                  target="_blank"
                  class="text-light"
                >
                  <i class="bi bi-box-arrow-up-right" />
                  {{ tag }}
                </BLink>
              </BFormTag>
            </h6>
          </div>
        </template>
      </BFormTags>
      <!-- publications tag form with links out -->

      <!-- genereviews tag form with links out -->
      <label class="mr-sm-2 font-weight-bold" for="review-genereviews-select">Genereviews</label>

      <BBadge id="popover-badge-help-genereviews" pill href="#" variant="info">
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover target="popover-badge-help-genereviews" variant="info" triggers="focus">
        <template #title> GeneReviews instructions </template>
        Please add PMID for GeneReview article if available for this entity. <br />
        - Input is only valid when starting with
        <strong>"PMID:"</strong> followed by a number
      </BPopover>

      <BFormTags
        v-model="localFormData.genereviews"
        input-id="review-genereviews-select"
        no-outer-focus
        class="my-0"
        separator=",;"
        :tag-validator="tagValidatorPMID"
        remove-on-delete
        :disabled="readonly"
      >
        <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
          <BInputGroup class="my-0">
            <BFormInput
              v-bind="inputAttrs"
              placeholder="Enter PMIDs separated by comma or semicolon"
              class="form-control"
              size="sm"
              :disabled="readonly"
              v-on="inputHandlers"
            />
            <BButton variant="secondary" size="sm" :disabled="readonly" @click="addTag()">
              Add
            </BButton>
          </BInputGroup>

          <div class="d-inline-block">
            <h6>
              <BFormTag
                v-for="tag in tags"
                :key="tag"
                :title="tag"
                variant="secondary"
                @remove="removeTag(tag)"
              >
                <BLink
                  :href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')"
                  target="_blank"
                  class="text-light"
                >
                  <i class="bi bi-box-arrow-up-right" />
                  {{ tag }}
                </BLink>
              </BFormTag>
            </h6>
          </div>
        </template>
      </BFormTags>
      <!-- genereviews tag form with links out -->

      <!-- Review comment textarea -->
      <label class="mr-sm-2 font-weight-bold" for="review-textarea-comment">Comment</label>
      <BFormTextarea
        id="review-textarea-comment"
        v-model="localFormData.comment"
        rows="2"
        size="sm"
        placeholder="Additional comments to this entity relevant for the curator."
        :readonly="readonly"
      />
      <!-- Review comment textarea -->
    </BForm>
  </BOverlay>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';
import VariationProvenanceCard from '@/views/curate/components/VariationProvenanceCard.vue';
import type { ReviewFormData } from '@/views/curate/composables/useReviewForm';
import type {
  VariationProvenanceZonesApi,
  VariationZoneEntry,
} from '@/views/curate/composables/useVariationProvenanceZones';

interface TreeNode {
  id: string;
  label: string;
  children?: TreeNode[];
  [key: string]: unknown;
}

interface Props {
  modelValue: ReviewFormData;
  phenotypesOptions: TreeNode[];
  variationOptions: TreeNode[];
  loading?: boolean;
  readonly?: boolean;
  /**
   * #608 — variation-ontology provenance zones, owned by the parent's
   * `useReviewForm` composable so the zones and the picker share one selection.
   * `null` (the default) keeps this component exactly as it was pre-#608.
   */
  variationZones?: VariationProvenanceZonesApi | null;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  readonly: false,
  variationZones: null,
});

const emit = defineEmits<{
  (e: 'update:modelValue', value: ReviewFormData): void;
}>();

// Create local computed for v-model binding
const localFormData = computed({
  get: () => props.modelValue,
  set: (val: ReviewFormData) => emit('update:modelValue', val),
});

// ---------------------------------------------------------------------------
// #608 variation-ontology provenance zones
// ---------------------------------------------------------------------------

// The zones API exposes refs, and a prop object's nested refs are NOT unwrapped
// in the template, so each zone is re-exposed through a local computed.
const zonesActive = computed(() => Boolean(props.variationZones?.hasZones.value));
const zoneConfirmed = computed(() => props.variationZones?.confirmed.value ?? []);
const zoneNeedsConfirmation = computed(() => props.variationZones?.needsConfirmation.value ?? []);
const zoneSuggested = computed(() => props.variationZones?.suggested.value ?? []);

/**
 * Flatten the TreeMultiSelect options so a term the API did not name (e.g. one
 * the curator added in this session) can still be shown by its human label.
 * Option ids are the same `"<modifier_id>-<vario_id>"` tags the zones use.
 */
const variationLabelById = computed(() => {
  const labels = new Map<string, string>();
  const walk = (nodes: TreeNode[] | undefined): void => {
    (nodes ?? []).forEach((node) => {
      if (node?.id !== undefined && node?.id !== null) {
        labels.set(String(node.id), String(node.label ?? node.id));
      }
      walk(node?.children);
    });
  };
  walk(props.variationOptions);
  return labels;
});

/** Server-supplied name wins; then the tree label; then the bare CURIE. */
const displayName = (entry: VariationZoneEntry): string =>
  entry.varioName ||
  variationLabelById.value.get(entry.tag) ||
  variationLabelById.value.get(entry.varioId) ||
  entry.varioId;

/** Honest, grammatical count — exposed in TEXT, not conveyed by position. */
const termCount = (count: number): string => `${count} term${count === 1 ? '' : 's'}`;

/**
 * PMID tag validator
 */
const tagValidatorPMID = (tag: string): boolean => {
  const tagCopy = tag.replace(/\s+/g, '');
  const pmidNumber = tagCopy.replace(/PMID:/g, '').replace(/ /g, '');
  return (
    !Number.isNaN(Number(pmidNumber)) &&
    tagCopy.includes('PMID:') &&
    tagCopy.replace('PMID:', '').length > 4 &&
    tagCopy.replace('PMID:', '').length < 9
  );
};
</script>

<style scoped>
/* #608 variation-ontology provenance zones.
   Quiet by design: one bounded surface, neutral tokens, no status hues. An
   unconfirmed annotation is un-reviewed, not broken — saturated colour is
   reserved for the action buttons inside VariationProvenanceCard. */
.vario-zones {
  display: grid;
  gap: 0.6rem;
  margin: 0.35rem 0 0.5rem;
  padding: 0.6rem;
  border: 1px solid var(--border-subtle, #d9e0ea);
  border-radius: var(--radius-md, 0.375rem);
  background: var(--neutral-50, #fafafa);
}

.vario-zones__zone {
  display: grid;
  gap: 0.35rem;
  min-width: 0;
}

.vario-zones__heading {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.vario-zones__count {
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: none;
  letter-spacing: normal;
}

.vario-zones__hint {
  margin: 0;
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  line-height: 1.4;
}

.vario-zones__chips,
.vario-zones__cards {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.vario-zones__cards {
  display: grid;
  gap: 0.4rem;
}
</style>
