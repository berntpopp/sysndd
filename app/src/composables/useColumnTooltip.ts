/**
 * Composable for generating column header tooltip text.
 * Extracts the tooltip pattern used in TablesGenes into a reusable utility.
 *
 * The backend API returns field specs (fspec) with count and count_filtered
 * properties for each column. This composable formats those into a human-readable
 * tooltip string.
 */

export interface FieldWithCounts {
  key: string;
  label?: string;
  count?: number;
  count_filtered?: number;
  [key: string]: unknown;
}

export function useColumnTooltip() {
  /**
   * Generate tooltip text for a table column header.
   * Format: "Label (unique filtered/total values: X/Y)"
   *
   * @param field - Field definition with optional count data
   * @returns Formatted tooltip string
   */
  const getTooltipText = (field: FieldWithCounts): string => {
    const label = field.label || field.key;
    const filtered = field.count_filtered ?? 0;
    const total = field.count ?? 0;
    return `${label} (unique filtered/total values: ${filtered}/${total})`;
  };

  /**
   * Compact tooltip variant for tables whose columns do not all carry
   * distinct-value counts (e.g. continuous analysis metrics). Appends
   * "(unique/total: X/Y)" only when a filtered count is present; otherwise
   * returns the bare label so count-less columns never render a meaningless
   * "0/0".
   *
   * @param field - Field definition with optional count data
   * @returns Formatted tooltip string
   */
  const getCompactTooltipText = (field: FieldWithCounts): string => {
    const label = field.label || field.key;
    if (!field.count_filtered) {
      return label;
    }
    return `${label} (unique/total: ${field.count_filtered}/${field.count})`;
  };

  return { getTooltipText, getCompactTooltipText };
}
