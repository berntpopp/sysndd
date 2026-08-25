// app/src/views/pages/components/variationEvidenceRecords.ts
//
// Shape-dispatched normalizers for `variation_ontology_evidence.evidence_json` (#612).
//
// WHY THIS EXISTS
// ---------------
// The February 2026 backfill writes THREE record shapes and the pre-#612
// normalizer understood ONE. It probed a single alias list and dropped any row
// carrying none of those keys, so:
//   * clinvar   -> id + classification + consequence, but never `stars`, even
//                  though the summary line above it says "max 2 stars";
//   * extdb2    -> `consequence` alone; mechanism, confidence, categorisation,
//                  support, disease, allelic requirement and layer all dropped;
//   * synopsis  -> NOTHING. Every row was filtered out, so a curator saw a
//                  summary line above an empty body.
// That failure is silent BY DESIGN — an unrecognised key is omitted rather than
// guessed at — which is exactly why the shapes are pinned by a fixture shared
// with the R suite and with the writing repository:
// `api/tests/testthat/fixtures/variation-evidence-record-shapes.json` (admin#16).
//
// TWO RULES CARRIED OVER FROM variationProvenance.ts
//   1. NEVER SYNTHESISE. An absent key is omitted; a placeholder that implies
//      data is the fabrication this feature exists to prevent.
//   2. A value that is NOT RECORDED is `null`, never a plausible-looking zero.
//
// The writer DROPS an empty field rather than writing null (`_clean()` returns
// None and the builders assign only non-empty values), so a record legitimately
// carries a subset of its shape's keys.
//
// This module deliberately imports only from `variationWireScalars.ts`:
// `variationProvenance.ts` imports THIS module, so importing back would create
// a cycle.

import {
  asBoolean,
  asStrength,
  asText,
  isWireRecord,
} from './variationWireScalars';

export interface EvidenceField {
  /** Raw payload key — also the label for a key we do not have a name for. */
  key: string;
  label: string;
  value: string;
}

export type NormalizedEvidenceRecord =
  | {
      kind: 'clinvar';
      variationId: string | null;
      classification: string | null;
      /** 0-4 review stars, or `null` for NOT RECORDED (never zero stars). */
      stars: number | null;
      consequence: string | null;
      url: string | null;
    }
  | { kind: 'external'; fields: EvidenceField[] }
  | {
      kind: 'literature';
      matchedText: string | null;
      /** `true` = the match was NEGATED, i.e. evidence AGAINST the term. */
      negated: boolean | null;
      pattern: string | null;
      context: string | null;
    }
  | {
      kind: 'generic';
      variationId: string | null;
      consequence: string | null;
      classification: string | null;
      url: string | null;
    };

/** Keys the ClinVar renderer reads. Asserted against the shared fixture. */
export const CLINVAR_RECORD_KEYS = [
  'id',
  'classification',
  'stars',
  'consequence',
  'url',
] as const;

/**
 * External-database fields in DISPLAY order — also the understood-key set.
 *
 * Confidence and mechanism lead because they are what a curator decides on;
 * `layer` is provenance bookkeeping and comes last.
 */
export const EXTERNAL_FIELD_ORDER = [
  'confidence',
  'mechanism',
  'categorisation',
  'consequence',
  'allelic_requirement',
  'support',
  'disease',
  'layer',
] as const;

/** Keys the literature renderer reads. Asserted against the shared fixture. */
export const LITERATURE_RECORD_KEYS = [
  'matched_text',
  'negated',
  'pattern',
  'context',
] as const;

const EXTERNAL_FIELD_LABELS: Record<string, string> = {
  confidence: 'Confidence',
  mechanism: 'Mechanism',
  categorisation: 'Categorisation',
  consequence: 'Consequence',
  allelic_requirement: 'Allelic requirement',
  support: 'Support',
  disease: 'Disease',
  layer: 'Layer',
};

// Container aliases kept from the pre-#612 normalizer. `records` is the
// canonical key both repositories agreed on; the other two are legacy probes
// that cost nothing to keep.
const RECORD_LIST_KEYS = ['records', 'variants', 'evidence_records'];

// The pre-#612 generic probe, retained verbatim as the fallback for a source
// this module does not recognise — a future batch degrades to the old
// behaviour rather than to nothing.
const GENERIC_VARIATION_ID_KEYS = ['variation_id', 'clinvar_variation_id', 'accession', 'id'];

// Legacy identifier aliases the pre-#612 normalizer probed on ANY source. The
// live ClinVar batch writes `id`, so these are not part of the fixture-asserted
// contract (CLINVAR_RECORD_KEYS) -- but they are still probed after it, because
// dropping a key that used to render is the exact regression this change exists
// to fix.
const CLINVAR_LEGACY_ID_KEYS = ['variation_id', 'clinvar_variation_id', 'accession'];
const GENERIC_CONSEQUENCE_KEYS = ['consequence', 'molecular_consequence'];
const GENERIC_CLASSIFICATION_KEYS = ['classification', 'clinical_significance', 'significance'];

