<!-- views/curate/components/ReviewFormFields.vue -->
<template>
  <BOverlay
    :show="loading"
    rounded="sm"
  >
    <BForm @submit.stop.prevent>
      <!-- Synopsis textarea -->
      <label
        class="mr-sm-2 font-weight-bold"
        for="review-textarea-synopsis"
      >Synopsis</label>

      <BBadge
        id="popover-badge-help-synopsis"
        pill
        href="#"
        variant="info"
      >
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover
        target="popover-badge-help-synopsis"
        variant="info"
        triggers="focus"
      >
        <template #title>
          Synopsis instructions
        </template>
        Short summary for this disease entity. Please include information
        on: <br>
        <strong>a)</strong> approximate number of patients described in
        literature, <br>
        <strong>b)</strong> nature of reported variants, <br>
        <strong>c)</strong> severity of intellectual disability, <br>
        <strong>d)</strong> further phenotypic aspects (if possible with
        frequencies), <br>
        <strong>e)</strong> any valuable further information (e.g.
        genotype-phenotype correlations).<br>
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
      <label
        class="mr-sm-2 font-weight-bold"
        for="review-phenotype-select"
      >Phenotypes</label>

      <BBadge
        id="popover-badge-help-phenotypes"
        pill
        href="#"
        variant="info"
      >
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover
        target="popover-badge-help-phenotypes"
        variant="info"
        triggers="focus"
      >
        <template #title>
          Phenotypes instructions
        </template>
        Add or remove associated phenotypes. Only phenotypes that occur in
        20% or more of affected individuals should be included. Please
        also include information on severity of ID.
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
      <label
        class="mr-sm-2 font-weight-bold"
        for="review-variation-select"
      >Variation ontology</label>

      <BBadge
        id="popover-badge-help-variation"
        pill
        href="#"
        variant="info"
      >
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover
        target="popover-badge-help-variation"
        variant="info"
        triggers="focus"
      >
        <template #title>
          Variation instructions
        </template>
        Please select or deselect the types of variation associated with the disease entity.
        <br>
        Minimum information should include <strong>"protein truncating variation"</strong> and/or
        <strong>"non-synonymous variation"</strong>.
        <br>
        If known, please also select the functional impact of these variations,
        i.e. if there is a protein <strong>"loss-of-function"</strong> or <strong>"gain-of-function"</strong>.
        <br>
      </BPopover>

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
      <label
        class="mr-sm-2 font-weight-bold"
        for="review-publications-select"
      >Publications</label>

      <BBadge
        id="popover-badge-help-publications"
        pill
        href="#"
        variant="info"
      >
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover
        target="popover-badge-help-publications"
        variant="info"
        triggers="focus"
      >
        <template #title>
          Publications instructions
        </template>
        No complete catalog of entity-related literature required.
        <br>
        If information in the clinical synopsis is not only based on OMIM
        entries, please include PMID of the article(s) used as a source
        for the clinical synopsis. <br>
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
        <template
          #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
        >
          <BInputGroup class="my-0">
            <BFormInput
              v-bind="inputAttrs"
              placeholder="Enter PMIDs separated by comma or semicolon"
              class="form-control"
              size="sm"
              :disabled="readonly"
              v-on="inputHandlers"
            />
            <BButton
              variant="secondary"
              size="sm"
              :disabled="readonly"
              @click="addTag()"
            >
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
                  :href="
                    'https://pubmed.ncbi.nlm.nih.gov/' +
                      tag.replace('PMID:', '')
                  "
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
      <label
        class="mr-sm-2 font-weight-bold"
        for="review-genereviews-select"
      >Genereviews</label>

      <BBadge
        id="popover-badge-help-genereviews"
        pill
        href="#"
        variant="info"
      >
        <i class="bi bi-question-circle-fill" />
      </BBadge>

      <BPopover
        target="popover-badge-help-genereviews"
        variant="info"
        triggers="focus"
      >
        <template #title>
          GeneReviews instructions
        </template>
        Please add PMID for GeneReview article if available for this
        entity. <br>
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
        <template
          #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
        >
          <BInputGroup class="my-0">
            <BFormInput
              v-bind="inputAttrs"
              placeholder="Enter PMIDs separated by comma or semicolon"
              class="form-control"
              size="sm"
              :disabled="readonly"
              v-on="inputHandlers"
            />
            <BButton
              variant="secondary"
              size="sm"
              :disabled="readonly"
              @click="addTag()"
            >
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
                  :href="
                    'https://pubmed.ncbi.nlm.nih.gov/' +
                      tag.replace('PMID:', '')
                  "
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
      <label
        class="mr-sm-2 font-weight-bold"
        for="review-textarea-comment"
      >Comment</label>
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
import { computed, watch } from 'vue';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';
import type { ReviewFormData } from '@/views/curate/composables/useReviewForm';

interface TreeNode {
  id: string | number;
  label: string;
  children?: TreeNode[];
  [key: string]: any;
}

interface Props {
  modelValue: ReviewFormData;
  phenotypesOptions: TreeNode[];
  variationOptions: TreeNode[];
  loading?: boolean;
  readonly?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  readonly: false,
});

const emit = defineEmits<{
  (e: 'update:modelValue', value: ReviewFormData): void;
}>();

// Create local computed for v-model binding
const localFormData = computed({
  get: () => props.modelValue,
  set: (val: ReviewFormData) => emit('update:modelValue', val),
});

/**
 * PMID tag validator
 */
const tagValidatorPMID = (tag: string): boolean => {
  const tagCopy = tag.replace(/\s+/g, '');
  return (
    !Number.isNaN(Number(tagCopy.replaceAll('PMID:', '').replaceAll(' ', ''))) &&
    tagCopy.includes('PMID:') &&
    tagCopy.replace('PMID:', '').length > 4 &&
    tagCopy.replace('PMID:', '').length < 9
  );
};
</script>

<style scoped>
/* Component-specific styles if needed */
</style>
