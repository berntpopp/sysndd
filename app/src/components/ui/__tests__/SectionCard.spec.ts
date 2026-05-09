import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import SectionCard from '../SectionCard.vue';

describe('SectionCard', () => {
  it('renders skeleton stripes when loading', () => {
    const w = mount(SectionCard, {
      props: { loading: true, empty: false, error: null, title: 'X' },
    });
    expect(w.find('[data-testid="section-card-skeleton"]').exists()).toBe(true);
    expect(w.find('[data-testid="section-card-content"]').exists()).toBe(false);
  });

  it('renders nothing when empty and not loading and no error', () => {
    const w = mount(SectionCard, {
      props: { loading: false, empty: true, error: null, title: 'X' },
    });
    expect(w.find('[data-testid="section-card-skeleton"]').exists()).toBe(false);
    expect(w.find('[data-testid="section-card-content"]').exists()).toBe(false);
    expect(w.find('[data-testid="section-card-error"]').exists()).toBe(false);
  });

  it('renders the error variant when error is non-null', () => {
    const w = mount(SectionCard, {
      props: { loading: false, empty: false, error: 'boom', title: 'X' },
    });
    expect(w.find('[data-testid="section-card-error"]').exists()).toBe(true);
    expect(w.text()).toContain('boom');
  });

  it('renders the default slot when resolved', () => {
    const w = mount(SectionCard, {
      props: { loading: false, empty: false, error: null, title: 'X' },
      slots: { default: '<p>hello</p>' },
    });
    expect(w.find('[data-testid="section-card-content"]').exists()).toBe(true);
    expect(w.text()).toContain('hello');
  });

  it('renders the title prop in the default header', () => {
    const w = mount(SectionCard, {
      props: { loading: false, empty: false, error: null, title: 'My Section' },
      slots: { default: '<p>hi</p>' },
    });
    expect(w.text()).toContain('My Section');
  });

  it('uses the header slot when provided (overrides title)', () => {
    const w = mount(SectionCard, {
      props: { loading: false, empty: false, error: null, title: 'My Section' },
      slots: {
        default: '<p>hi</p>',
        header: '<h5 data-testid="custom-header">Custom!</h5>',
      },
    });
    expect(w.find('[data-testid="custom-header"]').exists()).toBe(true);
    expect(w.text()).not.toContain('My Section');
  });

  it('applies a stable minHeight during loading to avoid CLS', () => {
    const w = mount(SectionCard, {
      props: { loading: true, empty: false, error: null, title: 'X', minHeight: '12rem' },
    });
    const skel = w.find('[data-testid="section-card-skeleton"]');
    expect(skel.attributes('style')).toContain('min-height: 12rem');
  });

  it('keeps collapse behavior for empty resolved sections', () => {
    const w = mount(SectionCard, {
      props: { loading: false, empty: true, error: null, title: 'Collapsed' },
    });
    expect(w.text()).toBe('');
    expect(w.find('[data-testid="section-card-content"]').exists()).toBe(false);
    expect(w.find('[data-testid="section-card-error"]').exists()).toBe(false);
  });

  it('does not render generic wrapper titles as headings', () => {
    const w = mount(SectionCard, {
      props: { loading: false, empty: false, error: null, title: 'Associated Source' },
      slots: { default: '<p>loaded</p>' },
    });
    expect(w.find('[data-testid="section-card-title"]').exists()).toBe(true);
    expect(w.find('h1,h2,h3,h4,h5,h6').exists()).toBe(false);
  });

  it('uses the same non-heading title pattern for loading and error states', () => {
    const loading = mount(SectionCard, {
      props: { loading: true, empty: false, error: null, title: 'Loading Source' },
    });
    expect(loading.find('[data-testid="section-card-title"]').exists()).toBe(true);
    expect(loading.find('h1,h2,h3,h4,h5,h6').exists()).toBe(false);

    const error = mount(SectionCard, {
      props: { loading: false, empty: false, error: 'boom', title: 'Errored Source' },
    });
    expect(error.find('[data-testid="section-card-title"]').exists()).toBe(true);
    expect(error.find('h1,h2,h3,h4,h5,h6').exists()).toBe(false);
  });
});
