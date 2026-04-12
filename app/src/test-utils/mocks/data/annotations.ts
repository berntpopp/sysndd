// test-utils/mocks/data/annotations.ts
/**
 * Static fixtures for the auxiliary endpoints consumed by ManageAnnotations.vue
 * that are outside the Phase B.B1 locked table: annotation dates, deprecated
 * entities, pubtator stats tables, publication stats, comparisons metadata,
 * force-apply, publication refresh, and the bare publication list.
 *
 * All scalar fields follow R/Plumber's single-element-array serialisation
 * convention (CLAUDE.md — "R/Plumber returns JSON scalars as arrays") so the
 * view's `unwrapValue()` helper (ManageAnnotations.vue §1684) parses them
 * identically to the real API.
 */

export const annotationDatesOk = {
  omim_update: [null],
  hgnc_update: [null],
  mondo_update: [null],
  disease_ontology_update: [null],
};

export const deprecatedEntitiesOk = {
  deprecated_count: [0],
  affected_entity_count: [0],
  affected_entities: [],
  mim2gene_date: [null],
  message: ['No deprecated OMIM IDs detected.'],
};

export const deprecatedEntitiesForbidden = {
  error: 'Not authorised to view deprecated entities.',
};

// Cursor-paginated envelopes used by pubtator/genes and pubtator/table.
// ManageAnnotations reads only `meta[0].totalItems`, so the data array can
// stay empty for the stub.
export const pubtatorGenesOk = {
  links: [{ self: 'null', prev: 'null', next: 'null' }],
  meta: [
    {
      perPage: 10,
      currentPage: 1,
      totalPages: 0,
      totalItems: 0,
      pageItems: 0,
    },
  ],
  data: [],
};

export const pubtatorTableOk = {
  links: [{ self: 'null', prev: 'null', next: 'null' }],
  meta: [
    {
      perPage: 10,
      currentPage: 1,
      totalPages: 0,
      totalItems: 0,
      pageItems: 0,
    },
  ],
  data: [],
};

export const publicationStatsOk = {
  total: [0],
  oldest_update: [null],
  outdated_count: [0],
  filtered_count: [null],
};

export const comparisonsMetadataOk = {
  last_full_refresh: [null],
  last_refresh_status: ['never'],
  last_refresh_error: [null],
  sources_count: [0],
  rows_imported: [0],
};

export const publicationListOk = {
  links: [{ self: 'null', prev: 'null', next: 'null' }],
  meta: [
    {
      perPage: 10000,
      currentPage: 1,
      totalPages: 0,
      totalItems: 0,
      pageItems: 0,
    },
  ],
  data: [],
};

// PUT /api/admin/update_ontology_async — success and blocked-admin paths.
export const updateOntologyAsyncOk = {
  message: 'Ontology update job submitted.',
  job_id: ['ontology-update-2025-07-01'],
  status: ['accepted'],
};

export const updateOntologyAsyncForbidden = {
  error: 'Ontology update forbidden for non-admin.',
};

// PUT /api/admin/force_apply_ontology — success, missing blocked_job_id, and
// stale-CSV branches.
export const forceApplyOntologyOk = {
  message: 'Force-apply ontology job submitted.',
  job_id: ['force-apply-ontology-2025-07-01'],
  status: ['accepted'],
};

export const forceApplyOntologyBadRequest = {
  error: 'blocked_job_id query parameter is required',
};

// POST /api/admin/publications/refresh — success, missing payload, and
// already_running branches.
export const publicationsRefreshOk = {
  message: 'Publication refresh job submitted.',
  job_id: ['publication-refresh-2025-07-01'],
  status: ['accepted'],
  estimated_seconds: [30],
};

export const publicationsRefreshBadRequest = {
  error: 'No PMIDs provided and no date filter specified',
};
