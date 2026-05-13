<template>
  <div class="step-evidence">
    <!-- Publications -->
    <BFormGroup
      label="Publications"
      label-for="publications-input"
      :state="getFieldState('publications')"
      :invalid-feedback="getFieldError('publications')"
      class="mb-3"
    >
      <template #label>
        <span class="fw-bold">Publications <span class="text-danger">*</span></span>
      </template>
      <BFormTags
        v-model="formData.publications"
        input-id="publications-input"
        no-outer-focus
        class="publication-tags"
        separator=",;"
        :tag-validator="validatePMID"
        remove-on-delete
        add-on-change
        @blur="touchField('publications')"
      >
        <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
          <BInputGroup class="mb-2">
            <BFormInput
              v-bind="inputAttrs"
              autocomplete="off"
              placeholder="Enter PMIDs (e.g., PMID:12345678)"
              class="form-control"
              size="sm"
              aria-describedby="publications-help"
              v-on="inputHandlers"
            />
            <BButton variant="outline-secondary" size="sm" @click="addTag()"> Add </BButton>
          </BInputGroup>

          <div v-if="tags.length > 0" class="d-flex flex-wrap gap-2">
            <BFormTag
              v-for="tag in tags"
              :key="tag"
              :title="tag"
              variant="secondary"
              class="evidence-tag evidence-tag--publication"
              @remove="removeTag(tag)"
            >
              <BLink
                :href="getPubMedUrl(tag)"
                target="_blank"
                rel="noopener noreferrer"
                class="evidence-tag__link"
              >
                <i class="bi bi-box-arrow-up-right me-1" />
                {{ tag }}
              </BLink>
            </BFormTag>
          </div>
        </template>
      </BFormTags>
      <small id="publications-help" class="text-muted">
        Enter PMIDs separated by comma or semicolon. Format: PMID:12345678
      </small>
    </BFormGroup>

    <!-- GeneReviews (Optional) -->
    <BFormGroup label="GeneReviews" label-for="genereviews-input" class="mb-3">
      <template #label>
        <span class="fw-bold">GeneReviews</span>
        <span class="text-muted fw-normal ms-1">(optional)</span>
      </template>
      <BFormTags
        v-model="formData.genereviews"
        input-id="genereviews-input"
        no-outer-focus
        class="genereviews-tags"
        separator=",;"
        :tag-validator="validatePMID"
        remove-on-delete
        add-on-change
      >
        <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
          <BInputGroup class="mb-2">
            <BFormInput
              v-bind="inputAttrs"
              autocomplete="off"
              placeholder="Enter GeneReviews PMIDs"
              class="form-control"
              size="sm"
              aria-describedby="genereviews-help"
              v-on="inputHandlers"
            />
            <BButton variant="outline-secondary" size="sm" @click="addTag()"> Add </BButton>
          </BInputGroup>

          <div v-if="tags.length > 0" class="d-flex flex-wrap gap-2">
            <BFormTag
              v-for="tag in tags"
              :key="tag"
              :title="tag"
              variant="info"
              class="evidence-tag evidence-tag--genereview"
              @remove="removeTag(tag)"
            >
              <BLink
                :href="getPubMedUrl(tag)"
                target="_blank"
                rel="noopener noreferrer"
                class="evidence-tag__link"
              >
                <i class="bi bi-box-arrow-up-right me-1" />
                {{ tag }}
              </BLink>
            </BFormTag>
          </div>
        </template>
      </BFormTags>
      <small id="genereviews-help" class="text-muted">
        Add GeneReviews article PMIDs if available
      </small>
    </BFormGroup>

    <!-- Synopsis -->
    <BFormGroup
      label="Synopsis"
      label-for="synopsis-textarea"
      :state="getFieldState('synopsis')"
      :invalid-feedback="getFieldError('synopsis')"
      class="mb-3 step-evidence__synopsis"
    >
      <template #label>
        <span class="fw-bold">Synopsis <span class="text-danger">*</span></span>
      </template>
      <BFormTextarea
        id="synopsis-textarea"
        v-model="formData.synopsis"
        rows="5"
        size="sm"
        :state="getFieldState('synopsis')"
        placeholder="Provide a clinical summary describing this gene-disease relationship..."
        aria-describedby="synopsis-help synopsis-counter"
        @blur="touchField('synopsis')"
      />
      <div class="d-flex justify-content-between mt-1">
        <small id="synopsis-help" class="text-muted">
          Brief clinical summary (10-2000 characters)
        </small>
        <small
          id="synopsis-counter"
          :class="[
            'text-end',
            synopsisCharsRemaining < 0
              ? 'text-danger'
              : synopsisCharsRemaining < 100
                ? 'text-warning'
                : 'text-muted',
          ]"
        >
          {{ synopsisCharCount }}/2000 characters
        </small>
      </div>
    </BFormGroup>
  </div>
</template>

<script lang="ts">
import { defineComponent, inject, computed } from 'vue';
import {
  BFormGroup,
  BFormTags,
  BFormTag,
  BFormInput,
  BFormTextarea,
  BInputGroup,
  BButton,
  BLink,
} from 'bootstrap-vue-next';
import type { EntityFormData } from '@/composables/useEntityForm';
import { validatePMID } from '@/composables/useEntityForm';

export default defineComponent({
  name: 'StepEvidence',

  components: {
    BFormGroup,
    BFormTags,
    BFormTag,
    BFormInput,
    BFormTextarea,
    BInputGroup,
    BButton,
    BLink,
  },

  setup() {
    // Inject form state from parent
    const formData = inject<EntityFormData>('formData')!;
    const getFieldError = inject<(field: string) => string | null>('getFieldError')!;
    const getFieldState = inject<(field: string) => boolean | null>('getFieldState')!;
    const touchField = inject<(field: string) => void>('touchField')!;

    // Synopsis character helpers
    const synopsisCharCount = computed(() => formData.synopsis?.length || 0);
    const synopsisCharsRemaining = computed(() => 2000 - synopsisCharCount.value);

    // PubMed URL helper
    const getPubMedUrl = (pmid: string): string => {
      const id = pmid.replace('PMID:', '').trim();
      return `https://pubmed.ncbi.nlm.nih.gov/${id}`;
    };

    return {
      formData,
      getFieldError,
      getFieldState,
      touchField,
      validatePMID,
      synopsisCharCount,
      synopsisCharsRemaining,
      getPubMedUrl,
    };
  },
});
</script>

<style scoped>
.step-evidence {
  max-width: none;
}

.step-evidence :deep(.evidence-tag) {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  min-height: 1.45rem;
  margin: 0;
  padding: 0.14rem 0.42rem;
  border: 1px solid #0891b2;
  border-radius: 999px;
  background-color: #cffafe !important;
  color: #0f172a !important;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.2;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.07);
}

.step-evidence :deep(.evidence-tag--genereview) {
  border-color: #2563eb;
  background-color: #dbeafe !important;
}

.step-evidence :deep(.evidence-tag__link) {
  color: inherit;
  text-decoration: none;
}

.step-evidence :deep(.evidence-tag button),
.step-evidence :deep(.evidence-tag .btn-close) {
  width: 0.8rem;
  min-width: 0.8rem;
  height: 0.8rem;
  min-height: 0.8rem;
  margin-left: 0.1rem;
  padding: 0;
  background-size: 0.55rem;
  opacity: 0.62;
}

.publication-tags :deep(.b-form-tags-list),
.genereviews-tags :deep(.b-form-tags-list) {
  display: none;
}
</style>
