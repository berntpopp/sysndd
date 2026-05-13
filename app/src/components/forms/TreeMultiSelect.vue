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
    <div v-if="modelValue?.length" class="tree-multi-select__selected">
      <BFormTag
        v-for="id in modelValue"
        :key="id"
        v-b-tooltip.hover.top
        variant="secondary"
        class="tree-multi-select__tag"
        :class="modifierTagClass(id)"
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

function modifierTagClass(id: string): string {
  const label = getLabel(id).toLowerCase();
  const modifier = label.split(':')[0]?.trim();
  if (['present', 'uncertain', 'variable', 'rare', 'absent'].includes(modifier)) {
    return `tree-multi-select__tag--${modifier}`;
  }
  return '';
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

.tree-multi-select :deep(.tree-multi-select__tag) {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  max-width: 100%;
  min-height: 1.45rem;
  margin: 0;
  padding: 0.14rem 0.42rem;
  border: 1px solid #7c3aed;
  border-radius: 999px;
  background-color: #ede9fe !important;
  color: #0f172a !important;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.2;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.07);
  white-space: normal;
}

.tree-multi-select__selected {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.5rem;
}

.tree-multi-select :deep(.tree-multi-select__tag--present) {
  border-color: #16a34a;
  background-color: #dcfce7 !important;
}

.tree-multi-select :deep(.tree-multi-select__tag--uncertain) {
  border-color: #d97706;
  background-color: #fef3c7 !important;
}

.tree-multi-select :deep(.tree-multi-select__tag--variable) {
  border-color: #2563eb;
  background-color: #dbeafe !important;
}

.tree-multi-select :deep(.tree-multi-select__tag--rare) {
  border-color: #7c3aed;
  background-color: #ede9fe !important;
}

.tree-multi-select :deep(.tree-multi-select__tag--absent) {
  border-color: #64748b;
  background-color: #f1f5f9 !important;
  color: #334155 !important;
}

.tree-multi-select :deep(.tree-multi-select__tag button),
.tree-multi-select :deep(.tree-multi-select__tag .btn-close) {
  width: 0.8rem;
  min-width: 0.8rem;
  height: 0.8rem;
  min-height: 0.8rem;
  margin-left: 0.1rem;
  padding: 0;
  background-size: 0.55rem;
  opacity: 0.62;
}

.tree-multi-select :deep(.tree-multi-select__tag button:hover),
.tree-multi-select :deep(.tree-multi-select__tag .btn-close:hover) {
  opacity: 0.95;
}
</style>
