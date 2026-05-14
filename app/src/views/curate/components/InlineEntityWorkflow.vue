<template>
  <section class="inline-entity-workflow" :class="`inline-entity-workflow--${workflow}`">
    <header class="inline-entity-workflow__header">
      <div>
        <h3>{{ title }}</h3>
        <p>{{ description }}</p>
      </div>
      <BButton variant="outline-secondary" size="sm" @click="$emit('cancel')"> Cancel </BButton>
    </header>

    <BOverlay :show="loading" rounded="sm">
      <BForm class="inline-entity-workflow__form" @submit.stop.prevent="submit">
        <template v-if="workflow === 'rename'">
          <div class="inline-entity-workflow__field">
            <label for="ontology-select">New disease</label>
            <AutocompleteInput
              v-model:display-value="ontologyDisplayProxy"
              :model-value="ontologyInput as any"
              :results="ontologySearchResults"
              :loading="ontologySearchLoading"
              label="Disease"
              input-id="ontology-select"
              placeholder="Search by disease name or ontology ID..."
              item-key="id"
              item-label="label"
              item-secondary="id"
              @search="(q) => $emit('search-ontology', q)"
              @update:model-value="(id) => $emit('select-ontology', id)"
            />
            <small>Search by disease name or ontology identifier.</small>
          </div>
        </template>

        <template v-else-if="workflow === 'deactivate'">
          <div class="inline-entity-workflow__field">
            <label>Deactivate entity</label>
            <BFormCheckbox
              id="deactivateSwitch"
              :model-value="deactivateCheck"
              switch
              @update:model-value="updateDeactivateCheck"
            >
              I confirm this entity should be deactivated.
            </BFormCheckbox>
          </div>

          <div v-if="deactivateCheck" class="inline-entity-workflow__field">
            <label>Replacement entity</label>
            <BFormCheckbox
              id="replaceSwitch"
              :model-value="replaceCheck"
              switch
              @update:model-value="updateReplaceCheck"
            >
              This entity is replaced by another entity.
            </BFormCheckbox>
          </div>

          <div v-if="replaceCheck" class="inline-entity-workflow__field">
            <label for="replace-entity-select">Replacement</label>
            <AutocompleteInput
              v-model:display-value="replaceDisplayProxy"
              :model-value="replaceEntityInput as any"
              :results="replaceSearchResults"
              :loading="replaceSearchLoading"
              label="Replacement Entity"
              input-id="replace-entity-select"
              placeholder="Search by ID, gene symbol, or disease name..."
              item-key="entity_id"
              item-label="symbol"
              item-secondary="entity_id"
              item-description="disease_ontology_name"
              @search="(q) => $emit('search-replacement', q)"
              @update:model-value="(id) => $emit('select-replacement', id)"
            />
          </div>
        </template>

        <template v-else-if="workflow === 'review'">
          <div class="inline-entity-workflow__field">
            <label for="review-textarea-synopsis">Synopsis</label>
            <BFormTextarea
              id="review-textarea-synopsis"
              :model-value="review?.synopsis"
              rows="4"
              size="sm"
              @update:model-value="$emit('update:review', { ...review, synopsis: $event })"
            />
          </div>

          <div class="inline-entity-workflow__grid">
            <div class="inline-entity-workflow__field">
              <label for="review-phenotype-select">Phenotypes</label>
              <TreeMultiSelect
                v-if="phenotypeOptions && phenotypeOptions.length > 0"
                id="review-phenotype-select"
                :model-value="selectPhenotype"
                :options="phenotypeOptions"
                placeholder="Select phenotypes..."
                search-placeholder="Search phenotypes..."
                @update:model-value="$emit('update:select-phenotype', $event)"
              />
            </div>

            <div class="inline-entity-workflow__field">
              <label for="review-variation-select">Variation ontology</label>
              <TreeMultiSelect
                v-if="variationOptions && variationOptions.length > 0"
                id="review-variation-select"
                :model-value="selectVariation"
                :options="variationOptions"
                placeholder="Select variations..."
                search-placeholder="Search variation types..."
                @update:model-value="$emit('update:select-variation', $event)"
              />
            </div>
          </div>

          <div class="inline-entity-workflow__grid">
            <div class="inline-entity-workflow__field">
              <label for="review-literature-select">Publications</label>
              <BFormTags
                :model-value="selectAdditionalReferences"
                input-id="review-literature-select"
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
                  <div class="inline-entity-workflow__tags">
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      class="inline-entity-workflow__tag inline-entity-workflow__tag--publication"
                      @remove="removeTag(tag)"
                    >
                      {{ tag }}
                    </BFormTag>
                  </div>
                </template>
              </BFormTags>
            </div>

            <div class="inline-entity-workflow__field">
              <label for="review-genereviews-select">GeneReviews</label>
              <BFormTags
                :model-value="selectGeneReviews"
                input-id="review-genereviews-select"
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
                  <div class="inline-entity-workflow__tags">
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      class="inline-entity-workflow__tag inline-entity-workflow__tag--genereview"
                      @remove="removeTag(tag)"
                    >
                      {{ tag }}
                    </BFormTag>
                  </div>
                </template>
              </BFormTags>
            </div>
          </div>

          <div class="inline-entity-workflow__field">
            <label for="review-textarea-comment">Comment</label>
            <BFormTextarea
              id="review-textarea-comment"
              :model-value="review?.comment"
              rows="3"
              size="sm"
              placeholder="Additional comments relevant for the curator."
              @update:model-value="$emit('update:review', { ...review, comment: $event })"
            />
          </div>
        </template>

        <template v-else-if="workflow === 'status'">
          <div class="inline-entity-workflow__field">
            <label for="status-select">Status</label>
            <BSpinner v-if="statusOptionsLoading" small label="Loading..." />
            <BFormSelect
              v-else-if="statusOptions && statusOptions.length > 0"
              id="status-select"
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

          <div class="inline-entity-workflow__field">
            <BFormCheckbox
              id="removeSwitch"
              :model-value="formData.problematic"
              switch
              @update:model-value="$emit('update:form-data', { ...formData, problematic: $event })"
            >
              Suggest removal
            </BFormCheckbox>
          </div>

          <div class="inline-entity-workflow__field">
            <label for="status-textarea-comment">Comment</label>
            <BFormTextarea
              id="status-textarea-comment"
              :model-value="formData.comment"
              rows="4"
              size="sm"
              placeholder="Why should this entity's status be changed?"
              @update:model-value="$emit('update:form-data', { ...formData, comment: $event })"
            />
          </div>
        </template>

        <footer class="inline-entity-workflow__footer">
          <BButton variant="outline-secondary" size="sm" @click="$emit('cancel')">Cancel</BButton>
          <BButton variant="primary" size="sm" type="submit" :disabled="submitting === workflow">
            <BSpinner v-if="submitting === workflow" small class="me-1" />
            Submit
          </BButton>
        </footer>
      </BForm>
    </BOverlay>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import AutocompleteInput from '@/components/forms/AutocompleteInput.vue';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';

