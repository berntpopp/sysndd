// app/src/composables/useEntityStatus.ts
import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { getEntityStatus } from '@/api/entity';
import { useResource, type ResourceState } from './useResource';

export function useEntityStatus(
  entityId: string | number | Ref<string | number | null> | ComputedRef<string | number | null>
): ResourceState<unknown> {
  const idRef = computed<string | null>(() => {
    let v: string | number | null;
    if (isRef(entityId)) v = entityId.value;
    else v = entityId as string | number;
    return v === null || v === undefined || v === '' ? null : String(v);
  });
  const key = computed<string | null>(() => (idRef.value ? `entity-status:${idRef.value}` : null));
  return useResource<unknown>(key, async (signal) => getEntityStatus(idRef.value!, { signal }), {
    ttlMs: 60_000,
  });
}
