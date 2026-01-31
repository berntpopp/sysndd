import { type Ref, watch } from 'vue';

export interface TreeNode {
  id: string;
  label: string;
  children?: TreeNode[];
}

export function useHierarchyPath(options: Ref<TreeNode[]>) {
  const pathCache = new Map<string, TreeNode[]>();

  function buildCache() {
    pathCache.clear();

    function traverse(nodes: TreeNode[], ancestors: TreeNode[] = []) {
      for (const node of nodes) {
        const path = [...ancestors, node];
        pathCache.set(node.id, path);

        if (node.children) {
          traverse(node.children, path);
        }
      }
    }

    traverse(options.value);
  }

  // Rebuild cache when options change
  watch(options, buildCache, { immediate: true, deep: true });

  function getPath(nodeId: string): TreeNode[] {
    return pathCache.get(nodeId) || [];
  }

  function getPathString(nodeId: string): string {
    return getPath(nodeId)
      .map((n) => n.label)
      .join(' > ');
  }

  return { getPath, getPathString };
}
