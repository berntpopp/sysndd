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

export function applyPhenotypeLogicMode(
  filter: PhenotypeTableFilter,
  isOrMode: boolean
): PhenotypeTableFilter {
  return {
    ...filter,
    modifier_phenotype_id: {
      ...filter.modifier_phenotype_id,
      operator: isOrMode ? 'any' : 'all',
    },
  };
}
