<template>
  <TableShell
    title="Phenotype predictions"
    :meta="totalLabel"
    description="Current-release NDDScore phenotype predictions by gene."
    :loading="loading"
  >
    <template #toolbar>
      <div class="nddscore-hpo-toolbar">
        <div class="nddscore-hpo-toolbar__search">
          <TableSearchInput
            v-model="search"
            placeholder="Search gene or phenotype"
            :debounce-time="350"
            :loading="loading"
            @update:model-value="handleFilterChange"
            @clear="handleFilterChange"
          />
        </div>

        <BFormInput
          v-model="phenotypeId"
          size="sm"
          placeholder="Phenotype ID"
          aria-label="Phenotype ID"
          @update:model-value="handleFilterChange"
        />

        <BFormSelect
          v-model="passesThreshold"
          :options="passesThresholdOptions"
          size="sm"
          aria-label="Passes threshold"
          @update:model-value="handleFilterChange"
        />

        <div class="nddscore-hpo-toolbar__pagination">
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

    <div class="nddscore-hpo-table-wrap">
      <table class="table table-sm align-middle mb-0 nddscore-hpo-table">
        <thead>
          <tr>
            <th scope="col">Gene</th>
            <th scope="col">HGNC ID</th>
            <th scope="col">Phenotype ID</th>
            <th scope="col">Phenotype name</th>
            <th scope="col">Probability</th>
            <th scope="col">Rank for gene</th>
            <th scope="col">Passes threshold</th>
            <th scope="col">Term AUC-ROC</th>
            <th scope="col">Term training support</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!rows.length">
            <td colspan="9" class="nddscore-hpo-table__empty">No phenotype predictions found.</td>
          </tr>
          <tr v-for="row in rows" :key="rowKey(row)">
            <td>
              <span class="nddscore-hpo-table__symbol">{{ displayValue(row.gene_symbol) }}</span>
            </td>
            <td>
              <span class="nddscore-hpo-table__id">{{ displayValue(row.hgnc_id) }}</span>
            </td>
            <td>
              <span class="nddscore-hpo-table__id">{{ displayValue(row.phenotype_id) }}</span>
            </td>
            <td class="nddscore-hpo-table__name">{{ displayValue(row.phenotype_name) }}</td>
            <td class="nddscore-hpo-table__numeric">{{ formatDecimal(row.probability, 3) }}</td>
            <td class="nddscore-hpo-table__numeric">{{ displayValue(row.rank_for_gene) }}</td>
            <td>
              <BBadge :variant="passesThresholdVariant(row.passes_default_threshold)">
                {{ passesThresholdLabel(row.passes_default_threshold) }}
              </BBadge>
            </td>
            <td class="nddscore-hpo-table__numeric">{{ formatDecimal(row.term_auc_roc, 3) }}</td>
            <td class="nddscore-hpo-table__numeric">
              {{ displayValue(row.term_training_support) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </TableShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { BBadge, BFormInput, BFormSelect } from 'bootstrap-vue-next';
import type { ColorVariant } from 'bootstrap-vue-next';
import { fetchHpoPredictions, type NddScoreHpoPrediction } from '@/api/nddscore';
import TableShell from '@/components/table/TableShell.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

defineOptions({
  name: 'NddScoreHpoTable',
});

type HpoPredictionRow = NddScoreHpoPrediction & {
  release_id?: string;
  hgnc_id?: string | number;
  gene_symbol?: string;
  phenotype_id?: string;
  phenotype_name?: string;
  probability?: number | string;
  rank_for_gene?: number | string;
  passes_default_threshold?: boolean | number | string | null;
  term_auc_roc?: number | string | null;
  term_training_support?: number | string | null;
};

const rows = ref<HpoPredictionRow[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(25);
const loading = ref(false);
const search = ref('');
const phenotypeId = ref('');
const passesThreshold = ref('');
let requestSerial = 0;

const passesThresholdOptions = [
  { value: '', text: 'Any threshold status' },
  { value: 'true', text: 'Passes threshold' },
  { value: 'false', text: 'Below threshold' },
];

const totalLabel = computed(() => `${total.value.toLocaleString()} predictions`);

function normalizeRows(data: NddScoreHpoPrediction[] | undefined): HpoPredictionRow[] {
  return (data ?? []).map((row) => row as HpoPredictionRow);
}

async function loadRows() {
  const serial = ++requestSerial;
  loading.value = true;

  try {
    const result = await fetchHpoPredictions({
      search: search.value || undefined,
      phenotypeId: phenotypeId.value || undefined,
      passesThreshold: passesThreshold.value || undefined,
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

function rowKey(row: HpoPredictionRow): string {
  return [row.release_id, row.hgnc_id, row.phenotype_id, row.rank_for_gene]
    .map((value) => displayValue(value))
    .join(':');
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

function booleanValue(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

function passesThresholdVariant(value: unknown): ColorVariant {
  return booleanValue(value) ? 'success' : 'light';
}

function passesThresholdLabel(value: unknown): string {
  return booleanValue(value) ? 'Pass' : 'Below';
}

onMounted(() => {
  void loadRows();
});
</script>

<style scoped>
.nddscore-hpo-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 0.5rem;
}

.nddscore-hpo-toolbar__search {
  flex: 1 1 18rem;
  min-width: min(100%, 16rem);
}

.nddscore-hpo-toolbar :deep(.form-control),
.nddscore-hpo-toolbar :deep(.form-select) {
  width: auto;
  min-width: 10.5rem;
}

.nddscore-hpo-toolbar__pagination {
  flex: 0 1 18rem;
  min-width: min(100%, 15rem);
  margin-left: auto;
}

.nddscore-hpo-table-wrap {
  width: 100%;
  overflow-x: auto;
}

.nddscore-hpo-table {
  min-width: 68rem;
  font-size: 0.875rem;
}

.nddscore-hpo-table th {
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

.nddscore-hpo-table td {
  white-space: nowrap;
}

.nddscore-hpo-table__symbol,
.nddscore-hpo-table__id,
.nddscore-hpo-table__numeric {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}

.nddscore-hpo-table__symbol {
  font-weight: 700;
}

.nddscore-hpo-table__name {
  max-width: 24rem;
  overflow: hidden;
  text-overflow: ellipsis;
}

.nddscore-hpo-table__empty {
  padding: 1.5rem;
  color: var(--neutral-600, #757575);
  text-align: center;
}

@media (max-width: 767.98px) {
  .nddscore-hpo-toolbar__pagination {
    margin-left: 0;
  }
}
</style>
