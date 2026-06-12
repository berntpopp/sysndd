// Pure record-normalization and display formatters for the Manage NDDScore
// admin view. Extracted from ManageNDDScore.vue to keep the view a thinner
// shell. NDDScore is a model-derived prediction layer imported from Zenodo,
// separate from curated SysNDD evidence; these helpers only format admin
// provenance metadata.

export type NddScoreAdminRecord = Record<string, unknown>;

export function normalizeRecord(value: unknown): NddScoreAdminRecord | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as NddScoreAdminRecord;
}

export function parseRecord(value: unknown): NddScoreAdminRecord | null {
  if (typeof value === 'string') {
    try {
      return normalizeRecord(JSON.parse(value));
    } catch {
      return null;
    }
  }
  return normalizeRecord(value);
}

export function firstRawValue(
  record: NddScoreAdminRecord | null | undefined,
  keys: string[]
): unknown {
  if (!record) return undefined;
  return keys.map((key) => record[key]).find((value) => value !== null && value !== undefined);
}

export function displayValue(value: unknown): string {
  if (Array.isArray(value)) {
    return value.length === 1 ? displayValue(value[0]) : value.map(displayValue).join(', ');
  }
  if (value === null || value === undefined || value === '') return 'Not recorded';
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : 'Not recorded';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}

export function firstValue(record: NddScoreAdminRecord | null | undefined, keys: string[]): string {
  return displayValue(firstRawValue(record, keys));
}

export function formatInteger(value: unknown): string {
  const scalar = Array.isArray(value) ? value[0] : value;
  const numberValue = Number(scalar);
  return Number.isFinite(numberValue) ? numberValue.toLocaleString() : '0';
}

export function formatDate(value: unknown): string {
  const raw = displayValue(value);
  if (raw === 'Not recorded') return raw;
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? raw : parsed.toLocaleString();
}

export function humanizeKey(key: string): string {
  return key.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
}

export function statusClass(value: unknown): string {
  const normalized = displayValue(value).toLowerCase();
  if (['active', 'completed', 'success', 'succeeded'].includes(normalized)) return 'bg-success';
  if (['failed', 'error'].includes(normalized)) return 'bg-danger';
  if (['running', 'accepted', 'pending'].includes(normalized)) return 'bg-primary';
  return 'bg-secondary';
}

export function jobMode(job: NddScoreAdminRecord): string {
  const payload = parseRecord(job.request_payload_json);
  const validateOnly = firstRawValue(job, ['validate_only']) ?? payload?.validate_only;
  if (validateOnly === true || validateOnly === 'true' || validateOnly === 1)
    return 'Validate only';
  return 'Import';
}

export function jobReleaseId(job: NddScoreAdminRecord): string {
  const payload = parseRecord(job.request_payload_json);
  const result = parseRecord(firstRawValue(job, ['result_json', 'result_payload_json']));
  return displayValue(
    firstRawValue(job, ['release_id']) ??
      result?.release_id ??
      payload?.release_id ??
      payload?.record_id
  );
}

export function jobKey(job: NddScoreAdminRecord): string {
  return firstValue(job, ['job_id', 'id', 'created_at']);
}
