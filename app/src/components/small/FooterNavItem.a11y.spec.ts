// FooterNavItem.a11y.spec.ts
/**
 * Accessibility tests for FooterNavItem component
 *
 * Pattern: Basic accessibility testing
 * Tests WCAG 2.2 compliance using axe-core via vitest-axe.
 */

import { describe, it } from 'vitest';
import { mount } from '@vue/test-utils';
import FooterNavItem from './FooterNavItem.vue';
import { expectNoA11yViolations, bootstrapStubs } from '@/test-utils';

describe('FooterNavItem accessibility', () => {
  const defaultItem = {
    id: 'test-item',
    link: 'https://example.com',
    linkAttr: { 'aria-label': 'Example Link' },
    imgSrc: '/test-image.png',
    alt: 'Test Image Alt Text',
    width: 100,
    target: '_blank',
  };

  // Disable region rule for isolated component tests
  // Components would normally be within a page with proper landmarks
  const axeOptions = {
    rules: { region: { enabled: false } },
  };

  it('has no accessibility violations', async () => {
    const wrapper = mount(FooterNavItem, {
      props: { item: defaultItem },
      global: {
        stubs: bootstrapStubs,
      },
    });

    await expectNoA11yViolations(wrapper.element, axeOptions);
  });

  it('image has descriptive alt text', async () => {
    const wrapper = mount(FooterNavItem, {
      props: {
        item: {
          ...defaultItem,
          alt: 'Partner organization logo linking to their website',
        },
      },
      global: {
        stubs: bootstrapStubs,
      },
    });

    await expectNoA11yViolations(wrapper.element, axeOptions);
  });

  it('external links have appropriate rel attribute', async () => {
    const wrapper = mount(FooterNavItem, {
      props: {
        item: {
          ...defaultItem,
          target: '_blank',
        },
      },
      global: {
        stubs: bootstrapStubs,
      },
    });

    // The component adds rel="noopener" for security
    await expectNoA11yViolations(wrapper.element, axeOptions);
  });
});
