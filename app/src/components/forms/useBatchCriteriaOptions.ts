// src/components/forms/useBatchCriteriaOptions.ts
/**
 * Option loading, entity-search debounce, and gene-filter picker state for
 * BatchCriteriaForm.vue (#346, Wave 2 Task 4 extraction).
 *
 * This composable orchestrates OVER useBatchForm's return values rather
 * than duplicating them: the caller passes in the pieces it needs
 * (formData, geneOptions, entitySearchQuery, searchEntities, addEntity,
 * loadOptions) and this composable owns:
 *
 *   - triggering `loadOptions()` once on mount
 *   - debouncing entity-search input by `debounceMs` (default 300ms) and
 *     canceling a pending search whenever newer input arrives before the
 *     timer fires, so a stale query for outdated input is rejected before
 *     it ever reaches `searchEntities`
 *   - the gene-filter local search box: filtering/selecting gene options
 *     and mutating `formData.gene_list`
 *
 * Behavior-preserving extraction: this mirrors the local <script setup>
 * state BatchCriteriaForm.vue previously held directly (`useBatchForm`
 * itself, the form schema, validation, and the component's public emits
 * stay in the parent SFC).
 */
import { computed, onMounted, ref, type ComputedRef, type Ref } from 'vue';

export interface BatchCriteriaGeneOption {
  value: number;
  text: string;
}

export interface BatchCriteriaEntitySearchResult {
  entity_id: number;
  hgnc_id: number;
  symbol: string;
  disease_ontology_name: string;
  disease_ontology_id_version: string;
}

interface BatchCriteriaFormDataLike {
  gene_list: number[];
}

export interface UseBatchCriteriaOptionsParams {
  formData: BatchCriteriaFormDataLike;
  geneOptions: Ref<BatchCriteriaGeneOption[]>;
  entitySearchQuery: Ref<string>;
  searchEntities: (query: string) => void | Promise<void>;
  addEntity: (entity: BatchCriteriaEntitySearchResult) => void;
  loadOptions: () => void | Promise<void>;
  /** Debounce delay in ms for entity search. Defaults to 300 (behavior-preserving). */
  debounceMs?: number;
}

export interface UseBatchCriteriaOptionsResult {
  geneSearchQuery: Ref<string>;
  selectedGeneOptions: ComputedRef<BatchCriteriaGeneOption[]>;
  filteredGeneOptions: ComputedRef<BatchCriteriaGeneOption[]>;
  addGene: (geneId: number) => void;
  removeGene: (geneId: number) => void;
  onEntitySearch: () => void;
  selectEntity: (entity: BatchCriteriaEntitySearchResult) => void;
}

export function useBatchCriteriaOptions(
  params: UseBatchCriteriaOptionsParams
): UseBatchCriteriaOptionsResult {
  const {
    formData,
    geneOptions,
    entitySearchQuery,
    searchEntities,
    addEntity,
    loadOptions,
    debounceMs = 300,
  } = params;

  // --- Gene filter picker -------------------------------------------------
  const geneSearchQuery = ref('');

  const selectedGeneOptions = computed(() =>
    geneOptions.value.filter((gene) => formData.gene_list.includes(gene.value))
  );

  const filteredGeneOptions = computed(() => {
    const query = geneSearchQuery.value.trim().toLowerCase();
    if (query.length < 1) return [];

    return geneOptions.value
      .filter(
        (gene) => !formData.gene_list.includes(gene.value) && gene.text.toLowerCase().includes(query)
      )
      .slice(0, 8);
  });

  const addGene = (geneId: number) => {
    if (!formData.gene_list.includes(geneId)) {
      formData.gene_list.push(geneId);
    }
    geneSearchQuery.value = '';
  };

  const removeGene = (geneId: number) => {
    formData.gene_list = formData.gene_list.filter((id) => id !== geneId);
  };

  // --- Entity search debounce ----------------------------------------------
  // Reads entitySearchQuery.value at fire time (not at call time), matching
  // the original inline implementation: a rapid second keystroke clears the
  // pending timer via clearTimeout, so the stale (outdated) query is never
  // dispatched to searchEntities.
  let searchTimeout: ReturnType<typeof setTimeout> | null = null;

  const onEntitySearch = () => {
    if (searchTimeout) clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      searchTimeout = null;
      searchEntities(entitySearchQuery.value);
    }, debounceMs);
  };

  const selectEntity = (entity: BatchCriteriaEntitySearchResult) => {
    addEntity(entity);
  };

  // --- Option loading --------------------------------------------------------
  onMounted(() => {
    loadOptions();
  });

  return {
    geneSearchQuery,
    selectedGeneOptions,
    filteredGeneOptions,
    addGene,
    removeGene,
    onEntitySearch,
    selectEntity,
  };
}

export default useBatchCriteriaOptions;
