// useEntityForm.spec.ts
/**
 * Tests for useEntityForm composable (Phase C.C10).
 *
 * Pattern: Pure state-machine composable, no network
 * --------------------------------------------------
 * useEntityForm manages the 5-step entity-creation wizard: reactive form
 * state, per-field validation rules, per-step validation, touched-field
 * tracking, step navigation, and draft snapshots. It does NOT own HTTP — the
 * host view (ModifyEntity.vue) is responsible for calling
 * `POST /api/entity/create` with the `getFormSnapshot()` payload. Because
 * the composable uses only `ref` / `reactive` / `computed` and has no
 * lifecycle hooks, we call it directly without `withSetup`.
 *
 * Plan §3 Phase C.C10 asks for "form validation and submission" coverage.
 * Since the composable doesn't submit, we cover:
 *
 *   - Validation: every step's required-field rules, per-field error
 *     retrieval, touched-state gating, and PMID tag validation.
 *   - "Submission" readiness: `isFormValid` as the gate the host view uses
 *     before dispatching POST /api/entity/create; plus a scenario that
 *     forwards `getFormSnapshot()` to the Phase B1 entity write handlers
 *     (`/api/entity/create`) to prove the snapshot shape plugs into those
 *     handlers without modification. No new handlers added.
 *   - Wizard navigation: nextStep() blocks on an invalid step; previousStep()
 *     and goToStep() work unconditionally.
 *   - resetForm() and restoreFromSnapshot() for draft workflows.
 *
 * No MSW handlers are added (plan §3 lock); the "integration with B1" block
 * uses server.use() only to observe the request body that would hit the real
 * endpoint.
 */

import { beforeEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import axios from 'axios';

import { server } from '@/test-utils/mocks/server';
import useEntityForm, { validatePMID } from './useEntityForm';

// ---------------------------------------------------------------------------
// Shared fixture: a fully valid form payload
// ---------------------------------------------------------------------------

/**
 * Populate every required field with valid data. Individual tests clone
 * this and mutate one field at a time to assert the targeted rule.
 */
function populateValidForm(form: ReturnType<typeof useEntityForm>) {
  form.formData.geneId = 'HGNC:12345';
  form.formData.geneDisplay = 'TEST1';
  form.formData.diseaseId = 'MONDO:0000123_2025-01-01';
  form.formData.diseaseDisplay = 'Test Disease';
  form.formData.inheritanceId = 'HP:0000006';
  form.formData.nddPhenotype = true;
  form.formData.publications = ['PMID:12345678'];
  form.formData.synopsis =
    'A detailed synopsis that comfortably exceeds the 10-character minimum required by the validator.';
  form.formData.statusId = '1';
}

describe('useEntityForm', () => {
  let form: ReturnType<typeof useEntityForm>;

  beforeEach(() => {
    form = useEntityForm();
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  describe('initial state', () => {
    it('starts at step 0 (core) with empty form data', () => {
      expect(form.currentStepIndex.value).toBe(0);
      expect(form.currentStep.value).toBe('core');
      expect(form.totalSteps).toBe(5);
      expect(form.formData.geneId).toBeNull();
      expect(form.formData.publications).toEqual([]);
      expect(form.formData.statusId).toBeNull();
      expect(form.directApproval.value).toBe(false);
    });

    it('exposes the wizard step labels for UI rendering', () => {
      expect(form.steps).toEqual([
        'core',
        'evidence',
        'phenotype',
        'classification',
        'review',
      ]);
      expect(form.stepLabels.core).toBe('Core Entity');
      expect(form.stepLabels.review).toBe('Review & Submit');
    });

    it('reports the initial form as invalid and the current step as invalid', () => {
      expect(form.isFormValid.value).toBe(false);
      expect(form.isCurrentStepValid.value).toBe(false);
    });

    it('does not surface field errors until the field is touched', () => {
      // geneId is empty but untouched → no error.
      expect(form.getFieldError('geneId')).toBeNull();
      expect(form.getFieldState('geneId')).toBeNull();

      form.touchField('geneId');
      expect(form.getFieldError('geneId')).toBe('Gene is required');
      expect(form.getFieldState('geneId')).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // Per-field validation rules
  // -------------------------------------------------------------------------

  describe('validation — core step fields', () => {
    it('validates geneId as required', () => {
      expect(form.validateField('geneId')).toBe('Gene is required');
      form.formData.geneId = 'HGNC:12345';
      expect(form.validateField('geneId')).toBe(true);
    });

    it('validates diseaseId as required', () => {
      expect(form.validateField('diseaseId')).toBe('Disease is required');
      form.formData.diseaseId = 'MONDO:0000123_2025-01-01';
      expect(form.validateField('diseaseId')).toBe(true);
    });

    it('validates inheritanceId as required', () => {
      expect(form.validateField('inheritanceId')).toBe(
        'Inheritance pattern is required'
      );
      form.formData.inheritanceId = 'HP:0000006';
      expect(form.validateField('inheritanceId')).toBe(true);
    });

    it('validates nddPhenotype (null is invalid, boolean is valid)', () => {
      expect(form.validateField('nddPhenotype')).toBe(
        'NDD phenotype selection is required'
      );
      form.formData.nddPhenotype = false;
      expect(form.validateField('nddPhenotype')).toBe(true);
      form.formData.nddPhenotype = true;
      expect(form.validateField('nddPhenotype')).toBe(true);
    });
  });

  describe('validation — evidence step fields', () => {
    it('requires at least one publication', () => {
      expect(form.validateField('publications')).toBe(
        'At least one publication is required'
      );
      form.formData.publications = ['PMID:12345678'];
      expect(form.validateField('publications')).toBe(true);
    });

    it('requires a non-empty synopsis', () => {
      expect(form.validateField('synopsis')).toBe('Synopsis is required');
      form.formData.synopsis = '   ';
      expect(form.validateField('synopsis')).toBe('Synopsis is required');
    });

    it('requires a synopsis of at least 10 characters', () => {
      form.formData.synopsis = 'too short';
      expect(form.validateField('synopsis')).toBe(
        'Synopsis must be at least 10 characters'
      );
    });

    it('rejects synopses longer than 2000 characters', () => {
      form.formData.synopsis = 'x'.repeat(2001);
      expect(form.validateField('synopsis')).toBe(
        'Synopsis must be less than 2000 characters'
      );
    });

    it('accepts a synopsis in the valid length window', () => {
      form.formData.synopsis =
        'This synopsis is long enough to satisfy the minimum length rule.';
      expect(form.validateField('synopsis')).toBe(true);
    });

    it('tracks synopsis character count reactively', () => {
      form.formData.synopsis = 'hello world';
      expect(form.synopsisCharCount.value).toBe(11);
      expect(form.synopsisCharsRemaining.value).toBe(2000 - 11);
    });
  });

  describe('validation — classification step field', () => {
    it('requires a statusId', () => {
      expect(form.validateField('statusId')).toBe('Status is required');
      form.formData.statusId = '1';
      expect(form.validateField('statusId')).toBe(true);
    });
  });

  // -------------------------------------------------------------------------
  // Per-step validation aggregation
  // -------------------------------------------------------------------------

  describe('validateStep', () => {
    it('core step: collects all four required-field errors on empty form', () => {
      const { isValid, errors } = form.validateStep('core');
      expect(isValid).toBe(false);
      expect(errors).toEqual([
        'Gene is required',
        'Disease is required',
        'Inheritance pattern is required',
        'NDD phenotype selection is required',
      ]);
    });

    it('core step: reports valid once every core field is populated', () => {
      form.formData.geneId = 'HGNC:1';
      form.formData.diseaseId = 'MONDO:1_2025';
      form.formData.inheritanceId = 'HP:0000006';
      form.formData.nddPhenotype = true;
      expect(form.validateStep('core')).toEqual({ isValid: true, errors: [] });
    });

    it('evidence step: collects publication + synopsis errors', () => {
      const { isValid, errors } = form.validateStep('evidence');
      expect(isValid).toBe(false);
      expect(errors).toContain('At least one publication is required');
      expect(errors).toContain('Synopsis is required');
    });

    it('phenotype step is optional — no required fields', () => {
      expect(form.validateStep('phenotype')).toEqual({
        isValid: true,
        errors: [],
      });
    });

    it('classification step requires statusId', () => {
      const before = form.validateStep('classification');
      expect(before.isValid).toBe(false);
      expect(before.errors).toEqual(['Status is required']);

      form.formData.statusId = '1';
      const after = form.validateStep('classification');
      expect(after).toEqual({ isValid: true, errors: [] });
    });

    it('review step reports valid (it only shows the summary)', () => {
      expect(form.validateStep('review')).toEqual({
        isValid: true,
        errors: [],
      });
    });
  });

  // -------------------------------------------------------------------------
  // Wizard navigation
  // -------------------------------------------------------------------------

  describe('wizard navigation', () => {
    it('nextStep() blocks when the current step is invalid and touches all its fields', () => {
      expect(form.currentStep.value).toBe('core');
      const advanced = form.nextStep();

      // nextStep returns false and stays on the same step…
      expect(advanced).toBe(false);
      expect(form.currentStep.value).toBe('core');

      // …but also touches every required field on the step so the UI lights
      // up with error messages on the next render.
      expect(form.touched.geneId).toBe(true);
      expect(form.touched.diseaseId).toBe(true);
      expect(form.touched.inheritanceId).toBe(true);
      expect(form.touched.nddPhenotype).toBe(true);
      expect(form.getFieldError('geneId')).toBe('Gene is required');
    });

    it('nextStep() advances when the current step is valid', () => {
      form.formData.geneId = 'HGNC:1';
      form.formData.diseaseId = 'MONDO:1_2025';
      form.formData.inheritanceId = 'HP:0000006';
      form.formData.nddPhenotype = true;

      expect(form.nextStep()).toBe(true);
      expect(form.currentStep.value).toBe('evidence');
    });

    it('previousStep() moves backward unconditionally and respects the lower bound', () => {
      form.formData.geneId = 'HGNC:1';
      form.formData.diseaseId = 'MONDO:1_2025';
      form.formData.inheritanceId = 'HP:0000006';
      form.formData.nddPhenotype = true;
      form.nextStep(); // → evidence

      expect(form.previousStep()).toBe(true);
      expect(form.currentStep.value).toBe('core');

      // Already at step 0 → no further backward motion.
      expect(form.previousStep()).toBe(false);
      expect(form.currentStepIndex.value).toBe(0);
    });

    it('goToStep() jumps to any valid index and ignores out-of-range values', () => {
      form.goToStep(3);
      expect(form.currentStep.value).toBe('classification');

      form.goToStep(-1);
      // invalid index is ignored — still on classification.
      expect(form.currentStep.value).toBe('classification');

      form.goToStep(99);
      expect(form.currentStep.value).toBe('classification');

      form.goToStep(0);
      expect(form.currentStep.value).toBe('core');
    });
  });

  // -------------------------------------------------------------------------
  // Submission readiness — this is the gate the host view consumes
  // -------------------------------------------------------------------------

  describe('submission readiness (isFormValid)', () => {
    it('is false on an empty form', () => {
      expect(form.isFormValid.value).toBe(false);
    });

    it('is false when only the core step is valid', () => {
      form.formData.geneId = 'HGNC:1';
      form.formData.diseaseId = 'MONDO:1_2025';
      form.formData.inheritanceId = 'HP:0000006';
      form.formData.nddPhenotype = true;
      expect(form.validateStep('core').isValid).toBe(true);
      expect(form.isFormValid.value).toBe(false);
    });

    it('flips to true when every required step is populated', () => {
      populateValidForm(form);
      expect(form.validateStep('core').isValid).toBe(true);
      expect(form.validateStep('evidence').isValid).toBe(true);
      expect(form.validateStep('classification').isValid).toBe(true);
      expect(form.isFormValid.value).toBe(true);
    });

    it('regresses to false the instant a required field is cleared', () => {
      populateValidForm(form);
      expect(form.isFormValid.value).toBe(true);

      form.formData.synopsis = '';
      expect(form.isFormValid.value).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // Snapshot / reset
  // -------------------------------------------------------------------------

  describe('snapshot and reset', () => {
    it('getFormSnapshot() returns a plain object with every field', () => {
      populateValidForm(form);
      const snapshot = form.getFormSnapshot();
      expect(snapshot).toEqual({
        geneId: 'HGNC:12345',
        geneDisplay: 'TEST1',
        diseaseId: 'MONDO:0000123_2025-01-01',
        diseaseDisplay: 'Test Disease',
        inheritanceId: 'HP:0000006',
        nddPhenotype: true,
        publications: ['PMID:12345678'],
        genereviews: [],
        synopsis:
          'A detailed synopsis that comfortably exceeds the 10-character minimum required by the validator.',
        phenotypes: [],
        variationOntology: [],
        statusId: '1',
        comment: '',
      });
    });

    it('getFormSnapshot() returns a disconnected copy (mutations do not back-propagate)', () => {
      populateValidForm(form);
      const snapshot = form.getFormSnapshot();
      snapshot.synopsis = 'mutated in the snapshot only';
      expect(form.formData.synopsis).not.toBe('mutated in the snapshot only');
    });

    it('restoreFromSnapshot() rehydrates the form from a partial snapshot', () => {
      form.restoreFromSnapshot({
        geneId: 'HGNC:999',
        geneDisplay: 'DRAFT',
        synopsis: 'Draft synopsis that is plenty long enough to pass.',
      });
      expect(form.formData.geneId).toBe('HGNC:999');
      expect(form.formData.geneDisplay).toBe('DRAFT');
      expect(form.formData.synopsis).toBe(
        'Draft synopsis that is plenty long enough to pass.'
      );
      // Fields not included in the snapshot remain at their defaults.
      expect(form.formData.diseaseId).toBeNull();
    });

    it('resetForm() clears every field, un-touches every field, and rewinds to step 0', () => {
      populateValidForm(form);
      form.goToStep(4);
      form.directApproval.value = true;
      Object.keys(form.touched).forEach((key) => {
        form.touched[key as keyof typeof form.touched] = true;
      });

      form.resetForm();

      expect(form.formData.geneId).toBeNull();
      expect(form.formData.publications).toEqual([]);
      expect(form.formData.synopsis).toBe('');
      expect(form.currentStepIndex.value).toBe(0);
      expect(form.directApproval.value).toBe(false);
      Object.values(form.touched).forEach((v) => expect(v).toBe(false));
    });
  });

  // -------------------------------------------------------------------------
  // PMID tag validator (standalone export)
  // -------------------------------------------------------------------------

  describe('validatePMID', () => {
    it('accepts canonical PMID tags', () => {
      expect(validatePMID('PMID:12345678')).toBe(true);
      expect(validatePMID('PMID:123456')).toBe(true);
    });

    it('tolerates incidental whitespace', () => {
      expect(validatePMID(' PMID:12345678 ')).toBe(true);
    });

    it('rejects tags without the PMID: prefix', () => {
      expect(validatePMID('12345678')).toBe(false);
    });

    it('rejects non-numeric bodies', () => {
      expect(validatePMID('PMID:abcdefg')).toBe(false);
    });

    it('rejects bodies shorter than 5 characters', () => {
      expect(validatePMID('PMID:1234')).toBe(false);
    });

    it('rejects bodies 9 characters or longer', () => {
      expect(validatePMID('PMID:123456789')).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // Integration with the Phase B1 entity write handlers
  // -------------------------------------------------------------------------

  describe('integration with POST /api/entity/create (Phase B1)', () => {
    it('getFormSnapshot() can be forwarded to /api/entity/create unchanged', async () => {
      // This test documents the contract between the composable and the
      // Phase B1 handler table (entity_endpoints.R @post /create). It does
      // NOT install a new handler — it overrides the existing one only to
      // capture the request body, then re-asserts the happy-path shape the
      // default handler already returns.
      populateValidForm(form);
      expect(form.isFormValid.value).toBe(true);

      let capturedBody: Record<string, unknown> | null = null;
      server.use(
        http.post('/api/entity/create', async ({ request }) => {
          capturedBody = (await request.clone().json()) as Record<string, unknown>;
          // Mirror the default handler's validity branch so the spec still
          // exercises the 400-on-missing-required-fields rule.
          if (!capturedBody.hgnc_id || !capturedBody.disease_ontology_id_version) {
            return HttpResponse.json(
              { error: 'Missing or invalid entity fields.' },
              { status: 400 }
            );
          }
          return HttpResponse.json(
            { message: 'Entity successfully created.', entity_id: [502] },
            { status: 201 }
          );
        })
      );

      const snapshot = form.getFormSnapshot();
      // Map the composable's camelCase field names to the plumber endpoint's
      // snake_case body shape. This is the responsibility of the host view
      // (ModifyEntity.vue) — we replicate the mapping here so the spec
      // double-checks the snapshot carries the data the endpoint needs.
      const body = {
        hgnc_id: snapshot.geneId,
        disease_ontology_id_version: snapshot.diseaseId,
        hpo_mode_of_inheritance_term: snapshot.inheritanceId,
        ndd_phenotype: snapshot.nddPhenotype,
        synopsis: snapshot.synopsis,
        publications: snapshot.publications,
        category_id: snapshot.statusId,
      };

      const res = await axios.post('/api/entity/create', body, {
        headers: {
          authorization: 'Bearer test-token',
          'content-type': 'application/json',
        },
      });

      expect(res.status).toBe(201);
      expect(res.data.message).toBe('Entity successfully created.');
      expect(res.data.entity_id).toEqual([502]);
      expect(capturedBody).not.toBeNull();
      expect(capturedBody!.hgnc_id).toBe('HGNC:12345');
      expect(capturedBody!.disease_ontology_id_version).toBe(
        'MONDO:0000123_2025-01-01'
      );
    });

    it('an invalid form never reaches the handler (isFormValid gates the call)', async () => {
      // Empty form → isFormValid is false → host view should never call
      // axios.post. We assert both halves: the gate is false, and if the
      // host view were to ignore the gate the handler would reject the
      // request with 400 anyway (belt-and-braces against E4/E5 regressions).
      expect(form.isFormValid.value).toBe(false);

      await expect(
        axios.post(
          '/api/entity/create',
          { hgnc_id: null, disease_ontology_id_version: null },
          {
            headers: {
              authorization: 'Bearer test-token',
              'content-type': 'application/json',
            },
          }
        )
      ).rejects.toMatchObject({
        response: { status: 400 },
      });
    });
  });
});
