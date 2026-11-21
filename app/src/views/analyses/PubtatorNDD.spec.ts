import { flushPromises, mount, RouterLinkStub } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

const listPubtatorGenes = vi.hoisted(() =>
  vi.fn().mockResolvedValue({ meta: [{ totalItems: 206 }], data: [] })
);
vi.mock('@/api/publication', () => ({ listPubtatorGenes }));

import PubtatorNDD from './PubtatorNDD.vue';

describe('PubtatorNDD', () => {
  it('badges the Genes tab with the total literature-only genes, not the rows on one page', async () => {
    const wrapper = mount(PubtatorNDD, {
      global: {
        stubs: {
          RouterLink: RouterLinkStub,
          // the genes table reports only the novel genes on its current page
          RouterView: {
            emits: ['novel-count'],
            mounted() {
              this.$emit('novel-count', 6);
            },
            template: '<div />',
          },
        },
      },
    });
    await flushPromises();

    expect(listPubtatorGenes).toHaveBeenCalledWith(
      expect.objectContaining({ filter: 'equals(is_novel,1)', page_size: '1' })
    );
    expect(wrapper.get('.analysis-tab__badge').text()).toBe('206 literature only');
  });
});
