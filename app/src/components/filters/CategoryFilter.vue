<template>
  <BFormSelect
    v-model="selected"
    :options="options"
    size="sm"
    :class="{ 'filter-active': selected !== null }"
  >
    <template #first>
      <BFormSelectOption :value="null">
        {{ placeholder }}
      </BFormSelectOption>
    </template>
  </BFormSelect>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BFormSelect, BFormSelectOption } from 'bootstrap-vue-next';

interface Props {
  modelValue: string | null;
  options: Array<{ value: string; text: string }>;
  placeholder?: string;
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: 'All categories',
});

const emit = defineEmits<{
  'update:modelValue': [value: string | null];
}>();

const selected = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value),
});
</script>

<style scoped>
.filter-active {
  border-color: var(--bs-primary);
}
</style>
