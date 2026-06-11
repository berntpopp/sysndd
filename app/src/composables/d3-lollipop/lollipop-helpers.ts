/**
 * d3-lollipop/lollipop-helpers.ts
 *
 * Pure constants and helper functions for the D3 lollipop plot.
 * Internal to the d3-lollipop module — NOT part of the public composables API.
 * Do not re-export from @/composables.
 */

import type { LollipopFilterState, PathogenicityClass, EffectType } from '@/types/protein';
import { normalizeEffectType } from '@/types/protein';
import type { PlotMargin } from './useD3Lollipop';

// Default options
export const DEFAULT_WIDTH = 800;
export const DEFAULT_HEIGHT = 250;
export const DEFAULT_MARGIN: PlotMargin = { top: 60, right: 30, bottom: 60, left: 50 };

// Visual constants
export const BACKBONE_HEIGHT = 14;
export const STEM_BASE_HEIGHT = 18;
export const STEM_STACK_OFFSET = 8;
export const MARKER_RADIUS = 5;
export const MARKER_STROKE_WIDTH = 1;

// Adaptive rendering thresholds
export const AGGREGATION_THRESHOLD = 500; // Switch to aggregated mode above this count
export const MAX_STACK_DEPTH = 8; // Maximum stacking in individual mode
export const MIN_OPACITY = 0.25; // Minimum opacity for markers
export const MAX_OPACITY = 0.95; // Maximum opacity for markers
export const DENSITY_THRESHOLD = 200; // Reference count for density calculation
export const MIN_MARKER_RADIUS = 3; // Minimum marker size in aggregated mode
export const MAX_MARKER_RADIUS = 12; // Maximum marker size for high-count positions

/**
 * Map pathogenicity class to filter state key
 */
export function isClassificationVisible(
  classification: PathogenicityClass,
  filterState: LollipopFilterState
): boolean {
  switch (classification) {
    case 'Pathogenic':
      return filterState.pathogenic;
    case 'Likely pathogenic':
      return filterState.likelyPathogenic;
    case 'Uncertain significance':
      return filterState.vus;
    case 'Likely benign':
      return filterState.likelyBenign;
    case 'Benign':
      return filterState.benign;
    default:
      return true; // Show 'other' by default
  }
}

/**
 * Check if effect type is visible based on filter state
 */
export function isEffectTypeVisible(
  majorConsequence: string,
  filterState: LollipopFilterState
): boolean {
  // Safety check: if effectFilters is not defined, show all effect types
  if (!filterState.effectFilters) return true;

  const effectType: EffectType = normalizeEffectType(majorConsequence);
  return filterState.effectFilters[effectType];
}

/**
 * Calculate dynamic opacity based on zoom level and variant density
 *
 * @param visibleCount - Number of variants currently visible
 * @param zoomRatio - Ratio of visible range to total range (1.0 = full view)
 * @returns Opacity value between MIN_OPACITY and MAX_OPACITY
 */
export function calculateDynamicOpacity(visibleCount: number, zoomRatio: number): number {
  // Base opacity from density (fewer variants = higher opacity)
  const densityFactor = Math.min(1, DENSITY_THRESHOLD / Math.max(visibleCount, 1));

  // Zoom factor (more zoomed in = higher opacity)
  const zoomFactor = 1 - zoomRatio * 0.6;

  // Combined opacity with bounds
  const opacity = 0.5 * densityFactor + 0.5 * zoomFactor;
  return Math.max(MIN_OPACITY, Math.min(MAX_OPACITY, opacity));
}

/**
 * Calculate marker radius for aggregated variant based on count
 *
 * @param count - Number of variants at this position
 * @param maxCount - Maximum count at any position
 * @returns Marker radius scaled by count
 */
export function calculateAggregatedRadius(count: number, maxCount: number): number {
  // Use square root scaling so area is proportional to count
  const scale = Math.sqrt(count / Math.max(maxCount, 1));
  return MIN_MARKER_RADIUS + scale * (MAX_MARKER_RADIUS - MIN_MARKER_RADIUS);
}

/**
 * Determine rendering mode based on visible variant count
 *
 * @param visibleCount - Number of variants to render
 * @returns 'aggregated' if above threshold, 'individual' otherwise
 */
export function determineRenderingMode(visibleCount: number): 'aggregated' | 'individual' {
  return visibleCount > AGGREGATION_THRESHOLD ? 'aggregated' : 'individual';
}
