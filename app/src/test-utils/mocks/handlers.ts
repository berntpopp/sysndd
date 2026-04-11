// test-utils/mocks/handlers.ts
/**
 * MSW request handlers for API mocking in tests.
 *
 * Phase B.B1 (v11.0): handler set expanded to cover the locked table for every
 * real axios call site in the six top curate/admin views — see
 * `.plans/v11.0/phase-b.md` §3 Phase B.B1.  Each handler is documented with the
 * OpenAPI path it mirrors (§4.3) so the static verifier
 * (`scripts/verify-msw-against-openapi.sh`) can cross-reference the handler
 * against `api/endpoints/*.R` annotations.
 *
 * 2xx / 4xx selection: each handler returns its declared 2xx happy-path shape
 * by default and branches to a 4xx shape when the request carries a
 * distinguishable error trigger (a sentinel path param, query, or request-body
 * field — e.g. `id === '999'`, `?trigger_error=1`, or `{ user_name: '' }`).
 * Tests that want the error branch can either hit the sentinel shape directly
 * or call `server.use(...)` to install a per-test override.
 *
 * Adding a new handler?  Follow the same pattern:
 *   1. Add the fixture to `data/<family>.ts` (≤300 LoC per file).
 *   2. Add the handler here with a `// OpenAPI: <METHOD> /api/<path>` comment.
 *   3. Add a smoke test to `handlers.spec.ts` covering 2xx and 4xx.
 *   4. Run `scripts/verify-msw-against-openapi.sh` to confirm the underlying
 *      plumber annotation exists in `api/endpoints/*.R`.
 *
 * @example
 * // In a test file, override a handler:
 * import { http, HttpResponse } from 'msw';
 * import { server } from '@/test-utils/mocks/server';
 *
 * it('handles error response', async () => {
 *   server.use(
 *     http.get('/api/entity/:id', () => {
 *       return HttpResponse.json({ error: 'Not found' }, { status: 404 });
 *     })
 *   );
 *   // ... test error handling
 * });
 */

import { http, HttpResponse } from 'msw';

// ---------------------------------------------------------------------------
// Error trigger sentinels (self-review S1 on PR #236)
// ---------------------------------------------------------------------------
// Every handler in this file branches from its 2xx happy path to a 4xx error
// shape when the incoming request carries one of these distinguished shapes.
// Keeping them in one place lets tests import them (instead of hard-coding
// literals scattered across specs) and makes the contract between handlers
// and spec files discoverable. Handlers and specs currently use the literal
// values below; future handlers/specs SHOULD import from here.
//
// Usage from a spec file:
//   import { ERROR_SENTINELS } from '@/test-utils/mocks/handlers';
//   await fetch(`/api/entity/${ERROR_SENTINELS.NOT_FOUND_ID}`); // → 404
export const ERROR_SENTINELS = {
  /** Path-param sentinel that triggers a 404. Used by entity/review/status endpoints. */
  NOT_FOUND_ID: '999',
  /** POST /api/auth/authenticate user_name that triggers a 401. */
  WRONG_USER: 'wrong_user',
  /** Query string that triggers a 500-class error on endpoints that opt in. */
  TRIGGER_ERROR_QUERY: 'trigger_error=1',
  /** Authorization header that triggers 401 (omit header entirely instead of setting this). */
  NO_AUTH_HEADER: '',
  /** x-user-role header that triggers 403 on endpoints that branch on role. */
  VIEWER_ROLE: 'Viewer',
} as const;

