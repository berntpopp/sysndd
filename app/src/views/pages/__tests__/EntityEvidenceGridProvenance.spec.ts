// app/src/views/pages/__tests__/EntityEvidenceGridProvenance.spec.ts
//
// #608 Task 6 — the PUBLIC Variation Ontology provenance surface.
//
// The first test in this file is THE RELEASE GATE. The backfill that populates
// variation_ontology_assertion / variation_ontology_evidence lives in a
// different repository and has not run yet, so on day one every term arrives
// with `provenance: null`. Because absence of provenance MEANS
// curator-authored, presenting a provenance legend while rows are missing would
// positively assert that un-backfilled machine-derived annotations are curated
// — worse than saying nothing. So with no provenance anywhere the card must
// render byte-identically to its pre-#608 self.
//
// Dialog behaviour (lazy fetch, ordering, strength, keyboard, errors) lives in
// the sibling VariationProvenanceDialog.spec.ts.

import { describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { bootstrapStubs } from '@/test-utils';
import EntityEvidenceGrid, { type EntityEvidenceModel } from '../components/EntityEvidenceGrid.vue';

// The grid mounts the evidence dialog lazily; nothing here opens it, but stub
// the typed client anyway so an accidental fetch would be visible as a call
// count rather than an unhandled request.
const getEntityVariationEvidence = vi.fn();
vi.mock('@/api/entity', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/entity')>();
  return {
    ...actual,
    getEntityVariationEvidence: (...args: unknown[]) => getEntityVariationEvidence(...args),
  };
});

const stubs = {
  ...bootstrapStubs,
  BCard: { template: '<div><slot name="header" /><slot /></div>' },
  BCardText: { template: '<div><slot /></div>' },
};

function makeModel(variation: Record<string, unknown>[]): EntityEvidenceModel {
  return {
    publications: { loading: false, error: null, additionalRefs: [], geneReviews: [] },
    phenotypes: { loading: false, error: null, list: [] },
    variation: { loading: false, error: null, list: variation },
  };
}

function mountGrid(variation: Record<string, unknown>[]) {
  return mount(EntityEvidenceGrid, { props: { model: makeModel(variation) }, global: { stubs } });
}

// Plumber's json serializer does not auto-unbox, so every scalar nested inside
// the `provenance` list-column arrives as a length-1 ARRAY on the wire (the
// data-frame columns themselves stay scalar). Fixtures use the wire shape.
function wireProvenance(state: string, sources: Record<string, unknown>[], maxStrength: unknown) {
  return { state: [state], max_strength: maxStrength, sources };
}

const CLINVAR_SOURCE = {
  source_type: ['external_database'],
  source_key: ['clinvar'],
  strength: [1],
  summary: ['2 ClinVar records, max 1 star'],
};

const CURATED_TERM = {
  entity_id: 2097,
  vario_id: 'VariO:0133',
  vario_name: 'protein truncation',
  modifier_id: 3,
  provenance: null,
};

const MACHINE_TERM = {
  entity_id: 2097,
  vario_id: 'VariO:0017',
  vario_name: 'nonsynonymous variation',
  modifier_id: 1,
  provenance: wireProvenance('active_unconfirmed', [CLINVAR_SOURCE], [1]),
};

/** The Variation Ontology card is the 4th SectionCard in the grid. */
function variationCardHtml(w: ReturnType<typeof mountGrid>): string {
  const panels = w.findAll('.entity-chip-panel');
  return panels[panels.length - 1].html();
}

