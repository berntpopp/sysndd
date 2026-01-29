// app/src/types/alphafold.ts
/**
 * Type definitions for AlphaFold 3D structure data and ACMG clinical variant classification
 *
 * This module provides:
 * - AlphaFoldMetadata interface (matches backend external-proxy-alphafold.R response)
 * - ACMG color constants (shared source of truth for GeneClinVarCard, lollipop plot, 3D viewer)
 * - Helper functions for variant position parsing and significance classification
 */

/**
 * AlphaFold structure prediction metadata
 *
 * Response structure from backend /api/external/alphafold/<symbol> endpoint.
 * Matches external-proxy-alphafold.R return structure.
 */
export interface AlphaFoldMetadata {
  /** Source identifier (always "alphafold") */
  source: string;

  /** HGNC gene symbol */
  gene_symbol: string;

  /** UniProt accession (e.g., "P38398") */
  uniprot_accession: string;

  /** AlphaFold entry identifier (e.g., "AF-P38398-F1") */
  entry_id: string;

  /** URL to PDB format structure file */
  pdb_url: string;

  /** URL to mmCIF format structure file */
  cif_url: string;

  /** URL to BinaryCIF format structure file */
  bcif_url: string;

  /** URL to Predicted Aligned Error (PAE) image */
  pae_image_url: string;

  /** URL for viewer (same as cif_url) */
  model_url: string;

  /** ISO date of model creation */
  model_created_date: string;

  /** Latest model version number */
  latest_version: number;
}

/**
 * ACMG pathogenicity classification colors
 *
 * Shared color palette for all ACMG-colored components:
 * - GeneClinVarCard.vue (badge colors)
 * - Protein domain lollipop plot (variant markers)
 * - 3D structure viewer (variant spheres)
 *
 * Colors match Bootstrap variants and GeneClinVarCard custom badge styles:
 * - pathogenic: Bootstrap danger (#dc3545)
 * - likely_pathogenic: Custom orange (#fd7e14, .badge-lp)
 * - vus: Bootstrap warning (#ffc107)
 * - likely_benign: Custom teal (#20c997, .badge-lb)
 * - benign: Bootstrap success (#28a745)
 */
export const ACMG_COLORS = {
  pathogenic: '#dc3545',
  likely_pathogenic: '#fd7e14',
  vus: '#ffc107',
  likely_benign: '#20c997',
  benign: '#28a745',
} as const;

/**
 * ACMG pathogenicity classification text labels
 */
export const ACMG_LABELS = {
  pathogenic: 'Pathogenic',
  likely_pathogenic: 'Likely Pathogenic',
  vus: 'VUS',
  likely_benign: 'Likely Benign',
  benign: 'Benign',
} as const;

/**
 * ACMG pathogenicity classification type
 */
export type AcmgClassification = keyof typeof ACMG_COLORS;

/**
 * AlphaFold pLDDT confidence score legend
 *
 * AlphaFold stores per-residue confidence (pLDDT) in the B-factor column.
 * These colors match the AlphaFold Database convention:
 * - Very High (>90): Dark blue (#0053d6)
 * - Confident (70-90): Light blue (#65cbf3)
 * - Low (50-70): Yellow (#ffdb13)
 * - Very Low (<50): Orange (#ff7d45)
 *
 * NGL Viewer's 'bfactor' colorScheme auto-maps B-factor values to this gradient.
 */
export const PLDDT_LEGEND = [
  { label: 'Very High (>90)', color: '#0053d6', min: 90, max: 100 },
  { label: 'Confident (70-90)', color: '#65cbf3', min: 70, max: 90 },
  { label: 'Low (50-70)', color: '#ffdb13', min: 50, max: 70 },
  { label: 'Very Low (<50)', color: '#ff7d45', min: 0, max: 50 },
] as const;

/**
 * 3D structure representation types
 *
 * Supported NGL Viewer representation styles:
 * - cartoon: Ribbon diagram (default, shows secondary structure)
 * - surface: Molecular surface (shows protein envelope)
 * - ball+stick: Atomic detail (all atoms as spheres and bonds)
 */
export type RepresentationType = 'cartoon' | 'surface' | 'ball+stick';

/**
 * Check if a variant is mappable to 3D structure
 *
 * Only missense and inframe variants can be meaningfully highlighted on AlphaFold
 * 3D structures. Frameshifts, stops, and splice variants are excluded because:
 * - Frameshifts: Protein is truncated/altered downstream, no meaningful single position
 * - Stop/nonsense: Protein terminates, no residue to highlight
 * - Splice variants: No protein-level position available
 *
 * @param hgvsp - HGVS protein notation string
 * @returns true if variant is missense or inframe (mappable to 3D)
 *
 * @example
 * isStructureMappableVariant("p.Arg123Trp")  // → true (missense)
 * isStructureMappableVariant("p.Gly789del")  // → true (inframe deletion)
 * isStructureMappableVariant("p.Met100_Ala102dup")  // → true (inframe dup)
 * isStructureMappableVariant("p.Gln456*")    // → false (stop)
 * isStructureMappableVariant("p.Glu123fs")   // → false (frameshift)
 * isStructureMappableVariant(null)           // → false
 */
