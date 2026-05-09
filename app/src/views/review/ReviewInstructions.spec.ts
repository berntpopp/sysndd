import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import { DOCS_URLS } from '@/constants/docs';
import ReviewInstructions from './ReviewInstructions.vue';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

describe('ReviewInstructions', () => {
  const mountView = () =>
    mount(ReviewInstructions, {
      global: {
        stubs: {
          AuthenticatedPageShell: {
            props: ['title', 'description', 'contentClass'],
            template:
              '<section class="authenticated-page-shell" :class="contentClass"><h1>{{ title }}</h1><p>{{ description }}</p><slot /></section>',
          },
          BLink: {
            props: ['href', 'target', 'rel'],
            template: '<a :href="href" :target="target" :rel="rel"><slot /></a>',
          },
        },
      },
    });

  it('renders the modern authenticated shell with direct instruction links', () => {
    const wrapper = mountView();

    expect(wrapper.get('h1').text()).toBe('Review instructions');
    expect(wrapper.find('.accordion').exists()).toBe(false);
    expect(wrapper.find('.card').exists()).toBe(false);

    const hrefs = wrapper.findAll('a').map((link) => link.attributes('href'));
    expect(hrefs).toEqual([
      DOCS_URLS.CURATION_CRITERIA,
      DOCS_URLS.RE_REVIEW_INSTRUCTIONS,
      DOCS_URLS.TUTORIAL_VIDEOS,
    ]);

    expect(wrapper.text()).toContain('Curation criteria');
    expect(wrapper.text()).toContain('Re-review instructions');
    expect(wrapper.text()).toContain('Tutorial videos');
  });
});
