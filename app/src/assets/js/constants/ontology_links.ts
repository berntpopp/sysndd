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

// ---------------------------------------------------------------------------
// Cross-ontology outlink builder
// ---------------------------------------------------------------------------

/**
 * Allowlisted ontology prefixes used by the cross-ontology mapping layer.
 * The order here is intentionally the display order used by LinkedOntologies.
 */
export type OntologyPrefix =
  | 'MONDO'
  | 'Orphanet'
  | 'OMIM'
  | 'DOID'
  | 'UMLS'
  | 'MedGen'
  | 'NCIT'
  | 'GARD'
  | 'EFO';

/**
 * Result of {@link ontologyOutlink}.
 */
export interface OntologyOutlink {
  /** External URL, or null when no reliable public deep-link exists (e.g. UMLS). */
  url: string | null;
  /** Always the full CURIE/id passed in — callers control display formatting. */
  label: string;
}

/**
 * Build an external term-browser URL for a cross-ontology disease mapping entry.
 *
 * Dispatches on the allowlisted `prefix` string and applies the id-to-URL
 * transformation documented in OntologyView.vue. The `label` is always the
 * full `id` passed in — stripping for display is the caller's responsibility.
 *
 * Returns `{ url: null, label: id }` for UMLS (no reliable public deep-link).
 * Returns `{ url: null, label: id }` for unrecognised prefixes so callers can
 * safely degrade to plain text.
 *
 * @param prefix - One of the allowlisted ontology prefix strings.
 * @param id     - The full CURIE string, e.g. `"OMIM:618524"`, `"MONDO:0032745"`.
 */
export function ontologyOutlink(prefix: string, id: string): OntologyOutlink {
  const label = id;

  switch (prefix) {
    case 'OMIM': {
      // Strip "OMIM:" prefix and any "_.*" suffix (e.g. "OMIM:618524_1" → "618524")
      const digits = id.replace(/^OMIM:/, '').replace(/_.*$/, '');
      return { url: `https://www.omim.org/entry/${digits}`, label };
    }
    case 'MONDO': {
      // Replace ":" with "_" and strip the "MONDO:" prefix for the OBO PURL
      // e.g. "MONDO:0032745" → "MONDO_0032745"
      const local = id.replace(':', '_');
      return { url: `http://purl.obolibrary.org/obo/${local}`, label };
    }
    case 'Orphanet': {
      // Strip "Orphanet:" prefix
      const digits = id.replace(/^Orphanet:/, '');
      return {
        url: `https://www.orpha.net/consor/cgi-bin/OC_Exp.php?Expert=${digits}&lng=EN`,
        label,
      };
    }
    case 'DOID': {
      // Use the full DOID:... id in the URL path
      return { url: `https://disease-ontology.org/term/${id}`, label };
    }
    case 'UMLS': {
      // No reliable public deep-link
      return { url: null, label };
    }
    case 'MedGen': {
      // Strip "MedGen:" prefix
      const medgenId = id.replace(/^MedGen:/, '');
      return { url: `https://www.ncbi.nlm.nih.gov/medgen/${medgenId}`, label };
    }
    case 'NCIT': {
      // Strip "NCIT:" prefix
      const code = id.replace(/^NCIT:/, '');
      return {
        url: `https://ncit.nci.nih.gov/ncitbrowser/ConceptReport.jsp?dictionary=NCI_Thesaurus&code=${code}`,
        label,
      };
    }
    case 'GARD': {
      // Strip "GARD:" prefix
      const gardId = id.replace(/^GARD:/, '');
      return { url: `https://rarediseases.info.nih.gov/diseases/${gardId}/detail`, label };
    }
    case 'EFO': {
      // Use the full "EFO:..." id as the obo_id query param
      return { url: `https://www.ebi.ac.uk/ols4/ontologies/efo/terms?obo_id=${id}`, label };
    }
    default:
      return { url: null, label };
  }
}

export default ONTOLOGY_LINK_BASES;
