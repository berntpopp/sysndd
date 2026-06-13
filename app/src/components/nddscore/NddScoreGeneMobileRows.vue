<template>
  <MobileTableList
    :items="items"
    label="Gene predictions"
    empty-text="No gene predictions found."
    :item-key="rowKey"
  >
    <template #default="{ item, index }">
      <article class="mobile-record-row" role="listitem">
        <!-- Primary identity + action cluster -->
        <div class="mobile-record-row__topline">
          <div class="mobile-record-row__chips">
            <GeneBadge
              v-if="hasValue(item.gene_symbol)"
              :symbol="displayValue(item.gene_symbol)"
              :hgnc-id="displayValue(item.hgnc_id)"
              :link-to="detailLink(item)"
              size="sm"
            />
            <span v-else class="mobile-record-row__fallback">Unknown gene</span>

            <span
              v-if="hasValue(item.rank)"
              class="mobile-record-row__chip nddscore-mobile-row__rank"
              :title="`Rank: ${displayValue(item.rank)}`"
            >
              #{{ displayValue(item.rank) }}
            </span>
          </div>

          <button
            type="button"
            class="mobile-record-row__details-button"
            :aria-expanded="isExpanded(rowKey(item, index)) ? 'true' : 'false'"
            :aria-controls="`nddscore-mobile-row-details-${index}`"
            @click="toggleDetails(rowKey(item, index))"
          >
            {{ isExpanded(rowKey(item, index)) ? 'Hide' : 'Details' }}
          </button>
        </div>

        <!-- Headline prediction metrics -->
        <div class="mobile-record-row__chips" aria-label="NDDScore prediction summary">
          <span
            class="mobile-record-row__chip nddscore-mobile-row__score"
            :title="`NDDScore (ML prediction): ${formatDecimal(item.ndd_score, 3)}`"
          >
            <span class="nddscore-mobile-row__score-label">Score</span>
            <span class="nddscore-mobile-row__score-value">{{
              formatDecimal(item.ndd_score, 3)
            }}</span>
          </span>

          <BBadge
            :variant="riskVariant(item.risk_tier)"
            :title="`Risk tier: ${displayValue(item.risk_tier)}`"
          >
            {{ displayValue(item.risk_tier) }}
          </BBadge>

          <BBadge
            :variant="confidenceVariant(item.confidence_tier)"
            :title="`Confidence: ${displayValue(item.confidence_tier)}`"
          >
            {{ displayValue(item.confidence_tier) }}
          </BBadge>

          <RouterLink
            v-if="isKnownGene(item.known_sysndd_gene)"
            :to="knownGeneLink(item)"
            class="nddscore-mobile-row__known-link"
            title="Open the curated SysNDD gene page for this HGNC identifier."
          >
            <BBadge variant="info">Known</BBadge>
          </RouterLink>
          <BBadge v-else variant="light" title="Not a curated SysNDD gene"> New </BBadge>
        </div>

        <!-- Secondary detail, on demand -->
        <dl
          v-if="isExpanded(rowKey(item, index))"
          :id="`nddscore-mobile-row-details-${index}`"
          class="mobile-record-row__details"
        >
          <div v-if="hasValue(item.hgnc_id)" class="mobile-record-row__detail">
            <dt>HGNC</dt>
            <dd>{{ displayValue(item.hgnc_id) }}</dd>
          </div>
          <div class="mobile-record-row__detail">
            <dt>Percentile</dt>
            <dd>{{ formatPercentile(item.percentile) }}</dd>
          </div>
          <div v-if="hasValue(item.top_inheritance_mode)" class="mobile-record-row__detail">
            <dt>Top inheritance</dt>
            <dd>{{ displayValue(item.top_inheritance_mode) }}</dd>
          </div>
          <div v-if="hasValue(item.model_split)" class="mobile-record-row__detail">
            <dt>Split</dt>
            <dd>{{ displayValue(item.model_split) }}</dd>
          </div>
          <div class="mobile-record-row__detail">
            <dt>Predicted HPO</dt>
            <dd>{{ topHpoTooltip(item.top_hpo_predictions_json) }}</dd>
          </div>
        </dl>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { RouterLink } from 'vue-router';
import { BBadge } from 'bootstrap-vue-next';
import MobileTableList from '@/components/table/MobileTableList.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import { withReturnTo } from '@/utils/returnNavigation';
import {
  displayValue,
  formatDecimal,
  formatPercentile,
  riskVariant,
  confidenceVariant,
  isKnownGene,
  topHpoTooltip,
} from './nddScoreGeneTableFormatters';

// Mobile record rows for the NDDScore gene predictions table. Mirrors the
// EntitiesMobileRows/GenesMobileRows pattern so small viewports get scannable
// cards instead of a crushed fixed-layout table. These remain model-derived
// prediction-layer presentation, separate from curated SysNDD evidence.

defineOptions({
  name: 'NddScoreGeneMobileRows',
});

type Item = Record<string, unknown>;

const props = defineProps<{
  items: Item[];
}>();

const expandedRows = ref<Set<string>>(new Set());

watch(
  () => props.items,
  (items) => {
    const currentKeys = new Set(items.map((item, index) => rowKey(item, index)));
    expandedRows.value = new Set([...expandedRows.value].filter((key) => currentKeys.has(key)));
  },
  { deep: false }
);

function hasValue(value: unknown): boolean {
  return value !== null && value !== undefined && value !== '';
}

function rowKey(item: Item, index: number): string {
  const stableValue = item.hgnc_id ?? item.gene_symbol;
  return hasValue(stableValue) ? String(stableValue) : `row-${index}`;
}

function detailLink(item: Item): string | undefined {
  return hasValue(item.hgnc_id)
    ? withReturnTo(`/NDDScore/Gene/${encodeURIComponent(displayValue(item.hgnc_id))}`)
    : undefined;
}

function knownGeneLink(item: Item): string {
  return withReturnTo(`/Genes/${displayValue(item.hgnc_id)}`);
}

function isExpanded(key: string): boolean {
  return expandedRows.value.has(key);
}

function toggleDetails(key: string): void {
  const nextExpandedRows = new Set(expandedRows.value);

  if (nextExpandedRows.has(key)) {
    nextExpandedRows.delete(key);
  } else {
    nextExpandedRows.add(key);
  }

  expandedRows.value = nextExpandedRows;
}
</script>

<style scoped>
.nddscore-mobile-row__rank {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}

.nddscore-mobile-row__score {
  gap: 0.3rem;
}

.nddscore-mobile-row__score-label {
  color: #475569;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.nddscore-mobile-row__score-value {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-weight: 700;
}

.nddscore-mobile-row__known-link {
  text-decoration: none;
}
</style>
