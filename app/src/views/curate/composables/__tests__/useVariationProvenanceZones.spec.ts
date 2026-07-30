// views/curate/composables/__tests__/useVariationProvenanceZones.spec.ts
/**
 * #608 — zone partitioning rules, in isolation from the form and the API.
 *
 * The invariant these tests exist to protect: every key is the full
 * `"<modifier_id>-<vario_id>"` tag, never `vario_id` alone. `present` (1) and
 * `absent` (5) for the same VariO term are different assertions with independent
 * provenance state.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ref } from 'vue';

const entityApiMocks = vi.hoisted(() => ({
  getEntityVariation: vi.fn(),
  getEntityVariationSuggestions: vi.fn(),
}));

vi.mock('@/api/entity', () => entityApiMocks);

import useVariationProvenanceZones, {
  partitionVariationZones,
  variationTag,
} from '../useVariationProvenanceZones';
import type { EntityVariationRow, VariationSuggestion } from '@/api/entity';

const modifierLabel = (id: number) => ({ 1: 'present', 5: 'absent' })[id] ?? `modifier ${id}`;

function row(
  varioId: string,
  modifierId: number,
  state: 'active_unconfirmed' | 'confirmed' | null,
  strength: number | null = 1
): EntityVariationRow {
  return {
    entity_id: 7,
    vario_id: varioId,
    vario_name: `name of ${varioId}`,
    modifier_id: modifierId,
    provenance:
      state === null
        ? null
        : {
            state,
            max_strength: strength,
            sources: [
              {
                source_type: 'external_database',
                source_key: 'ClinVar',
                strength,
                summary: '2 records, single submitter',
              },
            ],
          },
  };
}

function suggestion(varioId: string, modifierId: number): VariationSuggestion {
  return {
    entity_id: 7,
    vario_id: varioId,
    vario_name: `name of ${varioId}`,
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
        // This surface does not show the import date; recorded as absent so the
        // fixture still matches the wire contract (#612).
        created_at: null,
      },
    ],
  };
}

describe('variationTag', () => {
  it('encodes the modifier and the CURIE, matching the form-tag format', () => {
    expect(variationTag(1, 'VariO:0017')).toBe('1-VariO:0017');
    expect(variationTag(5, 'VariO:0015-beta')).toBe('5-VariO:0015-beta');
  });
});

describe('partitionVariationZones', () => {
  it('puts a curator-authored (provenance === null) term in Confirmed with no decoration', () => {
    const result = partitionVariationZones({
      selectedTags: ['1-VariO:0002'],
      confirmedTags: [],
      provenanceRows: [row('VariO:0002', 1, null)],
      suggestions: [],
      modifierLabel,
    });

    expect(result.confirmed).toHaveLength(1);
    expect(result.confirmed[0].curatorAuthored).toBe(true);
    expect(result.confirmed[0].evidence).toEqual([]);
    expect(result.confirmed[0].maxStrength).toBeNull();
    expect(result.needsConfirmation).toEqual([]);
  });

  it('treats a selected term with no assertion row as curator-authored', () => {
    const result = partitionVariationZones({
      selectedTags: ['1-VariO:9999'],
      confirmedTags: [],
      provenanceRows: [],
      suggestions: [],
      modifierLabel,
    });

    expect(result.confirmed[0]).toMatchObject({
      tag: '1-VariO:9999',
      varioId: 'VariO:9999',
      modifierId: 1,
      curatorAuthored: true,
      zone: 'confirmed',
    });
  });

  it('keeps a hyphenated CURIE intact when there is no assertion row to read it from', () => {
    const result = partitionVariationZones({
      selectedTags: ['5-VariO:0015-beta'],
      confirmedTags: [],
      provenanceRows: [],
      suggestions: [],
      modifierLabel,
    });

    expect(result.confirmed[0].varioId).toBe('VariO:0015-beta');
    expect(result.confirmed[0].modifierId).toBe(5);
  });

  it('puts an active_unconfirmed term in Needs confirmation with its evidence inline', () => {
    const result = partitionVariationZones({
      selectedTags: ['1-VariO:0017'],
      confirmedTags: [],
      provenanceRows: [row('VariO:0017', 1, 'active_unconfirmed', 1)],
      suggestions: [],
      modifierLabel,
    });

    expect(result.needsConfirmation).toHaveLength(1);
    expect(result.needsConfirmation[0]).toMatchObject({
      zone: 'needs_confirmation',
      curatorAuthored: false,
      modifierLabel: 'present',
      maxStrength: 1,
    });
    expect(result.needsConfirmation[0].evidence).toEqual([
      {
        source_type: 'external_database',
        source_key: 'ClinVar',
        strength: 1,
        summary: '2 records, single submitter',
      },
    ]);
  });

  it('keeps an unrecorded strength as null rather than coercing it to zero', () => {
    const result = partitionVariationZones({
      selectedTags: ['1-VariO:0017'],
      confirmedTags: [],
      provenanceRows: [row('VariO:0017', 1, 'active_unconfirmed', null)],
      suggestions: [],
      modifierLabel,
    });

    expect(result.needsConfirmation[0].maxStrength).toBeNull();
    expect(result.needsConfirmation[0].evidence[0].strength).toBeNull();
  });

  it('leaves an already-confirmed machine-derived term in Confirmed', () => {
    const result = partitionVariationZones({
      selectedTags: ['1-VariO:0017'],
      confirmedTags: [],
      provenanceRows: [row('VariO:0017', 1, 'confirmed')],
      suggestions: [],
      modifierLabel,
    });

    expect(result.confirmed).toHaveLength(1);
    expect(result.confirmed[0].curatorAuthored).toBe(false);
    expect(result.needsConfirmation).toEqual([]);
  });

  it('IDENTITY: partitions present (1) and absent (5) of one vario_id independently', () => {
    const result = partitionVariationZones({
      selectedTags: ['1-VariO:0017', '5-VariO:0017'],
      confirmedTags: ['1-VariO:0017'],
      provenanceRows: [
        row('VariO:0017', 1, 'active_unconfirmed'),
        row('VariO:0017', 5, 'active_unconfirmed'),
      ],
      suggestions: [],
      modifierLabel,
    });

    expect(result.confirmed.map((e) => e.tag)).toEqual(['1-VariO:0017']);
    expect(result.needsConfirmation.map((e) => e.tag)).toEqual(['5-VariO:0017']);
    expect(result.needsConfirmation[0].modifierLabel).toBe('absent');
  });

  it('excludes a suggestion that is already selected, and one that was dismissed', () => {
    const result = partitionVariationZones({
      selectedTags: ['1-VariO:0508'],
      confirmedTags: [],
      dismissedTags: ['1-VariO:0600'],
      provenanceRows: [],
      suggestions: [
        suggestion('VariO:0508', 1),
        suggestion('VariO:0600', 1),
        suggestion('VariO:0700', 1),
      ],
      modifierLabel,
    });

    expect(result.suggested.map((e) => e.tag)).toEqual(['1-VariO:0700']);
    expect(result.suggested[0].evidence).toEqual([
      {
        source_type: 'external_database',
        source_key: 'ClinVar',
        strength: 3,
        summary: '6 records, expert panel',
      },
    ]);
  });

  it('preserves API source order (never re-sorts corroborating sources)', () => {
    const twoSources = row('VariO:0017', 1, 'active_unconfirmed');
    twoSources.provenance!.sources = [
      { source_type: 'external_database', source_key: 'ClinVar', strength: 1, summary: 'first' },
      { source_type: 'literature', source_key: 'PMID:1', strength: 4, summary: 'second' },
    ];

    const result = partitionVariationZones({
      selectedTags: ['1-VariO:0017'],
      confirmedTags: [],
      provenanceRows: [twoSources],
      suggestions: [],
      modifierLabel,
    });

    expect(result.needsConfirmation[0].evidence.map((e) => e.summary)).toEqual(['first', 'second']);
  });
});

describe('useVariationProvenanceZones', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  function setup(selected: string[] = []) {
    const selectedTags = ref<string[]>(selected);
    const confirmedTags = ref<string[]>([]);
    const zones = useVariationProvenanceZones({ selectedTags, confirmedTags });
    return { zones, selectedTags, confirmedTags };
  }

  it('is inert before anything is loaded', () => {
    const { zones } = setup(['1-VariO:0002']);
    expect(zones.hasZones.value).toBe(false);
    expect(zones.confirmed.value.map((e) => e.tag)).toEqual(['1-VariO:0002']);
  });

  it('confirmTerm records the action for exactly that tag', () => {
    const { zones, confirmedTags } = setup(['1-VariO:0017', '5-VariO:0017']);
    zones.confirmTerm('1-VariO:0017');

    expect(confirmedTags.value).toEqual(['1-VariO:0017']);
    expect(zones.provenanceActionFor('1-VariO:0017')).toBe('confirm');
    expect(zones.provenanceActionFor('5-VariO:0017')).toBeUndefined();
  });

  it('confirmTerm is idempotent', () => {
    const { zones, confirmedTags } = setup(['1-VariO:0017']);
    zones.confirmTerm('1-VariO:0017');
    zones.confirmTerm('1-VariO:0017');
    expect(confirmedTags.value).toEqual(['1-VariO:0017']);
  });

  it('removeTerm drops the tag from both the selection and the confirmed set', () => {
    const { zones, selectedTags, confirmedTags } = setup(['1-VariO:0017', '1-VariO:0508']);
    zones.confirmTerm('1-VariO:0017');
    zones.removeTerm('1-VariO:0017');

    expect(selectedTags.value).toEqual(['1-VariO:0508']);
    expect(confirmedTags.value).toEqual([]);
    expect(zones.provenanceActionFor('1-VariO:0017')).toBeUndefined();
  });

  it('acceptSuggestion selects AND confirms in one action', () => {
    const { zones, selectedTags, confirmedTags } = setup([]);
    zones.acceptSuggestion('1-VariO:0508');

    expect(selectedTags.value).toEqual(['1-VariO:0508']);
    expect(confirmedTags.value).toEqual(['1-VariO:0508']);
  });

  it('dismissSuggestion adds nothing to the selection', () => {
    const { zones, selectedTags, confirmedTags } = setup([]);
    zones.suggestions.value = [suggestion('VariO:0508', 1)];
    expect(zones.suggested.value).toHaveLength(1);

    zones.dismissSuggestion('1-VariO:0508');

    expect(zones.suggested.value).toEqual([]);
    expect(selectedTags.value).toEqual([]);
    expect(confirmedTags.value).toEqual([]);
  });

  it('loadForEntity fills both sources and flips hasZones', async () => {
    entityApiMocks.getEntityVariation.mockResolvedValue([
      row('VariO:0017', 1, 'active_unconfirmed'),
    ]);
    entityApiMocks.getEntityVariationSuggestions.mockResolvedValue([suggestion('VariO:0508', 1)]);

    const { zones } = setup(['1-VariO:0017']);
    await zones.loadForEntity(7);

    expect(zones.hasZones.value).toBe(true);
    expect(zones.needsConfirmation.value).toHaveLength(1);
    expect(zones.suggested.value).toHaveLength(1);
    expect(zones.loading.value).toBe(false);
  });

  it('loadForEntity never throws when either route fails, and degrades to no zones', async () => {
    entityApiMocks.getEntityVariation.mockRejectedValue(new Error('404 pre-#608 API'));
    entityApiMocks.getEntityVariationSuggestions.mockRejectedValue(new Error('403 not a Curator'));

    const { zones } = setup(['1-VariO:0017']);
    await expect(zones.loadForEntity(7)).resolves.toBeUndefined();

    expect(zones.hasZones.value).toBe(false);
    expect(zones.provenanceRows.value).toEqual([]);
    expect(zones.suggestions.value).toEqual([]);
  });

  it('reset clears fetched state and dismissals but leaves the selection alone', async () => {
    entityApiMocks.getEntityVariation.mockResolvedValue([
      row('VariO:0017', 1, 'active_unconfirmed'),
    ]);
    entityApiMocks.getEntityVariationSuggestions.mockResolvedValue([suggestion('VariO:0508', 1)]);

    const { zones, selectedTags } = setup(['1-VariO:0017']);
    await zones.loadForEntity(7);
    zones.dismissSuggestion('1-VariO:0508');

    zones.reset();

    expect(zones.provenanceRows.value).toEqual([]);
    expect(zones.suggestions.value).toEqual([]);
    expect(zones.hasZones.value).toBe(false);
    expect(selectedTags.value).toEqual(['1-VariO:0017']);
  });
});

describe('the REAL plumber wire shape (regression: length-1 array scalars)', () => {
  /**
   * Every fixture above uses plain scalars, which is why this bug shipped and was
   * only caught by driving the browser against the real API.
   *
   * plumber does NOT auto-unbox, so every scalar NESTED inside the `provenance`
   * list-column of `GET /api/entity/<id>/variation`, and every field of the
   * `list()`-built `GET .../variation/suggestions` response, arrives as a
   * LENGTH-1 ARRAY. Verified verbatim against the running API:
   *
   *   {"entity_id":123,"vario_id":"VariO:0017","modifier_id":1,
   *    "provenance":{"state":["active_unconfirmed"],"max_strength":[1],
   *      "sources":[{"source_type":["external_database"],"source_key":["clinvar"],
   *                  "strength":[1],"summary":["2 ClinVar records, max 1 star"]}]}}
   *
   * A strict `provenance.state === 'active_unconfirmed'` is FALSE against that,
   * so the "Needs confirmation" zone silently rendered EMPTY and every
   * machine-derived unconfirmed term was misfiled as Confirmed — i.e. the review
   * step the whole feature exists to force was invisible. These fixtures are
   * copied from the real payload; do not "tidy" them into plain scalars.
   */
  const wireRow = {
    entity_id: 123,
    vario_id: 'VariO:0017',
    vario_name: 'nonsynonymous variation',
    modifier_id: 1,
    provenance: {
      state: ['active_unconfirmed'],
      max_strength: [1],
      sources: [
        {
          source_type: ['external_database'],
          source_key: ['clinvar'],
          strength: [1],
          summary: ['2 ClinVar records, max 1 star'],
        },
      ],
    },
  } as unknown as EntityVariationRow;

  const wireSuggestion = {
    entity_id: [123],
    vario_id: ['VariO:0508'],
    vario_name: ['splice variation'],
    modifier_id: [1],
    state: ['suggested'],
    max_strength: [3],
    evidence: [
      {
        source_type: ['external_database'],
        source_key: ['clinvar'],
        batch_id: ['pw-fixture-2026-02'],
        source_version: ['2026-01 release'],
        evidence_summary: ['5 ClinVar records, max 3 stars'],
        evidence_strength: [3],
        evidence_json: {},
      },
    ],
  } as unknown as VariationSuggestion;

  it('files an array-wrapped active_unconfirmed state under needs_confirmation', () => {
    const result = partitionVariationZones({
      selectedTags: ['1-VariO:0017'],
      confirmedTags: [],
      provenanceRows: [wireRow],
      suggestions: [],
      modifierLabel,
    });

    expect(result.needsConfirmation.map((e) => e.tag)).toEqual(['1-VariO:0017']);
    expect(result.confirmed).toEqual([]);
  });

  it('unwraps the nested scalars into plain values, not arrays', () => {
    const [entry] = partitionVariationZones({
      selectedTags: ['1-VariO:0017'],
      confirmedTags: [],
      provenanceRows: [wireRow],
      suggestions: [],
      modifierLabel,
    }).needsConfirmation;

    expect(entry.varioId).toBe('VariO:0017');
    expect(entry.varioName).toBe('nonsynonymous variation');
    expect(entry.modifierId).toBe(1);
    expect(entry.modifierLabel).toBe('present');
    expect(entry.maxStrength).toBe(1);
    expect(entry.curatorAuthored).toBe(false);
    // Strength must be a NUMBER: the card compares it to null and rounds it, and
    // an array would silently survive both while breaking any real arithmetic.
    expect(entry.evidence).toEqual([
      {
        source_type: 'external_database',
        source_key: 'clinvar',
        strength: 1,
        summary: '2 ClinVar records, max 1 star',
      },
    ]);
  });

  it('builds the suggestion tag and evidence from array-wrapped fields', () => {
    const [entry] = partitionVariationZones({
      selectedTags: [],
      confirmedTags: [],
      provenanceRows: [],
      suggestions: [wireSuggestion],
      modifierLabel,
    }).suggested;

    expect(entry.tag).toBe('1-VariO:0508');
    expect(entry.varioId).toBe('VariO:0508');
    expect(entry.varioName).toBe('splice variation');
    expect(entry.maxStrength).toBe(3);
    expect(entry.evidence[0].strength).toBe(3);
    expect(entry.evidence[0].summary).toBe('5 ClinVar records, max 3 stars');
  });

  it('keeps a null strength as null (NOT RECORDED), never 0', () => {
    const nullStrengthRow = {
      ...wireRow,
      provenance: {
        state: ['confirmed'],
        max_strength: null,
        sources: [
          {
            source_type: ['literature'],
            source_key: ['pubtator'],
            strength: null,
            summary: ['Co-mentioned in 4 publications; strength not scored'],
          },
        ],
      },
    } as unknown as EntityVariationRow;

    const [entry] = partitionVariationZones({
      selectedTags: ['1-VariO:0017'],
      confirmedTags: [],
      provenanceRows: [nullStrengthRow],
      suggestions: [],
      modifierLabel,
    }).confirmed;

    expect(entry.maxStrength).toBeNull();
    expect(entry.evidence[0].strength).toBeNull();
  });
});
