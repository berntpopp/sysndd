// app/src/types/gene.ts
/**
 * Type definitions for gene API responses
 */

/**
 * Gene API response from /api/gene/<symbol> endpoint.
 *
 * Most fields arrive as `string[]` because the R backend pipes the row through
 * `dplyr::mutate(across(..., ~ str_split(., "\\|")))`, which turns every
 * character column into a list column. Even single-value fields like `symbol`
 * therefore come back wrapped in an array.
 *
 * Exception: `gnomad_constraints` is a JSON-encoded blob and is deliberately
 * excluded from the pipe-split transformation (Phase A A2,
 * `.plans/v11.0/phase-a.md` §3 A2). It arrives as a plain scalar string that
 * the consumer must `JSON.parse` into a `GnomADConstraints` object. Null when
 * no constraint data is available for the gene.
 */
export interface GeneApiData {
  hgnc_id: string[];
  symbol: string[];
  name: string[];
  entrez_id: string[];
  ensembl_gene_id: string[];
  ucsc_id: string[];
  ccds_id: string[];
  uniprot_ids: string[];
  omim_id: string[];
  mane_select: string[];
  mgd_id: string[];
  rgd_id: string[];
  STRING_id: string[];
  bed_hg38: string[]; // Chromosome coordinates like "chr17:12345-67890" (added by Plan 02)
  /**
   * JSON-encoded gnomAD v4 constraint scores (pre-annotated in DB).
   * Scalar string (not array) because the backend does not pipe-split this
   * column. Parse with `JSON.parse` into a `GnomADConstraints` object. May be
   * `null` when no constraint data is available.
   */
  gnomad_constraints: string | null;
  alphafold_id: string[]; // AlphaFold model identifier (AF-{uniprot_id}-F1) for Phase 45
}
