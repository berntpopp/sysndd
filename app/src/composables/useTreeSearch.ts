import { computed, type Ref } from 'vue';

export interface TreeNode {
  id: string;
  label: string;
  children?: TreeNode[];
  [key: string]: unknown;
}

interface UseTreeSearchOptions {
  matchFields?: string[];
}

export function useTreeSearch(
  options: Ref<TreeNode[]>,
  query: Ref<string>,
  config: UseTreeSearchOptions = {}
) {
  const { matchFields = ['label', 'id'] } = config;

  const filteredOptions = computed(() => {
    if (!query.value || query.value.trim() === '') {
      return options.value;
    }

    const lowerQuery = query.value.toLowerCase();

    function filterNode(node: TreeNode): TreeNode | null {
      // Check if node matches any of the specified fields
      const nodeMatches = matchFields.some((field) => {
        const value = node[field];
        return (
          typeof value === 'string' &&
          value.toLowerCase().includes(lowerQuery)
        );
      });

      // Recursively filter children
      const filteredChildren = node.children
        ?.map(filterNode)
        .filter((n): n is TreeNode => n !== null);

      // Include node if it matches OR if any children match (preserves ancestor context)
      if (nodeMatches || (filteredChildren && filteredChildren.length > 0)) {
        return {
          ...node,
          children: filteredChildren,
        };
      }

      return null;
    }

    return options.value
      .map(filterNode)
      .filter((n): n is TreeNode => n !== null);
  });

  return { filteredOptions };
}
