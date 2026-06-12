<!-- views/admin/components/OntologyEditModal.vue -->
<template>
  <BModal
    :model-value="modelValue"
    size="lg"
    centered
    header-class="border-bottom-0 pb-0"
    footer-class="border-top-0 pt-0"
    body-class="pt-2"
    @update:model-value="$emit('update:modelValue', $event)"
    @hidden="$emit('update:ontology', {})"
  >
    <template #header>
      <div class="w-100">
        <div class="d-flex justify-content-between align-items-start">
          <div>
            <h5 class="mb-1">
              <i class="bi bi-journal-text text-primary me-2" />
              Edit Ontology Term
            </h5>
            <p class="text-muted small mb-0">
              Modify the properties of this variation ontology entry
            </p>
          </div>
          <BButton variant="link" class="p-0 text-muted" @click="$emit('update:modelValue', false)">
            <i class="bi bi-x-lg" />
          </BButton>
        </div>
      </div>
    </template>

    <BForm @submit.prevent="$emit('save')">
      <!-- Read-only info card -->
      <BCard class="mb-3 bg-light border-0">
        <BRow>
          <BCol sm="6">
            <small class="text-muted d-block">Vario ID</small>
            <strong class="text-primary">{{ working.vario_id }}</strong>
          </BCol>
          <BCol sm="6">
            <small class="text-muted d-block">Last Updated</small>
            <strong>{{ working.update_date || 'Never' }}</strong>
          </BCol>
        </BRow>
      </BCard>

      <!-- Editable fields with improved styling -->
      <BFormGroup
        v-for="field in editableFields"
        :key="field.key"
        :label-for="'input-' + field.key"
        class="mb-3"
      >
        <template #label>
          <span class="fw-semibold">{{ field.label }}</span>
        </template>
        <!-- Use textarea for definition field -->
        <BFormTextarea
          v-if="field.key === 'definition'"
          :id="'input-' + field.key"
          v-model="working[field.key]"
          rows="3"
          placeholder="Enter definition..."
        />
        <!-- Use select for boolean fields -->
        <BFormSelect
          v-else-if="field.key === 'obsolete' || field.key === 'is_active'"
          :id="'input-' + field.key"
          v-model="working[field.key]"
        >
          <BFormSelectOption :value="1">
            {{ field.key === 'is_active' ? 'Active' : 'Yes (Obsolete)' }}
          </BFormSelectOption>
          <BFormSelectOption :value="0">
            {{ field.key === 'is_active' ? 'Inactive' : 'No (Current)' }}
          </BFormSelectOption>
        </BFormSelect>
        <!-- Use number input for sort -->
        <BFormInput
          v-else-if="field.key === 'sort'"
          :id="'input-' + field.key"
          v-model="working[field.key]"
          type="number"
          min="0"
        />
        <!-- Default text input -->
        <BFormInput v-else :id="'input-' + field.key" v-model="working[field.key]" />
      </BFormGroup>
    </BForm>

    <template #footer>
      <div class="d-flex justify-content-end gap-2 w-100">
        <BButton variant="outline-secondary" @click="$emit('update:modelValue', false)">
          <i class="bi bi-x-circle me-1" />
          Cancel
        </BButton>
        <BButton variant="primary" @click="$emit('save')">
          <i class="bi bi-check-circle me-1" />
          Save Changes
        </BButton>
      </div>
    </template>
  </BModal>
</template>

<script>
import { computed } from 'vue';

export default {
  name: 'OntologyEditModal',
  props: {
    /** Two-way modal visibility flag. */
    modelValue: { type: Boolean, default: false },
    /** The ontology row currently being edited; form inputs edit it in place. */
    ontology: { type: Object, default: () => ({}) },
    /** Full field catalog from the parent table; editable subset is derived. */
    fields: { type: Array, default: () => [] },
  },
  emits: ['update:modelValue', 'update:ontology', 'save'],
  setup(props) {
    // The form binds `v-model` on `working[field.key]`. `working` is the
    // parent's `ontology` object by reference, so in-place edits reflect
    // straight back into the parent's `ontologyToEdit` — preserving the
    // legacy inline-modal behavior. Reset on close is signalled via the
    // `update:ontology` emit from the `@hidden` handler.
    const working = computed(() => props.ontology);

    // Filter out non-editable fields like 'actions', 'vario_id', and
    // 'update_date' — identical to the legacy `editableFields` computed.
    const editableFields = computed(() =>
      props.fields.filter(
        (field) =>
          field.key !== 'actions' && field.key !== 'vario_id' && field.key !== 'update_date'
      )
    );

    return { working, editableFields };
  },
};
</script>