type Workflow = 'rename' | 'deactivate' | 'review' | 'status';

const props = defineProps<{
  workflow: Workflow;
  loading: boolean;
  submitting: string | null;
  ontologyDisplay: string;
  ontologyInput: string | null;
  ontologySearchResults: any[];
  ontologySearchLoading: boolean;
  deactivateCheck: boolean;
  replaceCheck: boolean;
  replaceDisplay: string;
  replaceEntityInput: number | null;
  replaceSearchResults: any[];
  replaceSearchLoading: boolean;
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
}>();

const emit = defineEmits<{
  (e: 'update:ontology-display', value: string): void;
  (e: 'select-ontology', value: string | null): void;
  (e: 'search-ontology', value: string): void;
  (e: 'update:deactivate-check', value: boolean): void;
  (e: 'update:replace-check', value: boolean): void;
  (e: 'update:replace-display', value: string): void;
  (e: 'select-replacement', value: number | null): void;
  (e: 'search-replacement', value: string): void;
  (e: 'update:review', value: any): void;
  (e: 'update:select-phenotype', value: string[]): void;
  (e: 'update:select-variation', value: string[]): void;
  (e: 'update:select-additional-references', value: string[]): void;
  (e: 'update:select-gene-reviews', value: string[]): void;
  (e: 'update:form-data', value: any): void;
  (e: 'submit-rename'): void;
  (e: 'submit-deactivate'): void;
  (e: 'submit-review'): void;
  (e: 'submit-status'): void;
  (e: 'cancel'): void;
}>();

const ontologyDisplayProxy = computed({
  get: () => props.ontologyDisplay,
  set: (value: string) => emit('update:ontology-display', value),
});

const replaceDisplayProxy = computed({
  get: () => props.replaceDisplay,
  set: (value: string) => emit('update:replace-display', value),
});

