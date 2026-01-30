<!-- components/forms/TreeMultiSelect.vue -->
<!-- Hierarchical multi-select using Bootstrap-Vue-Next primitives only -->
<template>
  <div class="tree-multi-select">
    <!-- Dropdown selector -->
    <BDropdown
      v-model="dropdownOpen"
      :auto-close="false"
      variant="outline-secondary"
      size="sm"
      block
      menu-class="tree-dropdown-menu"
      :disabled="disabled"
    >
      <template #button-content>
        <span v-if="!modelValue?.length" class="text-muted">
          {{ placeholder }}
        </span>
        <span v-else>
          {{ modelValue.length }} item{{ modelValue.length === 1 ? '' : 's' }} selected
        </span>
      </template>

      <!-- Search input -->
      <BDropdownForm @submit.prevent>
        <BFormInput
          v-model="searchQuery"
          :placeholder="searchPlaceholder"
          size="sm"
          debounce="300"
          type="search"
          aria-label="Search items"
        />
        <small v-if="searchQuery" class="text-muted d-block mt-1">
          {{ filteredLeafCount }} matching items
        </small>
      </BDropdownForm>

      <BDropdownDivider />

      <!-- Scrollable tree area -->
      <div class="tree-scroll-area">
        <div v-if="filteredOptions.length === 0" class="text-muted text-center py-3">
          <template v-if="searchQuery"> No items match "{{ searchQuery }}" </template>
          <template v-else> No options available </template>
        </div>
        <TreeNode
          v-for="node in filteredOptions"
          :key="node.id"
          :node="node"
          :selected="modelValue || []"
          @toggle="toggleSelection"
        />
      </div>

      <BDropdownDivider />

      <!-- Action buttons -->
      <div class="d-flex justify-content-between px-3 py-2">
        <BButton
          variant="link"
          size="sm"
          class="text-decoration-none p-0"
          :disabled="!modelValue?.length"
          @click="clearAll"
        >
          <i class="bi bi-x-circle me-1" />
          Clear All
        </BButton>
        <BButton variant="primary" size="sm" @click="dropdownOpen = false"> Done </BButton>
      </div>
    </BDropdown>

    <!-- Selected items as chips below selector (matches PMID pattern) -->
    <div v-if="modelValue?.length" class="mt-2">
      <BFormTag
        v-for="id in modelValue"
        :key="id"
        v-b-tooltip.hover.top
        variant="secondary"
        class="me-1 mb-1"
        :title="getFullPath(id)"
        @remove="removeSelection(id)"
      >
        {{ getLabel(id) }}
      </BFormTag>
    </div>

    <!-- Validation error -->
    <div v-if="error" class="invalid-feedback d-block mt-1">
      {{ error }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import TreeNode from './TreeNode.vue';
import { useTreeSearch, useHierarchyPath, type TreeNode as TreeNodeType } from '@/composables';

interface Props {
  modelValue: string[] | null;
  options: TreeNodeType[];
  placeholder?: string;
  searchPlaceholder?: string;
  error?: string;
  disabled?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: 'Select items...',
  searchPlaceholder: 'Search by name or code...',
  error: '',
  disabled: false,
});

const emit = defineEmits<{
  (e: 'update:modelValue', value: string[]): void;
}>();

const dropdownOpen = ref(false);
const searchQuery = ref('');

// Search filtering - preserves ancestor context
const { filteredOptions } = useTreeSearch(
  computed(() => props.options),
  searchQuery,
  { matchFields: ['label', 'id'] }
);

// Compute full hierarchy path for tooltips
const { getPathString } = useHierarchyPath(computed(() => props.options));

// Count filtered leaf nodes for search feedback
const filteredLeafCount = computed(() => {
  function countLeaves(nodes: TreeNodeType[]): number {
    return nodes.reduce((sum, node) => {
      if (!node.children || node.children.length === 0) {
        return sum + 1;
      }
      return sum + countLeaves(node.children);
    }, 0);
  }
  return countLeaves(filteredOptions.value);
});

// Build node lookup map for fast label retrieval
const nodeMap = computed(() => {
  const map = new Map<string, TreeNodeType>();

  function traverse(nodes: TreeNodeType[]) {
    for (const node of nodes) {
      map.set(node.id, node);
      if (node.children) {
        traverse(node.children);
      }
    }
  }

  traverse(props.options);
  return map;
});

function getLabel(id: string): string {
  const node = nodeMap.value.get(id);
  return node?.label || id;
}

function getFullPath(id: string): string {
  const path = getPathString(id);
  return path || id;
}

function toggleSelection(id: string) {
  const current = props.modelValue || [];
  const updated = current.includes(id) ? current.filter((v) => v !== id) : [...current, id];
  emit('update:modelValue', updated);
}

function removeSelection(id: string) {
  const updated = (props.modelValue || []).filter((v) => v !== id);
  emit('update:modelValue', updated);
}

function clearAll() {
  emit('update:modelValue', []);
}
</script>

<style scoped>
/* Dropdown menu styling */
.tree-multi-select :deep(.tree-dropdown-menu) {
  min-width: 350px;
  max-width: 500px;
}

/* Scrollable tree area */
.tree-scroll-area {
  max-height: 300px;
  overflow-y: auto;
  padding: 0 0.5rem;
}

/* Ensure dropdown stays above other content */
.tree-multi-select :deep(.dropdown-menu) {
  z-index: 1050;
}
</style>
