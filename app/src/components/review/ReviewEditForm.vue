<!-- components/review/ReviewEditForm.vue -->
<!--
  Form-body for EditReviewModal. Extracted so the parent modal stays under
  the 300 LoC cap Phase E imposes, and so E.E6 can re-use the same form body
  behind a generic ApprovalTableView if that surface also offers an inline
  edit form.
-->
<template>
  <BOverlay :show="loading" rounded="sm">
    <BForm ref="form" @submit.stop.prevent="$emit('submit')">
      <BFormGroup label="Synopsis" label-for="review-textarea-synopsis" class="mb-3">
        <template #label>
          <span class="fw-semibold">Synopsis</span>
        </template>
        <BFormTextarea
          id="review-textarea-synopsis"
          :model-value="reviewInfo.synopsis"
          rows="3"
          placeholder="Clinical synopsis of the entity..."
          @update:model-value="updateReviewInfo('synopsis', String($event ?? ''))"
        />
      </BFormGroup>

      <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
        <i class="bi bi-activity me-2" />
        Phenotypes & Variation
      </h6>

      <BFormGroup label="Phenotypes" label-for="review-phenotype-select" class="mb-3">
        <template #label>
          <span class="fw-semibold">Phenotypes</span>
        </template>
        <TreeMultiSelect
          v-if="phenotypeOptions && phenotypeOptions.length > 0"
          id="review-phenotype-select"
          :model-value="selectPhenotype"
          :options="phenotypeOptions"
          placeholder="Select phenotypes..."
          search-placeholder="Search phenotypes (name or HP:ID)..."
          @update:model-value="$emit('update:selectPhenotype', ($event as string[]) || [])"
        />
      </BFormGroup>

      <BFormGroup label="Variation Ontology" label-for="review-variation-select" class="mb-3">
        <template #label>
          <span class="fw-semibold">Variation Ontology</span>
        </template>
        <TreeMultiSelect
          v-if="variationOptions && variationOptions.length > 0"
          id="review-variation-select"
          :model-value="selectVariation"
          :options="variationOptions"
          placeholder="Select variations..."
          search-placeholder="Search variation types..."
          @update:model-value="$emit('update:selectVariation', ($event as string[]) || [])"
        />
      </BFormGroup>

      <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
        <i class="bi bi-journal-bookmark me-2" />
        Literature References
      </h6>

      <BFormGroup label="Publications" label-for="review-publications-select" class="mb-3">
        <template #label>
          <span class="fw-semibold">Publications</span>
        </template>
        <BFormTags
          :model-value="selectAdditionalReferences"
          input-id="review-literature-select"
          no-outer-focus
          class="my-0"
          separator=",;"
          :tag-validator="tagValidator"
          remove-on-delete
          @update:model-value="
            $emit('update:selectAdditionalReferences', ($event as string[]) || [])
          "
        >
          <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
            <BInputGroup class="my-0">
              <BFormInput
                v-bind="inputAttrs"
                placeholder="Enter PMIDs separated by comma or semicolon"
                class="form-control"
                v-on="inputHandlers"
              />
              <BButton variant="outline-secondary" @click="addTag()"> Add </BButton>
            </BInputGroup>

            <div class="d-flex flex-wrap gap-1 mt-2">
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
                  <i class="bi bi-box-arrow-up-right me-1" />
                  {{ tag }}
                </BLink>
              </BFormTag>
            </div>
          </template>
        </BFormTags>
      </BFormGroup>

      <BFormGroup label="GeneReviews" label-for="review-genereviews-select" class="mb-3">
        <template #label>
          <span class="fw-semibold">GeneReviews</span>
        </template>
        <BFormTags
          :model-value="selectGeneReviews"
          input-id="review-genereviews-select"
          no-outer-focus
          class="my-0"
          separator=",;"
          :tag-validator="tagValidator"
          remove-on-delete
          @update:model-value="$emit('update:selectGeneReviews', ($event as string[]) || [])"
        >
          <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
            <BInputGroup class="my-0">
              <BFormInput
                v-bind="inputAttrs"
                placeholder="Enter PMIDs separated by comma or semicolon"
                class="form-control"
                v-on="inputHandlers"
              />
              <BButton variant="outline-secondary" @click="addTag()"> Add </BButton>
            </BInputGroup>

            <div class="d-flex flex-wrap gap-1 mt-2">
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
                  <i class="bi bi-box-arrow-up-right me-1" />
                  {{ tag }}
                </BLink>
              </BFormTag>
            </div>
          </template>
        </BFormTags>
      </BFormGroup>

      <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
        <i class="bi bi-chat-left-text me-2" />
        Notes
      </h6>

      <BFormGroup label="Comment" label-for="review-textarea-comment" class="mb-0">
        <template #label>
          <span class="fw-semibold">Comment</span>
        </template>
        <BFormTextarea
          id="review-textarea-comment"
          :model-value="reviewInfo.comment"
          rows="3"
          placeholder="Additional comments to this entity relevant for the curator..."
          @update:model-value="updateReviewInfo('comment', String($event ?? ''))"
        />
      </BFormGroup>
    </BForm>
  </BOverlay>
</template>

<script setup lang="ts">
import type { PropType } from 'vue';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';

export interface ReviewInfoShape {
  synopsis?: string | null;
  comment?: string | null;
  review_id?: number | null;
  entity_id?: number | null;
  review_user_name?: string | null;
  review_user_role?: string | null;
}

export interface TreeOption {
  id: string;
  label: string;
  children?: TreeOption[];
  [key: string]: unknown;
}

const props = defineProps({
  loading: { type: Boolean, default: false },
  reviewInfo: { type: Object as PropType<ReviewInfoShape>, required: true },
  phenotypeOptions: { type: Array as PropType<TreeOption[]>, default: () => [] },
  variationOptions: { type: Array as PropType<TreeOption[]>, default: () => [] },
  selectPhenotype: { type: Array as PropType<string[]>, default: () => [] },
  selectVariation: { type: Array as PropType<string[]>, default: () => [] },
  selectAdditionalReferences: { type: Array as PropType<string[]>, default: () => [] },
  selectGeneReviews: { type: Array as PropType<string[]>, default: () => [] },
  tagValidator: { type: Function as PropType<(tag: string) => boolean>, required: true },
});

const emit = defineEmits<{
  (e: 'submit'): void;
  (e: 'update:reviewInfo', value: ReviewInfoShape): void;
  (e: 'update:selectPhenotype', value: string[]): void;
  (e: 'update:selectVariation', value: string[]): void;
  (e: 'update:selectAdditionalReferences', value: string[]): void;
  (e: 'update:selectGeneReviews', value: string[]): void;
}>();

const updateReviewInfo = (field: 'synopsis' | 'comment', value: string): void => {
  emit('update:reviewInfo', { ...props.reviewInfo, [field]: value });
};
</script>
