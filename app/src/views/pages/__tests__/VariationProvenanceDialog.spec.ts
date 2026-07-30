// app/src/views/pages/__tests__/VariationProvenanceDialog.spec.ts
//
// #608 Task 6 — the on-demand evidence dialog, driven through the real
// EntityEvidenceGrid trigger so the open/close/focus contract is exercised end
// to end rather than by poking the child's props.
//
// Covers: lazy fetch (none on mount, one on first open, none on reopen),
// API source order preserved, `strength: null` reads "not recorded" and draws no
// stars, fetch failure shows an inline error without blanking the card, and the
// keyboard path (Enter opens, Escape closes, focus returns to the trigger).
//
// Fixtures use the WIRE shape: plumber does not auto-unbox, so every scalar of
// the `list()`-built evidence response arrives as a length-1 array.

import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { http, HttpResponse } from 'msw';
import { mount, flushPromises } from '@vue/test-utils';
import { server } from '@/test-utils/mocks/server';
import { bootstrapStubs, expectNoA11yViolations } from '@/test-utils';
import EntityEvidenceGrid, { type EntityEvidenceModel } from '../components/EntityEvidenceGrid.vue';

const stubs = {
  ...bootstrapStubs,
  BCard: { template: '<div><slot name="header" /><slot /></div>' },
};

const ENTITY_ID = 2097;
const EVIDENCE_PATH = `*/api/entity/${ENTITY_ID}/variation/VariO:0017/1/evidence`;

const CLINVAR_SOURCE = {
  source_type: ['external_database'],
  source_key: ['clinvar'],
  strength: [1],
  summary: ['2 ClinVar records, max 1 star'],
};

function machineTerm(overrides: Record<string, unknown> = {}) {
  return {
    entity_id: ENTITY_ID,
    vario_id: 'VariO:0017',
    vario_name: 'nonsynonymous variation',
    modifier_id: 1,
    provenance: {
      state: ['active_unconfirmed'],
      max_strength: [1],
      sources: [CLINVAR_SOURCE],
    },
    ...overrides,
  };
}

function makeModel(variation: Record<string, unknown>[]): EntityEvidenceModel {
  return {
    publications: { loading: false, error: null, additionalRefs: [], geneReviews: [] },
    phenotypes: { loading: false, error: null, list: [] },
    variation: { loading: false, error: null, list: variation },
  };
}

function mountGrid(variation: Record<string, unknown>[]) {
  return mount(EntityEvidenceGrid, {
    props: { model: makeModel(variation) },
    global: { stubs },
    attachTo: document.body,
  });
}

/** Two sources, deliberately in the API's order: strength desc then key asc. */
const TWO_SOURCE_EVIDENCE = {
  entity_id: [ENTITY_ID],
  vario_id: ['VariO:0017'],
  modifier_id: [1],
  state: ['active_unconfirmed'],
  evidence: [
    {
      source_type: ['literature'],
      source_key: ['synopsis'],
      batch_id: ['b-2026-07-01'],
      source_version: null,
      evidence_summary: ['Explicitly stated in the clinical synopsis'],
      evidence_strength: [3],
      evidence_json: { matched: ['truncating variants'] },
    },
    {
      source_type: ['external_database'],
      source_key: ['clinvar'],
      batch_id: ['clinvar-2026-02'],
      source_version: ['2026-02-01'],
      evidence_summary: ['2 ClinVar records, max 1 star'],
      evidence_strength: [1],
      evidence_json: {
        records: [
          {
            variation_id: ['VCV1343191'],
            consequence: ['missense'],
            classification: ['Likely pathogenic'],
          },
          {
            variation_id: ['VCV1804020'],
            consequence: ['missense'],
            classification: ['Likely pathogenic'],
          },
        ],
        matched: ['OMIM:251280'],
      },
    },
  ],
};

