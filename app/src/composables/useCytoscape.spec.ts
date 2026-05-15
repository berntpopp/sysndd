import { describe, expect, it, vi, beforeEach } from 'vitest';
import { ref } from 'vue';
import { useCytoscape } from './useCytoscape';

type TapEvent = { target: unknown };
type TapHandler = (event: TapEvent) => void;
type HandlerEntry = {
  event: string;
  selectorOrHandler: unknown;
  handler?: TapHandler;
};

const mocks = vi.hoisted(() => {
  const handlers: HandlerEntry[] = [];
  const collection = {
    remove: vi.fn(),
    removeClass: vi.fn(),
    not: vi.fn(() => collection),
    addClass: vi.fn(),
    boundingBox: vi.fn(() => ({ w: 0, h: 0 })),
  };
  const core = {
    on: vi.fn((event: string, selectorOrHandler: unknown, handler?: TapHandler) => {
      handlers.push({ event, selectorOrHandler, handler });
      return core;
    }),
    destroy: vi.fn(),
    elements: vi.fn(() => collection),
    add: vi.fn(),
    layout: vi.fn(() => ({ run: vi.fn() })),
    resize: vi.fn(),
    fit: vi.fn(),
    nodes: vi.fn(() => ({ length: 0 })),
    zoom: vi.fn(() => 1),
  };
  const cytoscapeMock = Object.assign(vi.fn(() => core), { use: vi.fn() });

  return { collection, core, cytoscapeMock, handlers };
});

vi.mock('cytoscape', () => ({
  default: mocks.cytoscapeMock,
}));

vi.mock('cytoscape-fcose', () => ({
  default: vi.fn(),
}));

vi.mock('cytoscape-svg', () => ({
  default: vi.fn(),
}));

function getCoreTapHandler(): TapHandler | undefined {
  return mocks.handlers.find(
    (entry) => entry.event === 'tap' && typeof entry.selectorOrHandler === 'function'
  )?.selectorOrHandler as TapHandler | undefined;
}

describe('useCytoscape', () => {
  beforeEach(() => {
    mocks.handlers.length = 0;
    mocks.cytoscapeMock.mockClear();
    mocks.core.on.mockClear();
  });

  it('calls the background click callback only for core background taps', () => {
    const container = document.createElement('div');
    const onBackgroundClick = vi.fn();

    const { initializeCytoscape } = useCytoscape({
      container: ref(container),
      onBackgroundClick,
    });

    initializeCytoscape();

    const coreTapHandler = getCoreTapHandler();

    expect(coreTapHandler).toBeTypeOf('function');

    coreTapHandler?.({ target: mocks.core });
    coreTapHandler?.({ target: { id: () => 'HGNC:1234' } });

    expect(onBackgroundClick).toHaveBeenCalledTimes(1);
  });
});