describe('EntityEvidenceGrid — variation provenance (#608)', () => {
  it('INERTNESS GATE: renders no provenance affordance when every term has provenance null', () => {
    const w = mountGrid([
      CURATED_TERM,
      { ...CURATED_TERM, vario_id: 'VariO:0001', vario_name: 'variation', modifier_id: 1 },
    ]);

    // Nothing provenance-shaped exists in the DOM at all.
    expect(w.find('[data-testid="variation-provenance-legend"]').exists()).toBe(false);
    expect(w.find('[data-testid="variation-provenance-legend-text"]').exists()).toBe(false);
    expect(w.find('[data-testid="variation-provenance-dialog"]').exists()).toBe(false);
    expect(w.findAll('[data-testid^="variation-provenance-trigger"]')).toHaveLength(0);
    expect(w.findAll('[data-testid^="variation-provenance-group"]')).toHaveLength(0);
    expect(w.findAll('.variation-provenance-trigger')).toHaveLength(0);
    // No trigger means no button anywhere in the variation card…
    expect(variationCardHtml(w)).not.toContain('<button');
    // …and no provenance vocabulary leaked into the markup.
    const html = w.html();
    for (const token of ['provenance', 'unconfirmed', 'machine-derived', 'confirmed']) {
      expect(html.toLowerCase()).not.toContain(token);
    }
    // No lazy fetch was armed.
    expect(getEntityVariationEvidence).not.toHaveBeenCalled();
    w.unmount();
  });

  it('INERTNESS GATE: `provenance: null` renders byte-identically to a pre-#608 payload with no provenance key', () => {
    const withNull = mountGrid([CURATED_TERM]);
    const preChange = mountGrid([
      {
        entity_id: 2097,
        vario_id: 'VariO:0133',
        vario_name: 'protein truncation',
        modifier_id: 3,
      },
    ]);
    expect(variationCardHtml(withNull)).toBe(variationCardHtml(preChange));

    // Golden inert markup, captured from `git show HEAD:` of the pre-#608
    // component during implementation and asserted verbatim here so the gate
    // survives without keeping a frozen copy of the old file around. Note there
    // is exactly ONE comment node — the PRE-EXISTING `v-if` placeholder for the
    // empty-state span. No provenance `v-if` placeholder, no wrapper element and
    // no template comment may appear, which is why the component branches with
    // `v-if`/`v-else` on <template> instead of gating each affordance.
    const GOLDEN_INERT_PANEL =
      '<div class="entity-chip-panel">' +
      '<a class="entity-chip entity-chip-variation entity-chip--variable" ' +
      'href="https://www.ebi.ac.uk/ols4/ontologies/vario/classes?iri=' +
      'http%3A%2F%2Fpurl.obolibrary.org%2Fobo%2FVariO_0133" target="_blank" rel="noopener" ' +
      'aria-label="Variation ontology term: variable | VariO:0133" ' +
      'data-testid="variation-chip-VariO:0133" data-tooltip="variable | VariO:0133">' +
      '<i class="bi bi-box-arrow-up-right" aria-hidden="true"></i> protein truncation</a>\n' +
      '  <!--v-if-->\n' +
      '</div>';
    expect(variationCardHtml(withNull).replace(/ data-v-[0-9a-f]+=""/g, '')).toBe(
      GOLDEN_INERT_PANEL
    );
    withNull.unmount();
    preChange.unmount();
  });

  it('leaves the SectionCard default header untouched when no term has provenance', () => {
    const w = mountGrid([CURATED_TERM]);
    const titles = w.findAll('[data-testid="section-card-title"]').map((n) => n.text());
    expect(titles).toContain('Variation Ontology');
    expect(w.find('.variation-card-header').exists()).toBe(false);
    w.unmount();
  });

  it('renders a curator-authored term exactly as before even when a sibling term is machine-derived', () => {
    const w = mountGrid([CURATED_TERM, MACHINE_TERM]);
    const chip = w.get('[data-testid="variation-chip-VariO:0133"]');

    expect(chip.classes()).toContain('entity-chip');
    expect(chip.classes()).toContain('entity-chip-variation');
    expect(chip.classes()).toContain('entity-chip--variable');
    expect(chip.attributes('title')).toBeUndefined();
    expect(chip.attributes('data-tooltip')).toBe('variable | VariO:0133');
    expect(chip.attributes('aria-label')).toBe('Variation ontology term: variable | VariO:0133');
    expect(chip.attributes('href')).toContain('ebi.ac.uk/ols4');
    // The curator-authored term gets NO trigger of its own.
    expect(w.find('[data-testid="variation-provenance-trigger-VariO:0133-3"]').exists()).toBe(
      false
    );
    w.unmount();
  });

  it('renders a provenance trigger for a machine-derived term whose accessible name states the state in words', () => {
    const w = mountGrid([MACHINE_TERM]);
    const trigger = w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]');

    expect(trigger.element.tagName).toBe('BUTTON');
    expect(trigger.attributes('type')).toBe('button');
    expect(trigger.attributes('aria-haspopup')).toBe('dialog');
    expect(trigger.attributes('aria-expanded')).toBe('false');

    const label = trigger.attributes('aria-label') ?? '';
    expect(label).toContain('nonsynonymous variation');
    expect(label).toContain('machine-derived');
    expect(label).toContain('not confirmed');
    // State must not be carried by glyph/colour alone: the glyph is decorative.
    expect(trigger.find('i').attributes('aria-hidden')).toBe('true');
    w.unmount();
  });

  it('does not use warning or danger tones for the unconfirmed state', () => {
    const w = mountGrid([MACHINE_TERM]);
    const trigger = w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]');
    expect(trigger.classes()).toContain('sysndd-chip--neutral');
    expect(trigger.classes()).not.toContain('sysndd-chip--warning');
    expect(trigger.classes()).not.toContain('sysndd-chip--danger');
    expect(variationCardHtml(w)).not.toContain('status-warning');
    expect(variationCardHtml(w)).not.toContain('status-danger');
    w.unmount();
  });

  it('IDENTITY: present and absent for the same vario_id each render their own state', () => {
    const present = {
      ...MACHINE_TERM,
      modifier_id: 1,
      provenance: wireProvenance('active_unconfirmed', [CLINVAR_SOURCE], [1]),
    };
    const absent = {
      ...MACHINE_TERM,
      modifier_id: 5,
      provenance: wireProvenance(
        'confirmed',
        [{ ...CLINVAR_SOURCE, strength: null, summary: ['curator confirmed'] }],
        null
      ),
    };
    const w = mountGrid([present, absent]);

    const presentTrigger = w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]');
    const absentTrigger = w.get('[data-testid="variation-provenance-trigger-VariO:0017-5"]');

    expect(presentTrigger.attributes('aria-label')).toContain('not confirmed');
    expect(absentTrigger.attributes('aria-label')).toContain('confirmed by a curator');
    expect(absentTrigger.attributes('aria-label')).not.toContain('not confirmed');
    expect(presentTrigger.classes()).toContain('variation-provenance-trigger--unconfirmed');
    expect(absentTrigger.classes()).not.toContain('variation-provenance-trigger--unconfirmed');
    w.unmount();
  });

  it('keeps the term chip external href intact when the term has provenance', () => {
    const w = mountGrid([MACHINE_TERM]);
    const chip = w.get('[data-testid="variation-chip-VariO:0017"]');
    const href = chip.attributes('href') as string;
    expect(href.startsWith('https://www.ebi.ac.uk/ols4/ontologies/vario/classes?iri=')).toBe(true);
    expect(href).toContain(encodeURIComponent('http://purl.obolibrary.org/obo/VariO_0017'));
    expect(chip.attributes('title')).toBeUndefined();
    expect(chip.attributes('data-tooltip')).toBe('present | VariO:0017');
    w.unmount();
  });

  it('exposes a quiet header legend that explains the notation on demand', async () => {
    const w = mountGrid([MACHINE_TERM]);
    const legend = w.get('[data-testid="variation-provenance-legend"]');
    expect(legend.element.tagName).toBe('BUTTON');
    expect(legend.attributes('aria-expanded')).toBe('false');
    expect(w.find('[data-testid="variation-provenance-legend-text"]').exists()).toBe(false);

    await legend.trigger('click');
    expect(legend.attributes('aria-expanded')).toBe('true');
    const text = w.get('[data-testid="variation-provenance-legend-text"]').text();
    expect(text).toContain('machine-derived');

    await legend.trigger('click');
    expect(w.find('[data-testid="variation-provenance-legend-text"]').exists()).toBe(false);
    w.unmount();
  });

  it('tolerates unwrapped (auto-unboxed) scalars as well as plumber length-1 arrays', () => {
    const unwrapped = {
      ...MACHINE_TERM,
      provenance: {
        state: 'active_unconfirmed',
        max_strength: 1,
        sources: [
          {
            source_type: 'external_database',
            source_key: 'clinvar',
            strength: 1,
            summary: '2 ClinVar records, max 1 star',
          },
        ],
      },
    };
    const w = mountGrid([unwrapped]);
    expect(
      w.get('[data-testid="variation-provenance-trigger-VariO:0017-1"]').attributes('aria-label')
    ).toContain('not confirmed');
    w.unmount();
  });

  it('ignores a provenance block whose state is not a served public state', () => {
    const w = mountGrid([
      { ...MACHINE_TERM, provenance: wireProvenance('suggested', [CLINVAR_SOURCE], [1]) },
    ]);
    expect(w.findAll('[data-testid^="variation-provenance-trigger"]')).toHaveLength(0);
    expect(w.find('[data-testid="variation-provenance-legend"]').exists()).toBe(false);
    w.unmount();
  });
});
