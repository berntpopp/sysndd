// views/curate/components/ReviewFormFields.provenance.spec.ts
/**
 * #608 — rendering contract for the three-zone variation-ontology picker.
 *
 * Covers what the composable specs cannot: that the zones actually appear, that
 * the counts in TEXT match the number of cards rendered, that every action
 * button is a real `<button>` whose accessible name names the term it acts on,
 * and — most importantly — that the picker is INERT (byte-for-byte pre-#608)
 * when there is no provenance and no suggestion. That inert case is production
 * on day one, before the provenance backfill runs.
 *
 * The `data-testid` hooks asserted here are the contract the Playwright spec
 * depends on; renaming one is a breaking change.
 */

import { describe, it, expect, vi } from 'vitest';
import { mount, type VueWrapper } from '@vue/test-utils';
import { ref } from 'vue';
import { expectNoA11yViolations } from '@/test-utils';
import ReviewFormFields from './ReviewFormFields.vue';
import useVariationProvenanceZones from '@/views/curate/composables/useVariationProvenanceZones';
import type { EntityVariationRow, VariationSuggestion } from '@/api/entity';
import type { ReviewFormData } from '@/views/curate/composables/useReviewForm';

vi.mock('@/api/entity', () => ({
  getEntityVariation: vi.fn(),
  getEntityVariationSuggestions: vi.fn(),
}));

const passthrough = (tag = 'div') => ({ template: `<${tag}><slot /></${tag}>` });

const stubs = {
  BOverlay: passthrough(),
  BForm: passthrough('form'),
  BBadge: passthrough('span'),
  BPopover: passthrough(),
  BFormTextarea: { template: '<textarea />' },
  BFormTags: { template: '<div class="b-form-tags" />' },
  BInputGroup: passthrough(),
  BFormInput: { template: '<input />' },
  BButton: { template: '<button><slot /></button>' },
  BFormTag: passthrough('span'),
  BLink: passthrough('a'),
  TreeMultiSelect: { template: '<div class="tree-multi-select" />' },
};

function provenanceRow(
  varioId: string,
  modifierId: number,
  state: 'active_unconfirmed' | 'confirmed' | null,
  strength: number | null = 1,
  summary = '2 records, single submitter'
): EntityVariationRow {
  return {
    entity_id: 7,
    vario_id: varioId,
    vario_name: `nonsynonymous ${varioId}`,
    modifier_id: modifierId,
    provenance:
      state === null
        ? null
        : {
            state,
            max_strength: strength,
            sources: [
              { source_type: 'external_database', source_key: 'ClinVar', strength, summary },
            ],
          },
  };
}

function suggestion(varioId: string, modifierId: number): VariationSuggestion {
  return {
    entity_id: 7,
    vario_id: varioId,
    vario_name: `splice ${varioId}`,
    modifier_id: modifierId,
    state: 'suggested',
    max_strength: 3,
    evidence: [
      {
        source_type: 'external_database',
        source_key: 'ClinVar',
        batch_id: 'b1',
        source_version: null,
        evidence_summary: '6 records, expert panel',
        evidence_strength: 3,
        evidence_json: null,
      },
    ],
  };
}

function formData(variationOntology: string[]): ReviewFormData {
  return {
    synopsis: 'A synopsis long enough to be valid',
    phenotypes: [],
    variationOntology,
    variationConfirmed: [],
    publications: [],
    genereviews: [],
    comment: '',
  };
}

function mountFields(options: {
  selected: string[];
  provenanceRows?: EntityVariationRow[];
  suggestions?: VariationSuggestion[];
}) {
  const data = formData(options.selected);
  const selectedTags = ref(data.variationOntology);
  const confirmedTags = ref(data.variationConfirmed);
  const zones = useVariationProvenanceZones({ selectedTags, confirmedTags });
  zones.provenanceRows.value = options.provenanceRows ?? [];
  zones.suggestions.value = options.suggestions ?? [];

  const wrapper = mount(ReviewFormFields, {
    props: {
      modelValue: data,
      phenotypesOptions: [],
      variationOptions: [{ id: '1-VariO:9999', label: 'a tree-only label' }],
      variationZones: zones,
    },
    global: { stubs },
  });

  return { wrapper, zones, selectedTags, confirmedTags };
}

const testids = (wrapper: VueWrapper, id: string) => wrapper.findAll(`[data-testid="${id}"]`);

