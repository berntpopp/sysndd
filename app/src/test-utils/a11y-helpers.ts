// test-utils/a11y-helpers.ts
/// <reference types="vitest-axe/extend-expect" />
/**
 * Accessibility testing helpers for WCAG 2.2 compliance.
 *
 * Uses axe-core via vitest-axe to detect accessibility violations.
 * axe-core can automatically detect ~57% of WCAG issues.
 *
 * @example
 * import { expectNoA11yViolations } from '@/test-utils';
 * import { mount } from '@vue/test-utils';
 *
 * it('has no accessibility violations', async () => {
 *   const wrapper = mount(MyComponent);
 *   await expectNoA11yViolations(wrapper.element);
 * });
 */

import { axe } from 'vitest-axe';
import { expect } from 'vitest';
import type { AxeResults, RunOptions } from 'axe-core';

/**
 * Default axe configuration for WCAG 2.2 AA testing
 */
export const defaultAxeConfig: RunOptions = {
  rules: {
    // WCAG 2.2 AA rules - customize as needed
    // Most rules are enabled by default in axe-core
  },
};

/**
 * Run accessibility checks and assert no violations.
 *
 * @param element - DOM element to test
 * @param options - Optional axe configuration
 * @throws If accessibility violations are found
 *
 * @example
 * // Basic usage
 * await expectNoA11yViolations(wrapper.element);
 *
 * // With custom options
 * await expectNoA11yViolations(wrapper.element, {
 *   rules: { 'color-contrast': { enabled: false } }
 * });
 */
export async function expectNoA11yViolations(
  element: Element,
  options?: RunOptions
): Promise<void> {
  const config = { ...defaultAxeConfig, ...options };
  const results = await axe(element, config);
  // Type assertion for vitest-axe matcher (extended in vitest.setup.ts)
  (expect(results) as unknown as { toHaveNoViolations: () => void }).toHaveNoViolations();
}

/**
 * Run accessibility checks and return detailed results.
 * Use when you need to inspect violations without asserting.
 *
 * @param element - DOM element to test
 * @param options - Optional axe configuration
 * @returns axe-core results object
 */
export async function runAxe(element: Element, options?: RunOptions): Promise<AxeResults> {
  const config = { ...defaultAxeConfig, ...options };
  return axe(element, config);
}

/**
 * Log accessibility violations in a readable format.
 * Useful for debugging failing accessibility tests.
 *
 * @param results - axe-core results object
 */
export function logViolations(results: AxeResults): void {
  if (results.violations.length === 0) {
    console.log('No accessibility violations found');
    return;
  }

  console.log(`Found ${results.violations.length} accessibility violations:`);
  results.violations.forEach((violation, index) => {
    console.log(`\n${index + 1}. ${violation.id}: ${violation.description}`);
    console.log(`   Impact: ${violation.impact}`);
    console.log(`   WCAG: ${violation.tags.filter((t) => t.startsWith('wcag')).join(', ')}`);
    console.log(`   Help: ${violation.helpUrl}`);
    console.log(`   Affected elements:`);
    violation.nodes.forEach((node) => {
      console.log(`     - ${node.target}`);
    });
  });
}

export default {
  expectNoA11yViolations,
  runAxe,
  logViolations,
  defaultAxeConfig,
};