import {
  signinOk,
  signinUnauthorized,
  authenticateTokenOk,
  authenticateBadRequest,
  authenticateUnauthorized,
  refreshTokenOk,
  refreshTokenUnauthorized,
} from './data/auth';
import {
  userTableOk,
  userListOk,
  userRoleListOk,
  userUpdateOk,
  userUpdateForbidden,
  userDeleteOk,
  userDeleteNotFound,
  bulkApproveOk,
  bulkApproveBadRequest,
  bulkAssignRoleOk,
  bulkAssignRoleBadRequest,
  bulkDeleteOk,
  bulkDeleteBadRequest,
  passwordUpdateOk,
  passwordUpdateConflict,
} from './data/users';
import {
  reviewByIdOk,
  reviewByIdNotFound,
  reviewPhenotypesOk,
  reviewPhenotypesNotFound,
  reviewVariationOk,
  reviewVariationNotFound,
  reviewPublicationsOk,
  reviewPublicationsNotFound,
  reviewCreateOk,
  reviewCreateBadRequest,
  reviewUpdateOk,
  reviewUpdateBadRequest,
  reviewApproveByIdOk,
  reviewApproveByIdNotFound,
  reviewApproveAllOk,
  reviewApproveAllForbidden,
} from './data/reviews';
import {
  statusByIdOk,
  statusByIdNotFound,
  statusCreateOk,
  statusCreateBadRequest,
  statusUpdateOk,
  statusUpdateBadRequest,
  statusApproveByIdOk,
  statusApproveByIdNotFound,
  statusApproveAllOk,
  statusApproveAllForbidden,
} from './data/statuses';
import {
  entityByIdOk,
  entityByIdNotFound,
  entityCreateOk,
  entityCreateBadRequest,
  entityRenameOk,
  entityRenameBadRequest,
  entityDeactivateOk,
  entityDeactivateBadRequest,
  entityReviewListOk,
  entityReviewListNotFound,
  entityStatusListOk,
  entityStatusListNotFound,
} from './data/entities';
import {
  jobsHistoryOk,
  jobsHistoryForbidden,
  jobStatusOk,
  jobStatusNotFound,
  hgncUpdateSubmitOk,
  hgncUpdateSubmitForbidden,
  ontologyUpdateSubmitOk,
  ontologyUpdateSubmitForbidden,
  comparisonsUpdateSubmitOk,
  comparisonsUpdateSubmitForbidden,
  clusteringSubmitOk,
  clusteringSubmitBadRequest,
  phenotypeClusteringSubmitOk,
  phenotypeClusteringSubmitBadRequest,
} from './data/jobs';

/**
 * Parse a JSON body from a request, returning an empty object on failure.
 * Handlers can then probe fields (e.g. `body.user_name`) for 4xx triggers
 * without worrying about parse errors.
 */
const readJsonBody = async (request: Request): Promise<Record<string, unknown>> => {
  try {
    const parsed = await request.clone().json();
    if (parsed && typeof parsed === 'object') {
      return parsed as Record<string, unknown>;
    }
    return {};
  } catch {
    return {};
  }
};

/**
 * Default handlers for the curate/admin view axios call sites (Phase B.B1).
 */
