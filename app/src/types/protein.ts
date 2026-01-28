// app/src/types/protein.ts
/**
 * Type definitions for protein domain visualization (lollipop plot)
 *
 * These types bridge backend API responses (UniProt domains, gnomAD ClinVar variants)
 * to the D3.js lollipop plot visualization component.
 */

/**
 * ACMG pathogenicity classification categories
 * Used for coloring variant markers and filtering
 */
export type PathogenicityClass =
  | 'Pathogenic'
  | 'Likely pathogenic'
  | 'Uncertain significance'
  | 'Likely benign'
  | 'Benign'
  | 'other';

/**
 * Color palette for pathogenicity classes following ACMG conventions
 * Red spectrum for pathogenic, green spectrum for benign
 */
export const PATHOGENICITY_COLORS: Record<PathogenicityClass, string> = {
  Pathogenic: '#d73027',
  'Likely pathogenic': '#fc8d59',
  'Uncertain significance': '#fee08b',
  'Likely benign': '#91cf60',
  Benign: '#1a9850',
  other: '#999999',
} as const;

/**
 * Protein domain from UniProt features API
 * Maps to external-proxy-uniprot.R response: type, description, begin, end
 */
export interface ProteinDomain {
  /** Feature type (e.g., 'DOMAIN', 'REGION', 'MOTIF', 'ZN_FING', 'DNA_BIND') */
  type: string;
  /** Human-readable description (e.g., 'Protein kinase domain') */
  description: string;
  /** Start amino acid position (1-indexed) */
  begin: number;
  /** End amino acid position (1-indexed) */
  end: number;
}

/**
 * Processed ClinVar variant for lollipop plot rendering
 * Derived from gnomAD ClinVar API response (external-proxy-gnomad.R)
 */
export interface ProcessedVariant {
  /** Amino acid position (1-indexed) derived from hgvsp or calculated from hgvsc */
  proteinPosition: number;
  /** Protein HGVS notation (e.g., 'p.Arg123Trp') */
  proteinHGVS: string;
  /** Coding HGVS notation (e.g., 'c.367C>T') */
  codingHGVS: string;
  /** Normalized pathogenicity classification */
  classification: PathogenicityClass;
  /** Review status confidence (0-4 stars) */
  goldStars: number;
  /** ClinVar review status text */
  reviewStatus: string;
  /** ClinVar variation ID */
  clinvarId: string;
  /** gnomAD variant identifier (chrom-pos-ref-alt) */
  variantId: string;
  /** Most severe consequence (missense_variant, frameshift, splice_donor, etc.) */
  majorConsequence: string;
  /** True if mapped to approximate position from intronic/splice variant */
  isSpliceVariant: boolean;
  /** Whether variant is observed in gnomAD population data */
  inGnomad: boolean;
}

/**
 * Complete data structure for the lollipop plot
 * Aggregates protein metadata, domains, and variants
 */
export interface ProteinPlotData {
  /** Total protein length in amino acids */
  proteinLength: number;
  /** Protein name (e.g., 'Tumor protein p53') */
  proteinName: string;
  /** UniProt accession (e.g., 'P04637') */
  accession: string;
  /** Protein domain features from UniProt */
  domains: ProteinDomain[];
  /** Processed ClinVar variants for visualization */
  variants: ProcessedVariant[];
}

/**
 * Filter state for lollipop plot pathogenicity visibility
 * Controls which variant categories are rendered
 */
export interface LollipopFilterState {
  /** Show Pathogenic variants */
  pathogenic: boolean;
  /** Show Likely pathogenic variants */
  likelyPathogenic: boolean;
  /** Show Uncertain significance (VUS) variants */
  vus: boolean;
  /** Show Likely benign variants */
  likelyBenign: boolean;
  /** Show Benign variants */
  benign: boolean;
}

/**
 * Normalize gnomAD clinical_significance string to PathogenicityClass
 *
 * gnomAD API returns various formats:
 * - "Pathogenic", "Likely_pathogenic", "Uncertain_significance", "Benign"
 * - Combined: "Pathogenic/Likely_pathogenic", "Benign/Likely_benign"
 * - With underscores: "Uncertain_significance"
 *
 * @param raw - Raw clinical_significance string from gnomAD API
 * @returns Normalized PathogenicityClass
 */
