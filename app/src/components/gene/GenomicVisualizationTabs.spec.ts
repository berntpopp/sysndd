import { describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import GenomicVisualizationTabs from './GenomicVisualizationTabs.vue';

const getEnsemblStructure = vi.fn();
vi.mock('@/api/external', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/api/external')>()),
  getEnsemblStructure: (...args: unknown[]) => getEnsemblStructure(...args),
}));

const stubs = {
  BCard: { template: '<div><slot name="header" /><slot /></div>' },
  BTabs: { template: '<div><slot /></div>' },
  BTab: { template: '<div @click="$emit(\'click\')"><slot name="title" /><slot /></div>' },
  BBadge: { template: '<span><slot /></span>' },
  BSpinner: { template: '<span />' },
  ProteinDomainLollipopPlot: true,
  ProteinLollipopSkeleton: true,
  GeneStructurePlotWithVariants: true,
  ProteinStructure3D: true,
};

function mountTabs() {
  return mount(GenomicVisualizationTabs, {
    props: {
      geneSymbol: 'FBXO11',
      clinvarVariants: [],
      clinvarLoading: false,
      clinvarError: null,
      uniprotData: null,
      uniprotLoading: false,
      uniprotError: null,
      alphafoldPdbUrl: null,
      alphafoldLoading: false,
      alphafoldError: null,
    },
    global: { stubs },
  });
}

describe('GenomicVisualizationTabs', () => {
  it('fetches the gene structure once when its tab opens (a second response re-renders the plot)', async () => {
    let resolve!: (v: unknown) => void;
    getEnsemblStructure.mockReset();
    getEnsemblStructure.mockImplementation(() => new Promise((r) => (resolve = r)));
    const w = mountTabs();
    // The tab's click handler and the index watcher both ask for the data.
    await w
      .findAll('div')
      .find((d) => d.text().startsWith('Gene Structure'))!
      .trigger('click');
    await flushPromises();
    resolve({ found: false });
    await flushPromises();
    expect(getEnsemblStructure).toHaveBeenCalledTimes(1);
  });

  it('fetches the new gene when the symbol changes while the old fetch is in flight', async () => {
    const pending: Record<string, (v: unknown) => void> = {};
    getEnsemblStructure.mockReset();
    getEnsemblStructure.mockImplementation(
      (symbol: string) => new Promise((r) => (pending[symbol] = r))
    );
    const w = mountTabs();
    await w
      .findAll('div')
      .find((d) => d.text().startsWith('Gene Structure'))!
      .trigger('click');
    await flushPromises();
    await w.setProps({ geneSymbol: 'ARID1B' });
    await flushPromises();
    expect(getEnsemblStructure).toHaveBeenLastCalledWith('ARID1B', expect.anything());
    // The stale FBXO11 response must not land on the ARID1B page.
    pending.FBXO11({ found: false });
    await flushPromises();
    expect(getEnsemblStructure).toHaveBeenCalledTimes(2);
  });

  it('shows variant counts with a thousands separator', () => {
    const w = mountTabs();
    w.setProps({
      clinvarVariants: Array.from({ length: 1934 }, () => ({})) as never,
    });
    return w.vm.$nextTick().then(() => {
      expect(w.text()).toContain('1,934 variants');
      expect(w.text()).not.toContain('1.9K');
    });
  });
});
