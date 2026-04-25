<!-- views/review/components/ReviewEditModal.vue -->
<!--
  Review-edit modal extracted from `Review.vue` during W6 of v11.1
  finish-hardening. Owns the entity-context header, the saving spinner
  glue, and the `ReviewFormFields` form.

  The form-data binding stays in the parent's `useReviewForm` composable;
  this component receives it as a v-model proxy so the existing reactive
  flow stays intact. No API calls live here — the parent calls
  `$ref.show()` and the form composable's loaders before the modal
  opens.
-->
<template>
  <BModal
    :id="modalDescriptor.id"
    :ref="modalDescriptor.id"
    size="xl"
    centered
    ok-title="Submit"
    no-close-on-esc
    no-close-on-backdrop
    header-class="border-bottom-0 pb-0"
    footer-class="border-top-0 pt-0"
    :busy="loading"
    @show="$emit('show')"
    @ok="$emit('ok')"
  >
    <template #title>
      <div class="d-flex align-items-center">
        <i class="bi bi-pencil-square me-2 text-primary" />
        <span class="fw-semibold">Edit Review</span>
      </div>
    </template>

    <template #footer="{ ok, cancel }">
      <div class="w-100 d-flex justify-content-between align-items-center">
        <div class="d-flex align-items-center gap-2 text-muted small">
          <span v-if="isSaving" class="d-flex align-items-center gap-1">
            <BSpinner small variant="secondary" />
            <span>Saving...</span>
          </span>
          <span v-if="reviewInfo.review_user_name" class="d-flex align-items-center gap-1">
            <i :class="'bi bi-' + userIcon[reviewInfo.review_user_role]" />
            <span>{{ reviewInfo.review_user_name }}</span>
            <span class="text-muted">·</span>
            <span>{{ reviewInfo.review_date?.substring(0, 10) }}</span>
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

    <!-- Entity context header -->
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
          :link-to="'/Ontology/' + entityInfo.disease_ontology_id_version.replace(/_.+/g, '')"
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

    <!-- Review form section -->
    <h6 class="text-muted border-bottom pb-2 mb-3">
      <i class="bi bi-journal-text me-2" />
      Review Information
    </h6>

    <ReviewFormFields
      :model-value="formData"
      :phenotypes-options="phenotypesOptions"
      :variation-options="variationOptions"
      :loading="loading"
      @update:model-value="$emit('update:formData', $event)"
    />
  </BModal>
</template>

<script>
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import ReviewFormFields from '@/views/curate/components/ReviewFormFields.vue';

export default {
  name: 'ReviewEditModal',
  components: {
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
    ReviewFormFields,
  },
  props: {
    modalDescriptor: {
      type: Object,
      required: true,
    },
    formData: {
      type: Object,
      required: true,
    },
    reviewInfo: {
      type: Object,
      required: true,
    },
    entityInfo: {
      type: Object,
      required: true,
    },
    phenotypesOptions: {
      type: Array,
      default: () => [],
    },
    variationOptions: {
      type: Array,
      default: () => [],
    },
    loading: { type: Boolean, default: false },
    isSaving: { type: Boolean, default: false },
    userIcon: { type: Object, default: () => ({}) },
  },
  emits: ['show', 'ok', 'update:formData'],
  methods: {
    show() {
      this.$refs[this.modalDescriptor.id]?.show();
    },
    hide() {
      this.$refs[this.modalDescriptor.id]?.hide();
    },
  },
};
</script>
