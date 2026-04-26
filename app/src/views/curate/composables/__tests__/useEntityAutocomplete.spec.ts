import { describe, expect, test } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { useEntityAutocomplete } from '../useEntityAutocomplete';

// Lifecycle (listen / resetHandlers / close) is provided globally by
// vitest.setup.ts. This file only adds per-test handler overrides via
// `server.use(...)`.

describe('useEntityAutocomplete', () => {
  test('searchEntity skips when query < 2 chars and clears results', async () => {
    const a = useEntityAutocomplete();
    a.entity_search_results.value = [{ entity_id: 1 } as any];
    await a.searchEntity('');
    expect(a.entity_search_results.value).toEqual([]);
  });

  test('searchEntity GETs and populates results capped at 10', async () => {
    server.use(
      http.get('*/api/entity/*', () =>
        HttpResponse.json({
          data: Array.from({ length: 25 }, (_, i) => ({ entity_id: i + 1, symbol: `G${i}` })),
        }),
      ),
    );
    const a = useEntityAutocomplete();
    await a.searchEntity('GR');
    expect(a.entity_search_results.value.length).toBe(10);
  });

  test('searchOntology populates ontology_search_results capped at 10', async () => {
    server.use(
      http.get('*/api/search/ontology*', () =>
        HttpResponse.json(Array.from({ length: 15 }, (_, i) => ({ id: `HP:${i}`, label: `term ${i}` }))),
      ),
    );
    const a = useEntityAutocomplete();
    await a.searchOntology('seizure');
    expect(a.ontology_search_results.value.length).toBe(10);
  });

  test('searchReplacementEntity excludes the current entity_id', async () => {
    server.use(
      http.get('*/api/entity/*', () =>
        HttpResponse.json({
          data: [
            { entity_id: 5, symbol: 'CURRENT' },
            { entity_id: 6, symbol: 'OTHER' },
          ],
        }),
      ),
    );
    const a = useEntityAutocomplete({ getCurrentEntityId: () => 5 });
    await a.searchReplacementEntity('GR');
    expect(a.replace_entity_search_results.value.map((e) => e.entity_id)).toEqual([6]);
  });

  test('clearAll resets every buffer', () => {
    const a = useEntityAutocomplete();
    a.entity_search_results.value = [{ entity_id: 1 } as any];
    a.ontology_search_results.value = [{ id: 'HP:1', label: 'x' } as any];
    a.replace_entity_search_results.value = [{ entity_id: 2 } as any];
    a.modify_entity_input.value = 9;
    a.ontology_input.value = 'HP:2';
    a.replace_entity_input.value = 3;
    a.clearAll();
    expect(a.entity_search_results.value).toEqual([]);
    expect(a.ontology_search_results.value).toEqual([]);
    expect(a.replace_entity_search_results.value).toEqual([]);
    expect(a.modify_entity_input.value).toBeNull();
    expect(a.ontology_input.value).toBeNull();
    expect(a.replace_entity_input.value).toBeNull();
  });
});
