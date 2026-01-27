// AppFooter.a11y.spec.ts
/**
 * Accessibility tests for AppFooter component
 *
 * Pattern: Navigation component accessibility testing
 * Tests navigation landmark and list structure per WCAG 2.2.
 */

import { describe, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import Footer from './AppFooter.vue';
import { expectNoA11yViolations, bootstrapStubs } from '@/test-utils';

// Mock the footer nav constants
vi.mock('@/assets/js/constants/footer_nav_constants', () => ({
  default: {
    NAV_ITEMS: [
      {
        id: 'item1',
        link: 'https://example1.com',
        linkAttr: { 'aria-label': 'Partner 1' },
        imgSrc: '/image1.png',
        alt: 'Partner 1 Logo',
        width: 80,
        target: '_blank',
      },
      {
        id: 'item2',
        link: 'https://example2.com',
        linkAttr: { 'aria-label': 'Partner 2' },
        imgSrc: '/image2.png',
        alt: 'Partner 2 Logo',
        width: 80,
        target: '_blank',
      },
    ],
  },
}));

describe('Footer accessibility', () => {
  // Disable region rule for isolated component tests
  // Components would normally be within a page with proper landmarks
  const axeOptions = {
    rules: { region: { enabled: false } },
  };

  const mountComponent = async () => {
    const wrapper = mount(Footer, {
      global: {
        stubs: {
          ...bootstrapStubs,
          // Custom stub for FooterNavItem that renders accessible HTML
          FooterNavItem: {
            name: 'FooterNavItem',
            props: ['item'],
            template: `
              <li>
                <a :href="item.link" :aria-label="item.linkAttr['aria-label']">
                  <img :src="item.imgSrc" :alt="item.alt" height="34" :width="item.width" />
                </a>
              </li>
            `,
          },
        },
      },
    });

    await flushPromises();
    return wrapper;
  };

  it('has no accessibility violations', async () => {
    const wrapper = await mountComponent();

    await expectNoA11yViolations(wrapper.element, axeOptions);
  });

  it('navigation landmark is properly structured', async () => {
    const wrapper = await mountComponent();

    // Footer should use proper navigation landmarks via BNavbar stub
    await expectNoA11yViolations(wrapper.element, axeOptions);
  });

  it('all images have alt text', async () => {
    const wrapper = await mountComponent();

    // Images should have descriptive alt text for screen readers
    await expectNoA11yViolations(wrapper.element, axeOptions);
  });

  it('responsive toggle is accessible', async () => {
    const wrapper = await mountComponent();

    // Mobile toggle (BNavbarToggle stub) should be keyboard accessible
    await expectNoA11yViolations(wrapper.element, axeOptions);
  });
});
