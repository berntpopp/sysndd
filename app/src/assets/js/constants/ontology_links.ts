// ontology_links.ts
//
// Central, configurable base URLs for external ontology term browsers, plus
// pure helpers that build a term-detail link from a SysNDD ontology id.
//
// Why this module exists (issue #98):
//   The VariO (Variation Ontology) link in the entity view was hardcoded to an
//   `aber-owl.net` fragment URL that no longer reliably resolves to a term page.
//   Per the issue, ontology base links should live in one configurable place so
//   they can be repointed without touching component logic.
//
// Scope note: this module ONLY governs how a stored ontology id (e.g.
// `VariO:0001`) is turned into an outbound link. It does NOT migrate or
// reinterpret curated `vario_id` values — changing the underlying ontology of a
// curated variant record is a curation decision and is deliberately out of
// scope here. See documentation/12-ontology-link-config.md.

/**
 * Override hook for the VariO term-browser base URL.
 *
 * Set `VITE_VARIO_BASE_URL` in the appropriate `app/.env*` file to repoint VariO
 * links at deploy time without a code change. When unset, the verified default
 * below is used.
 */
const VARIO_BASE_URL_OVERRIDE = import.meta.env.VITE_VARIO_BASE_URL;

/**
 * Default external term-browser base URLs for ontologies linked from SysNDD.
 *
 * VARIO points at EBI OLS4, which (verified 2026-06) serves live VariO term
 * pages, e.g. https://www.ebi.ac.uk/ols4/ontologies/vario/classes?iri=...VariO_0001
 * resolves to the real "variation" term. The OBO PURL / OntoBee / Bioregistry
 * routes 404 for this orphaned ontology, and the previous aber-owl.net fragment
 * URL was an insecure (http://) SPA fragment link, so OLS4 is the canonical
 * working target.
 *
 * `as const` enables literal type inference for consumers.
 */
const ONTOLOGY_LINK_BASES = {
  /**
   * EBI OLS4 VariO term-browser base. The numeric id (`VariO:0001`) is appended
   * as an OBO PURL IRI by {@link varioTermUrl}.
   */
  VARIO: 'https://www.ebi.ac.uk/ols4/ontologies/vario/classes?iri=',
} as const;

/** Resolved VariO base URL: deploy-time override wins, else the verified default. */
export const VARIO_BASE_URL: string =
  (typeof VARIO_BASE_URL_OVERRIDE === 'string' && VARIO_BASE_URL_OVERRIDE.trim()) ||
  ONTOLOGY_LINK_BASES.VARIO;

/** OBO PURL prefix VariO terms dereference through. */
const OBO_PURL_PREFIX = 'http://purl.obolibrary.org/obo/';

/**
 * Build an external term-browser URL for a VariO id.
 *
 * Accepts the SysNDD-stored form `VariO:NNNN` (the `variation_ontology_list`
 * primary-key format) and converts it to the OBO PURL IRI that OLS4 expects.
 * Returns an empty string for blank/invalid ids so callers can suppress the
 * link rather than emit a broken one.
 *
 * @example
 *   varioTermUrl('VariO:0001')
 *   // 'https://www.ebi.ac.uk/ols4/ontologies/vario/classes?iri=http%3A%2F%2Fpurl.obolibrary.org%2Fobo%2FVariO_0001'
 */
export function varioTermUrl(varioId: unknown): string {
  const id = varioId == null ? '' : String(varioId).trim();
  // Expect the `VariO:NNNN` (or generic `PREFIX:NNNN`) shape; bail on anything else.
  if (!/^[A-Za-z]+:\w+$/.test(id)) {
    return '';
  }
  const oboLocalId = id.replace(':', '_');
  const iri = encodeURIComponent(`${OBO_PURL_PREFIX}${oboLocalId}`);
  return `${VARIO_BASE_URL}${iri}`;
}

export default ONTOLOGY_LINK_BASES;
