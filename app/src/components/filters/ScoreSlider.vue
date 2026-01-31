<template>
  <div class="score-slider">
    <BInputGroup size="sm">
      <BFormSelect
        v-model="selectedPreset"
        :options="presetOptions"
        :class="{ 'filter-active': modelValue !== null }"
      >
        <template #first>
          <BFormSelectOption :value="null"> All FDR values </BFormSelectOption>
        </template>
      </BFormSelect>

      <!-- Custom value input (shown when "Custom" selected) -->
      <BFormInput
        v-if="selectedPreset === 'custom'"
        v-model="customValueText"
        type="text"
        placeholder="1e-5"
        class="custom-input"
        @blur="parseCustomValue"
        @keyup.enter="parseCustomValue"
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
    { value: 1e-10, label: '< 1e-10 (very strict)' },
    { value: 1e-5, label: '< 1e-5 (strict)' },
    { value: 0.01, label: '< 0.01' },
    { value: 0.05, label: '< 0.05' },
  ],
});

const emit = defineEmits<{
  'update:modelValue': [value: number | null];
}>();

const customValue = ref<number | null>(null);
const customValueText = ref<string>('');
const selectedPreset = ref<number | 'custom' | null>(null);

// Parse custom value from text input (supports scientific notation like "1e-5")
function parseCustomValue() {
  const parsed = parseFloat(customValueText.value);
  if (!isNaN(parsed) && parsed > 0 && parsed <= 1) {
    customValue.value = parsed;
    emit('update:modelValue', parsed);
  }
}

// Convert presets to dropdown options
const presetOptions = computed(() => [
  ...props.presets.map((p) => ({ value: p.value, text: p.label })),
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
  if (selectedPreset.value === 'custom' && value !== null) {
    // Update text representation with scientific notation for very small values
    customValueText.value = value < 0.001 ? value.toExponential() : String(value);
    emit('update:modelValue', value);
  }
});

// Initialize from modelValue
watch(
  () => props.modelValue,
  (value) => {
    if (value === null) {
      selectedPreset.value = null;
      customValueText.value = '';
    } else if (props.presets.some((p) => p.value === value)) {
      selectedPreset.value = value;
    } else {
      selectedPreset.value = 'custom';
      customValue.value = value;
      // Display small values in scientific notation
      customValueText.value = value < 0.001 ? value.toExponential() : String(value);
    }
  },
  { immediate: true }
);
</script>

<style scoped>
.custom-input {
  max-width: 80px;
}

.filter-active {
  border-color: var(--bs-primary);
}
</style>
