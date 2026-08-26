// app/src/views/pages/components/variationProvenance.ts
//
// Pure presentation helpers for the #608 variation-ontology provenance surface.
// No Vue, no HTTP — the sibling `.vue` files and their specs both drive these,
// which keeps EntityEvidenceGrid.vue and VariationProvenanceDialog.vue small.
//
// TWO HARD RULES LIVE HERE
// -----------------------
// 1. NEVER SYNTHESISE. `summary` is the source's own stored wording and is shown
//    verbatim. There is no protein/cDNA (HGVS) label in the payload because the
//    importer never recorded one — so none is rendered. A field that is absent
//    is omitted; a placeholder that implies data is exactly the fabrication this
//    feature exists to prevent.
//    The import date IS now served (`created_at`, #612) and is rendered as a
//    DATE only. The column behind it is a MySQL `DATETIME` with no timezone, so
//    the API sends no zone designator and `formatImportedDate()` reads the
//    calendar fields literally rather than parsing an instant — showing a
//    wall-clock time, or shifting the date across a timezone boundary, would
//    both assert precision the payload does not carry.
// 2. `strength` / `max_strength` are `null` when NOT RECORDED. Null must never
//    render as zero stars, which would assert "we checked, it scored 0".
//
// WIRE SHAPE
// ----------
// The routes serialize with `jsonlite::toJSON(..., na = "string",
// null = "null")` and plumber does NOT auto-unbox, so:
//   * data-frame columns (`vario_id`, `modifier_id`, …) arrive as SCALARS, but
//   * every scalar nested inside the `provenance` list-column, and every field
//     of the `list()`-built evidence response, arrives as a LENGTH-1 ARRAY
//     (`"state":["active_unconfirmed"]`, `"strength":[1]`).
//   * a NULL becomes JSON `null` (not `[null]`, not `{}`, not `"NA"`).
// `unwrapScalar()` is therefore applied field-by-field to the fields we KNOW are
// scalars — never blanket-recursively, because `sources` / `evidence` / `records`
// are genuine arrays that happen to be length 1 sometimes.

import {
  asBoolean,
  asStrength,
  asText,
  isWireRecord,
  STRENGTH_SCALE_MAX,
  unwrapScalar,
} from './variationWireScalars';
import {
  clinvarVariationUrl as clinvarUrlFromId,
  normalizeEvidenceRecordList,
  type NormalizedEvidenceRecord,
} from './variationEvidenceRecords';

// Re-exported so the existing consumers of this module (EntityEvidenceGrid.vue,
// VariationProvenanceDialog.vue, useVariationEvidence.ts, and the specs) keep
// importing from one place, while the primitives themselves live in a
// dependency-free module that `variationEvidenceRecords.ts` can also use
// without importing back.
export { unwrapScalar, asBoolean, STRENGTH_SCALE_MAX };
export type { NormalizedEvidenceRecord };

/** States the public read may ever carry. `suggested`/`rejected` never appear. */
export const PUBLIC_PROVENANCE_STATES = ['active_unconfirmed', 'confirmed'] as const;
export type PublicProvenanceState = (typeof PUBLIC_PROVENANCE_STATES)[number];

export interface NormalizedSource {
  sourceType: string | null;
  sourceKey: string | null;
  strength: number | null;
  summary: string | null;
}

export interface NormalizedProvenance {
  state: PublicProvenanceState;
  maxStrength: number | null;
  sources: NormalizedSource[];
}

export interface NormalizedEvidence {
  sourceType: string | null;
  sourceKey: string | null;
  batchId: string | null;
  sourceVersion: string | null;
  summary: string | null;
  strength: number | null;
  /** Import date, already formatted for display; `null` when not recorded. */
  importedOn: string | null;
  records: NormalizedEvidenceRecord[];
  matched: string[];
}

// ---------------------------------------------------------------------------
// Wire-shape helpers
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Compact provenance (the hot `/variation` read)
// ---------------------------------------------------------------------------

/**
 * Normalize one term's `provenance` block.
 *
 * Returns `null` for a curator-authored term — i.e. for JSON `null`, a missing
 * key, and (defensively) for `{}`, which is what jsonlite emits for a NULL list
 * element when the `null="null"` serializer argument is lost. Also returns
 * `null` for any state outside the served public set, so a workflow state that
 * should never reach this surface degrades to "no affordance" rather than
 * leaking curation state.
 */
