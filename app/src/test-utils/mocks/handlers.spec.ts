// test-utils/mocks/handlers.spec.ts
/**
 * Phase B.B1 smoke tests for the MSW handler set.
 *
 * Every handler listed in the Phase B.B1 locked table must have:
 *   - a 2xx happy-path response with the declared shape
 *   - at least one 4xx branch reachable via a distinguishable request shape
 *     (sentinel path param `999`, a `trigger_error` query, a missing-auth
 *     header, a `Viewer` user-role header, or a body with missing required
 *     fields).
 *
 * Each `it` exercises one handler's 2xx and one 4xx trigger by calling
 * `fetch()` directly — the server is already listening globally via
 * `vitest.setup.ts`, so this file deliberately does not install overrides.
 *
 * If you're adding a handler to `handlers.ts`, add a matching `it` here.
 */

import { describe, it, expect } from 'vitest';

describe('MSW handlers — Phase B.B1 smoke tests', () => {
  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  describe('auth', () => {
    it('POST /api/auth/authenticate returns 200 token on valid body', async () => {
      const res = await fetch('/api/auth/authenticate', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_name: 'test_user', password: 'hunter2!' }),
      });
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body)).toBe(true);
      expect(body[0]).toMatch(/^eyJ/);
    });

    it('POST /api/auth/authenticate returns 400 on too-short credentials', async () => {
      const res = await fetch('/api/auth/authenticate', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_name: 'x', password: 'y' }),
      });
      expect(res.status).toBe(400);
    });

    it('POST /api/auth/authenticate returns 401 on wrong_user/wrong_pass sentinel', async () => {
      const res = await fetch('/api/auth/authenticate', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_name: 'wrong_user', password: 'hunter2!' }),
      });
      expect(res.status).toBe(401);
    });

    it('GET /api/auth/refresh returns 200 with Authorization header', async () => {
      const res = await fetch('/api/auth/refresh', {
        headers: { authorization: 'Bearer test-token' },
      });
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body)).toBe(true);
    });

    it('GET /api/auth/refresh returns 401 without Authorization header', async () => {
      const res = await fetch('/api/auth/refresh');
      expect(res.status).toBe(401);
    });

    it('GET /api/auth/signin returns 200 with Authorization header', async () => {
      const res = await fetch('/api/auth/signin', {
        headers: { authorization: 'Bearer test-token' },
      });
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.user_name).toEqual(['test_user']);
    });

    it('GET /api/auth/signin returns 401 without Authorization header', async () => {
      const res = await fetch('/api/auth/signin');
      expect(res.status).toBe(401);
    });
  });

  // ---------------------------------------------------------------------------
  // User admin
  // ---------------------------------------------------------------------------

  describe('user admin', () => {
    it('GET /api/user/table returns 200 paginated envelope', async () => {
      const res = await fetch('/api/user/table');
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.data).toBeInstanceOf(Array);
      expect(body.links).toBeInstanceOf(Array);
      expect(body.meta).toBeInstanceOf(Array);
    });

    it('GET /api/user/table returns 400 on trigger_error=1', async () => {
      const res = await fetch('/api/user/table?trigger_error=1');
      expect(res.status).toBe(400);
    });

    it('GET /api/user/role_list returns 200 with Authorization', async () => {
      const res = await fetch('/api/user/role_list', {
        headers: { authorization: 'Bearer t' },
      });
      expect(res.status).toBe(200);
    });

    it('GET /api/user/role_list returns 401 without Authorization', async () => {
      const res = await fetch('/api/user/role_list');
      expect(res.status).toBe(401);
    });

    it('GET /api/user/list returns 200 with Authorization', async () => {
      const res = await fetch('/api/user/list', {
        headers: { authorization: 'Bearer t' },
      });
      expect(res.status).toBe(200);
    });

    it('GET /api/user/list returns 401 without Authorization', async () => {
      const res = await fetch('/api/user/list');
      expect(res.status).toBe(401);
    });

    it('PUT /api/user/update returns 200 on valid body', async () => {
      const res = await fetch('/api/user/update', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_id: 1, user_role: 'Viewer' }),
      });
      expect(res.status).toBe(200);
    });

    it('PUT /api/user/update returns 403 on missing user_id', async () => {
      const res = await fetch('/api/user/update', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({}),
      });
      expect(res.status).toBe(403);
    });

    it('PUT /api/user/delete returns 200 on valid user_id', async () => {
      const res = await fetch('/api/user/delete', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_id: 1 }),
      });
      expect(res.status).toBe(200);
    });

    it('PUT /api/user/delete returns 404 on sentinel 999', async () => {
      const res = await fetch('/api/user/delete', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_id: 999 }),
      });
      expect(res.status).toBe(404);
    });

    it('POST /api/user/bulk_approve returns 200 on non-empty user_ids', async () => {
      const res = await fetch('/api/user/bulk_approve', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_ids: [1, 2] }),
      });
      expect(res.status).toBe(200);
    });

    it('POST /api/user/bulk_approve returns 400 on empty user_ids', async () => {
      const res = await fetch('/api/user/bulk_approve', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_ids: [] }),
      });
      expect(res.status).toBe(400);
    });

    it('POST /api/user/bulk_assign_role returns 200 on valid body', async () => {
      const res = await fetch('/api/user/bulk_assign_role', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_ids: [1, 2], user_role: 'Viewer' }),
      });
      expect(res.status).toBe(200);
    });

    it('POST /api/user/bulk_assign_role returns 400 on empty role', async () => {
      const res = await fetch('/api/user/bulk_assign_role', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_ids: [1], user_role: '' }),
      });
      expect(res.status).toBe(400);
    });

    it('POST /api/user/bulk_delete returns 200 on non-empty user_ids', async () => {
      const res = await fetch('/api/user/bulk_delete', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_ids: [1, 2] }),
      });
      expect(res.status).toBe(200);
    });

    it('POST /api/user/bulk_delete returns 400 on empty user_ids', async () => {
      const res = await fetch('/api/user/bulk_delete', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ user_ids: [] }),
      });
      expect(res.status).toBe(400);
    });

    it('PUT /api/user/password/update returns 201 on valid body', async () => {
      const res = await fetch('/api/user/password/update', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          user_id_pass_change: 1,
          old_pass: 'OldPass1!',
          new_pass_1: 'NewPass1!',
          new_pass_2: 'NewPass1!',
        }),
      });
      expect(res.status).toBe(201);
    });

    it('PUT /api/user/password/update returns 409 on mismatched new passwords', async () => {
      const res = await fetch('/api/user/password/update', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          user_id_pass_change: 1,
          old_pass: 'OldPass1!',
          new_pass_1: 'NewPass1!',
          new_pass_2: 'Different!',
        }),
      });
      expect(res.status).toBe(409);
    });
  });

  // ---------------------------------------------------------------------------
  // Review workflow
  // ---------------------------------------------------------------------------

  describe('review workflow', () => {
    it('GET /api/review/:id returns 200 for valid id', async () => {
      const res = await fetch('/api/review/101');
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.review_id).toBe(101);
    });

    it('GET /api/review/:id returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/review/999');
      expect(res.status).toBe(404);
    });

    it('GET /api/review/:id/phenotypes returns 200 for valid id', async () => {
      const res = await fetch('/api/review/101/phenotypes');
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body)).toBe(true);
    });

    it('GET /api/review/:id/phenotypes returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/review/999/phenotypes');
      expect(res.status).toBe(404);
    });

    it('GET /api/review/:id/variation returns 200 for valid id', async () => {
      const res = await fetch('/api/review/101/variation');
      expect(res.status).toBe(200);
    });

    it('GET /api/review/:id/variation returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/review/999/variation');
      expect(res.status).toBe(404);
    });

    it('GET /api/review/:id/publications returns 200 for valid id', async () => {
      const res = await fetch('/api/review/101/publications');
      expect(res.status).toBe(200);
    });

    it('GET /api/review/:id/publications returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/review/999/publications');
      expect(res.status).toBe(404);
    });

    it('POST /api/review/create returns 201 on valid body', async () => {
      const res = await fetch('/api/review/create', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ entity_id: 501, synopsis: 'ok' }),
      });
      expect(res.status).toBe(201);
    });

    it('POST /api/review/create returns 400 on missing entity_id', async () => {
      const res = await fetch('/api/review/create', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ synopsis: 'ok' }),
      });
      expect(res.status).toBe(400);
    });

    it('PUT /api/review/update returns 200 on valid body', async () => {
      const res = await fetch('/api/review/update', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ review_id: 101, synopsis: 'ok' }),
      });
      expect(res.status).toBe(200);
    });

    it('PUT /api/review/update returns 400 on missing review_id', async () => {
      const res = await fetch('/api/review/update', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ synopsis: 'ok' }),
      });
      expect(res.status).toBe(400);
    });

    it('PUT /api/review/approve/:id returns 200 for valid id', async () => {
      const res = await fetch('/api/review/approve/101', { method: 'PUT' });
      expect(res.status).toBe(200);
    });

    it('PUT /api/review/approve/:id returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/review/approve/999', { method: 'PUT' });
      expect(res.status).toBe(404);
    });

    it('PUT /api/review/approve/all returns 200 for admin', async () => {
      const res = await fetch('/api/review/approve/all', {
        method: 'PUT',
        headers: { 'x-user-role': 'Administrator' },
      });
      expect(res.status).toBe(200);
    });

    it('PUT /api/review/approve/all returns 403 for Viewer', async () => {
      const res = await fetch('/api/review/approve/all', {
        method: 'PUT',
        headers: { 'x-user-role': 'Viewer' },
      });
      expect(res.status).toBe(403);
    });
  });

  // ---------------------------------------------------------------------------
  // Status workflow
  // ---------------------------------------------------------------------------

  describe('status workflow', () => {
    it('GET /api/status/:id returns 200 for valid id', async () => {
      const res = await fetch('/api/status/201');
      expect(res.status).toBe(200);
    });

    it('GET /api/status/:id returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/status/999');
      expect(res.status).toBe(404);
    });

    it('POST /api/status/create returns 201 on valid body', async () => {
      const res = await fetch('/api/status/create', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ entity_id: 501, category_id: 1 }),
      });
      expect(res.status).toBe(201);
    });

    it('POST /api/status/create returns 400 on missing category_id', async () => {
      const res = await fetch('/api/status/create', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ entity_id: 501 }),
      });
      expect(res.status).toBe(400);
    });

    it('PUT /api/status/update returns 200 on valid body', async () => {
      const res = await fetch('/api/status/update', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ status_id: 201, category_id: 2 }),
      });
      expect(res.status).toBe(200);
    });

    it('PUT /api/status/update returns 400 on missing status_id', async () => {
      const res = await fetch('/api/status/update', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ category_id: 2 }),
      });
      expect(res.status).toBe(400);
    });

    it('PUT /api/status/approve/:id returns 200 for valid id', async () => {
      const res = await fetch('/api/status/approve/201', { method: 'PUT' });
      expect(res.status).toBe(200);
    });

    it('PUT /api/status/approve/:id returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/status/approve/999', { method: 'PUT' });
      expect(res.status).toBe(404);
    });

    it('PUT /api/status/approve/all returns 200 for admin', async () => {
      const res = await fetch('/api/status/approve/all', {
        method: 'PUT',
        headers: { 'x-user-role': 'Administrator' },
      });
      expect(res.status).toBe(200);
    });

    it('PUT /api/status/approve/all returns 403 for Viewer', async () => {
      const res = await fetch('/api/status/approve/all', {
        method: 'PUT',
        headers: { 'x-user-role': 'Viewer' },
      });
      expect(res.status).toBe(403);
    });
  });

  // ---------------------------------------------------------------------------
  // Entity curation
  // ---------------------------------------------------------------------------

  describe('entity curation', () => {
    it('GET /api/entity/:sysndd_id returns 200 for valid id', async () => {
      const res = await fetch('/api/entity/501');
      expect(res.status).toBe(200);
    });

    it('GET /api/entity/:sysndd_id returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/entity/999');
      expect(res.status).toBe(404);
    });

    it('POST /api/entity/create returns 201 on valid body', async () => {
      const res = await fetch('/api/entity/create', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          hgnc_id: 'HGNC:12345',
          disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
        }),
      });
      expect(res.status).toBe(201);
    });

    it('POST /api/entity/create returns 400 on missing hgnc_id', async () => {
      const res = await fetch('/api/entity/create', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ disease_ontology_id_version: 'MONDO:0000123_2025-01-01' }),
      });
      expect(res.status).toBe(400);
    });

    it('POST /api/entity/rename returns 200 on valid body', async () => {
      const res = await fetch('/api/entity/rename', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ sysndd_id: 501, new_symbol: 'TEST2' }),
      });
      expect(res.status).toBe(200);
    });

    it('POST /api/entity/rename returns 400 on missing new_symbol', async () => {
      const res = await fetch('/api/entity/rename', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ sysndd_id: 501 }),
      });
      expect(res.status).toBe(400);
    });

    it('POST /api/entity/deactivate returns 200 on valid body', async () => {
      const res = await fetch('/api/entity/deactivate', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ sysndd_id: 501 }),
      });
      expect(res.status).toBe(200);
    });

    it('POST /api/entity/deactivate returns 400 on missing sysndd_id', async () => {
      const res = await fetch('/api/entity/deactivate', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({}),
      });
      expect(res.status).toBe(400);
    });

    it('GET /api/entity/:sysndd_id/review returns 200 for valid id', async () => {
      const res = await fetch('/api/entity/501/review');
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body)).toBe(true);
    });

    it('GET /api/entity/:sysndd_id/review returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/entity/999/review');
      expect(res.status).toBe(404);
    });

    it('GET /api/entity/:sysndd_id/status returns 200 for valid id', async () => {
      const res = await fetch('/api/entity/501/status');
      expect(res.status).toBe(200);
    });

    it('GET /api/entity/:sysndd_id/status returns 404 for sentinel 999', async () => {
      const res = await fetch('/api/entity/999/status');
      expect(res.status).toBe(404);
    });
  });

  // ---------------------------------------------------------------------------
  // Annotation jobs
  // ---------------------------------------------------------------------------

  describe('annotation jobs', () => {
    it('GET /api/jobs/history returns 200 for admin', async () => {
      const res = await fetch('/api/jobs/history', {
        headers: { 'x-user-role': 'Administrator' },
      });
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.data).toBeInstanceOf(Array);
    });

    it('GET /api/jobs/history returns 403 for Viewer', async () => {
      const res = await fetch('/api/jobs/history', {
        headers: { 'x-user-role': 'Viewer' },
      });
      expect(res.status).toBe(403);
    });

    it('GET /api/jobs/:job_id/status returns 200 for valid job_id', async () => {
      const res = await fetch('/api/jobs/hgnc-update-2025-06-01/status');
      expect(res.status).toBe(200);
    });

    it('GET /api/jobs/:job_id/status returns 404 for missing-job sentinel', async () => {
      const res = await fetch('/api/jobs/missing-job/status');
      expect(res.status).toBe(404);
    });

    it('POST /api/jobs/hgnc_update/submit returns 202 for admin', async () => {
      const res = await fetch('/api/jobs/hgnc_update/submit', {
        method: 'POST',
        headers: { 'x-user-role': 'Administrator' },
      });
      expect(res.status).toBe(202);
    });

    it('POST /api/jobs/hgnc_update/submit returns 403 for Viewer', async () => {
      const res = await fetch('/api/jobs/hgnc_update/submit', {
        method: 'POST',
        headers: { 'x-user-role': 'Viewer' },
      });
      expect(res.status).toBe(403);
    });

    it('POST /api/jobs/ontology_update/submit returns 202 for admin', async () => {
      const res = await fetch('/api/jobs/ontology_update/submit', {
        method: 'POST',
        headers: { 'x-user-role': 'Administrator' },
      });
      expect(res.status).toBe(202);
    });

    it('POST /api/jobs/ontology_update/submit returns 403 for Viewer', async () => {
      const res = await fetch('/api/jobs/ontology_update/submit', {
        method: 'POST',
        headers: { 'x-user-role': 'Viewer' },
      });
      expect(res.status).toBe(403);
    });

    it('POST /api/jobs/comparisons_update/submit returns 202 for admin', async () => {
      const res = await fetch('/api/jobs/comparisons_update/submit', {
        method: 'POST',
        headers: { 'x-user-role': 'Administrator' },
      });
      expect(res.status).toBe(202);
    });

    it('POST /api/jobs/comparisons_update/submit returns 403 for Viewer', async () => {
      const res = await fetch('/api/jobs/comparisons_update/submit', {
        method: 'POST',
        headers: { 'x-user-role': 'Viewer' },
      });
      expect(res.status).toBe(403);
    });

    it('POST /api/jobs/clustering/submit returns 202 with algorithm', async () => {
      const res = await fetch('/api/jobs/clustering/submit', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ algorithm: 'louvain' }),
      });
      expect(res.status).toBe(202);
    });

    it('POST /api/jobs/clustering/submit returns 400 without algorithm', async () => {
      const res = await fetch('/api/jobs/clustering/submit', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({}),
      });
      expect(res.status).toBe(400);
    });

    it('POST /api/jobs/phenotype_clustering/submit returns 202 with algorithm', async () => {
      const res = await fetch('/api/jobs/phenotype_clustering/submit', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ algorithm: 'kmeans' }),
      });
      expect(res.status).toBe(202);
    });

    it('POST /api/jobs/phenotype_clustering/submit returns 400 without algorithm', async () => {
      const res = await fetch('/api/jobs/phenotype_clustering/submit', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({}),
      });
      expect(res.status).toBe(400);
    });
  });
});
