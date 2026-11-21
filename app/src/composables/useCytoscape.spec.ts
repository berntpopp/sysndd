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
  const nodeCollection = {
    length: 0,
    items: [] as Array<{ x: number; y: number; size: number }>,
    forEach(callback: (node: unknown) => void) {
      for (const { x, y, size } of nodeCollection.items) {
        callback({
          data: (key: string) => (key === 'size' ? size : undefined),
          visible: () => true,
          position: () => ({ x, y }),
        });
      }
    },
    toggleClass: vi.fn(),
    addClass: vi.fn(),
    removeClass: vi.fn(),
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
    nodes: vi.fn(() => nodeCollection),
    zoom: vi.fn(() => 1),
    width: vi.fn(() => 800),
    height: vi.fn(() => 600),
    viewport: vi.fn(),
    png: vi.fn(() => 'data:image/png;base64,'),
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

  return { collection, core, cytoscapeMock, handlers, nodeCollection, positionCalls };
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
    mocks.nodeCollection.items = [];
    mocks.nodeCollection.toggleClass.mockClear();
    mocks.nodeCollection.addClass.mockClear();
    mocks.nodeCollection.removeClass.mockClear();
    mocks.core.fit.mockClear();
    mocks.core.viewport.mockClear();
    mocks.core.zoom.mockImplementation(() => 1);
  });

  it('frames stored positions from the gene positions, not by measuring every element', () => {
    mocks.nodeCollection.items = [
      { x: 0, y: 0, size: 14 },
      { x: 1000, y: 500, size: 14 },
    ];
    const { initializeCytoscape } = useCytoscape({ container: ref(document.createElement('div')) });

    initializeCytoscape([
      { data: { id: 'HGNC:1' }, position: { x: 0, y: 0 } },
      { data: { id: 'HGNC:2' }, position: { x: 1000, y: 500 } },
    ]);

    expect(mocks.core.fit).not.toHaveBeenCalled();
    // genes span x -40..1040 (size/2 + cluster box margin); 740 px usable width
    const { zoom, pan } = mocks.core.viewport.mock.calls[0][0];
    expect(zoom).toBeCloseTo(740 / 1080);
    expect(pan.x).toBeCloseTo((800 - zoom * 1000) / 2);
    expect(pan.y).toBeCloseTo((600 - zoom * 500) / 2);
  });

  it('mounts positioned nodes at once and adds the edges in frame-sized batches', () => {
    const frames: Array<() => void> = [];
    vi.useFakeTimers(); // before the stub: fake timers replace requestAnimationFrame too
    vi.stubGlobal('requestAnimationFrame', (cb: () => void) => frames.push(cb));
    const onLayoutReady = vi.fn();
    const { initializeCytoscape } = useCytoscape({
      container: ref(document.createElement('div')),
      onLayoutReady,
    });
    const nodes = [
      { data: { id: 'A' }, position: { x: 0, y: 0 } },
      { data: { id: 'B' }, position: { x: 1, y: 1 } },
    ];
    const edges = Array.from({ length: 1200 }, (_, i) => ({
      data: { id: `e${i}`, source: 'A', target: 'B' },
    }));
    mocks.core.add.mockClear();
    mocks.nodeCollection.items = [
      { x: 0, y: 0, size: 14 },
      { x: 1, y: 1, size: 14 },
    ];

    initializeCytoscape([...nodes, ...edges]);
    expect(mocks.core.viewport).toHaveBeenCalledTimes(1);

    expect(mocks.cytoscapeMock).toHaveBeenLastCalledWith(
      expect.objectContaining({ elements: nodes })
    );
    while (frames.length) frames.shift()!();
    expect(mocks.core.add.mock.calls.map(([batch]) => batch.length)).toEqual([500, 500, 200]);
    vi.runOnlyPendingTimers();
    expect(onLayoutReady).toHaveBeenCalledTimes(1);
    // framed once before the first paint, not again once the edges are in
    expect(mocks.core.viewport).toHaveBeenCalledTimes(1);
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('clears the loading state once the constructor layout has run', () => {
    const { initializeCytoscape, isLoading } = useCytoscape({
      container: ref(document.createElement('div')),
    });

    initializeCytoscape([{ data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } }]);

    // no layoutstop reaches the listener: it fired inside the constructor
    expect(isLoading.value).toBe(false);
  });

  it('shows gene labels only from the zoom at which they are legible', () => {
    mocks.core.zoom.mockImplementation(() => 0.4);
    const { initializeCytoscape } = useCytoscape({ container: ref(document.createElement('div')) });
    initializeCytoscape([{ data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } }]);
    expect(mocks.nodeCollection.toggleClass).toHaveBeenLastCalledWith('labelled', false);

    const zoomHandler = mocks.handlers.find((entry) => entry.event === 'zoom')
      ?.selectorOrHandler as () => void;
    mocks.core.zoom.mockImplementation(() => 1.2);
    zoomHandler();
    zoomHandler(); // no restyle while the zoom stays on the same side
    expect(mocks.nodeCollection.toggleClass).toHaveBeenCalledTimes(2);
    expect(mocks.nodeCollection.toggleClass).toHaveBeenLastCalledWith('labelled', true);
  });

  it('exports with every gene label and restores the zoomed-out view', () => {
    mocks.core.zoom.mockImplementation(() => 0.4);
    const { initializeCytoscape, exportPNG } = useCytoscape({
      container: ref(document.createElement('div')),
    });
    initializeCytoscape([{ data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } }]);

    mocks.core.png.mockImplementation(() => {
      expect(mocks.nodeCollection.addClass).toHaveBeenCalledWith('labelled');
      return 'png';
    });
    expect(exportPNG()).toBe('png');
    expect(mocks.nodeCollection.removeClass).toHaveBeenCalledWith('labelled');
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

  it('reports direct initialization readiness once when layoutstop also fires', () => {
    vi.useFakeTimers();
    const container = document.createElement('div');
    const onLayoutReady = vi.fn();
    const { initializeCytoscape } = useCytoscape({
      container: ref(container),
      onLayoutReady,
    });

    initializeCytoscape([{ data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } }]);

    const layoutStopHandler = mocks.handlers.find(
      (entry) => entry.event === 'layoutstop' && typeof entry.selectorOrHandler === 'function'
    )?.selectorOrHandler as (() => void) | undefined;
    layoutStopHandler?.();
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
