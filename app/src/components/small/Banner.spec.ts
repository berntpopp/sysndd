// Banner.spec.ts
/**
 * Tests for Banner component
 *
 * Pattern: Interactive component testing with localStorage
 * This component shows a dismissible banner that remembers user's choice.
 *
 * Demonstrates:
 * - Testing visibility conditions based on component state
 * - Testing user interactions via component methods
 * - Testing localStorage integration (mocked in vitest.setup.ts)
 * - Testing component state changes
 *
 * Note: This component uses Bootstrap-Vue-Next components which are globally
 * registered. We use shallowMount with explicit stubs to isolate the component.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { shallowMount } from '@vue/test-utils';
import Banner from './Banner.vue';

describe('Banner', () => {
  // localStorage is mocked in vitest.setup.ts and cleared between tests
  beforeEach(() => {
    window.localStorage.clear();
  });

  /**
   * Helper function to mount the component with explicit stubs
   * We stub Bootstrap-Vue-Next components to isolate the Banner component.
   */
  const mountComponent = () => {
    return shallowMount(Banner, {
      global: {
        stubs: {
          BAlert: true,
          BRow: true,
          BCol: true,
          BButton: true,
          BLink: true,
        },
      },
    });
  };

  // ---------------------------------------------------------------------------
  // Component state initialization tests
  // ---------------------------------------------------------------------------
  describe('initialization', () => {
    it('initializes banner_acknowledged to null when localStorage is empty', () => {
      const wrapper = mountComponent();

      // Component data should initialize from localStorage (null when empty)
      expect(wrapper.vm.banner_acknowledged).toBeNull();
    });

    it('initializes banner_acknowledged from localStorage', () => {
      window.localStorage.setItem('banner_acknowledged', 'true');

      const wrapper = mountComponent();

      // Component should read localStorage value on mount
      expect(wrapper.vm.banner_acknowledged).toBe('true');
    });
  });

  // ---------------------------------------------------------------------------
  // Visibility logic tests
  // ---------------------------------------------------------------------------
  describe('visibility', () => {
    it('renders banner content when not acknowledged', () => {
      const wrapper = mountComponent();

      // With banner_acknowledged = null (falsy), the v-if should show content
      expect(wrapper.vm.banner_acknowledged).toBeFalsy();

      // Content should be rendered
      expect(wrapper.text()).toContain('Usage policy');
      expect(wrapper.text()).toContain('Data privacy');
    });

    it('hides banner when previously acknowledged', () => {
      window.localStorage.setItem('banner_acknowledged', 'true');

      const wrapper = mountComponent();

      // With banner_acknowledged = 'true', the v-if="!banner_acknowledged" hides content
      expect(wrapper.vm.banner_acknowledged).toBeTruthy();

      // Content area should be empty or not contain main text
      // (the outer div still exists but inner content is hidden)
      expect(wrapper.text()).not.toContain('Usage policy');
    });
  });

  // ---------------------------------------------------------------------------
  // Content tests (when visible)
  // ---------------------------------------------------------------------------
  describe('content', () => {
    it('displays usage policy heading', () => {
      const wrapper = mountComponent();

      expect(wrapper.text()).toContain('Usage policy');
    });

    it('displays data privacy heading', () => {
      const wrapper = mountComponent();

      expect(wrapper.text()).toContain('Data privacy');
    });

    it('displays medical disclaimer text', () => {
      const wrapper = mountComponent();

      expect(wrapper.text()).toContain('not intended for direct diagnostic use');
    });

    it('displays genetics professional warning', () => {
      const wrapper = mountComponent();

      expect(wrapper.text()).toContain('genetics professional');
    });

    it('displays cookie policy information', () => {
      const wrapper = mountComponent();

      expect(wrapper.text()).toContain('does not use cookies');
    });

    it('displays dismiss button text', () => {
      const wrapper = mountComponent();

      expect(wrapper.text()).toContain('Dismiss');
    });
  });

  // ---------------------------------------------------------------------------
  // acknowledgeBanner method tests
  // ---------------------------------------------------------------------------
  describe('acknowledgeBanner', () => {
    it('calls localStorage.setItem when acknowledgeBanner is called', async () => {
      const wrapper = mountComponent();

      // Call the method directly
      wrapper.vm.acknowledgeBanner();

      // Verify localStorage was updated
      expect(window.localStorage.setItem).toHaveBeenCalledWith(
        'banner_acknowledged',
        true
      );
    });

    it('updates component state after acknowledgeBanner is called', async () => {
      const wrapper = mountComponent();

      // Initially not acknowledged
      expect(wrapper.vm.banner_acknowledged).toBeFalsy();

      // Call the method
      wrapper.vm.acknowledgeBanner();
      await wrapper.vm.$nextTick();

      // State should be updated (reads from localStorage after setItem)
      expect(wrapper.vm.banner_acknowledged).toBeTruthy();
    });

    it('hides banner after acknowledgement', async () => {
      const wrapper = mountComponent();

      // Initially visible
      expect(wrapper.text()).toContain('Usage policy');

      // Acknowledge
      wrapper.vm.acknowledgeBanner();
      await wrapper.vm.$nextTick();

      // Content should be hidden
      expect(wrapper.text()).not.toContain('Usage policy');
    });
  });

  // ---------------------------------------------------------------------------
  // Template structure tests
  // ---------------------------------------------------------------------------
  describe('template structure', () => {
    it('renders Bootstrap alert component', () => {
      const wrapper = mountComponent();

      // Check component exists in rendered HTML (may be stub or original component)
      // The component template uses BAlert with variant="danger"
      const html = wrapper.html();
      expect(html).toContain('variant="danger"');
    });

    it('renders Bootstrap button for dismiss', () => {
      const wrapper = mountComponent();

      // Check button configuration in rendered HTML
      const html = wrapper.html();
      expect(html).toContain('variant="outline-dark"');
      expect(html).toContain('Dismiss');
    });

    it('renders external link to legal notice', () => {
      const wrapper = mountComponent();

      // Check link configuration in rendered HTML
      const html = wrapper.html();
      expect(html).toContain('https://www.unibe.ch/legal_notice/index_eng.html');
      expect(html).toContain('target="_blank"');
    });

    it('has descriptive h6 headings', () => {
      const wrapper = mountComponent();

      const headings = wrapper.findAll('h6');
      expect(headings.length).toBe(2);
      expect(headings[0].text()).toBe('Usage policy');
      expect(headings[1].text()).toBe('Data privacy');
    });
  });
});

