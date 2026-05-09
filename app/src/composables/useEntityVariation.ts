// app/src/composables/useEntityVariation.ts
import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { getEntityVariation } from '@/api/entity';
import { useResource, type ResourceState } from './useResource';

export function useEntityVariation(
  entityId: string | number | Ref<string | number | null> | ComputedRef<string | number | null>
): ResourceState<unknown[]> {
  const idRef = computed<string | null>(() => {
    let v: string | number | null;
    if (isRef(entityId)) v = entityId.value;
    else v = entityId as string | number;
    return v === null || v === undefined || v === '' ? null : String(v);
  });
  const key = computed<string | null>(() => (idRef.value ? `entity-var:${idRef.value}` : null));
  return useResource<unknown[]>(
    key,
    async (signal) => (await getEntityVariation(idRef.value!, {}, { signal })) as unknown[],
    { ttlMs: 60_000 }
  );
}
