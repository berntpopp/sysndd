// src/components/analyses/curationUpsetDisplay.ts
//
// Pure display configuration and helpers for the curation-comparisons UpSet
// plot (AnalysesCurationUpset.vue): the color palette, plot-dimension math,
// option normalization, and source label/variant maps. Extracted so the
// component stays a thinner shell; none of these touch the @upsetjs render call.

/**
 * Per-source colors using the Wong/Okabe-Ito color-blind-friendly palette.
 * Reference: Wong, B. (2011) Nature Methods 8:441
 * https://www.nature.com/articles/nmeth.1618
 */
export const SOURCE_COLORS: Record<string, string> = {
  SysNDD: '#0072B2', // Blue - our main source, highly visible
  panelapp: '#009E73', // Bluish Green
  gene2phenotype: '#56B4E9', // Sky Blue
  orphanet_id: '#F0E442', // Yellow
  radboudumc_ID: '#CC79A7', // Reddish Purple
  sfari: '#E69F00', // Orange
  geisinger_DBD: '#D55E00', // Vermilion
  omim_ndd: '#000000', // Black
};

/** Highlight color for the SysNDD query set (matches SysNDD source). */
export const SYSNDD_HIGHLIGHT_COLOR = '#0072B2';

/** Highlight color for the core-overlap query (high contrast with blue). */
export const CORE_OVERLAP_COLOR = '#D55E00';

/** Default selected sources shown on first render / reset. */
export const DEFAULT_SELECTED_SOURCES = ['SysNDD', 'panelapp', 'gene2phenotype'];

/** Width/height for the rendered UpSet plot. */
export interface UpsetPlotDimensions {
  width: number;
  height: number;
}

/**
 * Compute responsive plot dimensions from the available container width.
 *
 * Width is clamped to [300, 1320]; height steps up with width.
 *
 * @param containerWidth - The measured container width (px), if known
 * @param fallbackViewportWidth - Width to use when no container width is known
 */
export function computeUpsetPlotDimensions(
  containerWidth: number | undefined,
  fallbackViewportWidth: number
): UpsetPlotDimensions {
  const availableWidth = containerWidth || fallbackViewportWidth;
  const width = Math.max(300, Math.min(Math.floor(availableWidth), 1320));
  const height = width < 520 ? 430 : width < 900 ? 500 : 560;
  return { width, height };
}

/** A normalized { value, text } select option. */
export interface UpsetSelectOption {
  value: unknown;
  text: unknown;
}

/**
 * Normalize source options for the selector.
 *
 * Unlike the generic select normalizer, this prefers the `list` property used
 * by the comparisons options endpoint.
 */
export function normalizeUpsetSelectOptions(options: unknown): UpsetSelectOption[] {
  if (!options || !Array.isArray(options)) return [];
  return options.map((opt) => {
    if (typeof opt === 'object' && opt !== null) {
      const o = opt as { list?: unknown; id?: unknown; value?: unknown; label?: unknown; text?: unknown };
      return {
        value: o.list || o.id || o.value,
        text: o.list || o.label || o.text || o.id,
      };
    }
    return { value: opt, text: opt };
  });
}

/** Display labels for known sources; unknown sources get underscores stripped. */
const SOURCE_NAME_MAP: Record<string, string> = {
  SysNDD: 'SysNDD',
  panelapp: 'PanelApp',
  gene2phenotype: 'Gene2Phenotype',
  orphanet_id: 'Orphanet',
  radboudumc_ID: 'Radboudumc',
  sfari: 'SFARI',
  geisinger_DBD: 'Geisinger DBD',
  omim_ndd: 'OMIM NDD',
};

/** Format a source name for display (mapped label, or underscores -> spaces). */
export function formatSourceName(name: string | null | undefined): string {
  if (!name) return '';
  return SOURCE_NAME_MAP[name] || name.replace(/_/g, ' ');
}

/** Bootstrap variant per source for the source chips. */
const SOURCE_VARIANT_MAP: Record<string, string> = {
  SysNDD: 'primary',
  panelapp: 'success',
  gene2phenotype: 'info',
  orphanet_id: 'warning',
  radboudumc_ID: 'secondary',
  sfari: 'danger',
  geisinger_DBD: 'dark',
  omim_ndd: 'light',
};

/** Get the Bootstrap variant for a source chip (defaults to 'secondary'). */
export function getSourceVariant(source: string): string {
  return SOURCE_VARIANT_MAP[source] || 'secondary';
}