describe('ReviewFormFields — #608 provenance zones', () => {
  it('INERT: renders the plain picker with no zone scaffolding when there is nothing to decide', () => {
    const { wrapper } = mountFields({
      selected: ['1-VariO:0002'],
      provenanceRows: [provenanceRow('VariO:0002', 1, null)],
    });

    expect(wrapper.find('[data-testid="variation-provenance-zones"]').exists()).toBe(false);
    expect(testids(wrapper, 'variation-card')).toHaveLength(0);
    // The picker itself is untouched.
    expect(wrapper.find('.tree-multi-select').exists()).toBe(true);
  });

  it('is also inert with no provenance data at all (pre-backfill production)', () => {
    const { wrapper } = mountFields({ selected: ['1-VariO:0002'] });
    expect(wrapper.find('[data-testid="variation-provenance-zones"]').exists()).toBe(false);
  });

  it('renders all three zones with counts that match the rendered entries', () => {
    const { wrapper } = mountFields({
      selected: ['1-VariO:0002', '1-VariO:0017', '5-VariO:0017'],
      provenanceRows: [
        provenanceRow('VariO:0002', 1, null),
        provenanceRow('VariO:0017', 1, 'active_unconfirmed'),
        provenanceRow('VariO:0017', 5, 'active_unconfirmed'),
      ],
      suggestions: [suggestion('VariO:0508', 1)],
    });

    expect(wrapper.find('[data-testid="variation-provenance-zones"]').exists()).toBe(true);

    const confirmedZone = wrapper.find('[data-testid="variation-zone-confirmed"]');
    const needsZone = wrapper.find('[data-testid="variation-zone-needs-confirmation"]');
    const suggestedZone = wrapper.find('[data-testid="variation-zone-suggested"]');

    expect(confirmedZone.exists()).toBe(true);
    expect(needsZone.exists()).toBe(true);
    expect(suggestedZone.exists()).toBe(true);

    // Counts are in text, not conveyed by position, and are grammatical.
    expect(wrapper.find('[data-testid="variation-zone-confirmed-count"]').text()).toBe('1 term');
    expect(wrapper.find('[data-testid="variation-zone-needs-confirmation-count"]').text()).toBe(
      '2 terms'
    );
    expect(wrapper.find('[data-testid="variation-zone-suggested-count"]').text()).toBe('1 term');

    // ...and they match what is actually rendered.
    expect(confirmedZone.findAll('[data-testid="variation-confirmed-chip"]')).toHaveLength(1);
    expect(needsZone.findAll('[data-testid="variation-card"]')).toHaveLength(2);
    expect(suggestedZone.findAll('[data-testid="variation-card"]')).toHaveLength(1);

    // Each zone is a labelled region whose name is exposed to assistive tech.
    expect(needsZone.attributes('aria-labelledby')).toBe('vario-zone-needs-confirmation-heading');
    expect(wrapper.find('#vario-zone-needs-confirmation-heading').text()).toContain(
      'Needs confirmation'
    );
  });

  it('renders the stored evidence inline, verbatim, with no invented labels', () => {
    const { wrapper } = mountFields({
      selected: ['1-VariO:0017'],
      provenanceRows: [
        provenanceRow('VariO:0017', 1, 'active_unconfirmed', 1, '2 records, single submitter'),
      ],
    });

    const card = wrapper.find('[data-testid="variation-card"]');
    expect(card.text()).toContain('ClinVar');
    expect(card.text()).toContain('2 records, single submitter');
    expect(card.text()).toContain('VariO:0017');
    // No fabricated protein/cDNA label may appear anywhere.
    expect(card.text()).not.toMatch(/p\.[A-Z][a-z]{2}\d+/);
  });

  it('omits strength entirely when it is not recorded (never zero stars)', () => {
    const { wrapper } = mountFields({
      selected: ['1-VariO:0017'],
      provenanceRows: [provenanceRow('VariO:0017', 1, 'active_unconfirmed', null)],
    });

    const card = wrapper.find('[data-testid="variation-card"]');
    expect(card.text()).not.toContain('☆');
    expect(card.text()).not.toContain('★');
    expect(card.text()).not.toContain('NA');
    expect(card.text()).toContain('2 records, single submitter');
  });

  it('gives every action button an accessible name that names its own term', () => {
    const { wrapper } = mountFields({
      selected: ['1-VariO:0017', '5-VariO:0017'],
      provenanceRows: [
        provenanceRow('VariO:0017', 1, 'active_unconfirmed'),
        provenanceRow('VariO:0017', 5, 'active_unconfirmed'),
      ],
      suggestions: [suggestion('VariO:0508', 1)],
    });

    const labels = wrapper
      .findAll('button[data-testid^="variation-action-"]')
      .map((button) => [button.element.tagName, button.attributes('aria-label')]);

    expect(labels).toEqual([
      ['BUTTON', 'Confirm nonsynonymous VariO:0017, present'],
      ['BUTTON', 'Remove nonsynonymous VariO:0017, present'],
      ['BUTTON', 'Confirm nonsynonymous VariO:0017, absent'],
      ['BUTTON', 'Remove nonsynonymous VariO:0017, absent'],
      ['BUTTON', 'Accept splice VariO:0508, present'],
      ['BUTTON', 'Dismiss splice VariO:0508, present'],
    ]);
  });

  it('Confirm moves only the clicked assertion, leaving its absent twin unconfirmed', async () => {
    const { wrapper, confirmedTags } = mountFields({
      selected: ['1-VariO:0017', '5-VariO:0017'],
      provenanceRows: [
        provenanceRow('VariO:0017', 1, 'active_unconfirmed'),
        provenanceRow('VariO:0017', 5, 'active_unconfirmed'),
      ],
    });

    const presentCard = wrapper.find('[data-tag="1-VariO:0017"]');
    await presentCard.find('[data-testid="variation-action-confirm"]').trigger('click');

    expect(confirmedTags.value).toEqual(['1-VariO:0017']);
    expect(
      wrapper
        .find('[data-testid="variation-zone-needs-confirmation"]')
        .findAll('[data-testid="variation-card"]')
    ).toHaveLength(1);
    expect(
      wrapper
        .find('[data-testid="variation-zone-needs-confirmation"]')
        .find('[data-tag]')
        .attributes('data-tag')
    ).toBe('5-VariO:0017');
    expect(wrapper.find('[data-testid="variation-zone-confirmed-count"]').text()).toBe('1 term');
  });

  it('Remove drops the term from the selection', async () => {
    const { wrapper, selectedTags } = mountFields({
      selected: ['1-VariO:0017'],
      provenanceRows: [provenanceRow('VariO:0017', 1, 'active_unconfirmed')],
    });

    await wrapper.find('[data-testid="variation-action-remove"]').trigger('click');

    expect(selectedTags.value).toEqual([]);
    expect(wrapper.find('[data-testid="variation-provenance-zones"]').exists()).toBe(false);
  });

  it('Accept adds the suggestion to the selection and Dismiss adds nothing', async () => {
    const accepted = mountFields({
      selected: [],
      suggestions: [suggestion('VariO:0508', 1)],
    });
    await accepted.wrapper.find('[data-testid="variation-action-accept"]').trigger('click');
    expect(accepted.selectedTags.value).toEqual(['1-VariO:0508']);
    expect(accepted.confirmedTags.value).toEqual(['1-VariO:0508']);

    const dismissed = mountFields({
      selected: [],
      suggestions: [suggestion('VariO:0508', 1)],
    });
    await dismissed.wrapper.find('[data-testid="variation-action-dismiss"]').trigger('click');
    expect(dismissed.selectedTags.value).toEqual([]);
    expect(dismissed.confirmedTags.value).toEqual([]);
    expect(dismissed.wrapper.find('[data-testid="variation-provenance-zones"]').exists()).toBe(
      false
    );
  });

  it('falls back to the tree label, then the CURIE, when the API named nothing', () => {
    const { wrapper } = mountFields({
      selected: ['1-VariO:9999', '1-VariO:0017'],
      provenanceRows: [provenanceRow('VariO:0017', 1, 'active_unconfirmed')],
    });

    expect(wrapper.find('[data-testid="variation-confirmed-chip"]').text()).toContain(
      'a tree-only label'
    );
  });

  it('does not use an alarming status tone for the Needs-confirmation zone', () => {
    const { wrapper } = mountFields({
      selected: ['1-VariO:0017'],
      provenanceRows: [provenanceRow('VariO:0017', 1, 'active_unconfirmed')],
    });

    const html = wrapper.find('[data-testid="variation-provenance-zones"]').html();
    expect(html).not.toContain('sysndd-chip--danger');
    expect(html).not.toContain('sysndd-chip--warning');
    expect(html).not.toContain('alert-danger');
    expect(html).not.toContain('alert-warning');
  });

  it('disables the zone actions when the form is read-only', () => {
    const data = formData(['1-VariO:0017']);
    const zones = useVariationProvenanceZones({
      selectedTags: ref(data.variationOntology),
      confirmedTags: ref(data.variationConfirmed),
    });
    zones.provenanceRows.value = [provenanceRow('VariO:0017', 1, 'active_unconfirmed')];

    const wrapper = mount(ReviewFormFields, {
      props: {
        modelValue: data,
        phenotypesOptions: [],
        variationOptions: [],
        readonly: true,
        variationZones: zones,
      },
      global: { stubs },
    });

    wrapper.findAll('button[data-testid^="variation-action-"]').forEach((button) => {
      expect(button.attributes('disabled')).toBeDefined();
    });
  });

  it('has no axe violations with all three zones rendered', async () => {
    const { wrapper } = mountFields({
      selected: ['1-VariO:0002', '1-VariO:0017'],
      provenanceRows: [
        provenanceRow('VariO:0002', 1, null),
        provenanceRow('VariO:0017', 1, 'active_unconfirmed'),
      ],
      suggestions: [suggestion('VariO:0508', 1)],
    });

    // `region` is a page-level landmark rule: this mount is a form fragment
    // with no surrounding <main>, so every sibling field would be reported.
    // Disabled here only — the surrounding page owns its landmarks.
    await expectNoA11yViolations(wrapper.element as HTMLElement, {
      rules: { region: { enabled: false } },
    });
  });
});
