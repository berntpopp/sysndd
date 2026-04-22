# Architecture Patterns: Re-Review Batch Management and Reusable Curation Forms

**Domain:** Curation workflow modernization for SysNDD
**Researched:** 2026-01-26
**Focus:** Dynamic batch management, gene-specific assignment, reusable form components
**Confidence:** HIGH (based on direct codebase analysis)

## Executive Summary

The current SysNDD architecture provides solid patterns that can be extended for the new capabilities. The key findings are:

1. **Re-review batches are static** - Created offline via R scripts with hardcoded groupings of 20 genes per batch
2. **Assignment is batch-level only** - Users get assigned whole batches, not specific genes
3. **Form duplication exists** - Review.vue, ModifyEntity.vue, and CreateEntity wizard all duplicate curation form logic
4. **Strong composable patterns exist** - useEntityForm, useFormDraft, useAsyncJob provide reusable patterns to follow

The architecture should add dynamic batch management at the backend while extracting reusable form components at the frontend.

## Current Architecture Analysis

### Database Model (Re-Review)

```
re_review_entity_connect
+------------------------+
| re_review_entity_id PK |
| entity_id FK           |
| re_review_batch        | <-- Static batch number
| status_id FK           |
| review_id FK           |
| re_review_review_saved |
| re_review_status_saved |
| re_review_submitted    |
| re_review_approved     |
| approving_user_id FK   |
| created_at             |
+------------------------+

re_review_assignment
+------------------+
| assignment_id PK |
| user_id FK       |
| re_review_batch  | <-- References batch number
+------------------+
```

**Limitation:** Batches are pre-created with entities grouped by gene (hgnc_id). The R script `db/09_Rcommands_sysndd_db_table_re_review.R` creates batches of 20 genes each:

```r
# Current static batch creation logic
group_size <- 20
ndd_entity_hgnc_id_batch <- ndd_entity %>%
  arrange(entity_id) %>%
  select(hgnc_id) %>%
  unique() %>%
  mutate(re_review_batch = (row_number()-1) %/% group_size + 1)
```

### Current Backend Pattern (Plumber)

```
endpoints/re_review_endpoints.R
+-----------------------------------+
| PUT /submit                       | Update re_review_entity_connect
| PUT /unsubmit/<id>               | Revert submission
| PUT /approve/<id>                | Approve re-review
| GET /table                       | Cursor-paginated re-review list
| GET /batch/apply                 | Email curators for new batch
| PUT /batch/assign                | Assign NEXT unassigned batch
| DELETE /batch/unassign           | Remove batch assignment
| GET /assignment_table            | Summary statistics
+-----------------------------------+
```

**Key Limitation:** `/batch/assign` only finds the next unassigned batch:

```r
# Current: picks NEXT unassigned batch, no control
re_review_entity_connect <- pool %>%
  tbl("re_review_entity_connect") %>%
  select(re_review_batch) %>%
  anti_join(re_review_assignment, by = c("re_review_batch")) %>%
  summarize(re_review_batch = min(re_review_batch))
```

No ability to:
- Create new batches dynamically
- Assign specific genes/entities to users
- Recalculate batches based on criteria
- Filter entities by date range (hardcoded `2020-01-01`)

### Current Frontend Pattern (Forms)

| Component | Pattern | State Management | Reusability |
|-----------|---------|------------------|-------------|
| CreateEntity.vue | 5-step wizard | useEntityForm composable + provide/inject | HIGH |
| Review.vue | Modal-based inline | Options API + local data | LOW |
| ModifyEntity.vue | Modal-based actions | Options API + local data | LOW |
| ManageReReview.vue | Table + actions | Options API + local data | MEDIUM |

**Excellent Pattern in CreateEntity:** Uses `provide/inject` to share form state with step components:

```typescript
// Parent (CreateEntity.vue) provides:
provide('formData', formData);
provide('getFieldError', getFieldError);
provide('getFieldState', getFieldState);
provide('touchField', touchField);

// Child (StepEvidence.vue) injects:
const formData = inject<EntityFormData>('formData')!;
const touchField = inject<(field: string) => void>('touchField')!;
```

