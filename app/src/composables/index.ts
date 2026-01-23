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
// eslint-disable-next-line import/no-cycle
export { default as useTableMethods } from './useTableMethods';
