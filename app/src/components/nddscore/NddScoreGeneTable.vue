<template>
  <TableShell
    title="Gene predictions"
    :meta="totalLabel"
    description="Current-release NDDScore gene association predictions."
    :loading="loading"
  >
    <template #toolbar>
      <div class="nddscore-gene-toolbar">
        <div class="nddscore-gene-toolbar__search">
          <TableSearchInput
            v-model="search"
            placeholder="Search gene symbol or HGNC ID"
            :debounce-time="350"
            :loading="loading"
            @update:model-value="handleFilterChange"
            @clear="handleFilterChange"
          />
        </div>

        <BFormSelect
          v-model="riskTier"
          :options="riskTierOptions"
          size="sm"
          aria-label="Risk tier"
          @update:model-value="handleFilterChange"
        />
        <BFormSelect
          v-model="confidenceTier"
          :options="confidenceTierOptions"
          size="sm"
          aria-label="Confidence tier"
          @update:model-value="handleFilterChange"
        />
        <BFormSelect
          v-model="knownSysnddGene"
          :options="knownSysnddOptions"
          size="sm"
          aria-label="Known SysNDD gene"
          @update:model-value="handleFilterChange"
        />

        <div class="nddscore-gene-toolbar__pagination">
          <TablePaginationControls
            :total-rows="total"
            :initial-per-page="pageSize"
            :current-page="page"
            :page-options="[10, 25, 50, 100]"
            @page-change="handlePageChange"
            @per-page-change="handlePageSizeChange"
          />
        </div>
      </div>
    </template>

    <div class="nddscore-gene-table-wrap">
      <table class="table table-sm align-middle mb-0 nddscore-gene-table">
        <thead>
          <tr>
            <th scope="col">Gene</th>
            <th scope="col">HGNC ID</th>
            <th scope="col">NDD score</th>
            <th scope="col">Rank</th>
            <th scope="col">Percentile</th>
            <th scope="col">Risk tier</th>
            <th scope="col">Confidence</th>
            <th scope="col">SysNDD</th>
            <th scope="col">Top inheritance</th>
            <th scope="col">Predicted HPO</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!rows.length">
            <td colspan="10" class="nddscore-gene-table__empty">No gene predictions found.</td>
          </tr>
          <tr
            v-for="row in rows"
            :key="`${row.release_id}-${row.hgnc_id}`"
            class="nddscore-gene-table__row"
            tabindex="0"
            @click="goToGene(row)"
            @keydown.enter.prevent="goToGene(row)"
          >
            <td>
              <span class="nddscore-gene-table__symbol">{{ displayValue(row.gene_symbol) }}</span>
            </td>
            <td>
              <span class="nddscore-gene-table__id">{{ displayValue(row.hgnc_id) }}</span>
            </td>
            <td class="nddscore-gene-table__numeric">{{ formatDecimal(row.ndd_score, 3) }}</td>
            <td class="nddscore-gene-table__numeric">{{ displayValue(row.rank) }}</td>
            <td class="nddscore-gene-table__numeric">{{ formatPercentile(row.percentile) }}</td>
            <td>
              <BBadge :variant="riskVariant(row.risk_tier)">
                {{ displayValue(row.risk_tier) }}
              </BBadge>
            </td>
            <td>
              <BBadge :variant="confidenceVariant(row.confidence_tier)">
                {{ displayValue(row.confidence_tier) }}
              </BBadge>
            </td>
            <td>
              <RouterLink
                v-if="isKnownGene(row.known_sysndd_gene)"
                :to="`/Genes/${row.hgnc_id}`"
                class="nddscore-gene-table__gene-link"
                @click.stop
              >
                <BBadge variant="info">Known</BBadge>
              </RouterLink>
              <BBadge v-else variant="light">New</BBadge>
            </td>
            <td>{{ displayValue(row.top_inheritance_mode) }}</td>
            <td>{{ topHpoLabel(row.top_hpo_predictions_json, row.n_predicted_hpo) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </TableShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { BBadge, BFormSelect } from 'bootstrap-vue-next';
import type { ColorVariant } from 'bootstrap-vue-next';
import { fetchGenePredictions, type NddScoreGenePrediction } from '@/api/nddscore';
import TableShell from '@/components/table/TableShell.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

defineOptions({
  name: 'NddScoreGeneTable',
});

type GenePredictionRow = NddScoreGenePrediction & {
  release_id?: string;
  hgnc_id?: string | number;
  gene_symbol?: string;
  ndd_score?: number | string;
  rank?: number | string;
  percentile?: number | string;
  risk_tier?: string;
  confidence_tier?: string;
  known_sysndd_gene?: boolean | number | string | null;
  top_inheritance_mode?: string | null;
  n_predicted_hpo?: number | string | null;
  top_hpo_predictions_json?: unknown;
};

const router = useRouter();

const rows = ref<GenePredictionRow[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(25);
const loading = ref(false);
const search = ref('');
const riskTier = ref<string | null>(null);
const confidenceTier = ref<string | null>(null);
const knownSysnddGene = ref<string | null>(null);
let requestSerial = 0;

const riskTierOptions = [
  { value: null, text: 'Any risk tier' },
  { value: 'Very High', text: 'Very High' },
  { value: 'High', text: 'High' },
  { value: 'Moderate', text: 'Moderate' },
  { value: 'Low', text: 'Low' },
];

const confidenceTierOptions = [
  { value: null, text: 'Any confidence' },
  { value: 'High', text: 'High' },
  { value: 'Moderate', text: 'Moderate' },
  { value: 'Low', text: 'Low' },
];

const knownSysnddOptions = [
  { value: null, text: 'Any SysNDD status' },
  { value: 'true', text: 'Known SysNDD gene' },
  { value: 'false', text: 'Not known in SysNDD' },
];

const totalLabel = computed(() => `${total.value.toLocaleString()} genes`);

function normalizeRows(data: NddScoreGenePrediction[] | undefined): GenePredictionRow[] {
  return (data ?? []).map((row) => row as GenePredictionRow);
}

async function loadRows() {
  const serial = ++requestSerial;
  loading.value = true;

  try {
    const result = await fetchGenePredictions({
      search: search.value || undefined,
      riskTier: riskTier.value || undefined,
      confidenceTier: confidenceTier.value || undefined,
      knownSysnddGene: knownSysnddGene.value || undefined,
      page: page.value,
      pageSize: pageSize.value,
    });

    if (serial !== requestSerial) {
      return;
    }

    rows.value = normalizeRows(result.data);
    total.value = Number(result.total) || 0;
    page.value = Number(result.page) || page.value;
    pageSize.value = Number(result.page_size) || pageSize.value;
  } finally {
    if (serial === requestSerial) {
      loading.value = false;
    }
  }
}

function handleFilterChange() {
  page.value = 1;
  void loadRows();
}

function handlePageChange(nextPage: number) {
  page.value = nextPage;
  void loadRows();
}

function handlePageSizeChange(nextPageSize: number) {
  pageSize.value = nextPageSize;
  page.value = 1;
  void loadRows();
}

function goToGene(row: GenePredictionRow) {
  if (row.hgnc_id == null) {
    return;
  }

  void router.push({ name: 'NDDScoreGeneDetail', params: { hgncIdOrSymbol: String(row.hgnc_id) } });
}

function displayValue(value: unknown): string {
  if (value == null || value === '') {
    return 'NA';
  }
  return String(value);
}

function numericValue(value: unknown): number | null {
  const numberValue = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
}

function formatDecimal(value: unknown, digits: number): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : numberValue.toFixed(digits);
}

function formatPercentile(value: unknown): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : `${numberValue.toFixed(1)}%`;
}

function riskVariant(value: unknown): ColorVariant {
  switch (String(value).toLowerCase()) {
    case 'very high':
      return 'danger';
    case 'high':
      return 'warning';
    case 'moderate':
      return 'info';
    default:
      return 'light';
  }
}

function confidenceVariant(value: unknown): ColorVariant {
  switch (String(value).toLowerCase()) {
    case 'high':
      return 'success';
    case 'moderate':
      return 'info';
    default:
      return 'light';
  }
}

function isKnownGene(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

function parseHpoPredictions(value: unknown): Array<Record<string, unknown>> {
  if (Array.isArray(value)) {
    return value.filter((entry): entry is Record<string, unknown> => Boolean(entry));
  }

  if (typeof value !== 'string' || value.length === 0) {
    return [];
  }

  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed)
      ? parsed.filter((entry): entry is Record<string, unknown> => Boolean(entry))
      : [];
  } catch {
    return [];
  }
}

