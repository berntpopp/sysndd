// utils/ontologyTags.ts
/**
 * Shared encoding for the curation form tags that pair a curation *modifier*
 * with an *ontology term*.
 *
 * Both the review read endpoints (`/api/review/<id>/phenotypes`,
 * `.../variation`) and the TreeMultiSelect option ids
 * (`/api/list/{phenotype,variation_ontology}?tree=true`) encode a selection as
 * `"<modifier_id>-<ontology_id>"`, e.g. `"1-HP:0001249"` or `"5-VariO:0015"`.
 *
 * The ontology half is a **CURIE string, never an integer**. Coercing it with
 * `Number()` produces `NaN`, and `JSON.stringify` writes `NaN` as `null`, so
 * the API received `phenotype_id: null` / `vario_id: null` and failed the
 * connect step with HTTP 500 ("Error connecting phenotypes." / "Error
 * connecting variation ontology.") — see issue #600. Only the modifier is
 * numeric; the ontology id must be forwarded verbatim.
 */

export interface OntologyTagParts {
  /** Numeric curation modifier id (1 = present, 5 = absent, ...). */
  modifierId: number;
  /** Ontology CURIE, forwarded to the API unchanged (e.g. `HP:0001249`). */
  ontologyId: string;
}

/**
 * Split a `"<modifier_id>-<ontology_id>"` tag into its two halves.
 *
 * Splits on the FIRST separator only, so an ontology id that itself contains a
 * hyphen is never truncated.
 */
export function splitOntologyTag(item: string): OntologyTagParts {
  const separator = item.indexOf('-');
  if (separator === -1) {
    return { modifierId: Number(item), ontologyId: '' };
  }
  return {
    modifierId: Number(item.slice(0, separator)),
    ontologyId: item.slice(separator + 1),
  };
}

export default splitOntologyTag;
