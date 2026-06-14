// composables/annotations/annotationsConfirmCopy.ts
//
// Confirmation copy for the heavy / irreversible annotation operations on the
// ManageAnnotations page. Kept out of the (oversized) SFC; consumed via
// useConfirmGate + ConfirmActionModal.

import type { ConfirmGateConfig } from '@/composables/useConfirmGate';

export const ONTOLOGY_UPDATE_CONFIRM: ConfirmGateConfig = {
  title: 'Update ontology annotations?',
  message:
    'This starts a background job that refreshes OMIM / MONDO / Disease Ontology ' +
    'annotations and may auto-fix affected entity versions. Continue?',
  confirmLabel: 'Update ontology',
  confirmVariant: 'warning',
};

export const FORCE_APPLY_CONFIRM: ConfirmGateConfig = {
  title: 'Force-apply blocked ontology update?',
  message:
    'Force-applying overrides the critical-change safety block, applies the new ontology, ' +
    'and creates a re-review batch for the affected entities. This cannot be undone. Continue?',
  confirmLabel: 'Force-apply',
  confirmVariant: 'danger',
};

export const COMPARISONS_REFRESH_CONFIRM: ConfirmGateConfig = {
  title: 'Refresh comparisons data?',
  message: 'This starts a background job that rebuilds the external database comparison tables. Continue?',
  confirmLabel: 'Refresh comparisons',
  confirmVariant: 'warning',
};

export const REFRESH_ALL_PUBLICATIONS_CONFIRM: ConfirmGateConfig = {
  title: 'Refresh all publications?',
  message:
    'This re-fetches metadata for the entire publication corpus from PubMed. It is ' +
    'rate-limited and may take a long time to complete. Continue?',
  confirmLabel: 'Refresh all',
  confirmVariant: 'warning',
};