**Problem in Review.vue:** Duplicates form logic that could be shared:
- Synopsis textarea with same validation
- Phenotype multiselect (same options, same format)
- Variation ontology multiselect
- Publications tag input
- GeneReviews tag input
- Comment textarea

**Same duplication in ModifyEntity.vue** for Modify Review and Modify Status modals.

## Recommended Architecture

### 1. Backend: Re-Review Service Layer

Create a dedicated service for batch management following existing patterns.

**New File:** `api/services/re-review-service.R`

```r
#' Create a new batch from entity criteria
#'
#' @param criteria List with filter parameters
#'   - date_before: Only include entities reviewed before this date
#'   - hgnc_ids: Specific genes to include (optional)
#'   - exclude_approved: Exclude already approved entities (default TRUE)
#' @param batch_size Integer target size for batch (default 20)
#' @param pool Database connection pool
#' @return List with status, batch_id, entity_count
svc_re_review_create_batch <- function(criteria, batch_size = 20, pool) {
  # 1. Find eligible entities based on criteria
  eligible_entities <- pool %>%
    tbl("ndd_entity_view") %>%
    left_join(tbl(pool, "ndd_entity_review"), by = "entity_id") %>%
    filter(review_date < !!criteria$date_before) %>%
    collect()

  # 2. Filter by hgnc_ids if provided
  if (!is.null(criteria$hgnc_ids)) {
    eligible_entities <- eligible_entities %>%
      filter(hgnc_id %in% criteria$hgnc_ids)
  }

  # 3. Exclude already in re_review if requested
  if (isTRUE(criteria$exclude_existing)) {
    existing <- pool %>%
      tbl("re_review_entity_connect") %>%
      select(entity_id) %>%
      collect()
    eligible_entities <- eligible_entities %>%
      anti_join(existing, by = "entity_id")
  }

  # 4. Get next batch number
  max_batch <- pool %>%
    tbl("re_review_entity_connect") %>%
    summarize(max_batch = max(re_review_batch, na.rm = TRUE)) %>%
    pull(max_batch)
  next_batch <- ifelse(is.na(max_batch), 1, max_batch + 1)

  # 5. Insert into re_review_entity_connect (batch_size entities)
  entities_to_insert <- eligible_entities %>%
    head(batch_size) %>%
    mutate(
      re_review_batch = next_batch,
      re_review_review_saved = FALSE,
      re_review_status_saved = FALSE,
      re_review_submitted = FALSE,
      re_review_approved = FALSE
    )

  # 6. Insert via repository
  # ...

  list(
    status = 200,
    batch_id = next_batch,
    entity_count = nrow(entities_to_insert)
  )
}

#' Assign specific entities to user for re-review
#'
#' @param user_id User to assign
#' @param entity_ids Vector of entity IDs (gene-level granularity)
#' @param pool Database connection pool
svc_re_review_assign_entities <- function(user_id, entity_ids, pool) {
  # 1. Create new batch for these entities
  # 2. Insert assignment
}

#' Recalculate batch - add/remove entities based on criteria
svc_re_review_recalculate_batch <- function(batch_id, new_criteria, pool) {
  # 1. Remove entities not matching criteria
  # 2. Add entities matching criteria
  # 3. Return updated batch
}
```

**New Endpoints:** `api/endpoints/re_review_endpoints.R` (additions)

| Endpoint | Method | Purpose | Request Body |
|----------|--------|---------|--------------|
| `/batch/create` | POST | Create batch from criteria | `{criteria, batch_size}` |
| `/batch/{id}/entities` | PUT | Add/remove entities from batch | `{add: [], remove: []}` |
| `/batch/{id}/assign` | PUT | Assign specific batch to user | `{user_id}` |
| `/entities/assign` | PUT | Assign specific entities to user | `{user_id, entity_ids}` |
| `/batch/{id}/recalculate` | POST | Recalculate batch from criteria | `{criteria}` |

### 2. Frontend: Reusable Curation Form Components

Extract form elements from Review.vue and ModifyEntity.vue into reusable components.

#### Component Hierarchy