export const handlers = [
  // ---------------------------------------------------------------------------
  // Auth (post Phase A1 shapes)
  // ---------------------------------------------------------------------------

  // OpenAPI: POST /api/auth/authenticate
  // api/endpoints/authentication_endpoints.R @post authenticate
  // Body: { user_name: string, password: string }  (A1: JSON body, not query)
  http.post('/api/auth/authenticate', async ({ request }) => {
    const body = await readJsonBody(request);
    const userName = typeof body.user_name === 'string' ? body.user_name : '';
    const password = typeof body.password === 'string' ? body.password : '';

    if (userName.length < 5 || userName.length > 20 || password.length < 5 || password.length > 50) {
      return HttpResponse.text(authenticateBadRequest, { status: 400 });
    }
    if (userName === 'wrong_user' || password === 'wrong_pass') {
      return HttpResponse.text(authenticateUnauthorized, { status: 401 });
    }
    return HttpResponse.json(authenticateTokenOk);
  }),

  // OpenAPI: GET /api/auth/refresh
  // api/endpoints/authentication_endpoints.R @get refresh
  http.get('/api/auth/refresh', ({ request }) => {
    if (!request.headers.get('authorization')) {
      return HttpResponse.json(refreshTokenUnauthorized, { status: 401 });
    }
    return HttpResponse.json(refreshTokenOk);
  }),

  // OpenAPI: GET /api/auth/signin
  // api/endpoints/authentication_endpoints.R @get signin
  http.get('/api/auth/signin', ({ request }) => {
    if (!request.headers.get('authorization')) {
      return HttpResponse.json(signinUnauthorized, { status: 401 });
    }
    return HttpResponse.json(signinOk);
  }),

  // ---------------------------------------------------------------------------
  // User admin  (ManageUser.vue)
  // ---------------------------------------------------------------------------

  // OpenAPI: GET /api/user/table
  // api/endpoints/user_endpoints.R @get table
  http.get('/api/user/table', ({ request }) => {
    const url = new URL(request.url);
    if (url.searchParams.get('trigger_error') === '1') {
      return HttpResponse.json({ error: 'Invalid table query.' }, { status: 400 });
    }
    return HttpResponse.json(userTableOk);
  }),

  // OpenAPI: GET /api/user/role_list
  // api/endpoints/user_endpoints.R @get role_list
  http.get('/api/user/role_list', ({ request }) => {
    if (!request.headers.get('authorization')) {
      return HttpResponse.json({ error: 'Not authorised.' }, { status: 401 });
    }
    return HttpResponse.json(userRoleListOk);
  }),

  // OpenAPI: GET /api/user/list
  // api/endpoints/user_endpoints.R @get list
  http.get('/api/user/list', ({ request }) => {
    if (!request.headers.get('authorization')) {
      return HttpResponse.json({ error: 'Not authorised.' }, { status: 401 });
    }
    return HttpResponse.json(userListOk);
  }),

  // OpenAPI: PUT /api/user/update
  // api/endpoints/user_endpoints.R @put update
  // Body: { user_id: number, ... }
  http.put('/api/user/update', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.user_id || body.user_id === 0) {
      return HttpResponse.json(userUpdateForbidden, { status: 403 });
    }
    return HttpResponse.json(userUpdateOk);
  }),

  // OpenAPI: PUT /api/user/delete  (SPEC BUG — real annotation is @delete delete;
  //                                 see scripts/msw-openapi-exceptions.txt)
  // api/endpoints/user_endpoints.R @delete delete (at line 773)
  http.put('/api/user/delete', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.user_id || body.user_id === 999) {
      return HttpResponse.json(userDeleteNotFound, { status: 404 });
    }
    return HttpResponse.json(userDeleteOk);
  }),

  // OpenAPI: POST /api/user/bulk_approve
  // api/endpoints/user_endpoints.R @post bulk_approve
  // Body: { user_ids: number[] }
  http.post('/api/user/bulk_approve', async ({ request }) => {
    const body = await readJsonBody(request);
    const ids = Array.isArray(body.user_ids) ? body.user_ids : [];
    if (ids.length === 0) {
      return HttpResponse.json(bulkApproveBadRequest, { status: 400 });
    }
    return HttpResponse.json(bulkApproveOk);
  }),

  // OpenAPI: POST /api/user/bulk_assign_role
  // api/endpoints/user_endpoints.R @post bulk_assign_role
  // Body: { user_ids: number[], user_role: string }
  http.post('/api/user/bulk_assign_role', async ({ request }) => {
    const body = await readJsonBody(request);
    const ids = Array.isArray(body.user_ids) ? body.user_ids : [];
    const role = typeof body.user_role === 'string' ? body.user_role : '';
    if (ids.length === 0 || role === '') {
      return HttpResponse.json(bulkAssignRoleBadRequest, { status: 400 });
    }
    return HttpResponse.json(bulkAssignRoleOk);
  }),

  // OpenAPI: POST /api/user/bulk_delete
  // api/endpoints/user_endpoints.R @post bulk_delete
  // Body: { user_ids: number[] }
  http.post('/api/user/bulk_delete', async ({ request }) => {
    const body = await readJsonBody(request);
    const ids = Array.isArray(body.user_ids) ? body.user_ids : [];
    if (ids.length === 0) {
      return HttpResponse.json(bulkDeleteBadRequest, { status: 400 });
    }
    return HttpResponse.json(bulkDeleteOk);
  }),

  // OpenAPI: PUT /api/user/password/update
  // api/endpoints/user_endpoints.R @put password/update  (Phase A1 body shape)
  // Body: { user_id_pass_change: number, old_pass: string,
  //         new_pass_1: string, new_pass_2: string }
  http.put('/api/user/password/update', async ({ request }) => {
    const body = await readJsonBody(request);
    const id = typeof body.user_id_pass_change === 'number' ? body.user_id_pass_change : 0;
    const oldPass = typeof body.old_pass === 'string' ? body.old_pass : '';
    const newPass1 = typeof body.new_pass_1 === 'string' ? body.new_pass_1 : '';
    const newPass2 = typeof body.new_pass_2 === 'string' ? body.new_pass_2 : '';

    if (id === 0 || oldPass === '' || newPass1 === '' || newPass1 !== newPass2) {
      return HttpResponse.json(passwordUpdateConflict, { status: 409 });
    }
    return HttpResponse.json(passwordUpdateOk, { status: 201 });
  }),

  // ---------------------------------------------------------------------------
  // Review workflow  (ApproveReview.vue, Review.vue)
  // ---------------------------------------------------------------------------

  // OpenAPI: GET /api/review/:id
  // api/endpoints/review_endpoints.R @get /<review_id_requested>
  //
  // Wire shape note (Phase C batch review Q3 FAIL fix): the real R/Plumber
  // endpoint returns a 1-row array, not a bare object — `loadReviewInfo` in
  // `ApproveReview.vue` indexes `response.data[0].synopsis`. The fixture type
  // `ReviewRow` stays as a bare object for direct-import consumers (spec
  // field references), but the handler wraps it in an array to match the
  // real API wire contract.
  http.get('/api/review/:id', ({ params }) => {
    if (params.id === '999') {
      return HttpResponse.json(reviewByIdNotFound, { status: 404 });
    }
    return HttpResponse.json([reviewByIdOk]);
  }),

  // OpenAPI: GET /api/review/:id/phenotypes
  // api/endpoints/review_endpoints.R @get /<review_id_requested>/phenotypes
  http.get('/api/review/:id/phenotypes', ({ params }) => {
    if (params.id === '999') {
      return HttpResponse.json(reviewPhenotypesNotFound, { status: 404 });
    }
    return HttpResponse.json(reviewPhenotypesOk);
  }),

  // OpenAPI: GET /api/review/:id/variation
  // api/endpoints/review_endpoints.R @get /<review_id_requested>/variation
  http.get('/api/review/:id/variation', ({ params }) => {
    if (params.id === '999') {
      return HttpResponse.json(reviewVariationNotFound, { status: 404 });
    }
    return HttpResponse.json(reviewVariationOk);
  }),

  // OpenAPI: GET /api/review/:id/publications
  // api/endpoints/review_endpoints.R @get /<review_id_requested>/publications
  http.get('/api/review/:id/publications', ({ params }) => {
    if (params.id === '999') {
      return HttpResponse.json(reviewPublicationsNotFound, { status: 404 });
    }
    return HttpResponse.json(reviewPublicationsOk);
  }),

  // OpenAPI: POST /api/review/create
  // api/endpoints/review_endpoints.R @post /create
  http.post('/api/review/create', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.entity_id || !body.synopsis) {
      return HttpResponse.json(reviewCreateBadRequest, { status: 400 });
    }
    return HttpResponse.json(reviewCreateOk, { status: 201 });
  }),

  // OpenAPI: PUT /api/review/update
  // api/endpoints/review_endpoints.R @put /update
  http.put('/api/review/update', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.review_id) {
      return HttpResponse.json(reviewUpdateBadRequest, { status: 400 });
    }
    return HttpResponse.json(reviewUpdateOk);
  }),

  // OpenAPI: PUT /api/review/approve/all  (SPEC BUG — no bulk approve endpoint
  //                                        exists in review_endpoints.R; see
  //                                        scripts/msw-openapi-exceptions.txt)
  // Registered BEFORE `/approve/:id` so the literal match wins over the
  // parameterised one in MSW's first-match-wins ordering.
  http.put('/api/review/approve/all', ({ request }) => {
    if (request.headers.get('x-user-role') === 'Viewer') {
      return HttpResponse.json(reviewApproveAllForbidden, { status: 403 });
    }
    return HttpResponse.json(reviewApproveAllOk);
  }),

  // OpenAPI: PUT /api/review/approve/:id
  // api/endpoints/review_endpoints.R @put /approve/<review_id_requested>
  http.put('/api/review/approve/:id', ({ params }) => {
    if (params.id === '999') {
      return HttpResponse.json(reviewApproveByIdNotFound, { status: 404 });
    }
    return HttpResponse.json(reviewApproveByIdOk);
  }),

  // ---------------------------------------------------------------------------
  // Status workflow  (ApproveStatus.vue, ApproveReview.vue)
  // ---------------------------------------------------------------------------

  // OpenAPI: GET /api/status/:id
  // api/endpoints/status_endpoints.R @get /<status_id_requested>
  //
  // Wire shape note (Phase C batch review Q3 FAIL fix): same R/Plumber
  // 1-row-array convention as GET /api/review/:id above. `loadStatusInfo`
  // in `ApproveStatus.vue` indexes `response.data[0].category_id`.
  http.get('/api/status/:id', ({ params }) => {
    if (params.id === '999') {
      return HttpResponse.json(statusByIdNotFound, { status: 404 });
    }
    return HttpResponse.json([statusByIdOk]);
  }),

  // OpenAPI: POST /api/status/create
  // api/endpoints/status_endpoints.R @post /create
  http.post('/api/status/create', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.entity_id || !body.category_id) {
      return HttpResponse.json(statusCreateBadRequest, { status: 400 });
    }
    return HttpResponse.json(statusCreateOk, { status: 201 });
  }),

  // OpenAPI: PUT /api/status/update
  // api/endpoints/status_endpoints.R @put /update
  http.put('/api/status/update', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.status_id) {
      return HttpResponse.json(statusUpdateBadRequest, { status: 400 });
    }
    return HttpResponse.json(statusUpdateOk);
  }),

  // OpenAPI: PUT /api/status/approve/all  (SPEC BUG — no bulk approve endpoint
  //                                        exists in status_endpoints.R; see
  //                                        scripts/msw-openapi-exceptions.txt)
  // Registered BEFORE `/approve/:id` so the literal match wins over the
  // parameterised one in MSW's first-match-wins ordering.
  http.put('/api/status/approve/all', ({ request }) => {
    if (request.headers.get('x-user-role') === 'Viewer') {
      return HttpResponse.json(statusApproveAllForbidden, { status: 403 });
    }
    return HttpResponse.json(statusApproveAllOk);
  }),

  // OpenAPI: PUT /api/status/approve/:id
  // api/endpoints/status_endpoints.R @put /approve/<status_id_requested>
  http.put('/api/status/approve/:id', ({ params }) => {
    if (params.id === '999') {
      return HttpResponse.json(statusApproveByIdNotFound, { status: 404 });
    }
    return HttpResponse.json(statusApproveByIdOk);
  }),

  // ---------------------------------------------------------------------------
  // Entity curation  (ModifyEntity.vue, Review.vue)
  // ---------------------------------------------------------------------------

  // OpenAPI: GET /api/entity/:sysndd_id  (SPEC BUG — no bare @get /<sysndd_id>
  //                                        annotation exists in
  //                                        entity_endpoints.R; only `/` and
  //                                        `/<sysndd_id>/<sub>`. See
  //                                        scripts/msw-openapi-exceptions.txt)
  http.get('/api/entity/:sysndd_id', ({ params }) => {
    if (params.sysndd_id === '999') {
      return HttpResponse.json(entityByIdNotFound, { status: 404 });
    }
    return HttpResponse.json(entityByIdOk);
  }),

  // OpenAPI: POST /api/entity/create
  // api/endpoints/entity_endpoints.R @post /create
  http.post('/api/entity/create', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.hgnc_id || !body.disease_ontology_id_version) {
      return HttpResponse.json(entityCreateBadRequest, { status: 400 });
    }
    return HttpResponse.json(entityCreateOk, { status: 201 });
  }),

  // OpenAPI: POST /api/entity/rename
  // api/endpoints/entity_endpoints.R @post /rename  (line 408-419)
  //
  // Wire shape fix (Phase C batch review Q3 FAIL): the real endpoint reads
  // `req$argsBody$rename_json$entity$entity_id`, NOT a flat
  // `{sysndd_id, new_symbol}` body. The old handler would 400 every legit
  // request because `body.sysndd_id` is always undefined on the real wire.
  // The new validation mirrors the real endpoint: the payload envelope is
  // `{ rename_json: { entity: { entity_id, ... } } }`. For backwards
  // compatibility with any spec that still uses the flat form (none on
  // master), we accept either shape.
  http.post('/api/entity/rename', async ({ request }) => {
    const body = await readJsonBody(request);
    const entity = body?.rename_json?.entity;
    const hasNewWireShape = entity && entity.entity_id;
    const hasLegacyFlatShape = body?.sysndd_id && body?.new_symbol;
    if (!hasNewWireShape && !hasLegacyFlatShape) {
      return HttpResponse.json(entityRenameBadRequest, { status: 400 });
    }
    return HttpResponse.json(entityRenameOk);
  }),

  // OpenAPI: POST /api/entity/deactivate
  // api/endpoints/entity_endpoints.R @post /deactivate
  http.post('/api/entity/deactivate', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.sysndd_id) {
      return HttpResponse.json(entityDeactivateBadRequest, { status: 400 });
    }
    return HttpResponse.json(entityDeactivateOk);
  }),

  // OpenAPI: GET /api/entity/:sysndd_id/review
  // api/endpoints/entity_endpoints.R @get /<sysndd_id>/review
  http.get('/api/entity/:sysndd_id/review', ({ params }) => {
    if (params.sysndd_id === '999') {
      return HttpResponse.json(entityReviewListNotFound, { status: 404 });
    }
    return HttpResponse.json(entityReviewListOk);
  }),

  // OpenAPI: GET /api/entity/:sysndd_id/status
  // api/endpoints/entity_endpoints.R @get /<sysndd_id>/status
  http.get('/api/entity/:sysndd_id/status', ({ params }) => {
    if (params.sysndd_id === '999') {
      return HttpResponse.json(entityStatusListNotFound, { status: 404 });
    }
    return HttpResponse.json(entityStatusListOk);
  }),

  // ---------------------------------------------------------------------------
  // Annotation jobs  (ManageAnnotations.vue)
  // ---------------------------------------------------------------------------

  // OpenAPI: GET /api/jobs/history
  // api/endpoints/jobs_endpoints.R @get /history
  http.get('/api/jobs/history', ({ request }) => {
    if (request.headers.get('x-user-role') === 'Viewer') {
      return HttpResponse.json(jobsHistoryForbidden, { status: 403 });
    }
    return HttpResponse.json(jobsHistoryOk);
  }),

  // OpenAPI: GET /api/jobs/:job_id/status
  // api/endpoints/jobs_endpoints.R @get /<job_id>/status
  http.get('/api/jobs/:job_id/status', ({ params }) => {
    if (params.job_id === 'missing-job') {
      return HttpResponse.json(jobStatusNotFound, { status: 404 });
    }
    return HttpResponse.json(jobStatusOk);
  }),

  // OpenAPI: POST /api/jobs/hgnc_update/submit
  // api/endpoints/jobs_endpoints.R @post /hgnc_update/submit
  http.post('/api/jobs/hgnc_update/submit', ({ request }) => {
    if (request.headers.get('x-user-role') === 'Viewer') {
      return HttpResponse.json(hgncUpdateSubmitForbidden, { status: 403 });
    }
    return HttpResponse.json(hgncUpdateSubmitOk, { status: 202 });
  }),

  // OpenAPI: POST /api/jobs/ontology_update/submit
  // api/endpoints/jobs_endpoints.R @post /ontology_update/submit
  http.post('/api/jobs/ontology_update/submit', ({ request }) => {
    if (request.headers.get('x-user-role') === 'Viewer') {
      return HttpResponse.json(ontologyUpdateSubmitForbidden, { status: 403 });
    }
    return HttpResponse.json(ontologyUpdateSubmitOk, { status: 202 });
  }),

  // OpenAPI: POST /api/jobs/comparisons_update/submit
  // api/endpoints/jobs_endpoints.R @post /comparisons_update/submit
  http.post('/api/jobs/comparisons_update/submit', ({ request }) => {
    if (request.headers.get('x-user-role') === 'Viewer') {
      return HttpResponse.json(comparisonsUpdateSubmitForbidden, { status: 403 });
    }
    return HttpResponse.json(comparisonsUpdateSubmitOk, { status: 202 });
  }),

  // OpenAPI: POST /api/jobs/clustering/submit
  // api/endpoints/jobs_endpoints.R @post /clustering/submit
  http.post('/api/jobs/clustering/submit', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.algorithm) {
      return HttpResponse.json(clusteringSubmitBadRequest, { status: 400 });
    }
    return HttpResponse.json(clusteringSubmitOk, { status: 202 });
  }),

  // OpenAPI: POST /api/jobs/phenotype_clustering/submit
  // api/endpoints/jobs_endpoints.R @post /phenotype_clustering/submit
  http.post('/api/jobs/phenotype_clustering/submit', async ({ request }) => {
    const body = await readJsonBody(request);
    if (!body.algorithm) {
      return HttpResponse.json(phenotypeClusteringSubmitBadRequest, { status: 400 });
    }
    return HttpResponse.json(phenotypeClusteringSubmitOk, { status: 202 });
  }),
];

export default handlers;
