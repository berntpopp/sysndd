<!-- src/views/curate/components/RefusedReReviewPanel.vue -->
<!--
  Curator surface for re-review items a re-reviewer declined / refused for
  specialist attention (issue #54).

  Self-contained: owns its own data load via the typed re_review client
  (`getReReviewTable({ refused: true, curate: true })`) and the "clear refusal"
  mutation (`clearReReviewRefusal`). Lives in its own component so
  `ManageReReview.vue` (already over the file-size soft ceiling) does not grow.
-->
<template>
  <TableShell
    title="Refused / needs specialist"
    :meta="`${rows.length} flagged`"
    description="Entities a re-reviewer declined as too complex or out of scope. Reassign to a specialist or clear the refusal to return them to the queue."
  >
    <template #actions>
      <BButton
        size="sm"
        variant="outline-secondary"
        class="refused-icon-button"
        :disabled="loading"
        aria-label="Refresh refused re-review items"
        @click="loadRefused"
      >
        <BSpinner v-if="loading" small />
        <i v-else class="bi bi-arrow-clockwise" aria-hidden="true" />
      </BButton>
    </template>

    <div class="position-relative refused-table-wrap">
      <div v-if="!loading && rows.length === 0" class="text-center py-4">
        <i class="bi bi-flag fs-1 text-muted" aria-hidden="true" />
        <p class="text-muted mt-2 mb-0">No refused items.</p>
      </div>

      <GenericTable
        v-else
        :items="rows"
        :fields="fields"
        :is-busy="loading"
        :stacked-mode="false"
      >
        <template #cell-entity_id="{ row }">
          <span class="font-monospace">sysndd:{{ row.entity_id }}</span>
        </template>

        <template #cell-re_review_refusal_comment="{ row }">
          <span v-if="row.re_review_refusal_comment" class="refused-reason">
            {{ row.re_review_refusal_comment }}
          </span>
          <span v-else class="text-muted">—</span>
        </template>

        <template #cell-re_review_refused_user_name="{ row }">
          <BBadge variant="warning">
            {{ row.re_review_refused_user_name || 'Unknown' }}
          </BBadge>
        </template>

        <template #cell-re_review_refused_date="{ row }">
          <span class="small text-muted">
            {{ row.re_review_refused_date ? String(row.re_review_refused_date).substring(0, 10) : '—' }}
          </span>
        </template>

        <template #cell-actions="{ row }">
          <BButton
            size="sm"
            variant="outline-primary"
            :disabled="clearingId === row.re_review_entity_id"
            :aria-label="`Clear refusal for sysndd:${row.entity_id}`"
            @click="handleClear(row)"
          >
            <BSpinner v-if="clearingId === row.re_review_entity_id" small />
            <template v-else>
              <i class="bi bi-arrow-counterclockwise me-1" aria-hidden="true" />
              Return to queue
            </template>
          </BButton>
        </template>
      </GenericTable>
    </div>
  </TableShell>
</template>

<script>
import TableShell from '@/components/table/TableShell.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import { useToast } from '@/composables';
import { getReReviewTable, clearReReviewRefusal } from '@/api/re_review';

export default {
  name: 'RefusedReReviewPanel',
  components: { TableShell, GenericTable },
  emits: ['cleared'],
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
  data() {
    return {
      rows: [],
      loading: false,
      clearingId: null,
      fields: [
        { key: 'entity_id', label: 'Entity', class: 'text-start' },
        { key: 'symbol', label: 'Gene', class: 'text-start' },
        { key: 'disease_ontology_name', label: 'Disease', class: 'text-start' },
        { key: 're_review_refused_user_name', label: 'Refused by', class: 'text-start' },
        { key: 're_review_refusal_comment', label: 'Reason', class: 'text-start' },
        { key: 're_review_refused_date', label: 'Date', class: 'text-start' },
        { key: 'actions', label: 'Actions', class: 'text-center' },
      ],
    };
  },
  mounted() {
    this.loadRefused();
  },
  methods: {
    async loadRefused() {
      this.loading = true;
      try {
        const payload = await getReReviewTable({ refused: true, curate: true });
        this.rows = Array.isArray(payload) ? payload : (payload?.data ?? []);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.rows = [];
      } finally {
        this.loading = false;
      }
    },
    async handleClear(row) {
      this.clearingId = row.re_review_entity_id;
      try {
        await clearReReviewRefusal(row.re_review_entity_id);
        this.makeToast('Refusal cleared; entity returned to the re-review queue', 'Success', 'success');
        this.$emit('cleared', row);
        await this.loadRefused();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.clearingId = null;
      }
    },
  },
};
</script>

<style scoped>
.refused-icon-button {
  display: inline-grid;
  width: 2rem;
  min-width: 2rem;
  height: 2rem;
  padding: 0;
  place-items: center;
}

.refused-table-wrap {
  padding: 0.75rem;
}

.refused-reason {
  display: inline-block;
  max-width: min(28rem, 100%);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
}

.font-monospace {
  font-family: SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.9em;
}
</style>