export function isStructureMappableVariant(hgvsp: string | null | undefined): boolean {
  // Guard against null, undefined, or non-string values (API may return objects/arrays)
  if (!hgvsp || typeof hgvsp !== 'string') return false;

  const lower = hgvsp.toLowerCase();

  // Exclude frameshift variants (fs, frameshift)
  if (lower.includes('fs') || lower.includes('frameshift')) return false;

  // Exclude stop/nonsense variants (*, ter, stop)
  if (hgvsp.includes('*') || lower.includes('ter') || lower.includes('stop')) return false;

  // Exclude splice variants (no "p." prefix or contains splice-related terms)
  if (!hgvsp.startsWith('p.') || lower.includes('splice')) return false;

  // Exclude extension variants (ext)
  if (lower.includes('ext')) return false;

  // Accept missense (p.Arg123Trp) and inframe (p.Gly789del, p.Met100_Ala102dup)
  // These have meaningful single residue positions on the 3D structure
  return true;
}

/**
 * Parse residue number from HGVSP notation for 3D structure mapping
 *
 * Extracts amino acid position from HGVS protein notation (p. format).
 * Only returns position for structure-mappable variants (missense, inframe).
 *
 * Handles:
 * - Missense: "p.Arg123Trp" → 123
 * - Inframe deletion: "p.Gly789del" → 789
 * - Inframe duplication: "p.Met100dup" → 100
 *
 * Returns null for:
 * - Null input
 * - Frameshift variants (e.g., "p.Glu123fs")
 * - Stop/nonsense variants (e.g., "p.Gln456*")
 * - Splice variants
 * - Insertions (position ambiguous: "p.Arg123_Lys124insAla")
 * - Unrecognized format
 *
 * @param hgvsp - HGVS protein notation string (e.g., "p.Arg123Trp")
 * @returns Residue number (1-indexed) or null if not mappable to 3D structure
 *
 * @example
 * parseResidueNumber("p.Arg123Trp")  // → 123 (missense)
 * parseResidueNumber("p.Gly789del")  // → 789 (inframe deletion)
 * parseResidueNumber("p.Gln456*")    // → null (stop - not mappable)
 * parseResidueNumber("p.Glu123fs")   // → null (frameshift - not mappable)
 * parseResidueNumber(null)           // → null
 */
export function parseResidueNumber(hgvsp: string | null | undefined): number | null {
  // First check if this variant type is mappable to 3D structure
  // isStructureMappableVariant handles null/undefined/non-string values
  if (!isStructureMappableVariant(hgvsp)) return null;

  // Match pattern: "p." + 3-letter AA code + digits
  // Captures the digits as group 1
  const match = hgvsp!.match(/p\.\w{3}(\d+)/);

  return match ? parseInt(match[1], 10) : null;
}

/**
 * Classify clinical significance string to ACMG classification
 *
 * Normalizes ClinVar clinical_significance strings to one of 5 ACMG categories.
 * Handles both underscore and space formats from gnomAD API.
 *
 * Classification logic (matches GeneClinVarCard.vue counts computed property):
 * - "Pathogenic" (without "Likely") → pathogenic
 * - "Likely pathogenic" / "Likely_pathogenic" → likely_pathogenic
 * - "Uncertain significance" / "VUS" → vus
 * - "Likely benign" / "Likely_benign" → likely_benign
 * - "Benign" (without "Likely") → benign
 * - Conflicting/other → null
 *
 * @param significance - ClinVar clinical_significance string
 * @returns ACMG classification or null if unrecognized
 *
 * @example
 * classifyClinicalSignificance("Pathogenic")  // → "pathogenic"
 * classifyClinicalSignificance("Likely_pathogenic")  // → "likely_pathogenic"
 * classifyClinicalSignificance("Uncertain_significance")  // → "vus"
 * classifyClinicalSignificance("Conflicting")  // → null
 */
export function classifyClinicalSignificance(significance: string): AcmgClassification | null {
  // Normalize: lowercase and replace underscores with spaces
  const lower = significance.toLowerCase().replace(/_/g, ' ');

  // Match classification (order matters: check "likely pathogenic" before "pathogenic")
  if (lower.includes('pathogenic') && !lower.includes('likely')) return 'pathogenic';
  if (lower.includes('likely') && lower.includes('pathogenic')) return 'likely_pathogenic';
  if (lower.includes('uncertain') || lower.includes('vus')) return 'vus';
  if (lower.includes('likely') && lower.includes('benign')) return 'likely_benign';
  if (lower.includes('benign') && !lower.includes('likely')) return 'benign';

  return null;
}
