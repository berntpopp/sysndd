// app/src/views/curate/composables/useModifyEntityLookups.ts
/**
 * Loads the app-global lookup trees (phenotypes, variation ontology, status
 * categories) used by every ModifyEntity workflow. Extracted from
 * ModifyEntity.vue to keep the view under the file-size ceiling; the loader
 * runs once on mount and exposes the reactive option refs + loading state.
 */

import { onMounted, ref, type Ref } from 'vue';
import {
  listPhenotypesTree,
  listVariationOntologyTree,
  listStatusCategoriesTree,
} from '@/api/list';

/**
 * Transform the modifier tree so all modifiers become selectable children.
 * The API returns "present: X" as a parent with [uncertain, variable, ...] as
 * children; we want "X" as the parent with [present, uncertain, ...] children.
 */
export function transformModifierTree(nodes: any[]): any[] {
  return nodes.map((node) => {
    const phenotypeName = node.label.replace(/^present:\s*/, '');
    const ontologyCode = node.id.replace(/^\d+-/, '');
    return {
      id: `parent-${ontologyCode}`,
      label: phenotypeName,
      children: [
        { id: node.id, label: `present: ${phenotypeName}` },
        ...(node.children || []).map((child: any) => {
          const modifier = child.label.replace(/:\s*.*$/, '');
          return { id: child.id, label: `${modifier}: ${phenotypeName}` };
        }),
      ],
    };
  });
}

export interface UseModifyEntityLookupsOptions {
  onToast?: (...args: unknown[]) => void;
}

export interface UseModifyEntityLookupsReturn {
  phenotypes_options: Ref<any[] | null>;
  variation_ontology_options: Ref<any[] | null>;
  status_options: Ref<any[] | null>;
  status_options_loading: Ref<boolean>;
}

export function useModifyEntityLookups(
  options: UseModifyEntityLookupsOptions = {}
): UseModifyEntityLookupsReturn {
  const { onToast } = options;

  const phenotypes_options = ref<any[] | null>(null);
  const variation_ontology_options = ref<any[] | null>(null);
  const status_options = ref<any[] | null>(null);
  const status_options_loading = ref(false);

  onMounted(async () => {
    status_options_loading.value = true;
    try {
      const [phenotypes_data, variation_data, status_data] = await Promise.all([
        listPhenotypesTree(),
        listVariationOntologyTree(),
        listStatusCategoriesTree(),
      ]);

      const raw1: any = Array.isArray(phenotypes_data)
        ? phenotypes_data
        : (phenotypes_data as any)?.data || [];
      phenotypes_options.value = transformModifierTree(raw1);

      const raw2: any = Array.isArray(variation_data)
        ? variation_data
        : (variation_data as any)?.data || [];
      variation_ontology_options.value = transformModifierTree(raw2);

      status_options.value = Array.isArray(status_data)
        ? status_data
        : (status_data as any)?.data || [];
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      // Deterministic empty defaults so downstream modals render their
      // empty-state alerts instead of staying in null/loading limbo.
      if (phenotypes_options.value === null) phenotypes_options.value = [];
      if (variation_ontology_options.value === null) variation_ontology_options.value = [];
      if (status_options.value === null) status_options.value = [];
    } finally {
      status_options_loading.value = false;
    }
  });

  return {
    phenotypes_options,
    variation_ontology_options,
    status_options,
    status_options_loading,
  };
}

export default useModifyEntityLookups;