```
components/forms/curation/
+--------------------------------+
| CurationFormProvider.vue       | Provides form state via inject/provide
| ReviewFormFields.vue           | Synopsis, phenotypes, variations, publications
| StatusFormFields.vue           | Status select, removal switch, comment
| EntityBadgeHeader.vue          | Common entity display header
| index.ts                       | Barrel export
+--------------------------------+

composables/
+--------------------------------+
| useReviewForm.ts               | State/validation for review fields (NEW)
| useStatusForm.ts               | State/validation for status fields (NEW)
| useCurationForm.ts             | Combined review+status (NEW, uses above)
+--------------------------------+
```

#### CurationFormProvider Pattern

```vue
<!-- components/forms/curation/CurationFormProvider.vue -->
<template>
  <slot />
</template>

<script setup lang="ts">
import { provide } from 'vue';
import useReviewForm from '@/composables/useReviewForm';
import useStatusForm from '@/composables/useStatusForm';
import type { ReviewFormData, StatusFormData } from '@/composables/useCurationForm';

const props = defineProps<{
  mode: 'create' | 'edit' | 're-review';
  initialReviewData?: Partial<ReviewFormData>;
  initialStatusData?: Partial<StatusFormData>;
}>();

const emit = defineEmits<{
  (e: 'submit-review', data: ReviewFormData): void;
  (e: 'submit-status', data: StatusFormData): void;
}>();

// Initialize composables
const reviewForm = useReviewForm(props.initialReviewData);
const statusForm = useStatusForm(props.initialStatusData);

// Provide to children (mirrors CreateEntity pattern)
provide('reviewForm', reviewForm);
provide('statusForm', statusForm);
provide('curationMode', props.mode);

// Expose submit handlers
const submitReview = () => {
  if (reviewForm.isValid.value) {
    emit('submit-review', reviewForm.getFormSnapshot());
  }
};

const submitStatus = () => {
  if (statusForm.isValid.value) {
    emit('submit-status', statusForm.getFormSnapshot());
  }
};

defineExpose({ submitReview, submitStatus });
</script>
```

#### useReviewForm Composable

```typescript
// composables/useReviewForm.ts
import { ref, reactive, computed } from 'vue';

export interface ReviewFormData {
  synopsis: string;
  phenotypes: string[];
  variationOntology: string[];
  publications: string[];
  genereviews: string[];
  comment: string;
  review_id?: number;
  entity_id?: number;
}

export interface ReviewFormReturn {
  formData: ReviewFormData;
  touched: Record<string, boolean>;
  isValid: ComputedRef<boolean>;
  touchField: (field: string) => void;
  getFieldError: (field: string) => string | null;
  getFieldState: (field: string) => boolean | null;
  resetForm: () => void;
  getFormSnapshot: () => ReviewFormData;
  restoreFromSnapshot: (data: Partial<ReviewFormData>) => void;
}

export default function useReviewForm(
  initial?: Partial<ReviewFormData>
): ReviewFormReturn {
  const formData = reactive<ReviewFormData>({
    synopsis: initial?.synopsis ?? '',
    phenotypes: initial?.phenotypes ?? [],
    variationOntology: initial?.variationOntology ?? [],
    publications: initial?.publications ?? [],
    genereviews: initial?.genereviews ?? [],
    comment: initial?.comment ?? '',
    review_id: initial?.review_id,
    entity_id: initial?.entity_id,
  });

  const touched = reactive<Record<string, boolean>>({
    synopsis: false,
    phenotypes: false,
    publications: false,
  });

  // Validation rules (matches useEntityForm pattern)
  const validateSynopsis = (value: string): string | true => {
    if (!value || value.trim().length < 10) {
      return 'Synopsis must be at least 10 characters';
    }
    if (value.length > 2000) {
      return 'Synopsis must be less than 2000 characters';
    }
    return true;
  };

  const validatePublications = (value: string[]): string | true => {
    if (!value || value.length === 0) {
      return 'At least one publication is required';
    }
    return true;
  };

  // Field error getter (mirrors useEntityForm)
  const getFieldError = (fieldName: string): string | null => {
    if (!touched[fieldName]) return null;

    switch (fieldName) {
      case 'synopsis':
        const synopsisResult = validateSynopsis(formData.synopsis);
        return synopsisResult === true ? null : synopsisResult;
      case 'publications':
        const pubResult = validatePublications(formData.publications);
        return pubResult === true ? null : pubResult;
      default:
        return null;
    }
  };

  // Field state for Bootstrap validation
  const getFieldState = (fieldName: string): boolean | null => {
    if (!touched[fieldName]) return null;
    return getFieldError(fieldName) === null;
  };

  const touchField = (fieldName: string) => {
    touched[fieldName] = true;
  };

  const isValid = computed(() => {
    return (
      validateSynopsis(formData.synopsis) === true &&
      validatePublications(formData.publications) === true
    );
  });

  const resetForm = () => {
    formData.synopsis = '';
    formData.phenotypes = [];
    formData.variationOntology = [];
    formData.publications = [];
    formData.genereviews = [];
    formData.comment = '';
    formData.review_id = undefined;
    formData.entity_id = undefined;
    Object.keys(touched).forEach(key => { touched[key] = false; });
  };

  const getFormSnapshot = (): ReviewFormData => ({ ...formData });

  const restoreFromSnapshot = (data: Partial<ReviewFormData>) => {
    Object.assign(formData, data);
  };

  return {
    formData,
    touched,
    isValid,
    touchField,
    getFieldError,
    getFieldState,
    resetForm,
    getFormSnapshot,
    restoreFromSnapshot,
  };
}
```

