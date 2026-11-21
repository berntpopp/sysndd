// Display labels for the Panels columns; the API sends bare keys for the column list.
const PANEL_COLUMN_LABELS: Record<string, string> = {
  category: 'Category',
  inheritance: 'Inheritance',
  symbol: 'Symbol',
  hgnc_id: 'HGNC ID',
  entrez_id: 'Entrez ID',
  ensembl_gene_id: 'Ensembl ID',
  ucsc_id: 'UCSC ID',
  bed_hg19: 'BED (hg19)',
  bed_hg38: 'BED (hg38)',
};

export function panelColumnLabel(key: string): string {
  return PANEL_COLUMN_LABELS[key] ?? key.replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase());
}
