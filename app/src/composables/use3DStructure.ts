// composables/use3DStructure.ts

/**
 * Composable for NGL Viewer lifecycle management
 *
 * Provides a Vue 3 composable that handles NGL Stage initialization,
 * AlphaFold structure loading, representation toggling, variant marker management,
 * and proper cleanup to prevent WebGL context leaks.
 *
 * CRITICAL: NGL Stage instance is stored in a non-reactive variable (let stage)
 * to avoid Vue reactivity triggering performance issues with WebGL objects.
 * All NGL representations are wrapped in markRaw() before storage.
 *
 * CRITICAL: Always calls stage.dispose() in onBeforeUnmount to prevent
 * WebGL context leaks. Browsers limit to 8-16 WebGL contexts per origin.
 * Without dispose(), navigating 16 gene pages crashes with "Exceeded WebGL context limit".
 *
 * Pattern: Follows useCytoscape.ts non-reactive pattern for WebGL library integration.
 *
 * @returns NGL control functions and state
 */

import { ref, watch, onBeforeUnmount, markRaw, readonly, type Ref } from 'vue';
import * as NGL from 'ngl';
import type { RepresentationType } from '@/types/alphafold';

/**
 * State and controls returned by the composable
 */
export interface Use3DStructureReturn {
  /** Whether the NGL Stage is initialized */
  isInitialized: Readonly<Ref<boolean>>;
  /** Whether a structure is currently loading */
  isLoading: Readonly<Ref<boolean>>;
  /** Error message if operation failed, null otherwise */
  error: Readonly<Ref<string | null>>;
  /** Active representation type (cartoon/surface/ball+stick) */
  activeRepresentation: Readonly<Ref<RepresentationType>>;
  /** Load AlphaFold structure from URL (PDB or CIF format) */
  loadStructure: (url: string) => Promise<void>;
  /** Add variant marker at residue position (ACMG-colored sphere) */
  addVariantMarker: (residue: number, color: string, label: string) => void;
  /** Remove variant marker at residue position */
  removeVariantMarker: (residue: number) => void;
  /** Remove all variant markers */
  clearAllVariantMarkers: () => void;
  /** Switch between cartoon/surface/ball+stick representations */
  setRepresentation: (type: RepresentationType) => void;
  /** Reset view to default orientation (auto-center and zoom) */
  resetView: () => void;
  /** Cleanup Stage and release WebGL context */
  cleanup: () => void;
}

/**
 * Composable for managing NGL Stage lifecycle
 *
 * @param containerRef - Ref to the container HTML element
 * @returns State and control functions for the NGL Stage instance
 *
 * @example
 * ```typescript
 * const viewerContainer = ref<HTMLElement | null>(null);
 *
 * const {
 *   isInitialized,
 *   loadStructure,
 *   addVariantMarker,
 *   setRepresentation,
 * } = use3DStructure(viewerContainer);
 *
 * watch(metadata, (newMeta) => {
 *   if (newMeta?.pdb_url) {
 *     loadStructure(newMeta.pdb_url);
 *   }
 * });
 * ```
 */
