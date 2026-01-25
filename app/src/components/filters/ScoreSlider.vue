<template>
  <div class="score-slider">
    <BInputGroup size="sm">
      <BFormSelect
        v-model="selectedPreset"
        :options="presetOptions"
        :class="{ 'filter-active': modelValue !== null }"
      >
        <template #first>
          <BFormSelectOption :value="null">
            All FDR values
          </BFormSelectOption>
        </template>
      </BFormSelect>

      <!-- Custom value input (shown when "Custom" selected) -->
      <BFormInput
        v-if="selectedPreset === 'custom'"
        v-model.number="customValue"
        type="number"
        step="0.001"
        min="0"
        max="1"
        placeholder="0.05"
        class="custom-input"
      />
    </BInputGroup>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { BInputGroup, BFormSelect, BFormSelectOption, BFormInput } from 'bootstrap-vue-next';

interface Props {
  modelValue: number | null;
  presets?: Array<{ value: number; label: string }>;
}

const props = withDefaults(defineProps<Props>(), {
  presets: () => [
    { value: 0.01, label: '< 0.01' },
    { value: 0.05, label: '< 0.05' },
    { value: 0.1, label: '< 0.1' },
  ],
});

const emit = defineEmits<{
  'update:modelValue': [value: number | null];
}>();

const customValue = ref<number | null>(null);
const selectedPreset = ref<number | 'custom' | null>(null);

// Convert presets to dropdown options
const presetOptions = computed(() => [
  ...props.presets.map(p => ({ value: p.value, text: p.label })),
  { value: 'custom' as const, text: 'Custom...' },
]);

// Sync preset selection to model
watch(selectedPreset, (preset) => {
  if (preset === null) {
    emit('update:modelValue', null);
  } else if (preset === 'custom') {
    emit('update:modelValue', customValue.value);
  } else {
    emit('update:modelValue', preset);
  }
});

// Sync custom value changes
watch(customValue, (value) => {
  if (selectedPreset.value === 'custom') {
    emit('update:modelValue', value);
  }
});

// Initialize from modelValue
watch(() => props.modelValue, (value) => {
  if (value === null) {
    selectedPreset.value = null;
  } else if (props.presets.some(p => p.value === value)) {
    selectedPreset.value = value;
  } else {
    selectedPreset.value = 'custom';
    customValue.value = value;
  }
}, { immediate: true });
</script>

<style scoped>
.custom-input {
  max-width: 80px;
}

.filter-active {
  border-color: var(--bs-primary);
}
</style>
