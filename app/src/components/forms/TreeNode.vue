<!-- components/forms/TreeNode.vue -->
<!-- Recursive tree node component for hierarchical display -->
<template>
  <div class="tree-node">
    <!-- Parent node with children (navigation only - expand/collapse) -->
    <div v-if="hasChildren" class="parent-node">
      <BButton
        v-b-toggle="`collapse-${node.id}`"
        variant="link"
        size="sm"
        class="text-start w-100 d-flex align-items-center px-2 py-1 text-decoration-none"
        :class="{ 'text-primary': hasSelectedDescendants }"
      >
        <i class="bi bi-chevron-right me-2 collapse-icon" />
        <span class="flex-grow-1">{{ node.label }}</span>
        <BBadge v-if="selectedDescendantCount > 0" variant="primary" pill class="ms-2">
          {{ selectedDescendantCount }}
        </BBadge>
        <BBadge variant="secondary" pill class="ms-1">
          {{ leafCount }}
        </BBadge>
      </BButton>

      <BCollapse
        :id="`collapse-${node.id}`"
        :lazy="true"
        class="ms-3"
      >
        <TreeNode
          v-for="child in node.children"
          :key="child.id"
          :node="child"
          :selected="selected"
          @toggle="$emit('toggle', $event)"
        />
      </BCollapse>
    </div>

    <!-- Leaf node with checkbox (selectable) -->
    <div v-else class="leaf-node ps-4 py-1">
      <BFormCheckbox
        :id="`checkbox-${node.id}`"
        :model-value="selected.includes(node.id)"
        @update:model-value="$emit('toggle', node.id)"
      >
        <span>{{ node.label }}</span>
        <small class="text-muted ms-2">({{ extractCode(node.id) }})</small>
      </BFormCheckbox>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, type PropType } from 'vue';

interface TreeNodeType {
  id: string;
  label: string;
  children?: TreeNodeType[];
}

export default defineComponent({
  name: 'TreeNode', // Critical: enables self-reference for recursion
  props: {
    node: {
      type: Object as PropType<TreeNodeType>,
      required: true,
    },
    selected: {
      type: Array as PropType<string[]>,
      default: () => [],
    },
  },
  emits: ['toggle'],
  computed: {
    hasChildren(): boolean {
      return Boolean(this.node.children && this.node.children.length > 0);
    },
    leafCount(): number {
      return this.countLeaves(this.node);
    },
    selectedDescendantCount(): number {
      return this.countSelectedDescendants(this.node);
    },
    hasSelectedDescendants(): boolean {
      return this.selectedDescendantCount > 0;
    },
  },
  methods: {
    extractCode(id: string): string {
      // Extract HP:XXXXXXX or similar code from compound key like "present-HP:0001250"
      const match = id.match(/(HP:\d+|[A-Z]+:\d+)/);
      return match ? match[1] : id;
    },
    countLeaves(node: TreeNodeType): number {
      if (!node.children || node.children.length === 0) {
        return 1;
      }
      return node.children.reduce((sum, child) => sum + this.countLeaves(child), 0);
    },
    countSelectedDescendants(node: TreeNodeType): number {
      if (!node.children || node.children.length === 0) {
        return this.selected.includes(node.id) ? 1 : 0;
      }
      return node.children.reduce(
        (sum, child) => sum + this.countSelectedDescendants(child),
        0
      );
    },
  },
});
</script>

<style scoped>
/* Rotate chevron when expanded */
.collapse-icon {
  transition: transform 0.2s ease;
}

.not-collapsed .collapse-icon {
  transform: rotate(90deg);
}

/* Style parent node button */
.parent-node .btn-link {
  color: var(--bs-body-color);
}

.parent-node .btn-link:hover {
  color: var(--bs-primary);
  background-color: var(--bs-gray-100);
}

/* Leaf node hover */
.leaf-node:hover {
  background-color: var(--bs-gray-100);
}
</style>