export function normalizeVariationProvenance(raw: unknown): NormalizedProvenance | null {
  if (!isWireRecord(raw)) return null;
  const state = asText(raw.state);
  if (state === null) return null;
  if (!(PUBLIC_PROVENANCE_STATES as readonly string[]).includes(state)) return null;

  const sourcesRaw = Array.isArray(raw.sources) ? raw.sources : [];
  return {
    state: state as PublicProvenanceState,
    maxStrength: asStrength(raw.max_strength),
    // Order is the API's (strength desc, then source_key asc). NEVER re-sorted.
    sources: sourcesRaw.filter(isWireRecord).map((src) => ({
      sourceType: asText(src.source_type),
      sourceKey: asText(src.source_key),
      strength: asStrength(src.strength),
      summary: asText(src.summary),
    })),
  };
}

// ---------------------------------------------------------------------------
// Copy
// ---------------------------------------------------------------------------

/** One-line status sentence for a served state. */
export function provenanceStatusText(state: PublicProvenanceState): string {
  return state === 'confirmed' ? 'Confirmed by a curator' : 'Not yet confirmed by a curator';
}

/**
 * Accessible name for the provenance trigger.
 *
 * State is carried in WORDS here; the glyph and the dotted underline are
 * decorative reinforcement only.
 */
export function provenanceTriggerLabel(varioName: string, state: PublicProvenanceState): string {
  const stateWords = state === 'confirmed' ? 'confirmed by a curator' : 'not confirmed';
  return `${varioName}, machine-derived, ${stateWords}. Show evidence`;
}

/** Bootstrap-icon class for a served state. */
export function provenanceGlyphClass(state: PublicProvenanceState): string {
  return state === 'confirmed' ? 'bi bi-patch-check' : 'bi bi-cpu';
}

/**
 * Display name for a source key.
 *
 * Capitalisation of a known key is presentation; an unknown key is shown
 * VERBATIM rather than being prettified into something the payload never said.
 */
const SOURCE_KEY_LABELS: Record<string, string> = {
  clinvar: 'ClinVar',
  clingen: 'ClinGen',
  gnomad: 'gnomAD',
  hgmd: 'HGMD',
  omim: 'OMIM',
  decipher: 'DECIPHER',
  synopsis: 'Clinical synopsis',
};

export function sourceDisplayName(sourceKey: string | null): string {
  if (!sourceKey) return 'Unnamed source';
  return SOURCE_KEY_LABELS[sourceKey.toLowerCase()] ?? sourceKey;
}

/** `external_database` -> `external database`; unknown values pass through. */
export function sourceTypeText(sourceType: string | null): string | null {
  if (!sourceType) return null;
  return sourceType.replace(/_/g, ' ');
}

export interface StrengthDisplay {
  recorded: boolean;
  /** Text form — always rendered, because a glyph alone is not accessible. */
  text: string;
  /** Filled star count; 0 when not recorded (and then no stars are drawn). */
  filled: number;
  total: number;
}

/**
 * Strength as text plus an optional star count.
 *
 * `null` -> `{ recorded: false, text: 'Not recorded' }` and NO stars. Rendering
 * zero stars for an unrecorded value would assert a score that was never taken.
 */
export function strengthDisplay(strength: number | null): StrengthDisplay {
  if (strength === null) {
    return { recorded: false, text: 'Not recorded', filled: 0, total: STRENGTH_SCALE_MAX };
  }
  return {
    recorded: true,
    text: `${strength} of ${STRENGTH_SCALE_MAX}`,
    filled: strength,
    total: STRENGTH_SCALE_MAX,
  };
}

// ---------------------------------------------------------------------------
// Full evidence records (the on-demand `/evidence` read)
// ---------------------------------------------------------------------------

/**
 * ClinVar deep-link for a recorded variation identifier, gated on the source.
 *
 * The link-building rule itself lives in `./variationEvidenceRecords`, where the
 * per-shape normalizers use it; this wrapper keeps the source gate that callers
 * of this module rely on, so a non-ClinVar identifier can never acquire a
 * ClinVar URL.
 */
