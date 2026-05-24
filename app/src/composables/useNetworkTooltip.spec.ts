import { describe, expect, it, vi } from 'vitest';
import { ref } from 'vue';
import type { Core } from 'cytoscape';
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
});