function topHpoLabel(value: unknown, count: unknown): string {
  const predictions = parseHpoPredictions(value);
  const first = predictions[0];
  const label = first?.phenotype_name ?? first?.term_name ?? first?.phenotype_id ?? first?.hpo_id;
  const totalPredicted = numericValue(count);

  if (label) {
    return totalPredicted && totalPredicted > 1
      ? `${String(label)} +${totalPredicted - 1}`
      : String(label);
  }

  return totalPredicted ? String(totalPredicted) : 'NA';
}

onMounted(() => {
  void loadRows();
});
</script>

<style scoped>
.nddscore-gene-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 0.5rem;
}

.nddscore-gene-toolbar__search {
  flex: 1 1 18rem;
  min-width: min(100%, 16rem);
}

.nddscore-gene-toolbar :deep(.form-select) {
  width: auto;
  min-width: 10.5rem;
}

.nddscore-gene-toolbar__pagination {
  flex: 0 1 18rem;
  min-width: min(100%, 15rem);
  margin-left: auto;
}

.nddscore-gene-table-wrap {
  width: 100%;
  overflow-x: auto;
}

.nddscore-gene-table {
  min-width: 62rem;
  font-size: 0.875rem;
}

.nddscore-gene-table th {
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

.nddscore-gene-table td {
  white-space: nowrap;
}

.nddscore-gene-table__row {
  cursor: pointer;
}

.nddscore-gene-table__row:hover,
.nddscore-gene-table__row:focus {
  background: #f8fafc;
}

.nddscore-gene-table__symbol,
.nddscore-gene-table__id,
.nddscore-gene-table__numeric {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}

.nddscore-gene-table__symbol {
  font-weight: 700;
}

.nddscore-gene-table__gene-link {
  text-decoration: none;
}

.nddscore-gene-table__empty {
  padding: 1.5rem;
  color: var(--neutral-600, #757575);
  text-align: center;
}

@media (max-width: 767.98px) {
  .nddscore-gene-toolbar__pagination {
    margin-left: 0;
  }
}
</style>
