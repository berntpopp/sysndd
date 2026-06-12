import { ref } from 'vue';
import { useToast, type TreeNode } from '@/composables';
import { type SelectOption } from '@/composables/useEntityForm';
import {
  listInheritanceTree,
  listPhenotypesTree,
  listVariationOntologyTree,
  listStatusCategoriesTree,
  type TreeNode as ApiTreeNode,
} from '@/api/list';

/**
 * Flatten tree options for simple selects (inheritance, status). The typed-list
 * helpers return `ApiTreeNode[]` whose nested `children` entries are typed as
 * `{ id; label }` (a structural subset of the top-level node), so the recursive
 * call accepts them directly without an `as unknown` cast.
 */
export function flattenTreeOptions(
  options: ReadonlyArray<ApiTreeNode | { id: string | number; label: string }>,
  result: SelectOption[] = []
): SelectOption[] {
  options.forEach((opt) => {
    result.push({
      value: opt.id,
      text: opt.label,
    });
    const children = (opt as ApiTreeNode).children;
    if (children && Array.isArray(children)) {
      flattenTreeOptions(children, result);
    }
  });
  return result;
}

/**
 * Transform phenotype/variation tree to make all modifiers selectable children.
 * Copied from ModifyEntity.vue - API returns "present: X" as parent with
 * [uncertain, variable, rare, absent] as children. We want "X" as parent
 * with [present, uncertain, variable, rare, absent] as children.
 *
 * Output format matches TreeMultiSelect's expected { id, label, children } structure.
 */
export function transformModifierTree(
  nodes: { id: string; label: string; children?: { id: string; label: string }[] }[]
): TreeNode[] {
  return nodes.map((node) => {
    const phenotypeName = node.label.replace(/^present:\s*/, '');
    const ontologyCode = node.id.replace(/^\d+-/, '');
    return {
      id: `parent-${ontologyCode}`,
      label: phenotypeName,
      children: [
        { id: node.id, label: `present: ${phenotypeName}` },
        ...(node.children || []).map((child) => {
          const modifier = child.label.replace(/:\s*.*$/, '');
          return { id: child.id, label: `${modifier}: ${phenotypeName}` };
        }),
      ],
    };
  });
}

/**
 * Load and shape the inheritance / phenotype / variation / status option trees
 * for the entity create wizard. Extracted verbatim from CreateEntity.vue
 * (#346 WP5) so the view stays a thin shell. Returns the option refs plus a
 * `loadAllOptions()` that the view calls from `onMounted`.
 */
export default function useEntityCreateOptions() {
  const { makeToast } = useToast();

  const inheritanceOptions = ref<SelectOption[]>([]);
  const phenotypeOptions = ref<TreeNode[]>([]);
  const variationOptions = ref<TreeNode[]>([]);
  const statusOptions = ref<SelectOption[]>([]);

  // API helper for loading flat options (inheritance, status). Maps the legacy
  // `endpoint` string to the corresponding typed-tree client; `flattenTreeOptions`
  // then collapses the tree into a flat <SelectOption> list.
  const loadFlatOptions = async (
    endpoint: 'inheritance' | 'status',
    targetRef: typeof inheritanceOptions
  ) => {
    try {
      const fetcher = endpoint === 'inheritance' ? listInheritanceTree : listStatusCategoriesTree;
      const data = await fetcher();
      targetRef.value = flattenTreeOptions(data);
    } catch (e) {
      makeToast(e as Error, 'Error', 'danger');
    }
  };

  // API helper for loading tree options (phenotypes, variations). Maps the
  // legacy `endpoint` string to the matching typed-tree client.
  const loadTreeOptions = async (
    endpoint: 'phenotype' | 'variation_ontology',
    targetRef: typeof phenotypeOptions
  ) => {
    try {
      const fetcher = endpoint === 'phenotype' ? listPhenotypesTree : listVariationOntologyTree;
      const data = await fetcher();
      const rawData = (
        Array.isArray(data) ? data : ((data as { data?: unknown[] })?.data ?? [])
      ) as {
        id: string;
        label: string;
        children?: { id: string; label: string }[];
      }[];
      targetRef.value = transformModifierTree(rawData);
    } catch (e) {
      makeToast(e as Error, 'Error', 'danger');
      targetRef.value = [];
    }
  };

  const loadAllOptions = async () => {
    await Promise.all([
      loadFlatOptions('inheritance', inheritanceOptions),
      loadTreeOptions('phenotype', phenotypeOptions),
      loadTreeOptions('variation_ontology', variationOptions),
      loadFlatOptions('status', statusOptions),
    ]);
  };

  return {
    inheritanceOptions,
    phenotypeOptions,
    variationOptions,
    statusOptions,
    loadAllOptions,
  };
}
