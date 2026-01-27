// app/src/types/external.ts
/**
 * Type definitions for external genomic API responses
 *
 * These interfaces match the combined aggregation endpoint response structure
 * from the backend /api/external/gene/<symbol> endpoint, which fetches data from
 * multiple sources (gnomAD, ClinVar, UniProt, Ensembl, AlphaFold, MGI, RGD) in parallel.
 */

/**
 * gnomAD constraint scores for a gene
 *
 * Constraint metrics indicate tolerance to variation:
 * - pLI: probability of loss-of-function intolerance (0-1, higher = more constrained)
 * - oe_lof: observed/expected loss-of-function ratio (lower = more constrained)
 * - oe_mis: observed/expected missense ratio
 * - oe_syn: observed/expected synonymous ratio
 *
 * All fields nullable as some genes may lack constraint data.
 */
export interface GnomADConstraints {
  // Loss-of-function intolerance
  pLI: number | null;

  // Observed/expected ratios with confidence intervals
  oe_lof: number | null;
  oe_lof_lower: number | null;
  oe_lof_upper: number | null;

  oe_mis: number | null;
  oe_mis_lower: number | null;
  oe_mis_upper: number | null;

  oe_syn: number | null;
  oe_syn_lower: number | null;
  oe_syn_upper: number | null;

  // Expected and observed variant counts
  exp_lof: number | null;
  obs_lof: number | null;
  exp_mis: number | null;
  obs_mis: number | null;
  exp_syn: number | null;
  obs_syn: number | null;

  // Z-scores for deviation from expectation
  lof_z: number | null;
  mis_z: number | null;
  syn_z: number | null;
}

/**
 * ClinVar variant from gnomAD API
 *
 * Represents a single clinical variant with pathogenicity classification
 * and population frequency information.
 */
export interface ClinVarVariant {
  /** Clinical significance (e.g., "Pathogenic", "Benign", "VUS") */
  clinical_significance: string;

  /** ClinVar variation ID */
  clinvar_variation_id: string;

  /** Review status confidence (0-4 stars) */
  gold_stars: number;

  /** HGVS coding sequence notation (c. notation) */
  hgvsc: string | null;

  /** HGVS protein sequence notation (p. notation) */
  hgvsp: string | null;

  /** Whether variant is present in gnomAD population data */
  in_gnomad: boolean;

  /** Variant consequence (e.g., "missense_variant", "frameshift_variant") */
  major_consequence: string;

  /** Genomic position */
  pos: number;

  /** ClinVar review status text */
  review_status: string;

  /** Variant ID (chr-pos-ref-alt format) */
  variant_id: string;
}

/**
 * RFC 9457 Problem Details for HTTP APIs
 *
 * Standardized error format used by the backend aggregation endpoint
 * to communicate per-source errors.
 */
export interface ExternalApiError {
  /** URI identifying the problem type */
  type: string;

  /** Short, human-readable summary */
  title: string;

  /** HTTP status code */
  status: number;

  /** Human-readable explanation */
  detail: string;

  /** Source identifier (e.g., "gnomad_constraints", "gnomad_clinvar") */
  source: string;
}

/**
 * Combined external data response from aggregation endpoint
 *
 * The aggregation endpoint fetches data from all sources in parallel with error isolation.
 * Partial success returns 200 with available data + errors for failed sources.
 *
 * Source keys match backend function names:
 * - gnomad_constraints: constraint scores (nested under .constraints)
 * - gnomad_clinvar: ClinVar variants (nested under .variants)
 * - uniprot: protein domains (TODO: add interface in future plan)
 * - ensembl: gene structure (TODO: add interface in future plan)
 * - alphafold: 3D structure metadata (TODO: add interface in future plan)
 * - mgi: mouse phenotypes (TODO: add interface in future plan)
 * - rgd: rat phenotypes (TODO: add interface in future plan)
 */
export interface ExternalDataResponse {
  /** Gene symbol queried */
  gene_symbol: string;

  /** Data from each source (only present if successful) */
  sources: {
    /** gnomAD constraint scores */
    gnomad_constraints?: {
      source: string;
      gene_symbol: string;
      gene_id: string;
      constraints: GnomADConstraints;
    };

    /** ClinVar variants from gnomAD */
    gnomad_clinvar?: {
      source: string;
      gene_symbol: string;
      gene_id: string;
      variants: ClinVarVariant[];
      variant_count: number;
    };

    // Other sources (uniprot, ensembl, alphafold, mgi, rgd) represented as unknown for now
    // Will be typed in future plans when UI components consume them
    uniprot?: unknown;
    ensembl?: unknown;
    alphafold?: unknown;
    mgi?: unknown;
    rgd?: unknown;
  };

  /** Errors from failed sources (key = source name) */
  errors: Record<string, ExternalApiError>;

  /** ISO 8601 timestamp of response generation */
  timestamp: string;
}

/**
 * Generic per-source state container
 *
 * Enables independent loading/error/data state for each external data source,
 * supporting graceful degradation (one source fails, others still render).
 *
 * Pattern: COMPOSE-02/03 requirements from plan
 */
export interface SourceState<T> {
  /** Whether this source is currently loading */
  loading: boolean;

  /** Error message if fetch failed, null otherwise */
  error: string | null;

  /** Data from this source, null if not yet loaded or error occurred */
  data: T | null;
}
