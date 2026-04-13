<!-- components/review/EditReviewModal.vue -->
<!--
  Edit-review modal. The audit-trail footer block is wired for the Phase E.E5
  assertion at ApproveReview.spec.ts line 491 — do NOT rename the
  `data-testid="review-audit-trail-user-role"` attribute.
-->
<template>
  <BModal
    :id="modalId"
    :ref="modalId"
    size="xl"
    centered
    ok-title="Submit"
    no-close-on-esc
    no-close-on-backdrop
    header-class="border-bottom-0 pb-0"
    footer-class="border-top-0 pt-0"
    header-close-label="Close"
    :busy="loading"
    @ok="$emit('ok')"
    @hide="$emit('hide', $event)"
  >
    <template #title>
      <div class="d-flex align-items-center">
        <i class="bi bi-pencil-square me-2 text-primary" />
        <span class="fw-semibold">Edit Review</span>
      </div>
    </template>

    <template #footer="{ ok, cancel }">
      <div class="w-100 d-flex justify-content-between align-items-center">
        <div
          class="d-flex align-items-center gap-2 text-muted small"
          data-testid="review-audit-trail"
        >
          <span
            v-if="reviewInfo.review_user_name"
            class="d-flex align-items-center gap-1"
            data-testid="review-audit-trail-user"
          >
            <i :class="'bi bi-' + (userIcon[reviewInfo.review_user_role] || 'person')" />
            <span data-testid="review-audit-trail-user-name">
              {{ reviewInfo.review_user_name }}
            </span>
            <span class="text-muted">·</span>
            <span data-testid="review-audit-trail-user-role">
              {{ reviewInfo.review_user_role }}
            </span>
          </span>
          <span v-if="entityInfo.category" class="d-flex align-items-center gap-1">
            <span class="text-muted">·</span>
            <CategoryIcon :category="entityInfo.category" size="sm" :show-title="true" />
          </span>
        </div>
        <div class="d-flex gap-2">
          <BButton variant="outline-secondary" @click="cancel()"> Cancel </BButton>
          <BButton variant="primary" @click="ok()">
            <i class="bi bi-check-lg me-1" />
            Save Review
          </BButton>
        </div>
      </div>
    </template>

    <div class="bg-light rounded-3 p-3 mb-4">
      <h6 class="text-muted mb-2 small text-uppercase fw-semibold">
        <i class="bi bi-info-circle me-1" />
        Entity Details
      </h6>
      <div class="d-flex flex-wrap gap-2">
        <EntityBadge
          v-if="reviewInfo.entity_id"
          :entity-id="reviewInfo.entity_id"
          :link-to="'/Entities/' + reviewInfo.entity_id"
          size="sm"
        />
        <GeneBadge
          :symbol="entityInfo.symbol"
          :hgnc-id="entityInfo.hgnc_id"
          :link-to="'/Genes/' + entityInfo.hgnc_id"
          size="sm"
        />
        <DiseaseBadge
          :name="entityInfo.disease_ontology_name"
          :ontology-id="entityInfo.disease_ontology_id_version"
          :link-to="
            '/Ontology/' +
            (entityInfo.disease_ontology_id_version || '').replace(/_.+/g, '')
          "
          :max-length="35"
          size="sm"
        />
        <InheritanceBadge
          :full-name="entityInfo.hpo_mode_of_inheritance_term_name"
          :hpo-term="entityInfo.hpo_mode_of_inheritance_term"
          size="sm"
        />
      </div>
    </div>

    <h6 class="text-muted border-bottom pb-2 mb-3">
      <i class="bi bi-journal-text me-2" />
      Review Information
    </h6>

    <ReviewEditForm
      :loading="loading"
      :review-info="reviewInfo"
      :phenotype-options="phenotypeOptions"
      :variation-options="variationOptions"
      :select-phenotype="selectPhenotype"
      :select-variation="selectVariation"
      :select-additional-references="selectAdditionalReferences"
      :select-gene-reviews="selectGeneReviews"
      :tag-validator="tagValidator"
      @submit="$emit('ok')"
      @update:review-info="$emit('update:reviewInfo', $event)"
      @update:select-phenotype="$emit('update:selectPhenotype', $event)"
      @update:select-variation="$emit('update:selectVariation', $event)"
      @update:select-additional-references="$emit('update:selectAdditionalReferences', $event)"
      @update:select-gene-reviews="$emit('update:selectGeneReviews', $event)"
    />
  </BModal>
</template>

<script setup lang="ts">
import type { PropType } from 'vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import ReviewEditForm from '@/components/review/ReviewEditForm.vue';

export interface ReviewInfoShape {
  synopsis?: string | null;
  comment?: string | null;
  review_id?: number | null;
  entity_id?: number | null;
  review_user_name?: string | null;
  review_user_role?: string | null;
}

export interface EntityInfoShape {
  entity_id?: number;
  symbol?: string;
  hgnc_id?: string;
  disease_ontology_id_version?: string;
  disease_ontology_name?: string;
  hpo_mode_of_inheritance_term_name?: string;
  hpo_mode_of_inheritance_term?: string;
  category?: string;
}

export interface TreeOption {
  id: string;
  label: string;
  children?: TreeOption[];
  [key: string]: unknown;
}

defineProps({
  modalId: { type: String, default: 'review-modal' },
  loading: { type: Boolean, default: false },
  reviewInfo: { type: Object as PropType<ReviewInfoShape>, required: true },
  entityInfo: { type: Object as PropType<EntityInfoShape>, required: true },
  phenotypeOptions: { type: Array as PropType<TreeOption[]>, default: () => [] },
  variationOptions: { type: Array as PropType<TreeOption[]>, default: () => [] },
  selectPhenotype: { type: Array as PropType<string[]>, default: () => [] },
  selectVariation: { type: Array as PropType<string[]>, default: () => [] },
  selectAdditionalReferences: { type: Array as PropType<string[]>, default: () => [] },
  selectGeneReviews: { type: Array as PropType<string[]>, default: () => [] },
  userIcon: {
    type: Object as PropType<Record<string, string>>,
    default: () => ({}),
  },
  tagValidator: { type: Function as PropType<(tag: string) => boolean>, required: true },
});

defineEmits<{
  (e: 'ok'): void;
  (e: 'hide', event: unknown): void;
  (e: 'update:reviewInfo', value: ReviewInfoShape): void;
  (e: 'update:selectPhenotype', value: string[]): void;
  (e: 'update:selectVariation', value: string[]): void;
  (e: 'update:selectAdditionalReferences', value: string[]): void;
  (e: 'update:selectGeneReviews', value: string[]): void;
}>();
</script>
