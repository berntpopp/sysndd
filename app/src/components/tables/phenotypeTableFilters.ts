export interface PhenotypeFilterEntry {
  content: string | string[] | null;
  join_char: string | null;
  operator: string;
}

export type PhenotypeTableFilter = Record<string, PhenotypeFilterEntry>;

export function createDefaultPhenotypeFilter(): PhenotypeTableFilter {
  return {
    modifier_phenotype_id: { content: ['HP:0001249'], join_char: ',', operator: 'all' },
    any: { content: null, join_char: null, operator: 'contains' },
    entity_id: { content: null, join_char: null, operator: 'contains' },
    symbol: { content: null, join_char: null, operator: 'contains' },
    disease_ontology_name: { content: null, join_char: null, operator: 'contains' },
    disease_ontology_id_version: { content: null, join_char: null, operator: 'contains' },
    hpo_mode_of_inheritance_term_name: { content: null, join_char: ',', operator: 'any' },
    hpo_mode_of_inheritance_term: { content: null, join_char: ',', operator: 'any' },
    ndd_phenotype_word: { content: null, join_char: null, operator: 'contains' },
    category: { content: null, join_char: ',', operator: 'any' },
  };
}

/**
 * The `modifier_phenotype_id` filter operator for the AND/OR logic toggle.
 *
 * Callers MUST assign this onto the existing reactive filter in place, e.g.
 *   filter.modifier_phenotype_id.operator = phenotypeLogicOperator(isOr)
 * and never reassign the whole filter object. `TablesPhenotypes` watches
 * `filter` deeply and re-runs `filtered()` on every change, so swapping in a
 * fresh object re-fires the watcher endlessly ("Maximum recursive updates").
 * Writing the same string back is a no-op for Vue reactivity, so the in-place
 * assignment is idempotent and the watcher settles immediately. (#466)
 */
export function phenotypeLogicOperator(isOrMode: boolean): 'any' | 'all' {
  return isOrMode ? 'any' : 'all';
}
