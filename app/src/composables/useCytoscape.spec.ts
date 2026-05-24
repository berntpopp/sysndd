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
  const positionCalls: Array<{ id: string; position: { x: number; y: number } }> = [];
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
    batch: vi.fn((callback: () => void) => callback()),
    layout: vi.fn(() => ({ run: vi.fn() })),
    resize: vi.fn(),
    fit: vi.fn(),
    nodes: vi.fn(() => ({ length: 0 })),
    zoom: vi.fn(() => 1),
    getElementById: vi.fn((id: string) => ({
      position: vi.fn((position: { x: number; y: number }) => {
        positionCalls.push({ id, position });
      }),
    })),
  };
  const cytoscapeMock = Object.assign(
    vi.fn(() => core),
    { use: vi.fn() }
  );

  return { collection, core, cytoscapeMock, handlers, positionCalls };
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
    mocks.core.batch.mockClear();
    mocks.core.layout.mockClear();
    mocks.core.getElementById.mockClear();
    mocks.positionCalls.length = 0;
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

  it('uses preset layout when all gene nodes have positions', () => {
    const container = document.createElement('div');
    const { initializeCytoscape, updateElements } = useCytoscape({ container: ref(container) });

    initializeCytoscape();
    updateElements([
      { data: { id: 'cluster-1', isClusterParent: true } },
      { data: { id: 'HGNC:1', parent: 'cluster-1' }, position: { x: 1, y: 2 } },
      { data: { id: 'HGNC:2', parent: 'cluster-1' }, position: { x: 3, y: 4 } },
      { data: { id: 'e1', source: 'HGNC:1', target: 'HGNC:2' } },
    ]);

    expect(mocks.core.layout).toHaveBeenLastCalledWith(expect.objectContaining({ name: 'preset' }));
  });

  it('can initialize Cytoscape with the first element set directly', () => {
    const container = document.createElement('div');
    const { initializeCytoscape } = useCytoscape({ container: ref(container) });
    const elements = [{ data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } }];

    initializeCytoscape(elements);

    expect(mocks.cytoscapeMock).toHaveBeenLastCalledWith(
      expect.objectContaining({
        elements,
        layout: expect.objectContaining({ name: 'preset' }),
      })
    );
  });

  it('notifies readiness after direct initialization with elements', () => {
    vi.useFakeTimers();
    const container = document.createElement('div');
    const onLayoutReady = vi.fn();
    const { initializeCytoscape } = useCytoscape({
      container: ref(container),
      onLayoutReady,
    });

    initializeCytoscape([{ data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } }]);
    vi.runOnlyPendingTimers();

    expect(onLayoutReady).toHaveBeenCalledTimes(1);
    vi.useRealTimers();
  });

  it('batches element replacement before running layout', () => {
    const container = document.createElement('div');
    const { initializeCytoscape, updateElements } = useCytoscape({ container: ref(container) });

    initializeCytoscape();
    updateElements([{ data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } }]);

    expect(mocks.core.batch).toHaveBeenCalledTimes(1);
    expect(mocks.collection.remove).toHaveBeenCalled();
    expect(mocks.core.add).toHaveBeenCalled();
  });

  it('notifies when the layout has reached the fitted ready state', () => {
    vi.useFakeTimers();
    const container = document.createElement('div');
    const onLayoutReady = vi.fn();
    const { initializeCytoscape } = useCytoscape({
      container: ref(container),
      onLayoutReady,
    } as Parameters<typeof useCytoscape>[0] & { onLayoutReady: () => void });

    initializeCytoscape();

    const layoutStopHandler = mocks.handlers.find(
      (entry) => entry.event === 'layoutstop' && typeof entry.selectorOrHandler === 'function'
    )?.selectorOrHandler as (() => void) | undefined;
    layoutStopHandler?.();
    vi.runOnlyPendingTimers();

    expect(onLayoutReady).toHaveBeenCalledTimes(1);
    vi.useRealTimers();
  });

  it('falls back to fcose when a gene node lacks position', () => {
    const container = document.createElement('div');
    const { initializeCytoscape, updateElements } = useCytoscape({ container: ref(container) });

    initializeCytoscape();
    updateElements([
      { data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } },
      { data: { id: 'HGNC:2' } },
    ]);

    expect(mocks.core.layout).toHaveBeenLastCalledWith(expect.objectContaining({ name: 'fcose' }));
  });

  it('resets with preset layout when positioned elements are active', () => {
    const container = document.createElement('div');
    const { initializeCytoscape, updateElements, resetLayout } = useCytoscape({
      container: ref(container),
    });

    initializeCytoscape();
    updateElements([{ data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } }]);
    resetLayout();

    expect(mocks.positionCalls).toEqual([{ id: 'HGNC:1', position: { x: 1, y: 2 } }]);
    expect(mocks.core.layout).toHaveBeenLastCalledWith(expect.objectContaining({ name: 'preset' }));
  });
});
