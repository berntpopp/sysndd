<!-- app/src/views/curate/components/CombinedStatusReviewWorkflow.vue -->
<!--
  Combined Status & Review inline workflow (issues #36, #37).

  One panel that edits BOTH the status and the review of an entity instead of
  the two separate flows, with an optional Curator-gated direct-approval
  toggle. Field markup mirrors InlineEntityWorkflow's `status` and `review`
  branches so the two surfaces stay visually identical; this component only
  composes them and adds the direct-approval switch.
-->
<template>
  <section class="combined-workflow">
    <header class="combined-workflow__header">
      <div>
        <h3>Status &amp; Review</h3>
        <p>Adjust the status category and the clinical review together in one step.</p>
      </div>
      <BButton variant="outline-secondary" size="sm" @click="$emit('cancel')">Cancel</BButton>
    </header>

    <BOverlay :show="loading" rounded="sm">
      <BForm class="combined-workflow__form" @submit.stop.prevent="$emit('submit')">
        <!-- ============================= STATUS ============================ -->
        <fieldset class="combined-workflow__group">
          <legend class="combined-workflow__legend">
            <i class="bi bi-stoplights" aria-hidden="true" /> Status
          </legend>

          <div class="combined-workflow__field">
            <label for="combined-status-select">Status category</label>
            <BSpinner v-if="statusOptionsLoading" small label="Loading..." />
            <BFormSelect
              v-else-if="statusOptions && statusOptions.length > 0"
              id="combined-status-select"
              :model-value="formData.category_id"
              :options="normalizedStatusOptions"
              size="sm"
              @update:model-value="$emit('update:form-data', { ...formData, category_id: $event })"
            >
              <template #first>
                <BFormSelectOption :value="null">Select status...</BFormSelectOption>
              </template>
            </BFormSelect>
            <BAlert v-else-if="statusOptions !== null" variant="warning" class="mb-0">
              No status options available.
            </BAlert>
          </div>

          <div class="combined-workflow__field">
            <BFormCheckbox
              id="combined-remove-switch"
              :model-value="formData.problematic"
              switch
              @update:model-value="$emit('update:form-data', { ...formData, problematic: $event })"
            >
              Suggest removal
            </BFormCheckbox>
          </div>

          <div class="combined-workflow__field">
            <label for="combined-status-comment">Status comment</label>
            <BFormTextarea
              id="combined-status-comment"
              :model-value="formData.comment"
              rows="2"
              size="sm"
              placeholder="Why should this entity's status be changed?"
              @update:model-value="$emit('update:form-data', { ...formData, comment: $event })"
            />
          </div>
        </fieldset>

        <!-- ============================= REVIEW ============================ -->
        <fieldset class="combined-workflow__group">
          <legend class="combined-workflow__legend">
            <i class="bi bi-clipboard-plus" aria-hidden="true" /> Review
          </legend>

          <div class="combined-workflow__field">
            <label for="combined-review-synopsis">Synopsis</label>
            <BFormTextarea
              id="combined-review-synopsis"
              :model-value="review?.synopsis"
              rows="4"
              size="sm"
              @update:model-value="$emit('update:review', { ...review, synopsis: $event })"
            />
          </div>

          <div class="combined-workflow__grid">
            <div class="combined-workflow__field">
              <label for="combined-review-phenotype">Phenotypes</label>
              <TreeMultiSelect
                v-if="phenotypeOptions && phenotypeOptions.length > 0"
                id="combined-review-phenotype"
                :model-value="selectPhenotype"
                :options="phenotypeOptions"
                placeholder="Select phenotypes..."
                search-placeholder="Search phenotypes..."
                @update:model-value="$emit('update:select-phenotype', $event)"
              />
            </div>

            <div class="combined-workflow__field">
              <label for="combined-review-variation">Variation ontology</label>
              <TreeMultiSelect
                v-if="variationOptions && variationOptions.length > 0"
                id="combined-review-variation"
                :model-value="selectVariation"
                :options="variationOptions"
                placeholder="Select variations..."
                search-placeholder="Search variation types..."
                @update:model-value="$emit('update:select-variation', $event)"
              />
            </div>
          </div>

          <div class="combined-workflow__grid">
            <div class="combined-workflow__field">
              <label for="combined-review-publications">Publications</label>
              <BFormTags
                :model-value="selectAdditionalReferences"
                input-id="combined-review-publications"
                no-outer-focus
                separator=",;"
                :tag-validator="tagValidatorPMID"
                remove-on-delete
                @update:model-value="updateAdditionalReferences"
              >
                <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                  <BInputGroup>
                    <BFormInput
                      v-bind="inputAttrs"
                      placeholder="Enter PMIDs separated by comma or semicolon"
                      size="sm"
                      v-on="inputHandlers"
                    />
                    <BButton variant="secondary" size="sm" @click="addTag()">Add</BButton>
                  </BInputGroup>
                  <div class="combined-workflow__tags">
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      class="combined-workflow__tag combined-workflow__tag--publication"
                      @remove="removeTag(tag)"
                    >
                      {{ tag }}
                    </BFormTag>
                  </div>
                </template>
              </BFormTags>
            </div>

            <div class="combined-workflow__field">
              <label for="combined-review-genereviews">GeneReviews</label>
              <BFormTags
                :model-value="selectGeneReviews"
                input-id="combined-review-genereviews"
                no-outer-focus
                separator=",;"
                :tag-validator="tagValidatorPMID"
                remove-on-delete
                @update:model-value="updateGeneReviews"
              >
                <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                  <BInputGroup>
                    <BFormInput
                      v-bind="inputAttrs"
                      placeholder="Enter PMIDs separated by comma or semicolon"
                      size="sm"
                      v-on="inputHandlers"
                    />
                    <BButton variant="secondary" size="sm" @click="addTag()">Add</BButton>
                  </BInputGroup>
                  <div class="combined-workflow__tags">
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      class="combined-workflow__tag combined-workflow__tag--genereview"
                      @remove="removeTag(tag)"
                    >
                      {{ tag }}
                    </BFormTag>
                  </div>
                </template>
              </BFormTags>
            </div>
          </div>

          <div class="combined-workflow__field">
            <label for="combined-review-comment">Review comment</label>
            <BFormTextarea
              id="combined-review-comment"
              :model-value="review?.comment"
              rows="2"
              size="sm"
              placeholder="Additional comments relevant for the curator."
              @update:model-value="$emit('update:review', { ...review, comment: $event })"
            />
          </div>
        </fieldset>

        <footer class="combined-workflow__footer">
          <!-- Direct approval toggle — Curator+ only (issue #37). Hidden for
               non-permitted roles; the server re-checks the role too. -->
          <div
            v-if="canDirectApprove"
            class="combined-workflow__approval"
            title="Skip double review and approve immediately — Curator+ only."
          >
            <BFormCheckbox
              id="combined-direct-approval"
              :model-value="directApproval"
              switch
              size="sm"
              @update:model-value="updateDirectApproval"
            >
              Direct approval
            </BFormCheckbox>
          </div>

          <div class="combined-workflow__footer-actions">
            <BButton variant="outline-secondary" size="sm" @click="$emit('cancel')">Cancel</BButton>
            <BButton variant="primary" size="sm" type="submit" :disabled="submitting === 'combined'">
              <BSpinner v-if="submitting === 'combined'" small class="me-1" />
              {{ directApproval ? 'Submit &amp; approve' : 'Submit' }}
            </BButton>
          </div>
        </footer>
      </BForm>
    </BOverlay>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';

const props = defineProps<{
  loading: boolean;
  submitting: string | null;
  review: any;
  selectPhenotype: string[];
  selectVariation: string[];
  selectAdditionalReferences: string[];
  selectGeneReviews: string[];
  phenotypeOptions: any[];
  variationOptions: any[];
  statusOptions: any[] | null;
  statusOptionsLoading: boolean;
  formData: any;
  directApproval: boolean;
  /** When false the direct-approval toggle is hidden (non-Curator). */
  canDirectApprove: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:review', value: any): void;
  (e: 'update:select-phenotype', value: string[]): void;
  (e: 'update:select-variation', value: string[]): void;
  (e: 'update:select-additional-references', value: string[]): void;
  (e: 'update:select-gene-reviews', value: string[]): void;
  (e: 'update:form-data', value: any): void;
  (e: 'update:direct-approval', value: boolean): void;
  (e: 'submit'): void;
  (e: 'cancel'): void;
}>();

const normalizedStatusOptions = computed(() => {
  if (!props.statusOptions || !Array.isArray(props.statusOptions)) return [];
  return props.statusOptions.map((opt: any) => ({ value: opt.id, text: opt.label }));
});

function tagValidatorPMID(tag: string): boolean {
  const value = tag.replace(/\s+/g, '');
  return /^PMID:\d{5,8}$/.test(value);
}

function updateAdditionalReferences(value: unknown): void {
  emit('update:select-additional-references', Array.isArray(value) ? value : []);
}

function updateGeneReviews(value: unknown): void {
  emit('update:select-gene-reviews', Array.isArray(value) ? value : []);
}

function updateDirectApproval(value: unknown): void {
  emit('update:direct-approval', Boolean(value));
}
</script>

<style scoped>
.combined-workflow {
  display: grid;
  gap: 0.85rem;
  padding: 0.85rem;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #f8fafc;
}

.combined-workflow__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.combined-workflow__header h3 {
  margin: 0;
  color: #172033;
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.combined-workflow__header p {
  margin: 0.2rem 0 0;
  color: #526070;
  font-size: 0.8125rem;
  line-height: 1.35;
}

.combined-workflow__form {
  display: grid;
  gap: 0.85rem;
}

.combined-workflow__group {
  display: grid;
  gap: 0.6rem;
  margin: 0;
  padding: 0.7rem 0.75rem 0.8rem;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  background: #fff;
}

.combined-workflow__legend {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  width: auto;
  margin: 0;
  padding: 0 0.3rem;
  color: #344054;
  font-size: 0.8125rem;
  font-weight: 700;
  line-height: 1.2;
}

.combined-workflow__field {
  display: grid;
  gap: 0.45rem;
}

.combined-workflow__field label {
  margin: 0;
  color: #344054;
  font-size: 0.8125rem;
  font-weight: 700;
  line-height: 1.25;
}

.combined-workflow__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}

.combined-workflow :deep(.tree-multi-select .b-form-tags),
.combined-workflow :deep(.b-form-tags) {
  min-width: 0;
}

.combined-workflow :deep(.combined-workflow__tag) {
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

.combined-workflow :deep(.combined-workflow__tag--genereview) {
  border-color: #2563eb;
  background-color: #dbeafe !important;
}

.combined-workflow__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.5rem;
}

.combined-workflow__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding-top: 0.35rem;
}

.combined-workflow__approval {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.55rem;
  border: 1px solid #b8d3f7;
  border-radius: 999px;
  background: #eef6ff;
}

.combined-workflow__footer-actions {
  display: flex;
  gap: 0.5rem;
}

@media (max-width: 767.98px) {
  .combined-workflow__header {
    flex-direction: column;
  }

  .combined-workflow__grid {
    grid-template-columns: 1fr;
  }

  .combined-workflow__footer {
    flex-direction: column-reverse;
    align-items: stretch;
  }

  .combined-workflow__footer-actions {
    flex-direction: column-reverse;
  }

  .combined-workflow__footer-actions > .btn,
  .combined-workflow__header > .btn {
    width: 100%;
  }
}
</style>
