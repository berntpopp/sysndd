// FooterNavItem.spec.ts
/**
 * Tests for FooterNavItem component
 *
 * Pattern: Props-based component testing
 * This component receives an item prop and renders a nav link with image.
 *
 * Demonstrates:
 * - Testing prop handling
 * - Testing computed properties (relAttribute)
 * - Testing error handling (image fallback)
 * - Using bootstrap stubs for isolation
 */

import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import FooterNavItem from './FooterNavItem.vue';
import { bootstrapStubs } from '@/test-utils';

describe('FooterNavItem', () => {
  // Default test item with all required properties
  const defaultItem = {
    id: 'test-item',
    link: 'https://example.com',
    linkAttr: { 'aria-label': 'Example Link' },
    imgSrc: '/test-image.png',
    alt: 'Test Image',
    width: 100,
    target: '_blank',
  };

  /**
   * Helper function to mount the component with bootstrap stubs
   */
  const mountComponent = (item = defaultItem) => {
    return mount(FooterNavItem, {
      props: { item },
      global: {
        stubs: bootstrapStubs,
      },
    });
  };

  // ---------------------------------------------------------------------------
  // Rendering tests
  // ---------------------------------------------------------------------------
  describe('rendering', () => {
    it('renders an image with correct src attribute', () => {
      const wrapper = mountComponent();

      const img = wrapper.find('img');
      expect(img.exists()).toBe(true);
      expect(img.attributes('src')).toBe('/test-image.png');
    });

    it('renders an image with correct alt attribute', () => {
      const wrapper = mountComponent();

      const img = wrapper.find('img');
      expect(img.attributes('alt')).toBe('Test Image');
    });

    it('renders an image with correct width attribute', () => {
      const wrapper = mountComponent();

      const img = wrapper.find('img');
      expect(img.attributes('width')).toBe('100');
    });

    it('renders an image with fixed height of 34', () => {
      const wrapper = mountComponent();

      const img = wrapper.find('img');
      expect(img.attributes('height')).toBe('34');
    });

    it('renders BNavItem wrapper for the link', () => {
      const wrapper = mountComponent();

      // BNavItem is stubbed - check that component renders its wrapper
      // The stub renders as <li> containing the slot content (img)
      expect(wrapper.html()).toContain('img');
      expect(wrapper.find('img').exists()).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // Computed property tests: relAttribute
  // ---------------------------------------------------------------------------
  describe('relAttribute computed property', () => {
    it('returns "noopener" for external links (target="_blank")', () => {
      const wrapper = mountComponent({
        ...defaultItem,
        target: '_blank',
      });

      const img = wrapper.find('img');
      expect(img.attributes('rel')).toBe('noopener');
    });

    it('returns empty string for internal links (no target)', () => {
      const wrapper = mountComponent({
        ...defaultItem,
        target: '',
      });

      const img = wrapper.find('img');
      expect(img.attributes('rel')).toBe('');
    });

    it('returns empty string for self target', () => {
      const wrapper = mountComponent({
        ...defaultItem,
        target: '_self',
      });

      const img = wrapper.find('img');
      expect(img.attributes('rel')).toBe('');
    });

    it('returns empty string for parent target', () => {
      const wrapper = mountComponent({
        ...defaultItem,
        target: '_parent',
      });

      const img = wrapper.find('img');
      expect(img.attributes('rel')).toBe('');
    });
  });

  // ---------------------------------------------------------------------------
  // Image error handling tests
  // ---------------------------------------------------------------------------
  describe('image error handling', () => {
    it('sets fallback image on error', async () => {
      const wrapper = mountComponent();
      const img = wrapper.find('img');

      // Simulate image load error
      await img.trigger('error');

      // Verify fallback image is used
      expect(img.attributes('src')).toBe(
        '/brain-neurodevelopmental-disorders-sysndd-logo.png'
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Props validation tests
  // ---------------------------------------------------------------------------
  describe('props validation', () => {
    it('accepts item prop correctly', () => {
      const wrapper = mountComponent();
      expect(wrapper.vm.item).toEqual(defaultItem);
    });

    it('renders with different item data', () => {
      const customItem = {
        id: 'custom-item',
        link: 'https://custom.example.com',
        linkAttr: {},
        imgSrc: '/custom-image.svg',
        alt: 'Custom Alt Text',
        width: 150,
        target: '_self',
      };

      const wrapper = mountComponent(customItem);
      const img = wrapper.find('img');

      expect(img.attributes('src')).toBe('/custom-image.svg');
      expect(img.attributes('alt')).toBe('Custom Alt Text');
      expect(img.attributes('width')).toBe('150');
    });
  });
});