export function use3DStructure(
  containerRef: Ref<HTMLElement | null>
): Use3DStructureReturn {
  // CRITICAL: Store NGL instances in non-reactive variables
  // Using ref() would cause Vue reactivity to trigger performance issues
  // with WebGL objects (frozen UI, 100+ layout recalculations)
  // NGL v2.4.0 TypeScript typings are incomplete, so use any for Component
  let stage: InstanceType<typeof NGL.Stage> | null = null;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let structureComponent: any = null; // NGL.Component (untyped in v2.4.0)

  // Representation references for visibility toggle (Map is non-reactive)
  // Each NGL representation is wrapped in markRaw before storage
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const representations = new Map<string, any>();

  // Reactive state for UI binding (only UI-facing state is reactive)
  const isInitialized = ref(false);
  const isLoading = ref(false);
  const error = ref<string | null>(null);
  const activeRepresentation = ref<RepresentationType>('cartoon');

  /**
   * Handle window resize - updates Stage viewport
   */
  function handleResize(): void {
    if (stage) {
      stage.handleResize();
    }
  }

  /**
   * Initialize NGL Stage (private, called from container watch)
   */
  function initStage(): void {
    if (!containerRef.value) {
      console.warn('use3DStructure: container element not available');
      return;
    }

    // Clean up existing instance first
    if (stage) {
      stage.dispose();
      stage = null;
    }

    stage = new NGL.Stage(containerRef.value, {
      backgroundColor: 'white',
      tooltip: false, // Disable NGL's built-in tooltip (has broken dimensions)
    });

    // Handle window resize
    window.addEventListener('resize', handleResize);

    // CRITICAL: In flexbox layouts and Vue's lazy tab rendering, the container
    // may not have final dimensions at Stage creation time. A single rAF is not
    // enough because CSS layout may take multiple frames to settle.
    // Use a short timeout after rAF to ensure layout is complete.
    // See: https://github.com/nglviewer/ngl/issues/890
    requestAnimationFrame(() => {
      // First resize attempt after initial layout
      if (stage) {
        stage.handleResize();
      }
      // Second resize after CSS fully settles (handles lazy tabs, transitions)
      setTimeout(() => {
        if (stage) {
          stage.handleResize();
        }
      }, 100);
    });

    isInitialized.value = true;
  }

  /**
   * Load AlphaFold structure from URL (PDB or CIF format)
   *
   * NGL auto-detects file format from URL extension.
   * Default: cartoon with pLDDT confidence coloring (bfactor colorScheme).
   * Pre-creates surface and ball+stick representations (hidden) for instant toggle.
   *
   * @param url - URL to structure file (PDB or CIF format)
   */
  async function loadStructure(url: string): Promise<void> {
    if (!stage) {
      error.value = 'Viewer not initialized';
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      // Remove previous structure
      if (structureComponent) {
        stage.removeAllComponents();
        representations.clear();
        structureComponent = null;
      }

      // Load structure file (NGL auto-detects PDB/CIF from URL extension)
      structureComponent = await stage.loadFile(url);

      // Default: cartoon with pLDDT confidence coloring (STRUCT3D-01)
      // AlphaFold stores pLDDT in b-factor column -- NGL's bfactor colorScheme
      // auto-maps to blue-cyan-yellow-orange gradient matching AlphaFold DB convention
      const cartoonRepr = structureComponent.addRepresentation('cartoon', {
        colorScheme: 'bfactor',
      });
      representations.set('cartoon', markRaw(cartoonRepr));

      // Pre-create surface and ball+stick (hidden) for instant toggle (STRUCT3D-02)
      // Using setVisibility is faster than remove+add (avoids geometry re-parsing)
      const surfaceRepr = structureComponent.addRepresentation('surface', {
        colorScheme: 'bfactor',
        visible: false,
      });
      representations.set('surface', markRaw(surfaceRepr));

      const ballStickRepr = structureComponent.addRepresentation('ball+stick', {
        colorScheme: 'bfactor',
        visible: false,
      });
      representations.set('ball+stick', markRaw(ballStickRepr));

      activeRepresentation.value = 'cartoon';

      // Auto-center and zoom to fit structure (STRUCT3D-05 default view)
      structureComponent.autoView();

      // Force resize after structure load to ensure canvas fills container
      // This handles cases where container dimensions changed during load
      if (stage) {
        stage.handleResize();
      }
    } catch (err) {
      console.error('use3DStructure: Failed to load structure:', err);
      error.value = 'Failed to load 3D structure. Please try again.';
      throw err;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Switch between cartoon/surface/ball+stick representations (STRUCT3D-02)
   *
   * Uses setVisibility() for instant toggle (faster than remove+add which re-parses geometry).
   *
   * @param type - Representation type to activate
   */
  function setRepresentation(type: RepresentationType): void {
    if (!structureComponent) return;

    // Hide all base representations
    const baseTypes: RepresentationType[] = ['cartoon', 'surface', 'ball+stick'];
    baseTypes.forEach((name) => {
      const repr = representations.get(name);
      if (repr) {
        repr.setVisibility(name === type);
      }
    });

    activeRepresentation.value = type;
  }

  /**
   * Add variant marker at residue position (STRUCT3D-03)
   *
   * Creates an ACMG-colored spacefill representation (enlarged sphere) at the residue position.
   * If a marker already exists at this position, it is removed first (toggle behavior).
   *
   * @param residue - Residue number (1-indexed)
   * @param color - Hex color (e.g., ACMG_COLORS.pathogenic)
   * @param label - Variant label for identification (e.g., "p.Arg123Trp")
   */
  function addVariantMarker(residue: number, color: string, label: string): void {
    if (!structureComponent) return;

    const key = `variant-${residue}`;

    // Remove existing marker for this residue (toggle off/on)
    if (representations.has(key)) {
      removeVariantMarker(residue);
    }

    // Add spacefill representation at residue position (ACMG-colored sphere)
    const variantRepr = structureComponent.addRepresentation('spacefill', {
      sele: `${residue}`,       // NGL residue selection language
      color: color,              // ACMG hex color from ACMG_COLORS
      radius: 2.0,              // Enlarged sphere for visibility
      name: label,              // Variant label for identification
    });

    representations.set(key, markRaw(variantRepr));
  }

  /**
   * Remove variant marker at residue position
   *
   * @param residue - Residue number (1-indexed)
   */
  function removeVariantMarker(residue: number): void {
    const key = `variant-${residue}`;
    const repr = representations.get(key);
    if (repr && structureComponent) {
      structureComponent.removeRepresentation(repr);
      representations.delete(key);
    }
  }

  /**
   * Remove all variant markers
   */
  function clearAllVariantMarkers(): void {
    if (!structureComponent) return;

    // Remove all variant-* representations
    for (const [key, repr] of representations.entries()) {
      if (key.startsWith('variant-')) {
        structureComponent.removeRepresentation(repr);
        representations.delete(key);
      }
    }
  }

  /**
   * Reset view to default orientation (STRUCT3D-06)
   *
   * Auto-centers and zooms to fit the entire structure.
   */
  function resetView(): void {
    if (structureComponent) {
      structureComponent.autoView();
    }
  }

  /**
   * Cleanup Stage and release WebGL context (STRUCT3D-08)
   *
   * CRITICAL: Must be called before component unmount to prevent WebGL context leak.
   * Browsers limit to 8-16 WebGL contexts per origin.
   */
  function cleanup(): void {
    window.removeEventListener('resize', handleResize);

    if (stage) {
      stage.dispose();  // CRITICAL: Releases WebGL context
      stage = null;
    }

    structureComponent = null;
    representations.clear();
    isInitialized.value = false;
    isLoading.value = false;
    error.value = null;
  }

  // CRITICAL: Cleanup prevents WebGL context leak
  // Browsers limit to 8-16 WebGL contexts per origin
  // Without dispose(), navigating 16 gene pages crashes with "Exceeded WebGL context limit"
  onBeforeUnmount(() => {
    cleanup();
  });

  // Initialize Stage when container becomes available (lazy tab mount)
  // Bootstrap Vue Next <BTab lazy> mounts content asynchronously
  // onMounted may fire before container ref is populated
  watch(containerRef, (newVal) => {
    if (newVal && !isInitialized.value) {
      initStage();
    }
  }, { immediate: true });

  return {
    isInitialized: readonly(isInitialized),
    isLoading: readonly(isLoading),
    error: readonly(error),
    activeRepresentation: readonly(activeRepresentation),
    loadStructure,
    addVariantMarker,
    removeVariantMarker,
    clearAllVariantMarkers,
    setRepresentation,
    resetView,
    cleanup,
  };
}

export default use3DStructure;
