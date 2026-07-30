// views/curate/composables/useVariationProvenanceZones.ts
/**
 * #608 — three-zone partitioning for the curation form's variation-ontology
 * picker.
 *
 * WHY THIS EXISTS
 * ---------------
 * The curation form prefills the picker from the entity's existing terms. Before
 * #608 that meant a curator who opened an entity to fix one sentence of synopsis
 * got every existing term pre-checked, and saving rewrote all of them onto a new
 * curator-attributed review — no user action distinguished "I read the papers and
 * agree" from "I did not notice the pre-checked box". This composable makes the
 * decision visible and deliberate by splitting the picker's contents into three
 * zones and giving each machine-derived term an explicit action.
 *
 * WHAT THE SERVER OWNS (do not re-implement here)
 * -----------------------------------------------
 * Reconciliation is server-side and identity-aware. On every review save the API
 * compares the entity's previous assertion set against the submitted set:
 *
 *   - submitted + `active_unconfirmed` + no action  -> stays `active_unconfirmed`
 *   - submitted + `active_unconfirmed` + `confirm`  -> `confirmed` + attribution
 *   - submitted + `suggested`                       -> `confirmed` + attribution
 *   - submitted + `confirmed`                       -> unchanged, not re-stamped
 *   - NOT submitted (`active_unconfirmed`/`suggested`) -> `rejected`, but only
 *     when the save determines the entity's served term set
 *
 * Two consequences shape this module:
 *
 *  1. `Remove` and `Dismiss` need NO wire protocol. Dropping a term from the
 *     submitted set is what records a rejection. There is deliberately no
 *     `variation_ontology_rejected` array — the server cannot trust a client
 *     field, and an earlier design revision that added one was wrong.
 *  2. `Confirm` / `Accept` only need to set `provenance_action: "confirm"` on the
 *     submitted entry, which `provenanceActionFor()` drives.
 *
 * IDENTITY
 * --------
 * Every key in this module is the full selection tag `"<modifier_id>-<vario_id>"`,
 * NEVER `vario_id` alone. `present` (modifier 1) and `absent` (modifier 5) for the
 * same VariO term are different assertions with independent provenance state, and
 * confirming one must not confirm the other. This is the same encoding the form's
 * `formData.variationOntology` and the TreeMultiSelect option ids already use, so
 * the zones and the picker are keyed identically.
 */

import { computed, ref, type ComputedRef, type Ref } from 'vue';
import type { AxiosRequestConfig } from 'axios';
import {
  getEntityVariation,
  getEntityVariationSuggestions,
  type EntityVariationRow,
  type VariationSuggestion,
} from '@/api/entity';
import useText from '@/composables/useText';

export type VariationZoneKind = 'confirmed' | 'needs_confirmation' | 'suggested';

/**
 * One evidence line rendered inline on a zone card.
 *
 * `strength` is 0-4, or `null` meaning NOT RECORDED — which must never render as
 * zero stars. `summary` is the source's own stored wording, displayed verbatim;
 * it is never synthesised or embellished, and no protein/cDNA label is ever
 * derived from it (none is stored, and inventing one is exactly the fabrication
 * this feature exists to prevent).
 */
export interface VariationZoneEvidence {
  source_type: string;
  source_key: string;
  strength: number | null;
  summary: string;
}

export interface VariationZoneEntry {
  /** `"<modifier_id>-<vario_id>"` — the identity of this assertion. */
  tag: string;
  varioId: string;
  modifierId: number;
  /** Server-supplied term name; empty when only the local selection knows it. */
  varioName: string;
  /** `present` / `absent` / ... from the shared `modifier_text` vocabulary. */
  modifierLabel: string;
  zone: VariationZoneKind;
  /** True only for a curator-authored term (`provenance === null`). */
  curatorAuthored: boolean;
  maxStrength: number | null;
  evidence: VariationZoneEvidence[];
}

export interface VariationZonePartition {
  confirmed: VariationZoneEntry[];
  needsConfirmation: VariationZoneEntry[];
  suggested: VariationZoneEntry[];
}

export interface VariationProvenanceZonesApi {
  confirmed: ComputedRef<VariationZoneEntry[]>;
  needsConfirmation: ComputedRef<VariationZoneEntry[]>;
  suggested: ComputedRef<VariationZoneEntry[]>;
  /** False when there is nothing to act on — the form then renders as pre-#608. */
  hasZones: ComputedRef<boolean>;
  loading: Ref<boolean>;
  provenanceRows: Ref<EntityVariationRow[]>;
  suggestions: Ref<VariationSuggestion[]>;
  confirmTerm: (tag: string) => void;
  removeTerm: (tag: string) => void;
  acceptSuggestion: (tag: string) => void;
  dismissSuggestion: (tag: string) => void;
  provenanceActionFor: (tag: string) => 'confirm' | undefined;
  loadForEntity: (entityId: number | string, config?: AxiosRequestConfig) => Promise<void>;
  reset: () => void;
}

