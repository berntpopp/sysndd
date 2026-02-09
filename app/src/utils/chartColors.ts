// utils/chartColors.ts

/**
 * Shared chart color constants for consistent visual identity across charts.
 *
 * Consolidates colors previously duplicated in EntityTrendChart, ReReviewBarChart,
 * ContributorBarChart, and PubtatorNDDStats components.
 */

/** Primary muted blue used across multiple chart types */
export const CHART_PRIMARY = '#6699CC';

/** Dark blue for secondary elements (e.g. moving-average trend lines) */
export const CHART_SECONDARY = '#004488';

/** Evidence category colors for gene-disease association confidence levels */
export const CATEGORY_COLORS: Record<string, string> = {
  Definitive: '#4caf50',
  Moderate: '#2196f3',
  Limited: '#ff9800',
  Refuted: '#f44336',
};

/** Re-review workflow status colors (Okabe-Ito accessible palette) */
export const REVIEW_STATUS_COLORS = {
  approved: '#009E73',
  submitted: '#6699CC',
  notSubmitted: '#BBBBBB',
} as const;

/** Curation source colors (Bootstrap-aligned) */
export const CURATION_COLORS = {
  curated: '#198754', // Bootstrap success
  literatureOnly: '#0dcaf0', // Bootstrap info
  default: '#5470c6', // Histogram / fallback
} as const;
