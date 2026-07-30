// app/src/composables/useVariationEvidence.ts
//
// Lazy, cached read of `GET /api/entity/<id>/variation/<vario_id>/<modifier_id>/evidence`
// for the #608 provenance dialog.
//
// LAZY is the point. The Variation Ontology card must cost NOTHING extra on
// entity-page load, so nothing here fires until a reader actually opens a
// term's evidence. That is expressed the way the rest of the v11.3 detail-page
// layer expresses it: a `useResource` key that is `null` while there is no
// target. `useResource` is inert on a null key and activates on the first
// non-null one, so "fetch on first open" needs no imperative trigger.
//
// CACHED via the shared Pinia `cacheStore`, so:
//   * reopening the same term is a cache hit (zero requests), and
//   * opening a second term fetches only that term (its own key) and leaves the
//     first cached.
// TTL is long and revalidation is off on purpose: an evidence record is a frozen
// provenance artifact of a completed import batch, so re-fetching it inside a
// session can only cost latency.

import { computed, type ComputedRef, type Ref } from 'vue';
import { getEntityVariationEvidence } from '@/api/entity';
import { useResource, type ResourceState } from './useResource';
import {
  normalizeEvidenceRecords,
  normalizeEvidenceState,
  type NormalizedEvidence,
  type PublicProvenanceState,
} from '@/views/pages/components/variationProvenance';

/** Identity of one `(entity_id, vario_id, modifier_id)` assertion. */
export interface VariationEvidenceTarget {
  entityId: string | number;
  varioId: string;
  modifierId: string | number;
}

export interface VariationEvidenceResult {
  state: PublicProvenanceState | null;
  records: NormalizedEvidence[];
}

export type VariationEvidenceState = ResourceState<VariationEvidenceResult>;

/**
 * Evidence for the currently-open assertion, or an inert resource when none is.
 *
 * @param target Reactive assertion identity; `null` keeps the resource inert.
 */
export function useVariationEvidence(
  target: Ref<VariationEvidenceTarget | null> | ComputedRef<VariationEvidenceTarget | null>
): VariationEvidenceState {
  const key = computed<string | null>(() => {
    const t = target.value;
    if (!t || t.entityId === '' || t.entityId === null || t.varioId === '') return null;
    return `entity-var-evidence:${t.entityId}:${t.varioId}:${t.modifierId}`;
  });

  return useResource<VariationEvidenceResult>(
    key,
    async (signal) => {
      // Non-null whenever the key is non-null; the key is what gates the fetch.
      const t = target.value as VariationEvidenceTarget;
      const response = await getEntityVariationEvidence(t.entityId, t.varioId, t.modifierId, {
        signal,
      });
      return {
        state: normalizeEvidenceState(response?.state),
        records: normalizeEvidenceRecords(response?.evidence),
      };
    },
    // Frozen artifact: cache for the session, never revalidate in the background.
    { ttlMs: 15 * 60_000, staleWhileRevalidate: false }
  );
}

export default useVariationEvidence;
