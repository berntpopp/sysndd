// app/src/api/curate-variation-wire.ts
//
// Wire-shape normalization for the #612 curation-queue payloads.
//
// Same reason as `entity-variation-wire.ts`: the API is R/Plumber, its JSON
// serializer does NOT auto-unbox, and every field of a `list(...)`-built
// response therefore arrives as a LENGTH-1 ARRAY. The queue's rows are built
// exactly that way, so without this pass the typed client would declare
// primitives and hand back arrays.
//
// That is not a theoretical mismatch. A strict-equality test does not coerce,
// and this queue's entire UI turns on three of them —
// `row.state === 'active_unconfirmed'`, `row.served`, `row.moved` — which decide
// whether a curator is offered Confirm or Dismiss. Against `["suggested"]` and
// `[false]` every one of those reads wrong, and the picker would offer the
// action the server is going to refuse.
//
// Applied FIELD BY FIELD to the fields documented as scalars, never
// blanket-recursively: `data` and `evidence` are genuine arrays.

import type {
  VariationSuggestionEvidence,
  VariationSuggestionPage,
  VariationSuggestionRow,
} from './curate_variation';

/** Unwrap plumber's length-1 array around a contractually scalar field. */
export function unwrapWireScalar(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.length === 1 ? value[0] : undefined;
  }
  return value;
}

function asText(value: unknown): string | null {
  const raw = unwrapWireScalar(value);
  if (raw === null || raw === undefined) return null;
  const text = String(raw).trim();
  return text === '' ? null : text;
}

function asNumber(value: unknown, fallback = 0): number {
  const raw = unwrapWireScalar(value);
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/** A recorded 0-4 strength, or `null` for NOT RECORDED — never coerced to 0. */
function asStrength(value: unknown): number | null {
  const raw = unwrapWireScalar(value);
  if (raw === null || raw === undefined || raw === '') return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * A wire boolean.
 *
 * `false` is the answer that MATTERS here: `served: false` is what makes Dismiss
 * available, and `moved: false` is what keeps a row out of the laundered
 * worklist. A value that cannot be read is `false`, because "we could not
 * determine that this term is served" must never be treated as "it is served".
 */
function asFlag(value: unknown): boolean {
  const raw = unwrapWireScalar(value);
  if (typeof raw === 'boolean') return raw;
  if (raw === 'true' || raw === 1) return true;
  return false;
}

function normalizeEvidence(raw: unknown): VariationSuggestionEvidence[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((entry) => {
    const record = (entry ?? {}) as Record<string, unknown>;
    return {
      source_type: asText(record.source_type),
      source_key: asText(record.source_key),
      batch_id: asText(record.batch_id),
      // Order is the API's (recorded strength desc, then source_key). Not re-sorted.
      strength: asStrength(record.strength),
      summary: asText(record.summary),
    };
  });
}

/** Normalize one queue row. */
export function normalizeSuggestionRow(raw: unknown): VariationSuggestionRow {
  const record = (raw ?? {}) as Record<string, unknown>;
  const state = asText(record.state);
  return {
    entity_id: asNumber(record.entity_id),
    symbol: asText(record.symbol),
    disease_ontology_name: asText(record.disease_ontology_name),
    vario_id: asText(record.vario_id) ?? '',
    vario_name: asText(record.vario_name),
    modifier_id: asNumber(record.modifier_id),
    // An unrecognised state is reported verbatim rather than guessed at; the
    // row then offers no action, because neither predicate matches it.
    state: (state ?? 'suggested') as VariationSuggestionRow['state'],
    served: asFlag(record.served),
    moved: asFlag(record.moved),
    max_strength: asStrength(record.max_strength),
    evidence: normalizeEvidence(record.evidence),
  };
}

/** Normalize a `{meta, data}` page. */
export function normalizeSuggestionPage(raw: unknown): VariationSuggestionPage {
  const payload = (raw ?? {}) as Record<string, unknown>;
  const meta = (payload.meta ?? {}) as Record<string, unknown>;
  return {
    meta: {
      page: asNumber(meta.page, 1),
      page_size: asNumber(meta.page_size, 25),
      total: asNumber(meta.total),
    },
    data: Array.isArray(payload.data) ? payload.data.map(normalizeSuggestionRow) : [],
  };
}

/** Normalize a `{requested, applied, skipped}` batch result. */
export function normalizeApplyResult(raw: unknown): {
  requested: number;
  applied: number;
  skipped: Array<{
    entity_id: number;
    vario_id: string;
    modifier_id: number;
    reason: string;
  }>;
} {
  const payload = (raw ?? {}) as Record<string, unknown>;
  const skipped = Array.isArray(payload.skipped) ? payload.skipped : [];
  return {
    requested: asNumber(payload.requested),
    applied: asNumber(payload.applied),
    skipped: skipped.map((entry) => {
      const record = (entry ?? {}) as Record<string, unknown>;
      return {
        entity_id: asNumber(record.entity_id),
        vario_id: asText(record.vario_id) ?? '',
        modifier_id: asNumber(record.modifier_id),
        reason: asText(record.reason) ?? 'unknown',
      };
    }),
  };
}
