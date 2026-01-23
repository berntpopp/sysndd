// Footer.spec.ts
/**
 * Tests for Footer component
 *
 * Pattern: Component with async/lazy-loaded children
 * This component uses defineAsyncComponent for FooterNavItem.
 *
 * Demonstrates:
 * - Testing components with async children
 * - Stubbing async components
 * - Testing data from imported constants
 * - Using flushPromises to wait for async resolution
 *
 * Note: Footer imports constants and uses defineAsyncComponent to lazy-load
 * FooterNavItem. We stub the async component and mock the constants module.
 */

import { describe, it, expect, vi } from 'vitest';
import { shallowMount, flushPromises } from '@vue/test-utils';
import Footer from './Footer.vue';

// Mock the footer nav constants module
vi.mock('@/assets/js/constants/footer_nav_constants', () => ({
  default: {
    NAV_ITEMS: [
      {
        id: 'test-item-1',
        link: 'https://example1.com',
        linkAttr: { 'aria-label': 'test-link-1' },
        imgSrc: '/test-image-1.png',
        alt: 'Test Image 1',
        width: '80',
        target: '_blank',
      },
      {
        id: 'test-item-2',
        link: 'https://example2.com',
        linkAttr: { 'aria-label': 'test-link-2' },
        imgSrc: '/test-image-2.png',
        alt: 'Test Image 2',
        width: '100',
        target: '_self',
      },
      {
        id: 'test-item-3',
        link: 'https://example3.com',
        linkAttr: {},
        imgSrc: '/test-image-3.svg',
        alt: 'Test Image 3',
        width: '120',
        target: '_blank',
      },
    ],
  },
}));

describe('Footer', () => {
  /**
   * Helper function to mount the component with stubs
   * We stub all Bootstrap-Vue-Next components and the async FooterNavItem
   */
  const mountComponent = async () => {
    const wrapper = shallowMount(Footer, {
      global: {
        stubs: {
          // Stub Bootstrap-Vue-Next components
          BNavbar: true,
          BNavbarToggle: true,
          BNavbarNav: true,
          BCollapse: true,
          // Stub the async FooterNavItem component with a simple implementation
          FooterNavItem: {
            name: 'FooterNavItem',
            props: ['item'],
            template: '<div class="footer-nav-item-stub" :data-id="item.id">{{ item.alt }}</div>',
          },
        },
      },
    });

    // Wait for async components to resolve
    await flushPromises();

    return wrapper;
  };

  // ---------------------------------------------------------------------------
  // Component initialization tests
  // ---------------------------------------------------------------------------
  describe('initialization', () => {
    it('loads footer items from constants', async () => {
      const wrapper = await mountComponent();

      // Component data should be populated from constants
      expect(wrapper.vm.footerItems).toBeDefined();
      expect(wrapper.vm.footerItems).toHaveLength(3);
    });

    it('has correct item structure from constants', async () => {
      const wrapper = await mountComponent();

      const firstItem = wrapper.vm.footerItems[0];
      expect(firstItem.id).toBe('test-item-1');
      expect(firstItem.link).toBe('https://example1.com');
      expect(firstItem.alt).toBe('Test Image 1');
    });
  });

  // ---------------------------------------------------------------------------
  // Structure tests
  // ---------------------------------------------------------------------------
  describe('structure', () => {
    it('renders footer wrapper div', async () => {
      const wrapper = await mountComponent();

      expect(wrapper.find('.footer').exists()).toBe(true);
    });

    it('renders Bootstrap navbar component', async () => {
      const wrapper = await mountComponent();

      // Check for navbar stub in rendered HTML
      const html = wrapper.html();
      expect(html).toContain('bnavbar');
    });

    it('renders navbar toggle for mobile responsiveness', async () => {
      const wrapper = await mountComponent();

      const html = wrapper.html();
      expect(html).toContain('bnavbartoggle');
    });

    it('renders collapse container for nav items', async () => {
      const wrapper = await mountComponent();

      const html = wrapper.html();
      expect(html).toContain('bcollapse');
    });
  });

  // ---------------------------------------------------------------------------
  // Footer items data tests
  // ---------------------------------------------------------------------------
  describe('footer items', () => {
    it('has correct number of footer items from constants', async () => {
      const wrapper = await mountComponent();

      // Verify the component's data matches mocked constants
      expect(wrapper.vm.footerItems).toHaveLength(3);
    });

    it('footer items have required properties', async () => {
      const wrapper = await mountComponent();

      const items = wrapper.vm.footerItems;
      items.forEach((item: Record<string, unknown>) => {
        expect(item).toHaveProperty('id');
        expect(item).toHaveProperty('link');
        expect(item).toHaveProperty('imgSrc');
        expect(item).toHaveProperty('alt');
        expect(item).toHaveProperty('width');
        expect(item).toHaveProperty('target');
      });
    });

    it('footer items have correct values from mock', async () => {
      const wrapper = await mountComponent();

      const items = wrapper.vm.footerItems;
      expect(items[0].id).toBe('test-item-1');
      expect(items[1].id).toBe('test-item-2');
      expect(items[2].id).toBe('test-item-3');
    });
  });

  // ---------------------------------------------------------------------------
  // Styling tests
  // ---------------------------------------------------------------------------
  describe('styling', () => {
    it('applies bg-footer class for gradient background', async () => {
      const wrapper = await mountComponent();

      expect(wrapper.find('.bg-footer').exists()).toBe(true);
    });

    it('uses fixed bottom positioning', async () => {
      const wrapper = await mountComponent();

      // Check that fixed="bottom" is passed to navbar
      const html = wrapper.html();
      expect(html).toContain('fixed="bottom"');
    });

    it('uses light variant for navbar', async () => {
      const wrapper = await mountComponent();

      const html = wrapper.html();
      expect(html).toContain('type="light"');
      expect(html).toContain('variant="light"');
    });
  });

  // ---------------------------------------------------------------------------
  // Navbar configuration tests
  // ---------------------------------------------------------------------------
  describe('navbar configuration', () => {
    it('sets toggleable="sm" for small screen toggle', async () => {
      const wrapper = await mountComponent();

      const html = wrapper.html();
      expect(html).toContain('toggleable="sm"');
    });

    it('has collapse target for toggle button', async () => {
      const wrapper = await mountComponent();

      const html = wrapper.html();
      expect(html).toContain('target="footer-collapse"');
      expect(html).toContain('id="footer-collapse"');
    });

    it('applies is-nav attribute for semantic navigation', async () => {
      const wrapper = await mountComponent();

      const html = wrapper.html();
      expect(html).toContain('is-nav');
    });
  });

  // ---------------------------------------------------------------------------
  // v-for key binding tests
  // ---------------------------------------------------------------------------
  describe('key binding', () => {
    it('uses unique ids from constants for v-for keys', async () => {
      const wrapper = await mountComponent();

      // The v-for uses :key="index.id" - verify items have unique IDs
      const items = wrapper.vm.footerItems;
      const ids = items.map((item: Record<string, unknown>) => item.id);
      const uniqueIds = [...new Set(ids)];

      // Each item should have a unique ID
      expect(uniqueIds.length).toBe(ids.length);
      expect(ids).toHaveLength(3);
    });
  });
});
