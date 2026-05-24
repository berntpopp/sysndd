import type { ElementDefinition } from 'cytoscape';

/**
 * fcose layout options (cytoscape-fcose plugin)
 * The fcose plugin is not typed in cytoscape's LayoutOptions union,
 * so we define the minimal interface for the options we use.
 */
export interface FcoseLayoutOptions {
  name: 'fcose';
  quality?: 'default' | 'draft' | 'proof';
  randomize?: boolean;
  animate?: boolean;
  animationDuration?: number;
  fit?: boolean;
  padding?: number;
  nodeDimensionsIncludeLabels?: boolean;
  nodeSeparation?: number;
  nodeRepulsion?: number | ((node: unknown) => number);
  idealEdgeLength?: number | ((edge: unknown) => number);
  edgeElasticity?: number | ((edge: unknown) => number);
  nestingFactor?: number;
  gravity?: number;
  gravityRange?: number;
  gravityCompound?: number;
  gravityRangeCompound?: number;
  numIter?: number;
  tile?: boolean;
  tilingPaddingVertical?: number;
  tilingPaddingHorizontal?: number;
  packComponents?: boolean;
  ready?: () => void;
  stop?: () => void;
}

export interface PresetLayoutOptions {
  name: 'preset';
  fit: boolean;
  padding: number;
  animate: boolean;
}

export interface LayoutPosition {
  x: number;
  y: number;
}

export function isGeneNodeElement(element: ElementDefinition): boolean {
  return (
    Boolean(element.data?.id) &&
    element.data?.isClusterParent !== true &&
    !element.data?.source &&
    !element.data?.target
  );
}

export function hasFinitePosition(element: ElementDefinition): boolean {
  return Number.isFinite(element.position?.x) && Number.isFinite(element.position?.y);
}

export function shouldUsePresetLayout(elements: ElementDefinition[]): boolean {
  const geneNodes = elements.filter(isGeneNodeElement);
  return geneNodes.length > 0 && geneNodes.every(hasFinitePosition);
}

export function collectPresetPositions(elements: ElementDefinition[]): Map<string, LayoutPosition> {
  const positions = new Map<string, LayoutPosition>();

  for (const element of elements) {
    if (!isGeneNodeElement(element) || !hasFinitePosition(element)) {
      continue;
    }
    positions.set(String(element.data?.id), {
      x: Number(element.position?.x),
      y: Number(element.position?.y),
    });
  }

  return positions;
}

export function presetLayoutOptions(): PresetLayoutOptions {
  return { name: 'preset', fit: true, padding: 30, animate: false };
}

export function initialFcoseLayoutOptions(): FcoseLayoutOptions {
  return {
    name: 'fcose',
    quality: 'default',
    randomize: true,
    animate: false,
    nodeDimensionsIncludeLabels: false,
    fit: true,
    padding: 50,
    nodeSeparation: 100,
    nodeRepulsion: 15000,
    idealEdgeLength: 100,
    edgeElasticity: 0.45,
    nestingFactor: 0.5,
    gravity: 0.2,
    gravityRange: 3.8,
    gravityCompound: 1.5,
    gravityRangeCompound: 2.0,
    numIter: 2500,
    tile: true,
    tilingPaddingVertical: 20,
    tilingPaddingHorizontal: 20,
    packComponents: true,
  };
}

export function updateFcoseLayoutOptions(): FcoseLayoutOptions {
  return {
    name: 'fcose',
    quality: 'default',
    randomize: true,
    animate: false,
    fit: true,
    padding: 30,
    idealEdgeLength: 80,
    nodeRepulsion: 8000,
    edgeElasticity: 0.45,
    gravity: 0.25,
    numIter: 2500,
  };
}