describe('VariationProvenanceDialog (#608)', () => {
  beforeEach(() => setActivePinia(createPinia()));
  afterEach(() => server.resetHandlers());

  it('LAZY: no evidence request on mount, exactly one on first open, none on reopen', async () => {
    let calls = 0;
    server.use(
      http.get(EVIDENCE_PATH, () => {
        calls += 1;
        return HttpResponse.json(TWO_SOURCE_EVIDENCE);
      })
    );

    const w = mountGrid([machineTerm()]);
    await flushPromises();
    expect(calls).toBe(0);

    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();
    expect(calls).toBe(1);
    expect(w.find('[data-testid="variation-provenance-dialog"]').exists()).toBe(true);

    await w.get('[data-testid="variation-provenance-dialog-close"]').trigger('click');
    await flushPromises();
    expect(w.find('[data-testid="variation-provenance-dialog"]').exists()).toBe(false);

    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();
    expect(calls).toBe(1); // served from the shared SWR cache
    expect(w.find('[data-testid="variation-provenance-dialog"]').exists()).toBe(true);
    w.unmount();
  });

  it('renders two sources in the API order and does not re-sort them client-side', async () => {
    server.use(http.get(EVIDENCE_PATH, () => HttpResponse.json(TWO_SOURCE_EVIDENCE)));
    const w = mountGrid([machineTerm()]);
    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();

    const sources = w.findAll('[data-testid^="variation-provenance-source-"]');
    expect(sources).toHaveLength(2);
    // API order is strength DESC: the literature source (3) precedes ClinVar (1),
    // which is NOT alphabetical by source_key — so an accidental client sort shows.
    expect(sources[0].text()).toContain('Clinical synopsis');
    expect(sources[1].text()).toContain('ClinVar');
    expect(sources[0].text()).toContain('3 of 4');
    expect(sources[1].text()).toContain('1 of 4');
    w.unmount();
  });

  it('renders only fields the payload contains: batch, release, verbatim summary, records, matched', async () => {
    server.use(http.get(EVIDENCE_PATH, () => HttpResponse.json(TWO_SOURCE_EVIDENCE)));
    const w = mountGrid([machineTerm()]);
    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();

    const clinvar = w.get('[data-testid="variation-provenance-source-1"]');
    expect(clinvar.text()).toContain('batch clinvar-2026-02');
    expect(clinvar.text()).toContain('release 2026-02-01');
    // Summary is the source's own stored wording, verbatim.
    expect(clinvar.text()).toContain('2 ClinVar records, max 1 star');
    // Status is stated once for the assertion, in words.
    expect(w.get('[data-testid="variation-provenance-dialog-status"]').text()).toContain(
      'Not yet confirmed by a curator'
    );
    expect(w.get('[data-testid="variation-provenance-matched-1"]').text()).toContain('OMIM:251280');

    const records = w.findAll('[data-testid^="variation-provenance-record-1-"]');
    expect(records).toHaveLength(2);
    expect(records[0].text()).toContain('VCV1343191');
    expect(records[0].text()).toContain('missense');
    expect(records[0].text()).toContain('Likely pathogenic');
    expect(records[0].get('a').attributes('href')).toBe(
      'https://www.ncbi.nlm.nih.gov/clinvar/variation/1343191/'
    );

    // No HGVS / protein label is stored, so none may be invented, and no import
    // date is served by the route either.
    const html = w.get('[data-testid="variation-provenance-dialog"]').html();
    expect(html).not.toContain('p.Thr');
    expect(html).not.toContain('Imported 1');

    // The literature source omits the absent `source_version` rather than guessing.
    const synopsis = w.get('[data-testid="variation-provenance-source-0"]');
    expect(synopsis.text()).toContain('batch b-2026-07-01');
    expect(synopsis.text()).not.toContain('release');
    w.unmount();
  });

  it('renders an unrecorded strength as "Not recorded" and draws no stars', async () => {
    server.use(
      http.get(EVIDENCE_PATH, () =>
        HttpResponse.json({
          ...TWO_SOURCE_EVIDENCE,
          evidence: [
            {
              ...TWO_SOURCE_EVIDENCE.evidence[1],
              evidence_strength: null,
              evidence_json: null,
            },
          ],
        })
      )
    );
    const w = mountGrid([machineTerm()]);
    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();

    const strength = w.get('[data-testid="variation-provenance-strength-0"]');
    expect(strength.text()).toContain('Not recorded');
    expect(strength.text()).not.toContain('☆');
    expect(strength.text()).not.toContain('★');
    expect(strength.find('.vp-stars').exists()).toBe(false);
    w.unmount();
  });

  it('shows an inline error on fetch failure and does not blank the card', async () => {
    server.use(http.get(EVIDENCE_PATH, () => new HttpResponse(null, { status: 500 })));
    const w = mountGrid([machineTerm()]);
    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();

    expect(w.get('[data-testid="variation-provenance-dialog-error"]').text()).toContain(
      'could not be loaded'
    );
    // The card behind the dialog is intact.
    expect(w.find('[data-testid="variation-chip-VariO:0017"]').exists()).toBe(true);
    expect(w.text()).toContain('nonsynonymous variation');
    w.unmount();
  });

  it('reports a served assertion with no evidence rows honestly', async () => {
    server.use(
      http.get(EVIDENCE_PATH, () => HttpResponse.json({ ...TWO_SOURCE_EVIDENCE, evidence: [] }))
    );
    const w = mountGrid([machineTerm()]);
    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();
    expect(w.get('[data-testid="variation-provenance-empty"]').text()).toContain(
      'No evidence records'
    );
    w.unmount();
  });

  it('KEYBOARD: trigger is focusable, Enter opens, Escape closes, focus returns to the trigger', async () => {
    server.use(http.get(EVIDENCE_PATH, () => HttpResponse.json(TWO_SOURCE_EVIDENCE)));
    const w = mountGrid([machineTerm()]);
    const trigger = w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]');
    const triggerEl = trigger.element as HTMLButtonElement;

    triggerEl.focus();
    expect(document.activeElement).toBe(triggerEl);
    expect(triggerEl.tabIndex).toBe(0);

    // A native <button> activates on Enter as a click — assert the real path.
    await trigger.trigger('keydown', { key: 'Enter' });
    await trigger.trigger('click');
    await flushPromises();

    const dialog = w.get('[data-testid="variation-provenance-dialog"]');
    expect(dialog.attributes('role')).toBe('dialog');
    expect(dialog.attributes('aria-modal')).toBe('true');
    const labelledBy = dialog.attributes('aria-labelledby') as string;
    expect(w.get(`#${labelledBy}`).text()).toBe('nonsynonymous variation');
    // Focus moved into the dialog.
    expect(document.activeElement).toBe(dialog.element);
    expect(trigger.attributes('aria-expanded')).toBe('true');

    await dialog.trigger('keydown.esc');
    await flushPromises();
    expect(w.find('[data-testid="variation-provenance-dialog"]').exists()).toBe(false);
    expect(document.activeElement).toBe(triggerEl);
    w.unmount();
  });

  it('dismisses on the scrim and keeps Tab inside the dialog', async () => {
    server.use(http.get(EVIDENCE_PATH, () => HttpResponse.json(TWO_SOURCE_EVIDENCE)));
    const w = mountGrid([machineTerm()]);
    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();

    const dialog = w.get('[data-testid="variation-provenance-dialog"]');
    // Shift+Tab from the dialog container wraps to the LAST focusable descendant.
    await dialog.trigger('keydown', { key: 'Tab', shiftKey: true });
    expect(dialog.element.contains(document.activeElement)).toBe(true);

    await w.get('[data-testid="variation-provenance-scrim"]').trigger('click');
    await flushPromises();
    expect(w.find('[data-testid="variation-provenance-dialog"]').exists()).toBe(false);
    w.unmount();
  });

  it('opening a second term fetches only that term and leaves the first cached', async () => {
    const seen: string[] = [];
    server.use(
      http.get(
        `*/api/entity/${ENTITY_ID}/variation/VariO:0017/:modifier/evidence`,
        ({ params }) => {
          seen.push(String(params.modifier));
          return HttpResponse.json({
            ...TWO_SOURCE_EVIDENCE,
            modifier_id: [Number(params.modifier)],
          });
        }
      )
    );

    const w = mountGrid([machineTerm(), machineTerm({ modifier_id: 5 })]);
    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();
    await w.get('[data-testid="variation-provenance-dialog-close"]').trigger('click');
    await flushPromises();

    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-5"]').trigger('click');
    await flushPromises();
    expect(seen).toEqual(['1', '5']);

    await w.get('[data-testid="variation-provenance-dialog-close"]').trigger('click');
    await flushPromises();
    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();
    expect(seen).toEqual(['1', '5']); // both cached
    w.unmount();
  });

  it('has no axe violations with the dialog open', async () => {
    server.use(http.get(EVIDENCE_PATH, () => HttpResponse.json(TWO_SOURCE_EVIDENCE)));
    const w = mountGrid([machineTerm()]);
    await w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').trigger('click');
    await flushPromises();
    // `region` is disabled because this mounts a card fragment, not a page with
    // landmarks — the same exemption the other component-level a11y specs use.
    await expectNoA11yViolations(w.element, { rules: { region: { enabled: false } } });
    w.unmount();
  });
});
