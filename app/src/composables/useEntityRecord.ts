// app/src/composables/useEntityRecord.ts
//
// Hook for the single-entity record (one row from
// `GET /api/entity/?filter=equals(entity_id,N)`). Spec: §4.1.3.
//
// Wraps the typed `listEntities` client in `useResource` so callers receive
// SWR semantics (cache-first, background revalidate) keyed by `entity:<id>`.
// Resolves to `null` when the API returns an empty `data[]` array — the
// caller (e.g. EntityView) treats `null` as "not found".

import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { listEntities, type EntityRow } from '@/api/entity';
import { useResource, type ResourceState } from './useResource';

export function useEntityRecord(
  entityId: string | number | Ref<string | number | null> | ComputedRef<string | number | null>
): ResourceState<EntityRow | null> {
  const idRef = computed<string | null>(() => {
    let v: string | number | null;
    if (isRef(entityId)) v = entityId.value;
    else v = entityId as string | number;
    if (v === null || v === '' || v === undefined) return null;
    return String(v);
  });
  const key = computed<string | null>(() => (idRef.value ? `entity:${idRef.value}` : null));
  return useResource<EntityRow | null>(
    key,
    async (signal) => {
      const res = await listEntities({ filter: `equals(entity_id,${idRef.value})` }, { signal });
      return res.data[0] ?? null;
    },
    { ttlMs: 60_000 }
  );
}