export function clinvarVariationUrl(
  sourceKey: string | null,
  variationId: string | null
): string | null {
  if (!sourceKey || sourceKey.toLowerCase() !== 'clinvar') return null;
  return clinvarUrlFromId(variationId);
}

// Record normalization now lives in `./variationEvidenceRecords`, which
// dispatches on the source and renders all three shapes the importer writes.
// `matched` stays HERE and stays separate: it holds STRINGS (OMIM CURIEs), and
// folding it into the record-container probe would render each entry through
// `String(object)`.
const MATCHED_KEYS = ['matched', 'matched_diseases', 'matched_terms'];

function normalizeMatched(payload: unknown): string[] {
  if (!isWireRecord(payload)) return [];
  for (const key of MATCHED_KEYS) {
    const value = payload[key];
    if (Array.isArray(value)) {
      return value.map((item) => asText(item)).filter((item): item is string => item !== null);
    }
    const single = asText(value);
    if (single !== null) return [single];
  }
  return [];
}

/**
 * Format an evidence row's `created_at` as a display date, or `null`.
 *
 * The value is a MySQL `DATETIME` rendered without a zone designator (#612), so
 * it is NOT an instant: handing it to `new Date(...)` would have the engine
 * interpret it as local time and could shift the displayed date by a day for a
 * viewer in another timezone. The calendar fields are therefore read literally
 * off the leading `YYYY-MM-DD` and reassembled as a local date for formatting
 * only, which is exactly as much precision as the payload carries.
 *
 * Anything that is not a well-formed date prefix returns `null` — the dialog
 * then omits the date rather than printing something it cannot vouch for.
 */
export function formatImportedDate(value: unknown): string | null {
  const raw = asText(value);
  if (raw === null) return null;

  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw);
  if (!match) return null;

  const [, year, month, day] = match;
  const date = new Date(Number(year), Number(month) - 1, Number(day));
  if (Number.isNaN(date.getTime())) return null;
  // Reject a rolled-over date (e.g. "2026-02-31" -> 3 March) rather than
  // display a day the payload never recorded.
  if (date.getMonth() !== Number(month) - 1 || date.getDate() !== Number(day)) return null;

  return date.toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

/**
 * The parts of the dialog's "Imported" line, in display order.
 *
 * Each part is independently omitted when its value is null, so the line shows
 * exactly what the payload carries — and an empty array means the row is not
 * rendered at all rather than showing a bare label. Kept here, not in the
 * template, so the omission rules are driven by the spec instead of by nested
 * `v-if`s that have to hand-manage the separators.
 */
export function importedLineParts(evidence: NormalizedEvidence): string[] {
  const parts: string[] = [];
  if (evidence.importedOn) parts.push(evidence.importedOn);
  if (evidence.batchId) parts.push(`batch ${evidence.batchId}`);
  if (evidence.sourceVersion) parts.push(`release ${evidence.sourceVersion}`);
  return parts;
}

/** Normalize the `evidence` array of `GET …/variation/<vario>/<mod>/evidence`. */
export function normalizeEvidenceRecords(raw: unknown): NormalizedEvidence[] {
  const list = Array.isArray(raw) ? raw : [];
  // Order is the API's (recorded strength desc, then source_key asc). Not re-sorted.
  return list.filter(isWireRecord).map((row) => {
    const sourceKey = asText(row.source_key);
    return {
      sourceType: asText(row.source_type),
      sourceKey,
      batchId: asText(row.batch_id),
      sourceVersion: asText(row.source_version),
      summary: asText(row.evidence_summary),
      strength: asStrength(row.evidence_strength),
      importedOn: formatImportedDate(row.created_at),
      records: normalizeEvidenceRecordList(
        row.evidence_json,
        sourceKey,
        asText(row.source_type)
      ),
      matched: normalizeMatched(row.evidence_json),
    };
  });
}

/** The served state reported by the evidence route, or `null` if unusable. */
export function normalizeEvidenceState(raw: unknown): PublicProvenanceState | null {
  const state = asText(raw);
  if (state === null) return null;
  return (PUBLIC_PROVENANCE_STATES as readonly string[]).includes(state)
    ? (state as PublicProvenanceState)
    : null;
}
