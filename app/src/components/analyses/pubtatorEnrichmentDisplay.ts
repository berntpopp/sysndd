// src/components/analyses/pubtatorEnrichmentDisplay.ts
//
// Display formatting for the PubtatorNDD gene-prioritization enrichment metrics
// (issue #175). Extracted from PubtatorNDDGenes.vue to keep that component below
// the file-size ceiling and to make the formatting independently unit-testable.
//
// Metrics normalize a gene's NDD co-occurrence count by its total PubTator
// publication count so research-popularity bias does not dominate the ranking.

export interface PubtatorGeneFieldDefinition {
  key: string;
  label: string;
  sortable?: boolean;
  sortDirection?: string;
  class?: string;
  filterable?: boolean;
  count?: number;
  count_filtered?: number;
}

/**
 * Column definitions for the gene-prioritization table, including the issue
 * #175 enrichment columns (Background Pubs, Enrichment, FDR). Returned fresh on
 * each call so the component owns a mutable copy.
 */
export function createPubtatorGeneFields(): PubtatorGeneFieldDefinition[] {
  return [
    { key: 'gene_symbol', label: 'Gene', sortable: true, class: 'text-start', filterable: true },
    { key: 'gene_name', label: 'Name', sortable: true, class: 'text-start', filterable: true },
    { key: 'publication_count', label: 'NDD Pubs', sortable: true, class: 'text-center', filterable: false },
    { key: 'background_count', label: 'Background Pubs', sortable: true, class: 'text-center', filterable: false },
    { key: 'enrichment_ratio', label: 'Enrichment', sortable: true, class: 'text-center', filterable: false },
    { key: 'fdr_bh', label: 'FDR', sortable: true, class: 'text-center', filterable: false },
    { key: 'oldest_pub_date', label: 'Oldest Pub', sortable: true, class: 'text-center', filterable: false },
    { key: 'is_novel', label: 'Source', sortable: true, class: 'text-center', filterable: false },
    { key: 'pmids', label: 'PMIDs', sortable: false, class: 'text-start', filterable: false },
    { key: 'actions', label: '', sortable: false, class: 'text-center', filterable: false },
  ];
}

export interface EnrichmentRowLike {
  observed?: number | null;
  background_count?: number | null;
  enrichment_ratio?: number | null;
  npmi?: number | null;
  fisher_p?: number | null;
  fdr_bh?: number | null;
}

export type EnrichmentVariant = 'success' | 'warning' | 'secondary';

/** Compact large counts (e.g. 282103 -> "282.1k"). */
export function formatCount(n: number | null | undefined): string {
  if (n == null) return '—';
  if (n >= 1000) return `${Math.round(n / 100) / 10}k`;
  return String(n);
}

/** Round the enrichment ratio for display (coarser as the magnitude grows). */
export function formatEnrichment(ratio: number | null | undefined): string {
  if (ratio == null) return '—';
  if (ratio >= 100) return String(Math.round(ratio));
  if (ratio >= 10) return ratio.toFixed(0);
  return ratio.toFixed(1);
}

/** Color band: strongly enriched (success) / moderate (warning) / not enriched. */
export function enrichmentVariant(ratio: number | null | undefined): EnrichmentVariant {
  if (ratio == null) return 'secondary';
  if (ratio >= 5) return 'success';
  if (ratio >= 1) return 'warning';
  return 'secondary';
}

/** Tooltip combining ratio, NPMI, and the underlying counts. */
export function enrichmentTooltip(item: EnrichmentRowLike): string {
  const parts: string[] = [];
  if (item.enrichment_ratio != null) {
    parts.push(`Enrichment: ${item.enrichment_ratio.toFixed(2)}× more NDD co-mentions than expected`);
  }
  if (item.npmi != null) parts.push(`NPMI: ${item.npmi.toFixed(3)} (range −1..1)`);
  if (item.observed != null && item.background_count != null) {
    parts.push(`${item.observed} of ${item.background_count} total publications`);
  }
  return parts.join(' • ');
}

/** FDR significance stars (Benjamini-Hochberg q-value thresholds). */
export function fdrStars(q: number | null | undefined): string {
  if (q == null) return '';
  if (q < 0.001) return '***';
  if (q < 0.01) return '**';
  if (q < 0.05) return '*';
  return '';
}

/** CSS class pairing significance with weight/color (never color-alone). */
export function fdrClass(q: number | null | undefined): string {
  if (q == null) return 'text-muted';
  return q < 0.05 ? 'fw-bold text-success' : 'text-muted';
}

/** Tooltip describing the FDR q-value and its significance. */
export function fdrTooltip(q: number | null | undefined): string {
  if (q == null) return 'No FDR computed';
  const sig = q < 0.05 ? 'significant' : 'not significant';
  const display = q < 0.001 ? q.toExponential(1) : q.toFixed(3);
  return `BH-adjusted q = ${display} (${sig} at q < 0.05)`;
}
