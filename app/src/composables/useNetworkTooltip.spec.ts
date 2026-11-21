import { describe, expect, it, vi } from 'vitest';
import { ref } from 'vue';
import cytoscape, { type Core } from 'cytoscape';
import { useNetworkTooltip } from './useNetworkTooltip';

function makeCore() {
  return {
    on: vi.fn(),
    off: vi.fn(),
    nodes: vi.fn(() => ({
      filter: vi.fn(() => ({
        filter: vi.fn(() => ({ length: 0 })),
      })),
    })),
  } as unknown as Core & {
    on: ReturnType<typeof vi.fn>;
    off: ReturnType<typeof vi.fn>;
  };
}

describe('useNetworkTooltip', () => {
  it('installs tooltip handlers only once for the same Cytoscape instance', () => {
    const core = makeCore();
    const { setupTooltipHandlers } = useNetworkTooltip(
      () => core,
      ref(document.createElement('div'))
    );

    setupTooltipHandlers();
    setupTooltipHandlers();

    expect(core.on).toHaveBeenCalledTimes(3);
    expect(core.off).toHaveBeenCalledTimes(3);
  });

  it('removes tooltip handlers from the previous Cytoscape instance before installing new ones', () => {
    const firstCore = makeCore();
    const secondCore = makeCore();
    let currentCore = firstCore;
    const { setupTooltipHandlers } = useNetworkTooltip(
      () => currentCore,
      ref(document.createElement('div'))
    );

    setupTooltipHandlers();
    currentCore = secondCore;
    setupTooltipHandlers();

    expect(firstCore.off).toHaveBeenCalledTimes(6);
    expect(secondCore.off).toHaveBeenCalledTimes(3);
    expect(secondCore.on).toHaveBeenCalledTimes(3);
  });

  it('counts the visible genes of a plain cluster box', () => {
    const core = cytoscape({
      headless: true,
      styleEnabled: true,
      layout: { name: 'preset' },
      elements: [
        { data: { id: 'cluster-1', isClusterParent: true, boxWidth: 0, boxHeight: 0 } },
        { data: { id: 'A', cluster: '1' }, position: { x: 0, y: 0 } },
        { data: { id: 'B', cluster: '1.2' }, position: { x: 1, y: 1 } },
        { data: { id: 'C', cluster: '1' }, position: { x: 2, y: 2 } },
        { data: { id: 'D', cluster: '11' }, position: { x: 3, y: 3 } },
      ],
    });
    core.getElementById('C').style('display', 'none');
    const { setupTooltipHandlers, tooltipData } = useNetworkTooltip(
      () => core,
      ref(document.createElement('div'))
    );
    setupTooltipHandlers();

    core.getElementById('cluster-1').emit('mouseover');

    expect(tooltipData.value).toMatchObject({ symbol: 'Cluster 1', degree: 2 });
    core.destroy();
  });
});
