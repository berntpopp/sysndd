<!-- app/src/views/admin/components/MetadataEntryModal.vue -->
<!--
  Create/edit modal for a curation metadata vocabulary entry (issue #32).

  Renders one input per editable field declared by the vocabulary descriptor,
  plus the is_active / sort lifecycle controls. In edit mode for an anchored
  vocabulary the ontology term id (primary key) is shown read-only; in create
  mode (sysndd vocabularies only) it is auto-assigned by the API.
-->
<template>
  <BModal
    id="metadata-entry-modal"
    v-model="proxyVisible"
    :title="modalTitle"
    ok-variant="primary"
    :ok-title="okTitle"
    :ok-disabled="saving"
    cancel-title="Cancel"
    cancel-variant="outline-secondary"
    @ok.prevent="onSubmit"
    @cancel="$emit('cancel')"
  >
    <BForm @submit.prevent="onSubmit">
      <div v-if="mode === 'edit' && pkValue !== null" class="mb-3">
        <label class="form-label fw-semibold">{{ pkLabel }}</label>
        <BFormInput :model-value="String(pkValue)" disabled />
      </div>

      <div v-for="field in textFields" :key="field" class="mb-3">
        <label :for="`metadata-field-${field}`" class="form-label fw-semibold">
          {{ humanize(field) }}
        </label>
        <BFormInput
          :id="`metadata-field-${field}`"
          v-model="form[field]"
          :data-testid="`metadata-field-${field}`"
          type="text"
        />
      </div>

      <div v-for="field in flagFields" :key="field" class="mb-3 form-check form-switch">
        <input
          :id="`metadata-flag-${field}`"
          v-model="flags[field]"
          class="form-check-input"
          type="checkbox"
          :data-testid="`metadata-flag-${field}`"
        />
        <label class="form-check-label" :for="`metadata-flag-${field}`">
          {{ humanize(field) }}
        </label>
      </div>

      <div v-if="vocabulary?.has_sort" class="mb-3">
        <label for="metadata-sort" class="form-label fw-semibold">Sort order</label>
        <BFormInput id="metadata-sort" v-model="sortValue" type="number" />
      </div>

      <div v-if="vocabulary?.has_is_active" class="mb-1 form-check form-switch">
        <input
          id="metadata-is-active"
          v-model="isActive"
          class="form-check-input"
          type="checkbox"
          data-testid="metadata-is-active"
        />
        <label class="form-check-label" for="metadata-is-active">Active</label>
      </div>
    </BForm>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent, reactive, ref, watch, type PropType } from 'vue';
import type {
  MetadataVocabulary,
  MetadataRow,
  MetadataCellValue,
} from '@/api/metadata';

const FLAG_FIELDS = ['allowed_phenotype', 'allowed_variation'];

function humanizeLabel(field: string): string {
  return field
    .replace(/_/g, ' ')
    .replace(/\bhpo\b/gi, 'HPO')
    .replace(/^\w/, (c) => c.toUpperCase());
}

export default defineComponent({
  name: 'MetadataEntryModal',
  props: {
    visible: { type: Boolean, default: false },
    mode: { type: String as PropType<'create' | 'edit'>, default: 'create' },
    vocabulary: {
      type: Object as PropType<MetadataVocabulary | null>,
      default: null,
    },
    row: { type: Object as PropType<MetadataRow | null>, default: null },
    saving: { type: Boolean, default: false },
  },
  emits: ['update:visible', 'submit', 'cancel'],
  setup(props, { emit }) {
    const proxyVisible = computed({
      get: () => props.visible,
      set: (v) => emit('update:visible', v),
    });

    const form = reactive<Record<string, string>>({});
    const flags = reactive<Record<string, boolean>>({});
    const isActive = ref(true);
    const sortValue = ref<string>('');

    const textFields = computed(() =>
      (props.vocabulary?.fields ?? []).filter((f) => !FLAG_FIELDS.includes(f))
    );
    const flagFields = computed(() =>
      (props.vocabulary?.fields ?? []).filter((f) => FLAG_FIELDS.includes(f))
    );

    const pkValue = computed<MetadataCellValue | null>(() => {
      if (!props.vocabulary || !props.row) return null;
      return props.row[props.vocabulary.pk] ?? null;
    });
    const pkLabel = computed(() => humanizeLabel(props.vocabulary?.pk ?? 'Identifier'));

    const modalTitle = computed(() => {
      const label = props.vocabulary?.label ?? 'entry';
      return props.mode === 'create' ? `Add ${label}` : `Edit ${label}`;
    });
    const okTitle = computed(() => (props.mode === 'create' ? 'Create' : 'Save changes'));

    // Re-seed the form whenever the modal opens or the target row changes.
    watch(
      () => [props.visible, props.row, props.vocabulary],
      () => {
        if (!props.visible || !props.vocabulary) return;
        for (const field of textFields.value) {
          const raw = props.row?.[field];
          form[field] = raw === null || raw === undefined ? '' : String(raw);
        }
        for (const field of flagFields.value) {
          flags[field] = toBool(props.row?.[field]);
        }
        isActive.value = props.row ? toBool(props.row.is_active) : true;
        const sortRaw = props.row?.sort;
        sortValue.value = sortRaw === null || sortRaw === undefined ? '' : String(sortRaw);
      },
      { immediate: true }
    );

    function toBool(value: MetadataCellValue | undefined): boolean {
      return value === 1 || value === '1' || value === true;
    }

    function onSubmit() {
      const payload: Record<string, MetadataCellValue> = {};
      for (const field of textFields.value) {
        const v = (form[field] ?? '').trim();
        if (props.mode === 'create' || v.length > 0 || props.row?.[field] !== undefined) {
          payload[field] = v;
        }
      }
      for (const field of flagFields.value) {
        payload[field] = flags[field] ? 1 : 0;
      }
      if (props.vocabulary?.has_is_active) {
        payload.is_active = isActive.value ? 1 : 0;
      }
      if (props.vocabulary?.has_sort && sortValue.value !== '') {
        const n = Number(sortValue.value);
        if (!Number.isNaN(n)) payload.sort = n;
      }
      emit('submit', { mode: props.mode, pk: pkValue.value, payload });
    }

    return {
      proxyVisible,
      form,
      flags,
      isActive,
      sortValue,
      textFields,
      flagFields,
      pkValue,
      pkLabel,
      modalTitle,
      okTitle,
      humanize: humanizeLabel,
      onSubmit,
    };
  },
});
</script>
