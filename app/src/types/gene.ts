// app/src/types/gene.ts
/**
 * Type definitions for gene API responses
 */

/**
 * Gene API response from /api/gene/<symbol> endpoint
 * All fields are string arrays because the R backend pipes fields through str_split(., pattern = "\\|")
 * Even single-value fields like symbol come back as arrays.
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
}
