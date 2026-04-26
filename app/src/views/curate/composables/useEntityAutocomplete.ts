// app/src/views/curate/composables/useEntityAutocomplete.ts
import { ref, type Ref } from 'vue';
import { listEntities } from '@/api/entity';
import { searchOntology as searchOntologyApi } from '@/api/search';

export interface UseEntityAutocompleteOptions {
  onToast?: (...args: unknown[]) => void;
  getCurrentEntityId?: () => number | null | undefined;
}

export interface EntitySearchResult {
  entity_id: number;
  symbol?: string;
  disease_ontology_name?: string;
  disease_ontology_id_version?: string;
  hpo_mode_of_inheritance_term_name?: string;
}

export interface OntologySearchResult {
  id: string;
  label: string;
}

export function useEntityAutocomplete(options: UseEntityAutocompleteOptions = {}) {
  const { onToast, getCurrentEntityId } = options;

  // Inputs (selected ids)
  const modify_entity_input = ref<number | null>(null);
  const ontology_input = ref<string | null>(null);
  const replace_entity_input = ref<number | null>(null);

  // Display strings
  const entity_display = ref('');
  const ontology_display = ref('');
  const replace_entity_display = ref('');

  // Results
  const entity_search_results = ref<EntitySearchResult[]>([]);
  const ontology_search_results = ref<OntologySearchResult[]>([]);
  const replace_entity_search_results = ref<EntitySearchResult[]>([]);

  // Loading flags
  const entity_search_loading = ref(false);
  const ontology_search_loading = ref(false);
  const replace_entity_search_loading = ref(false);

  // Loaded flag
  const entity_loaded = ref(false);

  async function searchEntity(query: string): Promise<void> {
    if (!query || query.length < 2) {
      entity_search_results.value = [];
      return;
    }
    entity_search_loading.value = true;
    try {
      const response: any = await listEntities({ filter: `contains(any,${query})` });
      const data = response?.data || [];
      entity_search_results.value = Array.isArray(data) ? data.slice(0, 10) : [];
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      entity_search_results.value = [];
    } finally {
      entity_search_loading.value = false;
    }
  }

  async function searchOntology(query: string): Promise<void> {
    if (!query || query.length < 2) {
      ontology_search_results.value = [];
      return;
    }
    ontology_search_loading.value = true;
    try {
      const data: any = await searchOntologyApi(query, { tree: true });
      ontology_search_results.value = Array.isArray(data) ? data.slice(0, 10) : [];
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      ontology_search_results.value = [];
    } finally {
      ontology_search_loading.value = false;
    }
  }

  async function searchReplacementEntity(query: string): Promise<void> {
    if (!query || query.length < 2) {
      replace_entity_search_results.value = [];
      return;
    }
    replace_entity_search_loading.value = true;
    try {
      const response: any = await listEntities({ filter: `contains(any,${query})` });
      const data = response?.data || [];
      const currentId = getCurrentEntityId?.();
      replace_entity_search_results.value = Array.isArray(data)
        ? data.filter((e: EntitySearchResult) => e.entity_id !== currentId).slice(0, 10)
        : [];
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      replace_entity_search_results.value = [];
    } finally {
      replace_entity_search_loading.value = false;
    }
  }

  function onEntitySelected(entityId: number | null): void {
    modify_entity_input.value = entityId;
    if (!entityId) {
      entity_loaded.value = false;
    }
  }

  function onOntologySelected(ontologyId: string | null): void {
    ontology_input.value = ontologyId;
  }

  function onReplacementEntitySelected(entityId: number | null): void {
    replace_entity_input.value = entityId;
  }

  function normalizerEntitySearch(node: any) {
    return {
      id: node.entity_id,
      label: `sysndd:${node.entity_id} (${node.symbol} - ${node.disease_ontology_name} - (${node.disease_ontology_id_version}) - ${node.hpo_mode_of_inheritance_term_name})`,
    };
  }

  function normalizerOntologySearch(node: any) {
    return { id: node.id, label: `${node.id} (${node.label})` };
  }

  function clearAll(): void {
    modify_entity_input.value = null;
    ontology_input.value = null;
    replace_entity_input.value = null;
    entity_display.value = '';
    ontology_display.value = '';
    replace_entity_display.value = '';
    entity_search_results.value = [];
    ontology_search_results.value = [];
    replace_entity_search_results.value = [];
    entity_loaded.value = false;
  }

  return {
    modify_entity_input,
    ontology_input,
    replace_entity_input,
    entity_display,
    ontology_display,
    replace_entity_display,
    entity_search_results,
    ontology_search_results,
    replace_entity_search_results,
    entity_search_loading,
    ontology_search_loading,
    replace_entity_search_loading,
    entity_loaded,
    searchEntity,
    searchOntology,
    searchReplacementEntity,
    onEntitySelected,
    onOntologySelected,
    onReplacementEntitySelected,
    normalizerEntitySearch,
    normalizerOntologySearch,
    clearAll,
  };
}
