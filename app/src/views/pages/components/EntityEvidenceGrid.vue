<!-- app/src/views/pages/components/EntityEvidenceGrid.vue -->
<!--
  The four evidence chip-grid cards (Publications, Gene Reviews, Phenotypes,
  Variation Ontology). Extracted from EntityView.vue (#346). The parent keeps
  ownership of useEntityPublications/useEntityPhenotypes/useEntityVariation
  and the additional_references/gene_review publication split; this
  component owns only the chip presentation (URLs, tooltips, aria labels) and
  renders from a single `model` prop bundling the four resources.
-->
<template>
  <BRow class="entity-evidence-grid">
    <BCol cols="12" lg="6" xl="3" class="mb-2">
      <SectionCard
        :loading="model.publications.loading"
        :empty="false"
        :error="model.publications.error"
        title="Publications"
        min-height="9rem"
      >
        <div class="entity-chip-panel">
          <a
            v-for="publication in model.publications.additionalRefs"
            :key="String(publication.publication_id)"
            class="entity-chip entity-chip-publication"
            :href="pubmedUrl(publication)"
            target="_blank"
            rel="noopener"
            :aria-label="publicationAriaLabel(publication)"
            :data-testid="`publication-chip-${asString(publication.publication_id)}`"
            :data-tooltip="publicationTitle(publication)"
          >
            <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
            {{ publication.publication_id }}
          </a>
          <span v-if="model.publications.additionalRefs.length === 0" class="entity-empty-state">
            No publications linked.
          </span>
        </div>
      </SectionCard>
    </BCol>

    <BCol cols="12" lg="6" xl="2" class="mb-2">
      <SectionCard
        :loading="model.publications.loading"
        :empty="false"
        :error="model.publications.error"
        title="Gene Reviews"
        min-height="6rem"
      >
        <div class="entity-chip-panel">
          <a
            v-for="publication in model.publications.geneReviews"
            :key="String(publication.publication_id)"
            class="entity-chip entity-chip-genereview"
            :href="pubmedUrl(publication)"
            target="_blank"
            rel="noopener"
            :aria-label="publicationAriaLabel(publication)"
            :data-testid="`publication-chip-${asString(publication.publication_id)}`"
            :data-tooltip="publicationTitle(publication)"
          >
            <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
            {{ publication.publication_id }}
          </a>
          <span v-if="model.publications.geneReviews.length === 0" class="entity-empty-state">
            No GeneReviews linked.
          </span>
        </div>
      </SectionCard>
    </BCol>

    <BCol cols="12" lg="6" xl="5" class="mb-2">
      <SectionCard
        :loading="model.phenotypes.loading"
        :empty="false"
        :error="model.phenotypes.error"
        title="Phenotypes"
        min-height="18rem"
      >
        <div class="entity-chip-panel">
          <a
            v-for="phenotype in model.phenotypes.list"
            :key="String(phenotype.phenotype_id)"
            class="entity-chip entity-chip-phenotype"
            :class="modifierChipClass(phenotype)"
            :href="hpoUrl(phenotype)"
            target="_blank"
            rel="noopener"
            :aria-label="termAriaLabel(phenotype, 'phenotype_id', 'HPO term')"
            :data-testid="`phenotype-chip-${asString(phenotype.phenotype_id)}`"
            :data-tooltip="termTitle(phenotype, 'phenotype_id')"
          >
            <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
            {{ phenotype.HPO_term }}
          </a>
          <span v-if="model.phenotypes.list.length === 0" class="entity-empty-state">
            No phenotype terms linked.
          </span>
        </div>
      </SectionCard>
    </BCol>

    <BCol cols="12" lg="6" xl="2" class="mb-2">
      <SectionCard
        :loading="model.variation.loading"
        :empty="false"
        :error="model.variation.error"
        title="Variation Ontology"
        min-height="9rem"
      >
        <!--
          INERTNESS GATE (#608): every provenance affordance below is gated on
          `hasProvenance`. With the backfill not yet run, every term arrives with
          `provenance: null` and this card must render byte-identically to its
          pre-#608 self — including keeping SectionCard's DEFAULT header, which
          is why this slot is conditional rather than always provided.
        -->
        <template v-if="hasProvenance" #header>
          <div class="variation-card-header">
            <div data-testid="section-card-title" class="section-card-title">
              Variation Ontology
            </div>
            <button
              type="button"
              class="variation-provenance-legend"
              data-testid="variation-provenance-legend"
              :aria-expanded="legendOpen ? 'true' : 'false'"
              @click="legendOpen = !legendOpen"
            >
              <i class="bi bi-info-circle" aria-hidden="true" />
              provenance
            </button>
          </div>
        </template>
        <div class="entity-chip-panel">
          <template v-if="hasProvenance">
            <p
              v-if="legendOpen"
              class="variation-provenance-legend-text"
              data-testid="variation-provenance-legend-text"
            >
              Terms marked with a provenance button are machine-derived — imported from an external
              source or extracted from the literature — and are shown with the state of their
              curator review. Open one to see the evidence behind it. Unmarked terms were authored
              by a curator.
            </p>
            <template v-for="variant in model.variation.list" :key="variationKey(variant)">
              <!-- Curator-authored: the pre-#608 chip, untouched, no wrapper. -->
              <a v-if="!provenanceOf(variant)" v-bind="varioChipAttrs(variant)">
                <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
                {{ variant.vario_name }}
              </a>
              <!-- Machine-derived: the same chip (same href/tooltip/testid) plus a
                   SEPARATE trigger, so the external outlink keeps its own target. -->
              <span
                v-else
                class="entity-provenance-group"
                :data-testid="`variation-provenance-group-${asString(variant.vario_id)}-${asString(variant.modifier_id)}`"
              >
                <a v-bind="varioChipAttrs(variant)">
                  <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
                  {{ variant.vario_name }}
                </a>
                <button
                  :ref="(el) => registerTrigger(variant, el)"
                  type="button"
                  class="sysndd-chip sysndd-chip--neutral variation-provenance-trigger"
                  :class="{
                    'variation-provenance-trigger--unconfirmed':
                      provenanceOf(variant)!.state === 'active_unconfirmed',
                  }"
                  aria-haspopup="dialog"
                  :aria-expanded="isOpen(variant) ? 'true' : 'false'"
                  :aria-label="
                    provenanceTriggerLabel(
                      asString(variant.vario_name),
                      provenanceOf(variant)!.state
                    )
                  "
                  :data-testid="`variation-provenance-trigger-${asString(variant.vario_id)}-${asString(variant.modifier_id)}`"
                  @click="openEvidence(variant)"
                >
                  <i
                    :class="provenanceGlyphClass(provenanceOf(variant)!.state)"
                    aria-hidden="true"
                  />
                </button>
              </span>
            </template>
            <span v-if="model.variation.list.length === 0" class="entity-empty-state">
              No variation ontology terms linked.
            </span>
            <!-- Mounted only while a term is open, so the card costs nothing on
                 page load. Its wrapper is display:contents, so it adds no flex
                 item to this panel. -->
            <VariationProvenanceDialog
              v-if="openTarget"
              :target="openTarget"
              @close="closeEvidence"
            />
          </template>
          <template v-else>
            <a
              v-for="variant in model.variation.list"
              :key="variationKey(variant)"
              v-bind="varioChipAttrs(variant)"
            >
              <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
              {{ variant.vario_name }}
            </a>
            <span v-if="model.variation.list.length === 0" class="entity-empty-state">
              No variation ontology terms linked.
            </span>
          </template>
        </div>
      </SectionCard>
    </BCol>
  </BRow>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { BRow, BCol } from 'bootstrap-vue-next';
import SectionCard from '@/components/ui/SectionCard.vue';
import useText from '@/composables/useText';
import { varioTermUrl } from '@/assets/js/constants/ontology_links';
import VariationProvenanceDialog, {
  type VariationProvenanceDialogTarget,
} from './VariationProvenanceDialog.vue';
import {
  useVariationProvenanceDisclosure,
  variationAssertionKey as variationKey,
} from '@/composables/useVariationProvenanceDisclosure';
import {
  normalizeVariationProvenance,
  provenanceGlyphClass,
  provenanceTriggerLabel,
  type NormalizedProvenance,
} from './variationProvenance';

type EntityRowMap = Record<string, unknown>;

interface EntityEvidenceResource {
  loading: boolean;
  error: string | null;
}

export interface EntityEvidenceModel {
  publications: EntityEvidenceResource & {
    additionalRefs: EntityRowMap[];
    geneReviews: EntityRowMap[];
  };
  phenotypes: EntityEvidenceResource & { list: EntityRowMap[] };
  variation: EntityEvidenceResource & { list: EntityRowMap[] };
}

const props = defineProps<{ model: EntityEvidenceModel }>();

const { publication_hover_text, modifier_text } = useText();

const asString = (value: unknown): string => (value == null ? '' : String(value));

function pubmedUrl(publication: EntityRowMap): string {
  return `https://pubmed.ncbi.nlm.nih.gov/${asString(publication.publication_id).replace(/^PMID:\s*/, '')}`;
}

function publicationTitle(publication: EntityRowMap): string {
  return (publication_hover_text[asString(publication.publication_type)] ?? 'Publication').trim();
}

function publicationAriaLabel(publication: EntityRowMap): string {
  return `${publicationTitle(publication)} ${asString(publication.publication_id)}`.trim();
}

function hpoUrl(phenotype: EntityRowMap): string {
  return `https://hpo.jax.org/browse/term/${asString(phenotype.phenotype_id)}`;
}

// VariO links are built from the configurable EBI OLS4 base (the previous
// aber-owl.net target no longer reliably resolves to a term page). The base is
// overridable via VITE_VARIO_BASE_URL — see assets/js/constants/ontology_links.ts.
function varioUrl(variant: EntityRowMap): string {
  return varioTermUrl(variant.vario_id);
}

function termTitle(item: EntityRowMap, idKey: string): string {
  const modifier = modifier_text[Number(item.modifier_id)] ?? 'Evidence term';
  return `${modifier} | ${asString(item[idKey])}`;
}

function termAriaLabel(item: EntityRowMap, idKey: string, kind: string): string {
  return `${kind}: ${termTitle(item, idKey)}`;
}

function modifierChipClass(item: EntityRowMap): string {
  const modifier = modifier_text[Number(item.modifier_id)] ?? 'evidence';
  return `entity-chip--${modifier.replace(/\s+/g, '-').toLowerCase()}`;
}

// ---------------------------------------------------------------------------
// Variation-ontology provenance (#608)
// ---------------------------------------------------------------------------
//
// Everything below is INERT until at least one term carries a non-null
// `provenance` block. Absence of provenance means curator-authored, so while the
// backfill (which lives in another repository) has not run, this card must look
// exactly as it always did — see the gate comment in the template and the
// release-gate tests in __tests__/EntityEvidenceGridProvenance.spec.ts.

/**
 * Attributes of the variation term chip.
 *
 * Single source of truth so the curator-authored branch and the
 * machine-derived branch can never drift: the external OLS4 outlink, tooltip,
 * aria-label and testid are identical in both. The provenance dialog gets its
 * OWN trigger rather than stealing this anchor's click.
 */
function varioChipAttrs(variant: EntityRowMap): Record<string, unknown> {
  return {
    class: ['entity-chip', 'entity-chip-variation', modifierChipClass(variant)],
    href: varioUrl(variant),
    target: '_blank',
    rel: 'noopener',
    'aria-label': termAriaLabel(variant, 'vario_id', 'Variation ontology term'),
    'data-testid': `variation-chip-${asString(variant.vario_id)}`,
    'data-tooltip': termTitle(variant, 'vario_id'),
  };
}

function provenanceOf(variant: EntityRowMap): NormalizedProvenance | null {
  return normalizeVariationProvenance(variant.provenance);
}

const hasProvenance = computed(() =>
  props.model.variation.list.some((v) => provenanceOf(v) !== null)
);

const legendOpen = ref(false);

// Open/close + focus-return live in the composable; this component only supplies
// the row list and how to describe the open row to the dialog.
const {
  openTarget,
  isOpen,
  open: openEvidence,
  close: closeEvidence,
  registerTrigger,
} = useVariationProvenanceDisclosure<VariationProvenanceDialogTarget>(
  computed(() => props.model.variation.list),
  (variant) => {
    const provenance = provenanceOf(variant);
    if (!provenance) return null;
    return {
      entityId: asString(variant.entity_id),
      varioId: asString(variant.vario_id),
      varioName: asString(variant.vario_name),
      modifierId: asString(variant.modifier_id),
      modifierLabel: modifier_text[Number(variant.modifier_id)] ?? 'evidence term',
      state: provenance.state,
    };
  }
);
</script>

<style scoped>
.entity-evidence-grid {
  padding-top: 0.15rem;
}
.entity-chip-panel {
  padding: 0.75rem;
  display: flex;
  align-content: flex-start;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 0.35rem;
}
.entity-chip {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  max-width: 100%;
  min-height: 1.55rem;
  padding: 0.18rem 0.5rem;
  border: 1px solid transparent;
  border-radius: 999px;
  color: #0f172a;
  font-size: 0.78rem;
  font-weight: 700;
  line-height: 1.2;
  text-decoration: none;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.07);
  transition:
    transform 0.14s ease,
    border-color 0.14s ease,
    box-shadow 0.14s ease,
    background-color 0.14s ease;
}
.entity-chip::before,
.entity-chip::after {
  position: absolute;
  left: 50%;
  z-index: 20;
  opacity: 0;
  pointer-events: none;
  transform: translate(-50%, 0.25rem);
  transition:
    opacity 0.12s ease,
    transform 0.12s ease;
}
.entity-chip::before {
  bottom: calc(100% + 0.35rem);
  width: max-content;
  max-width: min(18rem, 85vw);
  padding: 0.38rem 0.5rem;
  border: 1px solid rgba(15, 23, 42, 0.14);
  border-radius: 0.4rem;
  background: rgba(15, 23, 42, 0.96);
  box-shadow: 0 0.5rem 1.2rem rgba(15, 23, 42, 0.18);
  color: #fff;
  content: attr(data-tooltip);
  font-size: 0.72rem;
  font-weight: 650;
  line-height: 1.25;
  text-align: center;
  white-space: normal;
}
.entity-chip::after {
  bottom: calc(100% + 0.12rem);
  border: 0.26rem solid transparent;
  border-top-color: rgba(15, 23, 42, 0.96);
  content: '';
}
.entity-chip-publication {
  border-color: #0891b2;
  background: #cffafe;
}
.entity-chip-genereview {
  border-color: #2563eb;
  background: #dbeafe;
}
.entity-chip-phenotype {
  border-color: #7c3aed;
  background: #ede9fe;
}
.entity-chip-variation {
  border-color: #16a34a;
  background: #dcfce7;
}
.entity-chip--present {
  border-color: #16a34a;
  background: #dcfce7;
}
.entity-chip--uncertain {
  border-color: #d97706;
  background: #fef3c7;
}
.entity-chip--variable {
  border-color: #2563eb;
  background: #dbeafe;
}
.entity-chip--rare {
  border-color: #7c3aed;
  background: #ede9fe;
}
.entity-chip--absent {
  border-color: #64748b;
  background: #f1f5f9;
  color: #334155;
}
.entity-chip:hover,
.entity-chip:focus {
  border-color: #0f172a;
  background-color: #fff;
  box-shadow: 0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
  color: #0f172a;
  outline: none;
  transform: translateY(-1px);
}
.entity-chip:hover::before,
.entity-chip:hover::after,
.entity-chip:focus::before,
.entity-chip:focus::after {
  opacity: 1;
  transform: translate(-50%, 0);
}
.entity-chip:focus-visible {
  box-shadow:
    0 0 0 0.16rem rgba(13, 110, 253, 0.22),
    0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
}
.entity-empty-state {
  color: var(--neutral-600, #667085);
  font-size: 0.84rem;
  font-weight: 650;
}
/* --- #608 provenance affordances (rendered only when a term has provenance) ---
   Quiet by default: neutral tone from the shared token-based chip classes plus a
   dotted bottom border for the unconfirmed state. Deliberately NOT
   --status-warning / --status-danger: an unconfirmed annotation is un-reviewed,
   not broken, and thousands of entity pages must not read as alarming. */
.variation-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--spacing-2, 0.5rem);
}
.variation-provenance-legend {
  padding: 0 0.2rem;
  border: none;
  background: none;
  color: var(--neutral-700, #616161);
  font-size: var(--font-size-xs, 0.75rem);
  line-height: 1.2;
}
.variation-provenance-legend:hover,
.variation-provenance-legend:focus-visible {
  color: var(--neutral-900, #212121);
  text-decoration: underline;
}
.variation-provenance-legend-text {
  flex: 1 0 100%;
  margin: 0 0 0.15rem;
  color: var(--neutral-700, #616161);
  font-size: var(--font-size-xs, 0.75rem);
  line-height: 1.35;
  /* An ancestor centres this card's contents, which suits short chips but turns
     this ~10-line explanatory paragraph into centred body copy in the narrow
     xl=2 column. Left-align just the prose; the chips keep the panel default. */
  text-align: left;
}
.entity-provenance-group {
  display: inline-flex;
  align-items: center;
  gap: 0.2rem;
  max-width: 100%;
}
.variation-provenance-trigger {
  min-height: 1.55rem;
  padding: 0.18rem 0.4rem;
  cursor: pointer;
  line-height: 1;
}
/* Dotted underline = "un-reviewed", reinforcing the state that the trigger's
   aria-label already states in words. */
.variation-provenance-trigger--unconfirmed {
  border-bottom: 1px dotted var(--neutral-600, #757575);
}
@media (prefers-reduced-motion: reduce) {
  .entity-chip {
    transition: none;
  }
  .entity-chip:hover,
  .entity-chip:focus {
    transform: none;
  }
  .entity-chip::before,
  .entity-chip::after {
    transition: none;
  }
}
@media (max-width: 575.98px) {
  .entity-chip-panel {
    padding: 0.65rem;
  }
}
</style>
