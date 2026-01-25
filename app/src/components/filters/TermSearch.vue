<template>
  <div class="term-search">
    <TableSearchInput
      v-model="searchPattern"
      :placeholder="placeholder"
      :debounce-time="300"
      :loading="isSearching"
    />
    <small v-if="noResults && searchPattern" class="text-muted d-block mt-1">
      No genes match '{{ searchPattern }}'
    </small>
    <small v-else-if="searchPattern" class="text-muted d-block mt-1">
      Wildcards: * (any chars), ? (one char)
    </small>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';

interface Props {
  modelValue: string;
  matchCount?: number;
  isSearching?: boolean;
  placeholder?: string;
}

const props = withDefaults(defineProps<Props>(), {
  matchCount: 0,
  isSearching: false,
  placeholder: 'Search genes (e.g., PKD*, BRCA?)',
});

const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

const searchPattern = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value ?? ''),
});

const noResults = computed(() =>
  props.matchCount === 0 && props.modelValue.length > 0 && !props.isSearching
);
</script>

<style scoped>
.term-search {
  min-width: 200px;
}
</style>