function firstText(row: Record<string, unknown>, keys: readonly string[]): string | null {
  for (const key of keys) {
    const value = asText(row[key]);
    if (value !== null) return value;
  }
  return null;
}

/**
 * ClinVar deep-link for a recorded variation identifier.
 *
 * Built only from a value that is genuinely a VCV accession or a bare numeric
 * id; anything else returns `null` so the id renders as plain text rather than
 * as a link that might not resolve.
 */
export function clinvarVariationUrl(variationId: string | null): string | null {
  if (!variationId) return null;
  const match = /^(?:VCV)?0*(\d+)(?:\.\d+)?$/i.exec(variationId);
  return match ? `https://www.ncbi.nlm.nih.gov/clinvar/variation/${match[1]}/` : null;
}

function normalizeClinvarRecord(row: Record<string, unknown>): NormalizedEvidenceRecord | null {
  const variationId = asText(row.id) ?? firstText(row, CLINVAR_LEGACY_ID_KEYS);
  const classification = asText(row.classification);
  const consequence = asText(row.consequence);
  const stars = asStrength(row.stars);

  if (variationId === null && classification === null && consequence === null && stars === null) {
    return null;
  }

  return {
    kind: 'clinvar',
    variationId,
    classification,
    stars,
    consequence,
    // Prefer the stored link; fall back to one derived from the id; null when
    // neither can be produced honestly.
    url: asText(row.url) ?? clinvarVariationUrl(variationId),
  };
}

function normalizeExternalRecord(row: Record<string, unknown>): NormalizedEvidenceRecord | null {
  const fields: EvidenceField[] = [];

  for (const key of EXTERNAL_FIELD_ORDER) {
    const value = asText(row[key]);
    if (value !== null) fields.push({ key, label: EXTERNAL_FIELD_LABELS[key], value });
  }

  // An unrecognised key is shown under its RAW name rather than dropped.
  // Dropping unknown keys is precisely what produced this bug.
  for (const key of Object.keys(row)) {
    if ((EXTERNAL_FIELD_ORDER as readonly string[]).includes(key)) continue;
    const value = asText(row[key]);
    if (value !== null) fields.push({ key, label: key, value });
  }

  return fields.length > 0 ? { kind: 'external', fields } : null;
}

function normalizeLiteratureRecord(row: Record<string, unknown>): NormalizedEvidenceRecord | null {
  const matchedText = asText(row.matched_text);
  const pattern = asText(row.pattern);
  const context = asText(row.context);
  const negated = asBoolean(row.negated);

  if (matchedText === null && pattern === null && context === null && negated === null) {
    return null;
  }

  return { kind: 'literature', matchedText, negated, pattern, context };
}

function normalizeGenericRecord(row: Record<string, unknown>): NormalizedEvidenceRecord | null {
  const variationId = firstText(row, GENERIC_VARIATION_ID_KEYS);
  const consequence = firstText(row, GENERIC_CONSEQUENCE_KEYS);
  const classification = firstText(row, GENERIC_CLASSIFICATION_KEYS);

  if (variationId === null && consequence === null && classification === null) return null;

  return {
    kind: 'generic',
    variationId,
    consequence,
    classification,
    url: asText(row.url),
  };
}

/**
 * Pick the renderer for one evidence row.
 *
 * `source_key` first, `source_type` second — so a future literature corpus gets
 * the literature renderer without being named here, while an unknown external
 * database falls through to the generic probe rather than being rendered under
 * guessed labels.
 */
function normalizerFor(
  sourceKey: string | null,
  sourceType: string | null
): (row: Record<string, unknown>) => NormalizedEvidenceRecord | null {
  const key = (sourceKey ?? '').toLowerCase();
  if (key === 'clinvar') return normalizeClinvarRecord;
  if (key === 'extdb2') return normalizeExternalRecord;
  if (key === 'synopsis' || (sourceType ?? '').toLowerCase() === 'literature') {
    return normalizeLiteratureRecord;
  }
  return normalizeGenericRecord;
}

/** Normalize one evidence row's `evidence_json` into renderable records. */
export function normalizeEvidenceRecordList(
  payload: unknown,
  sourceKey: string | null,
  sourceType: string | null
): NormalizedEvidenceRecord[] {
  if (!isWireRecord(payload)) return [];

  let list: unknown[] = [];
  for (const key of RECORD_LIST_KEYS) {
    if (Array.isArray(payload[key])) {
      list = payload[key] as unknown[];
      break;
    }
  }

  const normalize = normalizerFor(sourceKey, sourceType);

  return list
    .filter(isWireRecord)
    .map(normalize)
    .filter((row): row is NormalizedEvidenceRecord => row !== null);
}
