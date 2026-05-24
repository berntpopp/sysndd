import { describe, expect, it, vi, beforeEach } from 'vitest';
import { nextTick } from 'vue';

import { getNetworkEdges } from '@/api/analysis';
import { useNetworkData } from './useNetworkData';

vi.mock('@/api/analysis', () => ({
  getNetworkEdges: vi.fn(),
}));

const getNetworkEdgesMock = vi.mocked(getNetworkEdges);

describe('useNetworkData', () => {
  beforeEach(() => {
    getNetworkEdgesMock.mockReset();
  });

  it('fetches through the typed analysis client', async () => {
    getNetworkEdgesMock.mockResolvedValue({
      nodes: [],
      edges: [],
      metadata: {
        node_count: 0,
        edge_count: 0,
        cluster_count: 0,
        total_edges: 0,
        edges_filtered: false,
        elapsed_seconds: 0.1,
      },
    });

    const state = useNetworkData();

    await state.fetchNetworkData('subclusters', 3000);

    expect(getNetworkEdgesMock).toHaveBeenCalledWith({
      cluster_type: 'subclusters',
      max_edges: '3000',
    });
    expect(state.error.value).toBeNull();
  });

  it('converts finite API coordinates into Cytoscape positions', async () => {
    getNetworkEdgesMock.mockResolvedValue({
      nodes: [
        {
          hgnc_id: 'HGNC:1',
          symbol: 'AAA',
          cluster: 1,
          degree: 4,
          category: 'Definitive',
          x: 10,
          y: 20,
        },
        {
          hgnc_id: 'HGNC:2',
          symbol: 'BBB',
          cluster: 1,
          degree: 1,
          category: 'Moderate',
          x: 30,
          y: 40,
        },
      ],
      edges: [{ source: 'HGNC:1', target: 'HGNC:2', confidence: 0.8 }],
      metadata: {
        node_count: 2,
        edge_count: 1,
        cluster_count: 1,
        total_edges: 1,
        edges_filtered: false,
        elapsed_seconds: 0.1,
        display_layout_status: 'available',
      },
    });

    const state = useNetworkData();

    await state.fetchNetworkData('clusters');
    await nextTick();

    const gene = state.cytoscapeElements.value.find((element) => element.data?.id === 'HGNC:1');
    expect(gene?.position).toEqual({ x: 10, y: 20 });
  });

  it('omits Cytoscape positions when the display artifact is unavailable', async () => {
    getNetworkEdgesMock.mockResolvedValue({
      nodes: [{ hgnc_id: 'HGNC:1', symbol: 'AAA', cluster: 1, degree: 4, x: 10, y: 20 }],
      edges: [],
      metadata: {
        node_count: 1,
        edge_count: 0,
        cluster_count: 1,
        total_edges: 0,
        edges_filtered: false,
        elapsed_seconds: 0.1,
        display_layout_status: 'missing',
      },
    });

    const state = useNetworkData();

    await state.fetchNetworkData('clusters');
    await nextTick();

    const gene = state.cytoscapeElements.value.find((element) => element.data?.id === 'HGNC:1');
    expect(gene?.position).toBeUndefined();
  });

  it('omits Cytoscape positions when an available artifact has incomplete coordinates', async () => {
    getNetworkEdgesMock.mockResolvedValue({
      nodes: [{ hgnc_id: 'HGNC:1', symbol: 'AAA', cluster: 1, degree: 4, x: 10 }],
      edges: [],
      metadata: {
        node_count: 1,
        edge_count: 0,
        cluster_count: 1,
        total_edges: 0,
        edges_filtered: false,
        elapsed_seconds: 0.1,
        display_layout_status: 'available',
      },
    });

    const state = useNetworkData();

    await state.fetchNetworkData('clusters');
    await nextTick();

    const gene = state.cytoscapeElements.value.find((element) => element.data?.id === 'HGNC:1');
    expect(gene?.position).toBeUndefined();
  });
});
