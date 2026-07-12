import { describe, expect, it, vi, beforeEach } from 'vitest';
import { nextTick } from 'vue';

import { getNetworkEdges } from '@/api/analysis';
import type { NetworkResponse } from '@/api/analysis';
import { useNetworkData } from './useNetworkData';

vi.mock('@/api/analysis', () => ({
  getNetworkEdges: vi.fn(),
  // #420: the composable classifies fetch errors via this helper; default to
  // "not a snapshot-preparing 503" so the existing error-path assertions hold.
  isSnapshotPreparingError: vi.fn(() => false),
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
        snapshot: {
          analysis_type: 'gene_network_edges',
        },
      },
    });

    const state = useNetworkData();

    await state.fetchNetworkData();

    expect(getNetworkEdgesMock).toHaveBeenCalledWith({
      cluster_type: 'clusters',
      min_confidence: '400',
      max_edges: '10000',
    });
    expect(state.error.value).toBeNull();
    expect(state.metadata.value?.snapshot?.analysis_type).toBe('gene_network_edges');
  });

  it('keeps network data null and exposes snapshot problem codes on rejection', async () => {
    getNetworkEdgesMock.mockRejectedValue({
      isAxiosError: true,
      response: {
        status: 503,
        data: {
          code: 'snapshot_missing',
          message: 'No public analysis snapshot is currently available.',
        },
      },
    });

    const state = useNetworkData();

    await state.fetchNetworkData();

    expect(state.networkData.value).toBeNull();
    expect(state.error.value?.message).toContain('snapshot_missing');
  });

  it('reuses an in-flight preload when fetching the same network payload', async () => {
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

    const { preloadNetworkData } = await import('./useNetworkData');
    const preload = preloadNetworkData();
    const state = useNetworkData();
    await state.fetchNetworkData();
    await preload;

    expect(getNetworkEdgesMock).toHaveBeenCalledTimes(1);
  });

  it('keeps B able to receive a shared preload after A clears its local state', async () => {
    let resolveNetwork!: (value: NetworkResponse) => void;
    const network = new Promise<NetworkResponse>((resolve) => {
      resolveNetwork = resolve;
    });
    getNetworkEdgesMock.mockReturnValue(network);
    const a = useNetworkData();
    const b = useNetworkData();

    const requestA = a.fetchNetworkData();
    const requestB = b.fetchNetworkData();
    a.clearNetworkData();
    resolveNetwork({
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
    await Promise.all([requestA, requestB]);

    expect(a.networkData.value).toBeNull();
    expect(a.isLoading.value).toBe(false);
    expect(b.networkData.value).not.toBeNull();
    expect(b.isLoading.value).toBe(false);
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

    await state.fetchNetworkData();
    await nextTick();

    const gene = state.cytoscapeElements.value.find((element) => element.data?.id === 'HGNC:1');
    expect(gene?.position).toEqual({ x: 10, y: 20 });
  });

  it('builds an initial render payload with all nodes but only default-visible edges', async () => {
    getNetworkEdgesMock.mockResolvedValue({
      nodes: [
        { hgnc_id: 'HGNC:1', symbol: 'AAA', cluster: 1, degree: 4, category: 'Definitive' },
        { hgnc_id: 'HGNC:2', symbol: 'BBB', cluster: 1, degree: 1, category: 'Moderate' },
        { hgnc_id: 'HGNC:3', symbol: 'CCC', cluster: 1, degree: 1, category: 'Definitive' },
      ],
      edges: [
        { source: 'HGNC:1', target: 'HGNC:3', confidence: 0.9 },
        { source: 'HGNC:1', target: 'HGNC:2', confidence: 0.8 },
      ],
      metadata: {
        node_count: 3,
        edge_count: 2,
        cluster_count: 1,
        total_edges: 2,
        edges_filtered: false,
        elapsed_seconds: 0.1,
      },
    });

    const state = useNetworkData();

    await state.fetchNetworkData();
    await nextTick();

    const initialIds = state.cytoscapeInitialElements.value.map((element) => element.data?.id);
    expect(initialIds).toContain('HGNC:2');
    expect(initialIds).toContain('e0');
    expect(initialIds).not.toContain('e1');
    expect(state.cytoscapeElements.value.map((element) => element.data?.id)).toContain('e1');
  });

  it('builds a node-only payload for the fastest first paint', async () => {
    getNetworkEdgesMock.mockResolvedValue({
      nodes: [{ hgnc_id: 'HGNC:1', symbol: 'AAA', cluster: 1, degree: 4 }],
      edges: [{ source: 'HGNC:1', target: 'HGNC:1', confidence: 0.9 }],
      metadata: {
        node_count: 1,
        edge_count: 1,
        cluster_count: 1,
        total_edges: 1,
        edges_filtered: false,
        elapsed_seconds: 0.1,
      },
    });

    const state = useNetworkData();

    await state.fetchNetworkData();
    await nextTick();

    const nodeOnlyIds = state.cytoscapeNodeElements.value.map((element) => element.data?.id);
    expect(nodeOnlyIds).toContain('HGNC:1');
    expect(nodeOnlyIds).toContain('cluster-1');
    expect(nodeOnlyIds).not.toContain('e0');
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

    await state.fetchNetworkData();
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

    await state.fetchNetworkData();
    await nextTick();

    const gene = state.cytoscapeElements.value.find((element) => element.data?.id === 'HGNC:1');
    expect(gene?.position).toBeUndefined();
  });

  it('treats fetched network payloads as immutable to avoid deep reactivity overhead', async () => {
    getNetworkEdgesMock.mockResolvedValue({
      nodes: [{ hgnc_id: 'HGNC:1', symbol: 'AAA', cluster: 1, degree: 4 }],
      edges: [],
      metadata: {
        node_count: 1,
        edge_count: 0,
        cluster_count: 1,
        total_edges: 0,
        edges_filtered: false,
        elapsed_seconds: 0.1,
      },
    });

    const state = useNetworkData();

    await state.fetchNetworkData();
    const originalGene = state.cytoscapeElements.value.find(
      (element) => element.data?.id === 'HGNC:1'
    );
    expect(originalGene?.data?.symbol).toBe('AAA');

    state.networkData.value!.nodes[0].symbol = 'MUTATED';
    await nextTick();

    const cachedGene = state.cytoscapeElements.value.find(
      (element) => element.data?.id === 'HGNC:1'
    );
    expect(cachedGene?.data?.symbol).toBe('AAA');
  });
});