#### ReviewFormFields Component

```vue
<!-- components/forms/curation/ReviewFormFields.vue -->
<template>
  <div class="review-form-fields">
    <!-- Synopsis (reused from StepEvidence pattern) -->
    <BFormGroup
      label="Synopsis"
      :state="getFieldState('synopsis')"
      :invalid-feedback="getFieldError('synopsis')"
      class="mb-3"
    >
      <template #label>
        <span class="fw-bold">Synopsis <span class="text-danger">*</span></span>
        <BBadge
          id="popover-synopsis-help"
          pill
          href="#"
          variant="info"
          class="ms-1"
        >
          <i class="bi bi-question-circle-fill" />
        </BBadge>
        <BPopover target="popover-synopsis-help" triggers="focus">
          <template #title>Synopsis instructions</template>
          Short summary for this disease entity...
        </BPopover>
      </template>
      <BFormTextarea
        v-model="formData.synopsis"
        rows="3"
        :state="getFieldState('synopsis')"
        @blur="touchField('synopsis')"
      />
      <div class="d-flex justify-content-end mt-1">
        <small :class="synopsisCountClass">
          {{ formData.synopsis.length }}/2000
        </small>
      </div>
    </BFormGroup>

    <!-- Phenotypes (reused from StepPhenotypeVariation pattern) -->
    <BFormGroup label="Phenotypes" class="mb-3">
      <BFormSelect
        v-model="selectedPhenotype"
        :options="phenotypeOptions"
        size="sm"
        @change="addPhenotype"
      >
        <template #first>
          <BFormSelectOption :value="null">
            Add a phenotype term...
          </BFormSelectOption>
        </template>
      </BFormSelect>
      <!-- Selected badges -->
      <div v-if="formData.phenotypes.length > 0" class="mt-2 d-flex flex-wrap gap-2">
        <BBadge
          v-for="phenotype in formData.phenotypes"
          :key="phenotype"
          variant="primary"
          pill
        >
          {{ getPhenotypeLabel(phenotype) }}
          <BCloseButton variant="white" @click="removePhenotype(phenotype)" />
        </BBadge>
      </div>
    </BFormGroup>

    <!-- Variation Ontology -->
    <BFormGroup label="Variation Ontology" class="mb-3">
      <!-- Same pattern as phenotypes -->
    </BFormGroup>

    <!-- Publications (reused from StepEvidence pattern) -->
    <BFormGroup
      label="Publications"
      :state="getFieldState('publications')"
      :invalid-feedback="getFieldError('publications')"
      class="mb-3"
    >
      <BFormTags
        v-model="formData.publications"
        :tag-validator="validatePMID"
        separator=",;"
        remove-on-delete
        @blur="touchField('publications')"
      >
        <!-- Same template as StepEvidence -->
      </BFormTags>
    </BFormGroup>

    <!-- GeneReviews -->
    <BFormGroup label="GeneReviews" class="mb-3">
      <!-- Same pattern as publications -->
    </BFormGroup>

    <!-- Comment -->
    <BFormGroup label="Comment" class="mb-3">
      <BFormTextarea
        v-model="formData.comment"
        rows="2"
        placeholder="Additional comments relevant for the curator."
      />
    </BFormGroup>
  </div>
</template>

<script setup lang="ts">
import { inject, ref, computed } from 'vue';
import type { ReviewFormReturn } from '@/composables/useReviewForm';
import { validatePMID } from '@/composables/useEntityForm';

const props = defineProps<{
  phenotypeOptions: GroupedSelectOptions;
  variationOptions: GroupedSelectOptions;
}>();

// Inject form state from CurationFormProvider
const {
  formData,
  touchField,
  getFieldError,
  getFieldState,
} = inject<ReviewFormReturn>('reviewForm')!;

const selectedPhenotype = ref<string | null>(null);
const selectedVariation = ref<string | null>(null);

// Phenotype add/remove logic (same as StepPhenotypeVariation)
const addPhenotype = async () => {
  if (selectedPhenotype.value && !formData.phenotypes.includes(selectedPhenotype.value)) {
    formData.phenotypes.push(selectedPhenotype.value);
  }
  await nextTick();
  selectedPhenotype.value = null;
};

const removePhenotype = (value: string) => {
  const index = formData.phenotypes.indexOf(value);
  if (index > -1) formData.phenotypes.splice(index, 1);
};

// ... variation logic

const synopsisCountClass = computed(() => {
  const remaining = 2000 - formData.synopsis.length;
  if (remaining < 0) return 'text-danger';
  if (remaining < 100) return 'text-warning';
  return 'text-muted';
});
</script>
```

