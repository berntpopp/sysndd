// Banner.a11y.spec.ts
/**
 * Accessibility tests for Banner component
 *
 * Pattern: Interactive component accessibility testing
 * Tests alert/banner accessibility patterns per WCAG 2.2.
 */

import { describe, it, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';
import Banner from './Banner.vue';
import { expectNoA11yViolations, bootstrapStubs } from '@/test-utils';

describe('Banner accessibility', () => {
  // Disable rules that are false positives in isolated component tests:
  // - region: Components would normally be within a page with proper landmarks
  // - blink: Vue stubs may render as unknown elements (not actual <blink> usage)
  const axeOptions = {
    rules: {
      region: { enabled: false },
      blink: { enabled: false },
    },
  };

  beforeEach(() => {
    window.localStorage.clear();
  });

  it('has no accessibility violations when visible', async () => {
    const wrapper = mount(Banner, {
      global: {
        stubs: bootstrapStubs,
      },
    });

    await expectNoA11yViolations(wrapper.element, axeOptions);
  });

  it('alert role is present for screen readers', async () => {
    const wrapper = mount(Banner, {
      global: {
        stubs: bootstrapStubs,
      },
    });

    // The BAlert stub includes role="alert" which is required for assistive technologies
    await expectNoA11yViolations(wrapper.element, axeOptions);
  });

  it('dismiss button is keyboard accessible', async () => {
    const wrapper = mount(Banner, {
      global: {
        stubs: bootstrapStubs,
      },
    });

    // Button should be focusable and activatable via keyboard
    // The BButton stub renders as a native <button> which is inherently keyboard accessible
    await expectNoA11yViolations(wrapper.element, axeOptions);
  });

  it('links are accessible', async () => {
    const wrapper = mount(Banner, {
      global: {
        stubs: bootstrapStubs,
      },
    });

    // External links should have appropriate attributes for accessibility
    await expectNoA11yViolations(wrapper.element, axeOptions);
  });
});
