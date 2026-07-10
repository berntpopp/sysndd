// useBatchCriteriaOptions.spec.ts
/**
 * Tests for useBatchCriteriaOptions (#346, Wave 2 Task 4).
 *
 * The composable is a thin orchestrator over injected dependencies (the
 * pieces of useBatchForm's return value it needs), so these tests supply
 * plain vi.fn() stand-ins rather than mounting useBatchForm/MSW. Coverage
 * matches the brief's checklist: option loading on mount, the 300ms
 * entity-search debounce, stale-search rejection, and the gene-filter
 * picker helpers moved out of BatchCriteriaForm.vue.
 */
import { reactive, ref } from 'vue';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { withSetup } from '@/test-utils';
import useBatchCriteriaOptions, {
  type BatchCriteriaEntitySearchResult,
  type BatchCriteriaGeneOption,
} from './useBatchCriteriaOptions';

function makeParams(overrides: Partial<Parameters<typeof useBatchCriteriaOptions>[0]> = {}) {
  return {
    formData: reactive({ gene_list: [] as number[] }),
    geneOptions: ref<BatchCriteriaGeneOption[]>([
      { value: 1100, text: 'BRCA1' },
      { value: 1101, text: 'BRCA2' },
      { value: 1200, text: 'CHD8' },
    ]),
    entitySearchQuery: ref(''),
    searchEntities: vi.fn(),
    addEntity: vi.fn(),
    loadOptions: vi.fn(),
    ...overrides,
  };
}

describe('useBatchCriteriaOptions — option loading', () => {
  it('calls loadOptions exactly once when mounted', () => {
    const loadOptions = vi.fn();
    const [, app] = withSetup(() => useBatchCriteriaOptions(makeParams({ loadOptions })));

    expect(loadOptions).toHaveBeenCalledTimes(1);
    app.unmount();
  });
});

describe('useBatchCriteriaOptions — entity search debounce', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('waits 300ms before calling searchEntities', () => {
    const searchEntities = vi.fn();
    const entitySearchQuery = ref('BRCA');
    const [result, app] = withSetup(() =>
      useBatchCriteriaOptions(makeParams({ entitySearchQuery, searchEntities }))
    );

    result.onEntitySearch();
    expect(searchEntities).not.toHaveBeenCalled();

    vi.advanceTimersByTime(299);
    expect(searchEntities).not.toHaveBeenCalled();

    vi.advanceTimersByTime(1);
    expect(searchEntities).toHaveBeenCalledTimes(1);
    expect(searchEntities).toHaveBeenCalledWith('BRCA');

    app.unmount();
  });

  it('rejects a stale pending search when newer input arrives before the debounce fires', () => {
    const searchEntities = vi.fn();
    const entitySearchQuery = ref('B');
    const [result, app] = withSetup(() =>
      useBatchCriteriaOptions(makeParams({ entitySearchQuery, searchEntities }))
    );

    // First keystroke schedules a search for 'B'.
    result.onEntitySearch();
    vi.advanceTimersByTime(150);

    // A second keystroke arrives before the first timer fires — it must
    // cancel the pending 'B' search rather than letting both resolve.
    entitySearchQuery.value = 'BR';
    result.onEntitySearch();

    // The original 300ms window (measured from the first keystroke) has
    // now elapsed, but the stale search was canceled — it must not fire.
    vi.advanceTimersByTime(150);
    expect(searchEntities).not.toHaveBeenCalled();

    // The second timer's own 300ms window completes — only the latest
    // query is ever searched.
    vi.advanceTimersByTime(150);
    expect(searchEntities).toHaveBeenCalledTimes(1);
    expect(searchEntities).toHaveBeenCalledWith('BR');

    app.unmount();
  });

  it('reads the query value at fire time, not at call time', () => {
    const searchEntities = vi.fn();
    const entitySearchQuery = ref('initial');
    const [result, app] = withSetup(() =>
      useBatchCriteriaOptions(makeParams({ entitySearchQuery, searchEntities }))
    );

    result.onEntitySearch();
    entitySearchQuery.value = 'changed-before-fire';
    vi.advanceTimersByTime(300);

    expect(searchEntities).toHaveBeenCalledWith('changed-before-fire');
    app.unmount();
  });
});

describe('useBatchCriteriaOptions — entity selection', () => {
  it('selectEntity delegates to the injected addEntity', () => {
    const addEntity = vi.fn();
    const [result, app] = withSetup(() => useBatchCriteriaOptions(makeParams({ addEntity })));

    const entity: BatchCriteriaEntitySearchResult = {
      entity_id: 42,
      hgnc_id: 1100,
      symbol: 'BRCA1',
      disease_ontology_name: 'Breast cancer',
      disease_ontology_id_version: 'OMIM:604370_1',
    };
    result.selectEntity(entity);

    expect(addEntity).toHaveBeenCalledTimes(1);
    expect(addEntity).toHaveBeenCalledWith(entity);
    app.unmount();
  });
});

describe('useBatchCriteriaOptions — gene filter picker', () => {
  it('filteredGeneOptions excludes already-selected genes and matches by text', () => {
    const formData = reactive({ gene_list: [1101] });
    const [result, app] = withSetup(() => useBatchCriteriaOptions(makeParams({ formData })));

    result.geneSearchQuery.value = 'brc';
    // BRCA2 (1101) is already selected, so only BRCA1 should remain.
    expect(result.filteredGeneOptions.value).toEqual([{ value: 1100, text: 'BRCA1' }]);

    app.unmount();
  });

  it('filteredGeneOptions is empty until a query is typed', () => {
    const [result, app] = withSetup(() => useBatchCriteriaOptions(makeParams()));

    expect(result.filteredGeneOptions.value).toEqual([]);
    app.unmount();
  });

  it('addGene appends the gene id once and clears the search query', () => {
    const formData = reactive({ gene_list: [] as number[] });
    const [result, app] = withSetup(() => useBatchCriteriaOptions(makeParams({ formData })));

    result.geneSearchQuery.value = 'brc';
    result.addGene(1100);
    result.addGene(1100); // duplicate add is a no-op

    expect(formData.gene_list).toEqual([1100]);
    expect(result.geneSearchQuery.value).toBe('');
    app.unmount();
  });

  it('removeGene removes only the targeted gene id', () => {
    const formData = reactive({ gene_list: [1100, 1101] });
    const [result, app] = withSetup(() => useBatchCriteriaOptions(makeParams({ formData })));

    result.removeGene(1100);

    expect(formData.gene_list).toEqual([1101]);
    app.unmount();
  });

  it('selectedGeneOptions reflects the currently selected gene ids', () => {
    const formData = reactive({ gene_list: [1200] });
    const [result, app] = withSetup(() => useBatchCriteriaOptions(makeParams({ formData })));

    expect(result.selectedGeneOptions.value).toEqual([{ value: 1200, text: 'CHD8' }]);
    app.unmount();
  });
});
