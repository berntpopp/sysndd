// app/src/composables/useGeneRecord.ts
//
// Per-source hook for the gene record. Internally discriminates between an HGNC
// id and a symbol so the page issues exactly one /api/gene/<id> request — the
// duplicate ?input_type=symbol fallback is no longer needed.
//
// Spec: .planning/superpowers/specs/2026-04-26-v11.3-genes-entities-perf-ux-design.md §4.1

import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { getGene } from '@/api/genes';
import { useResource, type ResourceState } from './useResource';
import type { GeneApiData } from '@/types/gene';

const HGNC_RE = /^HGNC:?\d+$/i;

export function useGeneRecord(
  input: string | Ref<string | null> | ComputedRef<string | null>,
): ResourceState<GeneApiData | null> {
  const inputRef = computed<string | null>(() => {
    if (typeof input === 'string') return input || null;
    if (isRef(input)) return input.value;
    return null;
  });

  const inputType = computed<'hgnc' | 'symbol' | null>(() => {
    const v = inputRef.value;
    if (v === null) return null;
    return HGNC_RE.test(v) ? 'hgnc' : 'symbol';
  });

  const key = computed<string | null>(() => {
    const v = inputRef.value;
    const t = inputType.value;
    return v && t ? `gene:${t}:${v}` : null;
  });

  return useResource<GeneApiData | null>(
    key,
    async (signal) => {
      const v = inputRef.value;
      const t = inputType.value;
      if (!v || !t) return null;
      const rows = await getGene(v, t, { signal });
      return rows[0] ?? null;
    },
    { ttlMs: 60_000 },
  );
}