### 3. Integration Points

#### Backend Integration

| Existing Component | Integration Point |
|-------------------|-------------------|
| `re_review_endpoints.R` | Add new batch management endpoints |
| `review-service.R` | Use for review creation/update in re-review flow |
| `status-service.R` | Use for status creation/update in re-review flow |
| `entity-service.R` | Query entities for batch creation criteria |
| `db-helpers.R` | Use `db_execute_query`, `db_execute_statement` |

#### Frontend Integration

| Existing Component | Integration |
|-------------------|-------------|
| `Review.vue` | Replace inline modals with `CurationFormProvider` + `ReviewFormFields` |
| `ModifyEntity.vue` | Replace inline modals with reusable components |
| `ManageReReview.vue` | Add batch creation/assignment UI |
| `useEntityForm.ts` | Reference pattern for new composables |
| `useFormDraft.ts` | Reuse for curation form draft saving |
| `StepEvidence.vue` | Source of patterns for `ReviewFormFields` |
| `StepPhenotypeVariation.vue` | Source of patterns for phenotype/variation fields |

### 4. Data Flow Changes

#### Current Flow (Re-Review)
```
User requests batch
    |
    v
GET /batch/apply --> Email to curator
    |
    v
Curator assigns
    |
    v
PUT /batch/assign --> Picks NEXT available batch (no control)
    |
    v
User reviews entities in modal
    |
    v
PUT /submit --> Updates entity_connect
    |
    v
Curator approves
    |
    v
PUT /approve --> Updates status/review as primary
```

#### New Flow (Dynamic Batches)
```
Admin creates batch with criteria
    |
    v
POST /batch/create --> Creates batch from filtered entities
    |
    v
OR: Admin assigns specific genes
    |
    v
PUT /entities/assign --> Creates ad-hoc batch for specific entities
    |
    v
User reviews using reusable form components
    |
    v
PUT /submit --> Same as before
    |
    v
Curator can recalculate batch
    |
    v
POST /batch/{id}/recalculate --> Adds/removes entities
```

## Component Boundaries

### Backend Layers

