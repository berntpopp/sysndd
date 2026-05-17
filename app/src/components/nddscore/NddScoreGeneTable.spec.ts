import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import NddScoreGeneTable from './NddScoreGeneTable.vue';

const mocks = vi.hoisted(() => ({
  push: vi.fn(),
  fetchGenePredictions: vi.fn().mockResolvedValue({
    data: [],
    total: 0,
    page: 1,
    page_size: 25,
  }),
}));

vi.mock('vue-router', () => ({
  RouterLink: {
    props: ['to'],
    template: '<a :href="to"><slot /></a>',
  },
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('@/api/nddscore', () => ({
  fetchGenePredictions: mocks.fetchGenePredictions,
}));

describe('NddScoreGeneTable', () => {
  it('offers live NDDScore risk and confidence filter values', async () => {
    const wrapper = mount(NddScoreGeneTable);
    await flushPromises();

    expect(wrapper.text()).toContain('Very Low');
    expect(wrapper.text()).toContain('Medium');

    const selects = wrapper.findAll('select');
    expect((selects[0].element as HTMLSelectElement).options[0].value).toBe('');
    expect((selects[1].element as HTMLSelectElement).options[0].value).toBe('');
    await selects[1].setValue('Medium');
    await flushPromises();

    expect(mocks.fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        confidenceTier: 'Medium',
        page: 1,
      })
    );

    await selects[1].setValue('');
    await flushPromises();

    expect(mocks.fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        confidenceTier: undefined,
        page: 1,
      })
    );
  });
});
