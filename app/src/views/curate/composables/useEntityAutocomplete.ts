// app/src/views/curate/composables/useEntityAutocomplete.ts
import { ref, computed } from 'vue';
import { listEntities } from '@/api/entity';
import { searchOntology as searchOntologyApi } from '@/api/search';

export const OMIM_PENDING_HINT =
  'No matching disease found. If you recently added this OMIM ID, the disease dictionary may need an administrator refresh.';

const OMIM_SHAPED = /^(omim:?\s*)?\d{6}$/i;

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

  // Tracks the last trimmed ontology query for OMIM-shaped hint logic
  const last_ontology_query = ref('');

  // Loaded flag
  const entity_loaded = ref(false);

  // OMIM-aware no-results hint for the disease autocomplete
  const ontologyNoResultsMessage = computed(() =>
    ontology_search_results.value.length === 0 && OMIM_SHAPED.test(last_ontology_query.value)
      ? OMIM_PENDING_HINT
      : 'No results found'
  );

  // The list endpoint pages 10 rows sorted by entity_id, so an exact id match can sit below
  // (or off) that page; fetch it separately. When it exists it is the answer: the contains
  // rows only mention the number (OMIM ids, other fields) and read as noise under it.
  async function fetchEntityMatches(query: string): Promise<EntitySearchResult[]> {
    const id = query.trim();
    const [contains, exact]: any[] = await Promise.all([
      listEntities({ filter: `contains(any,${query})` }),
      // Only a ranking boost: if it fails, keep the contains results.
      /^\d+$/.test(id)
        ? listEntities({ filter: `equals(entity_id,${id})` }).catch(() => null)
        : null,
    ]);
    if (Array.isArray(exact?.data) && exact.data.length) return exact.data;
    const rows: EntitySearchResult[] = Array.isArray(contains?.data) ? contains.data : [];
    return rows.filter((e, i) => rows.findIndex((r) => r.entity_id === e.entity_id) === i);
  }

  async function searchEntity(query: string): Promise<void> {
    if (!query || query.length < 2) {
      entity_search_results.value = [];
      return;
    }
    entity_search_loading.value = true;
    try {
      const data = await fetchEntityMatches(query);
      entity_search_results.value = data.slice(0, 10);
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      entity_search_results.value = [];
    } finally {
      entity_search_loading.value = false;
    }
  }

  async function searchOntology(query: string): Promise<void> {
    last_ontology_query.value = (query || '').trim();
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
      const data = await fetchEntityMatches(query);
      const currentId = getCurrentEntityId?.();
      replace_entity_search_results.value = data
        .filter((e) => e.entity_id !== currentId)
        .slice(0, 10);
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
    ontologyNoResultsMessage,
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