export interface UseVariationProvenanceZonesOptions {
  /** Writable ref onto the form's `variationOntology` selection tags. */
  selectedTags: Ref<string[]>;
  /** Writable ref onto the tags the curator explicitly confirmed this session. */
  confirmedTags: Ref<string[]>;
}

/**
 * Build the selection tag for one assertion. Mirrors the loader in
 * `useReviewForm.loadReviewData` exactly, so entity-scoped provenance rows and
 * review-scoped selections key against each other.
 */
export function variationTag(modifierId: unknown, varioId: unknown): string {
  return `${modifierId}-${varioId}`;
}

function normaliseModifierId(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

/**
 * Compact the API's `provenance.sources` into the inline evidence shape.
 * `sources` arrives already ordered by the API (strength desc, then source_key);
 * it is deliberately NOT re-sorted here.
 */
function evidenceFromProvenance(row: EntityVariationRow): VariationZoneEvidence[] {
  const sources = row.provenance?.sources;
  if (!Array.isArray(sources)) return [];
  return sources.map((source) => ({
    source_type: source.source_type,
    source_key: source.source_key,
    strength: source.strength ?? null,
    summary: source.summary ?? '',
  }));
}

/** Same for a suggestion's full evidence records (different column names). */
function evidenceFromSuggestion(suggestion: VariationSuggestion): VariationZoneEvidence[] {
  if (!Array.isArray(suggestion.evidence)) return [];
  return suggestion.evidence.map((record) => ({
    source_type: record.source_type,
    source_key: record.source_key,
    strength: record.evidence_strength ?? null,
    summary: record.evidence_summary ?? '',
  }));
}

/**
 * Pure zone partitioning. Exported so the rules can be tested without a form,
 * an API, or a component.
 */
export function partitionVariationZones(input: {
  selectedTags: string[];
  confirmedTags: string[];
  dismissedTags?: string[];
  provenanceRows: EntityVariationRow[];
  suggestions: VariationSuggestion[];
  modifierLabel: (modifierId: number) => string;
}): VariationZonePartition {
  const confirmedSet = new Set(input.confirmedTags);
  const dismissedSet = new Set(input.dismissedTags ?? []);
  const selectedSet = new Set(input.selectedTags);

  const rowByTag = new Map<string, EntityVariationRow>();
  input.provenanceRows.forEach((row) => {
    rowByTag.set(variationTag(row.modifier_id, row.vario_id), row);
  });

  const confirmed: VariationZoneEntry[] = [];
  const needsConfirmation: VariationZoneEntry[] = [];

  // Selection order is the render order, so the zones read in the same sequence
  // the picker itself uses.
  input.selectedTags.forEach((tag) => {
    const row = rowByTag.get(tag);
    const modifierId = normaliseModifierId(row ? row.modifier_id : tag.split('-')[0]);
    const provenance = row?.provenance ?? null;
    // A term the entity-scoped read does not know about (e.g. one the curator
    // just added in this session) has no assertion row and is therefore
    // curator-authored by definition.
    const curatorAuthored = !row || provenance === null;
    const unconfirmed = provenance?.state === 'active_unconfirmed' && !confirmedSet.has(tag);

    const entry: VariationZoneEntry = {
      tag,
      varioId: row ? String(row.vario_id) : tag.slice(tag.indexOf('-') + 1),
      modifierId,
      varioName: row ? String(row.vario_name ?? '') : '',
      modifierLabel: input.modifierLabel(modifierId),
      zone: unconfirmed ? 'needs_confirmation' : 'confirmed',
      curatorAuthored,
      maxStrength: provenance?.max_strength ?? null,
      evidence: row ? evidenceFromProvenance(row) : [],
    };

    if (unconfirmed) {
      needsConfirmation.push(entry);
    } else {
      confirmed.push(entry);
    }
  });

  // Suggestions are unchecked by default: they are NOT in the submitted set
  // until accepted, and a dismissed one simply stops being offered.
  const suggested = input.suggestions
    .map((suggestion) => {
      const tag = variationTag(suggestion.modifier_id, suggestion.vario_id);
      const modifierId = normaliseModifierId(suggestion.modifier_id);
      return {
        tag,
        varioId: String(suggestion.vario_id),
        modifierId,
        varioName: String(suggestion.vario_name ?? ''),
        modifierLabel: input.modifierLabel(modifierId),
        zone: 'suggested' as const,
        curatorAuthored: false,
        maxStrength: suggestion.max_strength ?? null,
        evidence: evidenceFromSuggestion(suggestion),
      };
    })
    .filter((entry) => !selectedSet.has(entry.tag) && !dismissedSet.has(entry.tag));

  return { confirmed, needsConfirmation, suggested };
}

/**
 * Zone state + actions for one curation form instance.
 */
export default function useVariationProvenanceZones(
  options: UseVariationProvenanceZonesOptions
): VariationProvenanceZonesApi {
  const { selectedTags, confirmedTags } = options;
  const { modifier_text: modifierText } = useText();

  const provenanceRows = ref<EntityVariationRow[]>([]);
  const suggestions = ref<VariationSuggestion[]>([]);
  /** Session-only: a dismissed suggestion is never sent anywhere. */
  const dismissedTags = ref<string[]>([]);
  const loading = ref(false);

  const modifierLabel = (modifierId: number): string =>
    modifierText?.[modifierId] ?? `modifier ${modifierId}`;

  const partition = computed<VariationZonePartition>(() =>
    partitionVariationZones({
      selectedTags: selectedTags.value ?? [],
      confirmedTags: confirmedTags.value ?? [],
      dismissedTags: dismissedTags.value,
      provenanceRows: provenanceRows.value,
      suggestions: suggestions.value,
      modifierLabel,
    })
  );

  const confirmed = computed(() => partition.value.confirmed);
  const needsConfirmation = computed(() => partition.value.needsConfirmation);
  const suggested = computed(() => partition.value.suggested);

  // Inertness: with no unconfirmed term and no suggestion there is nothing to
  // decide, so the form renders the plain picker exactly as it did pre-#608.
  // That is production on day one, before the provenance backfill runs.
  const hasZones = computed(() => needsConfirmation.value.length > 0 || suggested.value.length > 0);

  const confirmTerm = (tag: string): void => {
    if (!confirmedTags.value.includes(tag)) {
      confirmedTags.value = [...confirmedTags.value, tag];
    }
  };

  const removeTerm = (tag: string): void => {
    selectedTags.value = selectedTags.value.filter((item) => item !== tag);
    confirmedTags.value = confirmedTags.value.filter((item) => item !== tag);
  };

  const acceptSuggestion = (tag: string): void => {
    if (!selectedTags.value.includes(tag)) {
      selectedTags.value = [...selectedTags.value, tag];
    }
    confirmTerm(tag);
  };

  const dismissSuggestion = (tag: string): void => {
    if (!dismissedTags.value.includes(tag)) {
      dismissedTags.value = [...dismissedTags.value, tag];
    }
  };

  const provenanceActionFor = (tag: string): 'confirm' | undefined =>
    confirmedTags.value.includes(tag) ? 'confirm' : undefined;

  /**
   * Fetch the entity-scoped provenance + suggestions.
   *
   * Best-effort and NON-THROWING by design: the provenance layer is additive
   * decoration on a form that must keep working when the route is unavailable
   * (a pre-#608 API build) or forbidden (the suggestions route is Curator-gated
   * and anonymous/Reviewer callers get a 403). Either failure degrades to "no
   * zones", never to a broken review form.
   */
  const loadForEntity = async (
    entityId: number | string,
    config?: AxiosRequestConfig
  ): Promise<void> => {
    loading.value = true;
    try {
      const [variationResult, suggestionResult] = await Promise.allSettled([
        getEntityVariation(entityId, {}, config),
        getEntityVariationSuggestions(entityId, config),
      ]);
      provenanceRows.value =
        variationResult.status === 'fulfilled' && Array.isArray(variationResult.value)
          ? variationResult.value
          : [];
      suggestions.value =
        suggestionResult.status === 'fulfilled' && Array.isArray(suggestionResult.value)
          ? suggestionResult.value
          : [];
    } finally {
      loading.value = false;
    }
  };

  const reset = (): void => {
    provenanceRows.value = [];
    suggestions.value = [];
    dismissedTags.value = [];
    loading.value = false;
  };

  return {
    confirmed,
    needsConfirmation,
    suggested,
    hasZones,
    loading,
    provenanceRows,
    suggestions,
    confirmTerm,
    removeTerm,
    acceptSuggestion,
    dismissSuggestion,
    provenanceActionFor,
    loadForEntity,
    reset,
  };
}
