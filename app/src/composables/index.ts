// composables/index.ts

/**
 * Barrel export for all composables
 *
 * Provides a single import point for all composables used throughout the application.
 * This pattern simplifies imports and makes it easier to manage composable dependencies.
 *
 * Usage:
 *   import { useToastNotifications, useColorAndSymbols } from '@/composables'
 */

// Toast notifications
export { default as useToastNotifications } from './useToastNotifications';
export { default as useToast } from './useToast';

// Modal controls
export { default as useModalControls } from './useModalControls';

// Style and symbol mappings
export { default as useColorAndSymbols } from './useColorAndSymbols';

// Text label mappings
export { default as useText } from './useText';

// Scrollbar utilities
export { default as useScrollbar } from './useScrollbar';

// URL parsing utilities
export { default as useUrlParsing } from './useUrlParsing';

// Table state management
export { default as useTableData } from './useTableData';
export { default as useTableMethods } from './useTableMethods';

// Entity form management
export { default as useEntityForm } from './useEntityForm';
export type {
  EntityFormData,
  GeneSearchResult,
  OntologySearchResult,
  SelectOption,
  StepValidation,
  WizardStep,
} from './useEntityForm';

// Form draft/auto-save utilities
export { default as useFormDraft } from './useFormDraft';

// Network visualization composables (Cytoscape.js integration)
export { default as useCytoscape } from './useCytoscape';
export type { CytoscapeOptions, CytoscapeState } from './useCytoscape';
export { usePhenotypeCytoscape } from './usePhenotypeCytoscape';
export type { PhenotypeCluster, PhenotypeCytoscapeOptions } from './usePhenotypeCytoscape';
export { default as useNetworkData } from './useNetworkData';
export type { NetworkDataState } from './useNetworkData';
export { default as useNetworkFilters } from './useNetworkFilters';
export type { CategoryFilter, NetworkFiltersState } from './useNetworkFilters';

// Filter and search utilities
export { useFilterSync, resetFilterSyncInstance } from './useFilterSync';
export type { FilterState, AnalysisTab, FilterSyncReturn } from './useFilterSync';

// Wildcard search
export { useWildcardSearch } from './useWildcardSearch';
export type { GeneWithSymbol, WildcardSearchReturn } from './useWildcardSearch';

// Network highlighting (bidirectional table-network hover)
export { useNetworkHighlight } from './useNetworkHighlight';
export type { HighlightState, HoverSource, NetworkHighlightReturn } from './useNetworkHighlight';

// Excel export utilities
export { useExcelExport } from './useExcelExport';
export type { ExcelExportOptions, UseExcelExportReturn } from './useExcelExport';

// Bulk selection for admin tables
export { useBulkSelection } from './useBulkSelection';
export type { BulkSelectionReturn } from './useBulkSelection';

// Filter presets for admin tables
export { useFilterPresets } from './useFilterPresets';
export type { FilterPreset, FilterPresetsReturn } from './useFilterPresets';

// CMS content management
export { useMarkdownRenderer, renderMarkdown } from './useMarkdownRenderer';
export { useCmsContent } from './useCmsContent';

// Async job management
export { default as useAsyncJob } from './useAsyncJob';
export type {
  JobProgress,
  JobStatus,
  UseAsyncJobOptions,
  UseAsyncJobReturn,
} from './useAsyncJob';

// Tree search and hierarchy utilities
export { useTreeSearch } from './useTreeSearch';
export type { TreeNode } from './useTreeSearch';
export { useHierarchyPath } from './useHierarchyPath';

// Accessibility - ARIA live region announcements
export { useAriaLive } from './useAriaLive';
export type { UseAriaLiveReturn } from './useAriaLive';

// Search suggestions
export { useSearchSuggestions } from './useSearchSuggestions';
export type { SearchSuggestion, UseSearchSuggestionsReturn } from './useSearchSuggestions';