const normalizedStatusOptions = computed(() => {
  if (!props.statusOptions || !Array.isArray(props.statusOptions)) return [];
  return props.statusOptions.map((opt: any) => ({ value: opt.id, text: opt.label }));
});

const title = computed(() => {
  switch (props.workflow) {
    case 'rename':
      return 'Rename Disease';
    case 'deactivate':
      return 'Deactivate Entity';
    case 'review':
      return 'Modify Review';
    case 'status':
      return 'Modify Status';
    default:
      return '';
  }
});

const description = computed(() => {
  switch (props.workflow) {
    case 'rename':
      return 'Replace the disease ontology assignment for this entity.';
    case 'deactivate':
      return 'Mark this entity inactive and optionally link its replacement.';
    case 'review':
      return 'Update synopsis, phenotype, variation, literature, and curator comments.';
    case 'status':
      return 'Submit a status-category change and supporting comment.';
    default:
      return '';
  }
});

function tagValidatorPMID(tag: string): boolean {
  const value = tag.replace(/\s+/g, '');
  return /^PMID:\d{5,8}$/.test(value);
}

function updateDeactivateCheck(value: unknown): void {
  emit('update:deactivate-check', Boolean(value));
}

function updateReplaceCheck(value: unknown): void {
  emit('update:replace-check', Boolean(value));
}

function updateAdditionalReferences(value: unknown): void {
  emit('update:select-additional-references', Array.isArray(value) ? value : []);
}

function updateGeneReviews(value: unknown): void {
  emit('update:select-gene-reviews', Array.isArray(value) ? value : []);
}

function submit(): void {
  switch (props.workflow) {
    case 'rename':
      emit('submit-rename');
      break;
    case 'deactivate':
      emit('submit-deactivate');
      break;
    case 'review':
      emit('submit-review');
      break;
    case 'status':
      emit('submit-status');
      break;
  }
}
</script>

<style scoped>
.inline-entity-workflow {
  display: grid;
  gap: 0.85rem;
  padding: 0.85rem;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #f8fafc;
}

.inline-entity-workflow__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.inline-entity-workflow__header h3 {
  margin: 0;
  color: #172033;
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.inline-entity-workflow__header p,
.inline-entity-workflow__field small {
  margin: 0.2rem 0 0;
  color: #526070;
  font-size: 0.8125rem;
  line-height: 1.35;
}

.inline-entity-workflow__form,
.inline-entity-workflow__field {
  display: grid;
  gap: 0.45rem;
}

.inline-entity-workflow__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}

.inline-entity-workflow__field label {
  margin: 0;
  color: #344054;
  font-size: 0.8125rem;
  font-weight: 700;
  line-height: 1.25;
}

.inline-entity-workflow :deep(.tree-multi-select .b-form-tags),
.inline-entity-workflow :deep(.b-form-tags) {
  min-width: 0;
}

.inline-entity-workflow :deep(.badge) {
  max-width: 100%;
  white-space: normal;
}

.inline-entity-workflow :deep(.b-form-tag) {
  max-width: 100%;
  overflow-wrap: anywhere;
  white-space: normal;
}

.inline-entity-workflow :deep(.inline-entity-workflow__tag) {
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

.inline-entity-workflow :deep(.inline-entity-workflow__tag--genereview) {
  border-color: #2563eb;
  background-color: #dbeafe !important;
}

.inline-entity-workflow :deep(.inline-entity-workflow__tag button),
.inline-entity-workflow :deep(.inline-entity-workflow__tag .btn-close) {
  width: 0.8rem;
  min-width: 0.8rem;
  height: 0.8rem;
  min-height: 0.8rem;
  margin-left: 0.1rem;
  padding: 0;
  background-size: 0.55rem;
  opacity: 0.62;
}

.inline-entity-workflow :deep(.inline-entity-workflow__tag button:hover),
.inline-entity-workflow :deep(.inline-entity-workflow__tag .btn-close:hover) {
  opacity: 0.95;
}

.inline-entity-workflow__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.5rem;
}

.inline-entity-workflow__footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  padding-top: 0.35rem;
}

@media (max-width: 767.98px) {
  .inline-entity-workflow__header {
    flex-direction: column;
  }

  .inline-entity-workflow__grid {
    grid-template-columns: 1fr;
  }

  .inline-entity-workflow__footer {
    flex-direction: column-reverse;
  }

  .inline-entity-workflow__footer > .btn,
  .inline-entity-workflow__header > .btn {
    width: 100%;
  }
}
</style>