```
+--------------------------------------------------+
|            Plumber Endpoints                      |
|   re_review_endpoints.R (batch management)        |
+------------------------+-------------------------+
                         |
+------------------------v-------------------------+
|            Service Layer                          |
|   re-review-service.R (NEW - business logic)      |
|   Uses: review-service.R, status-service.R        |
+------------------------+-------------------------+
                         |
+------------------------v-------------------------+
|         Repository Layer                          |
|   review-repository.R, status-repository.R        |
|   Database queries via pool                       |
+--------------------------------------------------+
```

### Frontend Layers

```
+--------------------------------------------------+
|            Views (Pages)                          |
|   Review.vue, ModifyEntity.vue, ManageReReview    |
+------------------------+-------------------------+
                         | uses
+------------------------v-------------------------+
|         Form Provider Components                  |
|   CurationFormProvider.vue                        |
|   (provide/inject pattern)                        |
+------------------------+-------------------------+
                         | provides to
+------------------------v-------------------------+
|         Reusable Form Components                  |
|   ReviewFormFields.vue, StatusFormFields.vue      |
|   EntityBadgeHeader.vue                           |
+------------------------+-------------------------+
                         | uses
+------------------------v-------------------------+
|            Composables                            |
|   useReviewForm.ts, useStatusForm.ts              |
|   useCurationForm.ts                              |
+--------------------------------------------------+
```

## Suggested Build Order

Based on dependency analysis, the recommended build order is:

### Phase 1: Backend Batch Management (Foundation)
1. **re-review-service.R** - Core batch creation/assignment logic
2. **New endpoints** - `/batch/create`, `/entities/assign`
3. **No database migration needed** - Use existing tables

**Rationale:** Backend must support dynamic batch creation before frontend can use it.

**Deliverables:**
- `api/services/re-review-service.R`
- Extended `api/endpoints/re_review_endpoints.R`
- Unit tests for new service functions

---

### Phase 2: Reusable Form Composables
1. **useReviewForm.ts** - Extract review form logic from Review.vue
2. **useStatusForm.ts** - Extract status form logic
3. **useCurationForm.ts** - Combined for convenience
4. Export from `composables/index.ts`

**Rationale:** Composables are foundation for reusable components.

**Deliverables:**
- `app/src/composables/useReviewForm.ts`
- `app/src/composables/useStatusForm.ts`
- `app/src/composables/useCurationForm.ts`
- Updated `app/src/composables/index.ts`

---

### Phase 3: Reusable Form Components
1. **ReviewFormFields.vue** - Review form UI (synopsis, phenotypes, etc.)
2. **StatusFormFields.vue** - Status form UI
3. **CurationFormProvider.vue** - Provider wrapper
4. **EntityBadgeHeader.vue** - Common header display

**Rationale:** Components depend on composables from Phase 2.

**Deliverables:**
- `app/src/components/forms/curation/ReviewFormFields.vue`
- `app/src/components/forms/curation/StatusFormFields.vue`
- `app/src/components/forms/curation/CurationFormProvider.vue`
- `app/src/components/forms/curation/EntityBadgeHeader.vue`
- `app/src/components/forms/curation/index.ts`

---

### Phase 4: View Integration
1. **Update Review.vue** - Use new reusable components in modals
2. **Update ModifyEntity.vue** - Use new reusable components
3. **Update ManageReReview.vue** - Add batch creation UI

**Rationale:** Views are updated last, after reusable pieces are ready.

**Deliverables:**
- Refactored `Review.vue` using `CurationFormProvider`
- Refactored `ModifyEntity.vue` using reusable components
- Enhanced `ManageReReview.vue` with batch creation

---

### Phase 5: Advanced Features
1. **Batch recalculation endpoint** - POST `/batch/{id}/recalculate`
2. **Batch criteria builder UI** - Date range, gene list filters
3. **Gene-specific assignment UI** - Select genes for user

**Rationale:** Advanced features build on foundation from earlier phases.

## Anti-Patterns to Avoid

### 1. Inline Form Logic Duplication
**Current Problem in Review.vue:**
```vue
<!-- Review.vue has ~800 lines with duplicated form logic -->
<BFormTextarea v-model="review_info.synopsis" ... />
<BFormSelect v-model="select_phenotype[0]" ... />
<!-- Same fields duplicated in ModifyEntity.vue -->
```