export function normalizeClassification(raw: string): PathogenicityClass {
  if (!raw) return 'other';

  // Normalize: replace underscores with spaces, trim whitespace
  const normalized = raw.replace(/_/g, ' ').trim().toLowerCase();

  // Handle combined classifications - use more severe one
  if (normalized.includes('/')) {
    const parts = normalized.split('/').map((p) => p.trim());

    // Pathogenic > Likely pathogenic > VUS > Likely benign > Benign
    if (parts.some((p) => p === 'pathogenic')) return 'Pathogenic';
    if (parts.some((p) => p === 'likely pathogenic')) return 'Likely pathogenic';
    if (parts.some((p) => p === 'uncertain significance')) return 'Uncertain significance';
    if (parts.some((p) => p === 'likely benign')) return 'Likely benign';
    if (parts.some((p) => p === 'benign')) return 'Benign';
  }

  // Direct matches
  if (normalized === 'pathogenic') return 'Pathogenic';
  if (normalized === 'likely pathogenic') return 'Likely pathogenic';
  if (normalized === 'uncertain significance') return 'Uncertain significance';
  if (normalized === 'likely benign') return 'Likely benign';
  if (normalized === 'benign') return 'Benign';

  // Partial matches for edge cases
  if (normalized.includes('pathogenic') && !normalized.includes('likely'))
    return 'Pathogenic';
  if (normalized.includes('likely pathogenic')) return 'Likely pathogenic';
  if (normalized.includes('uncertain') || normalized.includes('vus'))
    return 'Uncertain significance';
  if (normalized.includes('likely benign')) return 'Likely benign';
  if (normalized.includes('benign')) return 'Benign';

  return 'other';
}

/**
 * Parse protein position from HGVS notation
 *
 * Priority:
 * 1. hgvsp (protein notation): p.Arg123Trp -> 123, p.Ter456Leu -> 456
 * 2. hgvsc (coding notation): c.367C>T -> floor(367/3) = 122
 * 3. Splice variants: c.123+2A>G -> floor(123/3) = 41 with isSplice=true
 *
 * @param hgvsp - Protein HGVS notation (e.g., 'p.Arg123Trp')
 * @param hgvsc - Coding HGVS notation (e.g., 'c.367C>T')
 * @returns Object with position and splice flag, or null if unparseable
 */
export function parseProteinPosition(
  hgvsp: string | null,
  hgvsc: string | null
): { position: number; isSplice: boolean } | null {
  // Try hgvsp first (preferred)
  if (hgvsp) {
    // Match patterns like: p.Arg123Trp, p.Ter456Leu, p.Met1?, p.Gly12del, p.Lys27_Ser30del
    // Extract the first position number after the amino acid code
    const proteinMatch = hgvsp.match(/p\.([A-Z][a-z]{2})?(\d+)/i);
    if (proteinMatch && proteinMatch[2]) {
      const position = parseInt(proteinMatch[2], 10);
      if (!isNaN(position) && position > 0) {
        return { position, isSplice: false };
      }
    }

    // Handle fs (frameshift) with position: p.Arg123fs
    const fsMatch = hgvsp.match(/p\.[A-Z][a-z]{2}(\d+)fs/i);
    if (fsMatch && fsMatch[1]) {
      const position = parseInt(fsMatch[1], 10);
      if (!isNaN(position) && position > 0) {
        return { position, isSplice: false };
      }
    }

    // Handle extension: p.*123Leuext*45
    const extMatch = hgvsp.match(/p\.\*(\d+)/i);
    if (extMatch && extMatch[1]) {
      const position = parseInt(extMatch[1], 10);
      if (!isNaN(position) && position > 0) {
        return { position, isSplice: false };
      }
    }
  }

  // Fall back to hgvsc
  if (hgvsc) {
    // Handle splice variants: c.123+2A>G, c.456-1G>A
    const spliceMatch = hgvsc.match(/c\.(\d+)[+-]/);
    if (spliceMatch && spliceMatch[1]) {
      const codingPos = parseInt(spliceMatch[1], 10);
      if (!isNaN(codingPos) && codingPos > 0) {
        // Convert coding position to approximate amino acid position
        const aaPosition = Math.floor(codingPos / 3) || 1;
        return { position: aaPosition, isSplice: true };
      }
    }

    // Standard coding position: c.367C>T, c.1234del, c.5678dup
    const codingMatch = hgvsc.match(/c\.(\d+)/);
    if (codingMatch && codingMatch[1]) {
      const codingPos = parseInt(codingMatch[1], 10);
      if (!isNaN(codingPos) && codingPos > 0) {
        // Convert coding position to amino acid position (1-indexed)
        // Add 2 before dividing to round to nearest codon, then use Math.ceil
        const aaPosition = Math.ceil(codingPos / 3);
        return { position: aaPosition, isSplice: false };
      }
    }
  }

  // Unable to parse position
  return null;
}
