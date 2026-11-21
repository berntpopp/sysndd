// Drill-down links for the phenotype and variant correlograms (#709).
// Each cell links to the entities its coefficient was computed on: the
// default scope of /api/{phenotype,variant}/correlation, carrying BOTH terms.

/** Mirrors the default `filter` of the two correlation endpoints. */
const CORRELATION_SCOPE = 'contains(ndd_phenotype_word,Yes),any(category,Definitive)';

const tableQuery = (filter: string) =>
  // No trailing slash: returnTo only accepts `/Entities?…` and `/Phenotypes?…`.
  `?sort=entity_id&filter=${CORRELATION_SCOPE},${filter}&page_after=0&page_size=10`;

// A diagonal cell (x === y) names one term; a repeated id shows up as a duplicate tag.
const termList = (xId: string, yId: string, prefix = '') =>
  [...new Set([xId, yId])].map((id) => `${prefix}${id}`).join(',');

/** Phenotype correlations count only "present" annotations (modifier 1). */
export function phenotypeCorrelationLink(xId: string, yId: string): string {
  return `/Phenotypes${tableQuery(`all(modifier_phenotype_id,${termList(xId, yId, '1-')})`)}`;
}

/** Variant correlations count every annotated VariO term. */
export function variantCorrelationLink(xId: string, yId: string): string {
  return `/Entities${tableQuery(`all(vario_id,${termList(xId, yId)})`)}`;
}
