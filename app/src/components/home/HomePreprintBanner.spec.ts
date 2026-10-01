// HomePreprintBanner.spec.ts
/**
 * Tests for the home-page preprint announcement strip.
 *
 * The banner uses plain anchors/buttons (no Bootstrap-Vue-Next components), so it
 * is fully mounted without stubs.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import HomePreprintBanner from './HomePreprintBanner.vue';
import { expectNoA11yViolations } from '@/test-utils';
import {
  SYSNDD_PREPRINT,
  PREPRINT_BANNER_STORAGE_KEY,
  formatPreprintCitation,
} from '@/constants/publication';

describe('HomePreprintBanner', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it('renders the preprint label, title, and DOI', () => {
    const wrapper = mount(HomePreprintBanner);

    expect(wrapper.find('[data-testid="preprint-banner"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('Preprint');
    expect(wrapper.text()).toContain(SYSNDD_PREPRINT.title);
    expect(wrapper.text()).toContain(SYSNDD_PREPRINT.doi);
  });

  it('links to the preprint in a new tab without leaking the opener', () => {
    const wrapper = mount(HomePreprintBanner);
    const link = wrapper.get('[data-testid="preprint-banner-link"]');

    expect(link.attributes('href')).toBe(SYSNDD_PREPRINT.url);
    expect(link.attributes('target')).toBe('_blank');
    expect(link.attributes('rel')).toContain('noopener');
  });

  it('is a labelled complementary landmark, not an alert', () => {
    const wrapper = mount(HomePreprintBanner);
    const root = wrapper.get('[data-testid="preprint-banner"]');

    expect(root.element.tagName).toBe('ASIDE');
    expect(root.attributes('aria-label')).toBeTruthy();
    expect(root.attributes('role')).toBeUndefined();
  });

  it('copies the formatted citation and confirms it', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true });

    const wrapper = mount(HomePreprintBanner);
    const button = wrapper.get('[data-testid="preprint-banner-copy"]');
    await button.trigger('click');
    await flushPromises();

    expect(writeText).toHaveBeenCalledWith(formatPreprintCitation(SYSNDD_PREPRINT));
    expect(button.text()).toContain('Copied');
  });

  it('reports a failed copy instead of claiming success', async () => {
    const writeText = vi.fn().mockRejectedValue(new Error('denied'));
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true });

    const wrapper = mount(HomePreprintBanner);
    const button = wrapper.get('[data-testid="preprint-banner-copy"]');
    await button.trigger('click');
    await flushPromises();

    expect(button.text()).toContain('Copy failed');
  });

  it('dismisses and remembers the dismissal for this DOI', async () => {
    const wrapper = mount(HomePreprintBanner);
    await wrapper.get('[data-testid="preprint-banner-dismiss"]').trigger('click');

    expect(wrapper.find('[data-testid="preprint-banner"]').exists()).toBe(false);
    expect(window.localStorage.getItem(PREPRINT_BANNER_STORAGE_KEY)).toBe(SYSNDD_PREPRINT.doi);

    const remounted = mount(HomePreprintBanner);
    expect(remounted.find('[data-testid="preprint-banner"]').exists()).toBe(false);
  });

  it('shows again when a different publication was dismissed earlier', () => {
    window.localStorage.setItem(PREPRINT_BANNER_STORAGE_KEY, '10.0000/some-older-announcement');

    const wrapper = mount(HomePreprintBanner);
    expect(wrapper.find('[data-testid="preprint-banner"]').exists()).toBe(true);
  });

  it('has no accessibility violations', async () => {
    const wrapper = mount(HomePreprintBanner);
    await expectNoA11yViolations(wrapper.element);
  });
});

describe('formatPreprintCitation', () => {
  it('produces a citable string with authors, title, server, and DOI', () => {
    const citation = formatPreprintCitation(SYSNDD_PREPRINT);

    expect(citation).toContain('Popp B');
    expect(citation).toContain('Zweier C');
    expect(citation).toContain(SYSNDD_PREPRINT.title);
    expect(citation).toContain('bioRxiv [Preprint]');
    expect(citation).toContain(`doi: ${SYSNDD_PREPRINT.doi}`);
  });
});
