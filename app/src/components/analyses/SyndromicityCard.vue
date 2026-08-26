<!--
  SyndromicityCard.vue

  Computed syndromicity for one phenotype cluster (#630).

  This card is deliberately INDEPENDENT of the LLM summary card: it is driven by
  the cluster row (which carries the block from the snapshot), so it renders
  whether or not a validated model summary exists. Placing it inside
  LlmSummaryCard would make deterministic, curation-derived data disappear
  whenever the model output was missing or judge-rejected.

  It also carries no AI-provenance affordances, because it is not AI output.
-->
<template>
  <BCard v-if="hasBlock" class="my-3 mx-2 syndromicity-card" no-body>
    <BCardBody>
      <div class="d-flex justify-content-between align-items-start mb-2">
        <div>
          <h6 class="card-title mb-1">
            <i class="bi bi-clipboard2-pulse me-1" />
            Organ-system involvement
          </h6>
          <small class="text-muted">{{ subtitle }}</small>
        </div>
        <BBadge :variant="variant" class="call-badge">{{ label }}</BBadge>
      </div>

      <div class="stat-row mb-2">
        <span class="stat">
          <strong>{{ scalarOf(block.syndromic) }}</strong> with ≥1 system
        </span>
        <span class="stat">
          <strong>{{ scalarOf(block.no_recorded_extraneurological_involvement) }}</strong>
          with none recorded
        </span>
        <span v-if="Number(scalarOf(block.insufficient_annotation)) > 0" class="stat">
          <strong>{{ scalarOf(block.insufficient_annotation) }}</strong> not annotated
        </span>
        <span class="stat">
          median <strong>{{ scalarOf(block.median_systems) }}</strong> systems
        </span>
      </div>

      <div v-if="systems.length" class="mb-2">
        <span class="section-label">Most involved systems</span>
        <div class="system-chips">
          <BBadge
            v-for="row in systems"
            :key="row.system"
            variant="light"
            class="system-chip"
          >
            {{ labelFor(row.system) }} <span class="chip-count">{{ row.count }}</span>
          </BBadge>
        </div>
      </div>

      <p class="provenance-note mb-0">
        <i class="bi bi-calculator me-1" />
        Computed from curated HPO annotations (rule {{ scalarOf(block.rule_version) }}).
        Counts distinct organ systems outside the nervous system; intellectual
        disability, nervous-system findings, head size and clinical-course terms
        are excluded. &ldquo;None recorded&rdquo; means no such system is
        documented, which is not the same as confirmed absence.
      </p>
    </BCardBody>
  </BCard>
</template>

<script setup lang="ts">
  import { computed } from 'vue';
  import {
    type SyndromicityBlock,
    hasSyndromicity,
    syndromicityLabel,
    syndromicityVariant,
    syndromicitySubtitle,
    topSystems,
    systemLabel,
    unwrapSyndromicityScalar,
  } from './syndromicityPresenter';

  const props = defineProps<{ block: SyndromicityBlock | null | undefined }>();

  const hasBlock = computed(() => hasSyndromicity(props.block));
  const label = computed(() => syndromicityLabel(props.block));
  const variant = computed(() => syndromicityVariant(props.block));
  const subtitle = computed(() => syndromicitySubtitle(props.block));
  const systems = computed(() => topSystems(props.block));
  const block = computed(() => props.block ?? ({} as SyndromicityBlock));

  const scalarOf = (value: unknown) => unwrapSyndromicityScalar(value as never);
  const labelFor = (system: string) => systemLabel(system);
</script>

<style scoped>
  .syndromicity-card {
    border-left: 3px solid var(--bs-secondary, #6c757d);
  }

  .call-badge {
    font-size: 0.8rem;
  }

  .stat-row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    font-size: 0.85rem;
  }

  .section-label {
    display: block;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--bs-secondary-color, #6c757d);
    margin-bottom: 0.25rem;
  }

  .system-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
  }

  .system-chip {
    font-weight: 400;
  }

  .chip-count {
    opacity: 0.65;
  }

  .provenance-note {
    font-size: 0.75rem;
    color: var(--bs-secondary-color, #6c757d);
  }
</style>
