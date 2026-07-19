// src/components/analyses/dataReleaseTable.ts
//
// Pure client-side table transform for the public /DataReleases page (#573
// Slice B, Task B2). Flattens the release LIST envelope (`ReleaseHead[]`)
// into flat rows for the `GenericTable` wrapper.
//
// Mirrors the dotted-key-flatten pattern of `normalizePhenotypeClusterRows()`
// in `phenotypeClusterTable.ts`: BootstrapVueNext's BTable renders a BLANK
// cell for any field key containing a dot (see the AGENTS.md BVN gotcha), and
// the release head's `zenodo` sub-object would otherwise force dotted access
// (`zenodo.version_doi`) that can't be bound as a flat field key. There is no
// dotted source key here (unlike the MCA stats), but the same flatten
// discipline applies to the nested `zenodo` object.
//
// Display-string formatting (byte size, the DOI "not assigned" sentinel) is
// baked directly into the row here rather than via a BTable `field.formatter`
// — `GenericDesktopTable.vue` only exposes custom cell slots for a fixed,
// hardcoded set of field keys (none of which are the release columns), so a
// per-field formatter would silently never run. Pre-formatting the row is
// the same convention already used for `ndd_score`/`percentile` in the
// NDDScore gene table.

import type { ReleaseHead } from '@/api/analysis_releases';

/** `GenericTable` fields config entry (flat keys only — see file header). */
export interface ReleaseTableField {
  key: string;
  label: string;
  sortable?: boolean;
}

/** Flat table row for one release (LIST route head — no manifest). */
export interface ReleaseTableRow {
  release_id: string;
  release_version: number;
  title: string;
  status: string;
  /** `published_at`, falling back to `created_at` when not yet published-dated. */
  published_at: string;
  source_data_version: string;
  file_count: number;
  total_bytes: number;
  /** Human-readable `total_bytes` (e.g. "1.2 MB"), via `formatReleaseBytes()`. */
  total_bytes_display: string;
  license: string;
  /** Flattened `zenodo.version_doi`; the DOI_UNASSIGNED sentinel when null. */
  zenodo_version_doi: string;
  /** Flattened `zenodo.concept_doi`; the DOI_UNASSIGNED sentinel when null. */
  zenodo_concept_doi: string;
  /** Flattened `zenodo.record_url`; the DOI_UNASSIGNED sentinel when null. */
  zenodo_record_url: string;
}

const BYTE_UNITS = ['B', 'KB', 'MB', 'GB', 'TB'] as const;

/** Sentinel shown for a `zenodo` field that has not been recorded yet (#573 DOI is additive). */
export const DOI_UNASSIGNED = '—';

/**
 * Human-readable byte size (e.g. "1.2 MB", "512 B", "1.5 KB"). Non-finite
 * (`NaN`/`Infinity`) and non-positive input degrade to "0 B" rather than
 * rendering "NaN" or indexing past the unit table.
 */
export function formatReleaseBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return '0 B';
  }
  const exponent = Math.min(
    Math.floor(Math.log(bytes) / Math.log(1024)),
    BYTE_UNITS.length - 1
  );
  const value = parseFloat((bytes / 1024 ** exponent).toFixed(1));
  return `${value} ${BYTE_UNITS[exponent]}`;
}

/** Flattens a possibly-null zenodo field to a display string. */
function doiOrDash(value: string | null | undefined): string {
  return value ? value : DOI_UNASSIGNED;
}

/**
 * `GenericTable` fields config for the releases list. Columns: Release,
 * Version, Published, Source data version, Files, Size, License, Version
 * DOI, plus a `Manifest` actions column (row selection — see
 * `views/analyses/DataReleases.vue`). No column is wired to client-side
 * sorting (the LIST route already returns newest-first); `sortable` is kept
 * optional on the type so a future column can opt in without a shape change.
 */
export const RELEASE_TABLE_FIELDS: ReleaseTableField[] = [
  { key: 'release_id', label: 'Release' },
  { key: 'release_version', label: 'Version' },
  { key: 'published_at', label: 'Published' },
  { key: 'source_data_version', label: 'Source data version' },
  { key: 'file_count', label: 'Files' },
  { key: 'total_bytes_display', label: 'Size' },
  { key: 'license', label: 'License' },
  { key: 'zenodo_version_doi', label: 'Version DOI' },
  { key: 'actions', label: 'Manifest' },
];

/**
 * Flattens the public LIST envelope's release heads into `GenericTable` rows.
 * Returns a new array; input heads are not mutated. Tolerates null/undefined
 * input (renders as an empty table rather than throwing).
 */
export function normalizeReleaseRows(
  releases: ReleaseHead[] | null | undefined
): ReleaseTableRow[] {
  return (releases || []).map((release) => ({
    release_id: release.release_id,
    release_version: release.release_version,
    title: release.title,
    status: release.status,
    published_at: release.published_at || release.created_at,
    source_data_version: release.source_data_version,
    file_count: release.file_count,
    total_bytes: release.total_bytes,
    total_bytes_display: formatReleaseBytes(release.total_bytes),
    license: release.license,
    zenodo_version_doi: doiOrDash(release.zenodo?.version_doi),
    zenodo_concept_doi: doiOrDash(release.zenodo?.concept_doi),
    zenodo_record_url: doiOrDash(release.zenodo?.record_url),
  }));
}
