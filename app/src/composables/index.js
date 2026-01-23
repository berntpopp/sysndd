// composables/index.js

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
export { default as useToastNotifications } from './useToastNotifications.js';
export { default as useToast } from './useToast.js';

// Modal controls
export { default as useModalControls } from './useModalControls.js';

// Style and symbol mappings
export { default as useColorAndSymbols } from './useColorAndSymbols.js';

// Text label mappings
export { default as useText } from './useText.js';

// Scrollbar utilities
export { default as useScrollbar } from './useScrollbar.js';

// URL parsing utilities
export { default as useUrlParsing } from './useUrlParsing.js';
