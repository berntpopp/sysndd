import type { EffectType } from '@/types/protein';
import { normalizeEffectType } from '@/types/protein';

export interface GeneStructureVariantLike {
  genomicPosition: number;
  classification: string;
  majorConsequence?: string | null;
}

export interface AggregatedGeneStructureVariant<T extends GeneStructureVariantLike> {
  genomicPosition: number;
  count: number;
  dominantClassification: string;
  classifications: Record<string, number>;
  variants: T[];
}

export interface GeneStructureVariantFilterState {
  pathogenicity: Record<string, boolean>;
  effectFilters: Record<EffectType, boolean>;
}

const AGGREGATION_THRESHOLD = 500;
const MIN_MARKER_RADIUS = 3;
const MAX_MARKER_RADIUS = 12;
const MIN_OPACITY = 0.25;
const MAX_OPACITY = 0.95;
const DENSITY_THRESHOLD = 200;

export function aggregateVariantsByGenomicPosition<T extends GeneStructureVariantLike>(
  variants: T[],
  geneLength: number
): AggregatedGeneStructureVariant<T>[] {
  const binSize = Math.max(100, Math.floor(geneLength / 100));
  const binMap = new Map<number, T[]>();

  for (const variant of variants) {
    const binKey = Math.floor(variant.genomicPosition / binSize) * binSize;
    if (!binMap.has(binKey)) {
      binMap.set(binKey, []);
    }
    binMap.get(binKey)!.push(variant);
  }

  return Array.from(binMap.values()).map((binVariants) => {
    const classifications: Record<string, number> = {};
    for (const variant of binVariants) {
      classifications[variant.classification] = (classifications[variant.classification] || 0) + 1;
    }

    let dominantClassification = 'Uncertain significance';
    let maxCount = 0;
    for (const [classification, count] of Object.entries(classifications)) {
      if (count > maxCount) {
        maxCount = count;
        dominantClassification = classification;
      }
    }

    const averagePosition =
      binVariants.reduce((sum, variant) => sum + variant.genomicPosition, 0) / binVariants.length;

    return {
      genomicPosition: Math.round(averagePosition),
      count: binVariants.length,
      dominantClassification,
      classifications,
      variants: binVariants,
    };
  });
}

export function calculateAggregatedRadius(count: number, maxCount: number): number {
  const scale = Math.sqrt(count / Math.max(maxCount, 1));
  return MIN_MARKER_RADIUS + scale * (MAX_MARKER_RADIUS - MIN_MARKER_RADIUS);
}

export function calculateDynamicOpacity(visibleCount: number): number {
  const densityFactor = Math.min(1, DENSITY_THRESHOLD / Math.max(visibleCount, 1));
  const opacity = 0.4 + 0.6 * densityFactor;
  return Math.max(MIN_OPACITY, Math.min(MAX_OPACITY, opacity));
}

export function determineRenderingMode(visibleCount: number): 'aggregated' | 'individual' {
  return visibleCount > AGGREGATION_THRESHOLD ? 'aggregated' : 'individual';
}

export function isGeneStructureVariantVisible(
  variant: GeneStructureVariantLike,
  filterState: GeneStructureVariantFilterState
): boolean {
  const pathogenicityVisible = filterState.pathogenicity[variant.classification] ?? true;
  const effectType = normalizeEffectType(variant.majorConsequence ?? '');
  const effectVisible = filterState.effectFilters[effectType];

  return pathogenicityVisible && effectVisible;
}
