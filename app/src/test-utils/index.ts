// test-utils/index.ts
/**
 * Test utilities barrel export
 *
 * Import all test utilities from here:
 * import { withSetup, mountWithRouter, bootstrapStubs, expectNoA11yViolations } from '@/test-utils';
 */

export { withSetup } from './with-setup';
export {
  createTestRouter,
  mountWithRouter,
  mountWithStore,
  mountWithPlugins,
  bootstrapStubs,
} from './mount-helpers';

// Accessibility testing helpers
export {
  expectNoA11yViolations,
  runAxe,
  logViolations,
  defaultAxeConfig,
} from './a11y-helpers';

// Re-export common testing utilities for convenience
export { mount, shallowMount } from '@vue/test-utils';
export { render, screen, fireEvent, waitFor } from '@testing-library/vue';
export { default as userEvent } from '@testing-library/user-event';