**Solution:** Extract to `ReviewFormFields.vue` and `useReviewForm.ts`.

### 2. Direct Database Queries in Endpoints
**Current Pattern in re_review_endpoints.R:**
```r
# Avoid: Complex business logic directly in endpoint
re_review_entity_connect <- pool %>%
  tbl("re_review_entity_connect") %>%
  filter(re_review_approved == 0) %>%
  inner_join(re_review_assignment, by = c("re_review_batch")) %>%
  inner_join(ndd_entity_view, by = c("entity_id")) %>%
  # ... many more joins ...
```

**Solution:** Move to service layer:
```r
# Endpoint calls service
result <- svc_re_review_get_table(user_id, curate, filter, pool)
```

### 3. Options API for New Components
**Current in ManageReReview.vue:**
```vue
<script>
export default {
  data() { return { ... } },
  methods: { async loadUserList() { ... } }
}
</script>
```

**Solution:** Use Composition API with `<script setup>` for new components.

### 4. Hardcoded Filter Dates
**Current in re_review_endpoints.R:**
```r
filter = "or(lessOrEqual(review_date,2020-01-01),equals(re_review_review_saved,1)"
```

**Solution:** Make filter criteria configurable at batch creation time.

### 5. Mixed Concerns in Review.vue
**Current:** Single 2000-line component handles:
- Table display
- Review modal
- Status modal
- Submit modal
- Approve modal
- Data loading
- Form validation

**Solution:** Split into focused components, share via provide/inject.

## Scalability Considerations

| Concern | Current State | Recommended Approach |
|---------|---------------|---------------------|
| Batch size | Fixed at 20 genes | Configurable per batch |
| Re-review criteria | Hardcoded date filter | Flexible filter builder |
| User assignment | Batch-level only | Gene-level granularity |
| Progress tracking | Full table scan | Cache statistics, use indexes |
| Form state | Lost on page refresh | Use `useFormDraft` for persistence |

## Risk Assessment

### Low Risk (Proven Patterns)
- Extracting composables (follow useEntityForm pattern)
- Creating reusable components (follow StepEvidence pattern)
- Adding new endpoints (follow existing endpoint structure)

### Medium Risk (New Service Layer)
- Creating re-review-service.R requires understanding existing data flow
- Batch recalculation logic needs careful transaction handling
- **Mitigation:** Start with simple batch creation, add recalculation later

### Considerations
- Review.vue is large (2000 lines) - refactor incrementally
- Options API to Composition API migration may need temporary dual support
- Test thoroughly with existing re-review data

## Sources

Analysis based on direct examination of:

**Backend:**
- `/home/bernt-popp/development/sysndd/api/endpoints/re_review_endpoints.R`
- `/home/bernt-popp/development/sysndd/api/services/entity-service.R`
- `/home/bernt-popp/development/sysndd/api/services/review-service.R`
- `/home/bernt-popp/development/sysndd/db/09_Rcommands_sysndd_db_table_re_review.R`

**Frontend:**
- `/home/bernt-popp/development/sysndd/app/src/views/review/Review.vue`
- `/home/bernt-popp/development/sysndd/app/src/views/curate/CreateEntity.vue`
- `/home/bernt-popp/development/sysndd/app/src/views/curate/ModifyEntity.vue`
- `/home/bernt-popp/development/sysndd/app/src/views/curate/ManageReReview.vue`
- `/home/bernt-popp/development/sysndd/app/src/composables/useEntityForm.ts`
- `/home/bernt-popp/development/sysndd/app/src/composables/useFormDraft.ts`
- `/home/bernt-popp/development/sysndd/app/src/composables/useAsyncJob.ts`
- `/home/bernt-popp/development/sysndd/app/src/components/forms/wizard/StepEvidence.vue`
- `/home/bernt-popp/development/sysndd/app/src/components/forms/wizard/StepPhenotypeVariation.vue`
- `/home/bernt-popp/development/sysndd/app/src/components/forms/wizard/FormWizard.vue`
