// Derived display rows for the Manage NDDScore admin view (active-release KPI
// counts, provenance rows, performance summary, and Zenodo comparison fields).
// Extracted from ManageNDDScore.vue so the view stays a thinner shell; these
// only present admin provenance for the model-derived prediction release.

import { computed, type ComputedRef, type Ref } from 'vue';
import type { NddScoreZenodoComparison } from '@/api/nddscore_admin';
import {
  normalizeRecord,
  parseRecord,
  firstRawValue,
  firstValue,
  displayValue,
  formatInteger,
  formatDate,
  humanizeKey,
  type NddScoreAdminRecord,
} from './nddScoreAdminFormatters';

export interface NddScoreCountItem {
  key: string;
  label: string;
  value: string;
}

export interface NddScoreDetailRow {
  label: string;
  value: string;
  mono: boolean;
}

export interface NddScorePerformanceRow {
  label: string;
  value: string;
}

export interface UseNddScoreAdminDerivedRows {
  activeReleaseStatus: ComputedRef<string>;
  countItems: ComputedRef<NddScoreCountItem[]>;
  releaseRows: ComputedRef<NddScoreDetailRow[]>;
  performanceRows: ComputedRef<NddScorePerformanceRow[]>;
  zenodoArchiveName: ComputedRef<string>;
  zenodoChecksum: ComputedRef<string>;
}

export function useNddScoreAdminDerivedRows(
  activeRelease: Ref<NddScoreAdminRecord | null>,
  zenodoResult: Ref<NddScoreZenodoComparison | null>,
  loadingStatus: Ref<boolean>
): UseNddScoreAdminDerivedRows {
  const activeReleaseStatus = computed(() => {
    if (loadingStatus.value) return 'Loading';
    if (!activeRelease.value) return 'No active release';
    return displayValue(activeRelease.value.import_status);
  });

  const countItems = computed<NddScoreCountItem[]>(() => [
    {
      key: 'genes',
      label: 'Genes',
      value: formatInteger(activeRelease.value?.n_genes),
    },
    {
      key: 'hpo-predictions',
      label: 'HPO predictions',
      value: formatInteger(activeRelease.value?.n_hpo_predictions),
    },
    {
      key: 'hpo-terms',
      label: 'HPO terms',
      value: formatInteger(activeRelease.value?.n_hpo_terms),
    },
  ]);

  const releaseRows = computed<NddScoreDetailRow[]>(() => [
    {
      label: 'Version DOI',
      value: displayValue(activeRelease.value?.version_doi),
      mono: true,
    },
    {
      label: 'Concept DOI',
      value: displayValue(activeRelease.value?.concept_doi),
      mono: true,
    },
    {
      label: 'Archive',
      value: firstValue(activeRelease.value, [
        'source_archive_name',
        'archive_name',
        'zenodo_archive_name',
      ]),
      mono: true,
    },
    {
      label: 'Checksum',
      value: firstValue(activeRelease.value, [
        'source_archive_checksum',
        'archive_checksum',
        'checksum',
      ]),
      mono: true,
    },
    {
      label: 'Activated',
      value: formatDate(activeRelease.value?.activated_at),
      mono: false,
    },
    {
      label: 'Imported',
      value: formatDate(firstValue(activeRelease.value, ['import_completed_at', 'imported_at'])),
      mono: false,
    },
  ]);

  const performanceRows = computed<NddScorePerformanceRow[]>(() => {
    const raw = firstRawValue(activeRelease.value, ['ndd_performance_json', 'performance_summary']);
    const record = parseRecord(raw);
    if (!record) return [];

    return Object.entries(record).map(([key, value]) => ({
      label: humanizeKey(key),
      value: displayValue(value),
    }));
  });

  const zenodoArchiveName = computed(() =>
    firstValue(normalizeRecord(zenodoResult.value?.zenodo), [
      'source_archive_name',
      'archive_name',
      'filename',
      'name',
    ])
  );

  const zenodoChecksum = computed(() =>
    firstValue(normalizeRecord(zenodoResult.value?.zenodo), [
      'archive_md5',
      'source_archive_checksum',
      'archive_checksum',
      'checksum',
    ])
  );

  return {
    activeReleaseStatus,
    countItems,
    releaseRows,
    performanceRows,
    zenodoArchiveName,
    zenodoChecksum,
  };
}
