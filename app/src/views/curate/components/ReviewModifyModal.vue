<!-- app/src/views/curate/components/ReviewModifyModal.vue -->
<template>
  <BModal
    id="modifyReviewModal"
    v-model="proxyVisible"
    size="xl"
    centered
    ok-title="Submit"
    no-close-on-esc
    no-close-on-backdrop
    header-bg-variant="dark"
    header-text-variant="light"
    header-close-label="Close"
    :busy="loading || submitting === 'review'"
    @ok.prevent="$emit('submit')"
    @hide="onHide"
  >
    <template #title>
      <div class="d-flex flex-column gap-2">
        <h4 class="mb-0">
          Modify Review
          <EntityBadge
            v-if="entity?.entity_id"
            :entity-id="entity.entity_id"
            variant="primary"
            size="md"
            class="ms-2"
          />
        </h4>
        <EntityContextStrip :entity="entity" />
      </div>
    </template>

    <BOverlay :show="loading" rounded="sm">
      <BForm @submit.stop.prevent="$emit('submit')">
        <!-- Synopsis textarea -->
        <label class="mr-sm-2 font-weight-bold" for="review-textarea-synopsis">Synopsis</label>
        <BFormTextarea
          id="review-textarea-synopsis"
          :model-value="review?.synopsis"
          rows="3"
          size="sm"
          @update:model-value="$emit('update:review', { ...review, synopsis: $event })"
        />

        <!-- Phenotype select -->
        <label class="mr-sm-2 font-weight-bold" for="review-phenotype-select">Phenotypes</label>
        <TreeMultiSelect
          v-if="phenotypeOptions && phenotypeOptions.length > 0"
          id="review-phenotype-select"
          :model-value="selectPhenotype"
          :options="phenotypeOptions"
          placeholder="Select phenotypes..."
          search-placeholder="Search phenotypes (name or HP:ID)..."
          @update:model-value="$emit('update:select-phenotype', $event)"
        />

        <!-- Variation ontology select -->
        <label class="mr-sm-2 font-weight-bold" for="review-variation-select"
          >Variation ontology</label
        >
        <TreeMultiSelect
          v-if="variationOptions && variationOptions.length > 0"
          id="review-variation-select"
          :model-value="selectVariation"
          :options="variationOptions"
          placeholder="Select variations..."
          search-placeholder="Search variation types..."
          @update:model-value="$emit('update:select-variation', $event)"
        />

        <!-- Publications tag form with links out -->
        <label class="mr-sm-2 font-weight-bold" for="review-publications-select"
          >Publications</label
        >
        <BFormTags
          :model-value="selectAdditionalReferences"
          input-id="review-literature-select"
          no-outer-focus
          class="my-0"
          separator=",;"
          :tag-validator="tagValidatorPMID"
          remove-on-delete
          @update:model-value="$emit('update:select-additional-references', $event)"
        >
          <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
            <BInputGroup class="my-0">
              <BFormInput
                v-bind="inputAttrs"
                placeholder="Enter PMIDs separated by comma or semicolon"
                class="form-control"
                size="sm"
                v-on="inputHandlers"
              />
              <BButton variant="secondary" size="sm" @click="addTag()">Add</BButton>
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

        <!-- Genereviews tag form with links out -->
        <label class="mr-sm-2 font-weight-bold" for="review-genereviews-select">Genereviews</label>
        <BFormTags
          :model-value="selectGeneReviews"
          input-id="review-genereviews-select"
          no-outer-focus
          class="my-0"
          separator=",;"
          :tag-validator="tagValidatorPMID"
          remove-on-delete
          @update:model-value="$emit('update:select-gene-reviews', $event)"
        >
          <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
            <BInputGroup class="my-0">
              <BFormInput
                v-bind="inputAttrs"
                placeholder="Enter PMIDs separated by comma or semicolon"
                class="form-control"
                size="sm"
                v-on="inputHandlers"
              />
              <BButton variant="secondary" size="sm" @click="addTag()">Add</BButton>
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

        <!-- Review comment textarea -->
        <label class="mr-sm-2 font-weight-bold" for="review-textarea-comment">Comment</label>
        <BFormTextarea
          id="review-textarea-comment"
          :model-value="review?.comment"
          rows="2"
          size="sm"
          placeholder="Additional comments to this entity relevant for the curator."
          @update:model-value="$emit('update:review', { ...review, comment: $event })"
        />
      </BForm>
    </BOverlay>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent, type PropType } from 'vue';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import EntityContextStrip from './EntityContextStrip.vue';

export default defineComponent({
  name: 'ReviewModifyModal',
  components: { TreeMultiSelect, EntityBadge, EntityContextStrip },
  props: {
    visible: { type: Boolean, default: false },
    loading: { type: Boolean, default: false },
    submitting: { type: String as PropType<string | null>, default: null },
    entity: { type: Object as PropType<Record<string, any> | null>, default: null },
    review: { type: Object as PropType<any>, default: null },
    selectPhenotype: { type: Array as PropType<string[]>, default: () => [] },
    selectVariation: { type: Array as PropType<string[]>, default: () => [] },
    selectAdditionalReferences: { type: Array as PropType<string[]>, default: () => [] },
    selectGeneReviews: { type: Array as PropType<string[]>, default: () => [] },
    phenotypeOptions: { type: Array as PropType<any[]>, default: () => [] },
    variationOptions: { type: Array as PropType<any[]>, default: () => [] },
    hasChanges: { type: Boolean, default: false },
    stoplightsStyle: { type: Object as PropType<Record<string, string>>, default: () => ({}) },
  },
  emits: [
    'update:visible',
    'update:review',
    'update:select-phenotype',
    'update:select-variation',
    'update:select-additional-references',
    'update:select-gene-reviews',
    'submit',
    'discard-request',
  ],
  setup(props, { emit }) {
    const proxyVisible = computed({
      get: () => props.visible,
      set: (v: boolean) => emit('update:visible', v),
    });

    function tagValidatorPMID(tag: string): boolean {
      // Tight: PMID: prefix at start, 5–8 digits only (no trailing/leading garbage).
      // Strips whitespace first to tolerate copy-paste, then enforces shape.
      const t = tag.replace(/\s+/g, '');
      return /^PMID:\d{5,8}$/.test(t);
    }

    function onHide(event: any): void {
      if (props.hasChanges && props.submitting !== 'review') {
        event?.preventDefault?.();
        emit('discard-request', 'review');
      }
    }

    return { proxyVisible, tagValidatorPMID, onHide };
  },
});
</script>
