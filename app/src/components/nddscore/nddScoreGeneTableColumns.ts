// Column definitions, select-filter option sets, and per-column help copy for
// the NDDScore gene predictions table. Extracted from NddScoreGeneTable.vue so
// the component stays a thinner shell; the machine-learning / not-curated copy
// invariants live verbatim in the strings below.

export type NddScoreGeneFieldKey =
  | 'gene_symbol'
  | 'ndd_score'
  | 'rank'
  | 'percentile'
  | 'risk_tier'
  | 'confidence_tier'
  | 'known_sysndd_gene'
  | 'model_split'
  | 'top_inheritance_mode'
  | 'top_hpo_predictions_json';

export interface NddScoreGeneFieldDefinition {
  key: NddScoreGeneFieldKey;
  label: string;
  sortable?: boolean;
  filterType?: 'text' | 'select' | 'range' | 'multi-select';
  selectOptions?: Array<{ value: string; text: string }>;
  numericStep?: string;
}

export const nddScoreRangeOperatorOptions = [
  { value: 'any', text: 'Any' },
  { value: 'gte', text: '>=' },
  { value: 'lte', text: '<=' },
  { value: 'eq', text: '=' },
  { value: 'range', text: 'Range' },
];

const riskTierOptions = [
  { value: 'Very High', text: 'Very High' },
  { value: 'High', text: 'High' },
  { value: 'Moderate', text: 'Moderate' },
  { value: 'Low', text: 'Low' },
  { value: 'Very Low', text: 'Very Low' },
];

const confidenceTierOptions = [
  { value: 'High', text: 'High' },
  { value: 'Medium', text: 'Medium' },
  { value: 'Low', text: 'Low' },
];

const knownSysnddOptions = [
  { value: 'true', text: 'Known SysNDD gene' },
  { value: 'false', text: 'Not known in SysNDD' },
];

const modelSplitOptions = [
  { value: 'train', text: 'Train' },
  { value: 'validation', text: 'Validation' },
  { value: 'test', text: 'Test' },
  { value: 'unseen', text: 'Unseen' },
];

const inheritanceModeOptions = [
  { value: 'AD', text: 'AD' },
  { value: 'AR', text: 'AR' },
  { value: 'XLD', text: 'XLD' },
  { value: 'XLR', text: 'XLR' },
];

export const nddScoreGeneFields: NddScoreGeneFieldDefinition[] = [
  { key: 'gene_symbol', label: 'Gene', sortable: true, filterType: 'text' },
  {
    key: 'ndd_score',
    label: 'NDD score',
    sortable: true,
    filterType: 'range',
    numericStep: '0.001',
  },
  { key: 'rank', label: 'Rank', sortable: true, filterType: 'range', numericStep: '1' },
  {
    key: 'percentile',
    label: 'Percentile',
    sortable: true,
    filterType: 'range',
    numericStep: '0.1',
  },
  {
    key: 'risk_tier',
    label: 'Risk tier',
    sortable: true,
    filterType: 'select',
    selectOptions: riskTierOptions,
  },
  {
    key: 'confidence_tier',
    label: 'Confidence',
    sortable: true,
    filterType: 'select',
    selectOptions: confidenceTierOptions,
  },
  {
    key: 'known_sysndd_gene',
    label: 'SysNDD',
    sortable: true,
    filterType: 'select',
    selectOptions: knownSysnddOptions,
  },
  {
    key: 'model_split',
    label: 'Split',
    sortable: false,
    filterType: 'select',
    selectOptions: modelSplitOptions,
  },
  {
    key: 'top_inheritance_mode',
    label: 'Top inheritance',
    sortable: false,
    filterType: 'select',
    selectOptions: inheritanceModeOptions,
  },
  {
    key: 'top_hpo_predictions_json',
    label: 'Predicted HPO',
    sortable: false,
    filterType: 'multi-select',
  },
];

export const nddScoreGeneColumnHelp: Record<string, string> = {
  gene_symbol: 'Gene symbol linked to the NDDScore prediction detail page.',
  ndd_score:
    'Model probability-like score for NDD gene candidacy; higher is stronger model support.',
  rank: 'Position of this gene in the active NDDScore release after sorting by NDD score.',
  percentile: 'Relative position among all genes in the active release.',
  risk_tier: 'Bucketed interpretation of the model score.',
  confidence_tier: 'Model confidence tier based on ensemble consistency and score stability.',
  known_sysndd_gene: 'Whether this HGNC identifier already has a curated SysNDD gene page.',
  model_split: 'Dataset split assigned in the active NDDScore release.',
  top_inheritance_mode: 'Highest-probability inheritance mode predicted by the model.',
  top_hpo_predictions_json: 'Top predicted phenotype association for this gene.',
};
