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
//    importer never recorded one, and the evidence route does NOT return an
//    import timestamp (`variation_ontology_evidence.created_at` is deliberately
//    not selected by svc_entity_variation_evidence()) — so no date is rendered
//    either. A field that is absent is omitted; a placeholder that implies data
//    is exactly the fabrication this feature exists to prevent.
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

/** States the public read may ever carry. `suggested`/`rejected` never appear. */
export const PUBLIC_PROVENANCE_STATES = ['active_unconfirmed', 'confirmed'] as const;
export type PublicProvenanceState = (typeof PUBLIC_PROVENANCE_STATES)[number];

/** Highest strength the 0-4 comparability scale can take. */
export const STRENGTH_SCALE_MAX = 4;

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

export interface NormalizedEvidenceRecordRow {
  /** Source-recorded variation identifier, e.g. a ClinVar `VCV…` accession. */
  variationId: string | null;
  consequence: string | null;
  classification: string | null;
  /** External deep-link, or null when none can be built honestly. */
  url: string | null;
}

export interface NormalizedEvidence {
  sourceType: string | null;
  sourceKey: string | null;
  batchId: string | null;
  sourceVersion: string | null;
  summary: string | null;
  strength: number | null;
  records: NormalizedEvidenceRecordRow[];
  matched: string[];
}

// ---------------------------------------------------------------------------
// Wire-shape helpers
// ---------------------------------------------------------------------------

/**
 * Unwrap plumber's length-1 array around a value that is contractually scalar.
 *
 * Only ever call this on a field documented as a scalar. Length-1 arrays that
 * are genuinely arrays (`sources`, `evidence`, `records`) must not pass through.
 */
export function unwrapScalar(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.length === 1 ? value[0] : undefined;
  }
  return value;
}

function asText(value: unknown): string | null {
  const raw = unwrapScalar(value);
  if (raw === null || raw === undefined) return null;
  const text = String(raw).trim();
  return text === '' ? null : text;
}

/**
 * A recorded 0-4 strength, or `null` for "not recorded".
 *
 * Anything non-finite or out of range is treated as not recorded rather than
 * being clamped into a plausible-looking score.
 */
function asStrength(value: unknown): number | null {
  const raw = unwrapScalar(value);
  if (raw === null || raw === undefined || raw === '') return null;
  const n = Number(raw);
  if (!Number.isFinite(n) || !Number.isInteger(n) || n < 0 || n > STRENGTH_SCALE_MAX) return null;
  return n;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

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
  if (!isRecord(raw)) return null;
  const state = asText(raw.state);
  if (state === null) return null;
  if (!(PUBLIC_PROVENANCE_STATES as readonly string[]).includes(state)) return null;

  const sourcesRaw = Array.isArray(raw.sources) ? raw.sources : [];
  return {
    state: state as PublicProvenanceState,
    maxStrength: asStrength(raw.max_strength),
    // Order is the API's (strength desc, then source_key asc). NEVER re-sorted.
    sources: sourcesRaw.filter(isRecord).map((src) => ({
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

// Keys the import manifests are documented to carry (design spec §7.3: ClinVar
// variation id, classification, review stars, consequence, matched identifiers).
// The manifests are produced in a different repository, so each field is probed
// through a small alias list and OMITTED when absent — the safe failure
// direction. A key we do not recognise is never rendered under a guessed label.
const RECORD_LIST_KEYS = ['records', 'variants', 'evidence_records'];
const VARIATION_ID_KEYS = ['variation_id', 'clinvar_variation_id', 'accession', 'id'];
const CONSEQUENCE_KEYS = ['consequence', 'molecular_consequence'];
const CLASSIFICATION_KEYS = ['classification', 'clinical_significance', 'significance'];
const MATCHED_KEYS = ['matched', 'matched_diseases', 'matched_terms'];

function firstText(row: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const text = asText(row[key]);
    if (text !== null) return text;
  }
  return null;
}

/**
 * ClinVar deep-link for a recorded variation identifier.
 *
 * Built only for the `clinvar` source and only from a value that is genuinely a
 * VCV accession or a bare numeric id; anything else returns `null` so the id
 * renders as plain text instead of a link that might not resolve.
 */
export function clinvarVariationUrl(
  sourceKey: string | null,
  variationId: string | null
): string | null {
  if (!sourceKey || sourceKey.toLowerCase() !== 'clinvar' || !variationId) return null;
  const match = /^(?:VCV)?0*(\d+)(?:\.\d+)?$/i.exec(variationId);
  if (!match) return null;
  return `https://www.ncbi.nlm.nih.gov/clinvar/variation/${match[1]}/`;
}

function normalizeRecordRows(
  payload: unknown,
  sourceKey: string | null
): NormalizedEvidenceRecordRow[] {
  if (!isRecord(payload)) return [];
  let list: unknown[] = [];
  for (const key of RECORD_LIST_KEYS) {
    if (Array.isArray(payload[key])) {
      list = payload[key] as unknown[];
      break;
    }
  }
  return (
    list
      .filter(isRecord)
      .map((row) => {
        const variationId = firstText(row, VARIATION_ID_KEYS);
        return {
          variationId,
          consequence: firstText(row, CONSEQUENCE_KEYS),
          classification: firstText(row, CLASSIFICATION_KEYS),
          url: clinvarVariationUrl(sourceKey, variationId),
        };
      })
      // A row that carries none of the documented fields would render as an empty
      // bullet — omit it rather than implying an unnamed record exists.
      .filter((row) => row.variationId || row.consequence || row.classification)
  );
}

function normalizeMatched(payload: unknown): string[] {
  if (!isRecord(payload)) return [];
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

/** Normalize the `evidence` array of `GET …/variation/<vario>/<mod>/evidence`. */
export function normalizeEvidenceRecords(raw: unknown): NormalizedEvidence[] {
  const list = Array.isArray(raw) ? raw : [];
  // Order is the API's (recorded strength desc, then source_key asc). Not re-sorted.
  return list.filter(isRecord).map((row) => {
    const sourceKey = asText(row.source_key);
    return {
      sourceType: asText(row.source_type),
      sourceKey,
      batchId: asText(row.batch_id),
      sourceVersion: asText(row.source_version),
      summary: asText(row.evidence_summary),
      strength: asStrength(row.evidence_strength),
      records: normalizeRecordRows(row.evidence_json, sourceKey),
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
