<!-- components/annotations/OntologyAnnotationsCard.vue -->
<template>
  <AdminOperationPanel
    title="Updating Ontology Annotations"
    :meta="lastUpdated ? `Last: ${formatDate(lastUpdated)}` : null"
    icon="bi-diagram-3"
    heading-tag="h2"
  >
    <BButton
      variant="primary"
      :disabled="ontologyJob.isLoading.value"
      @click="$emit('start-ontology')"
    >
      <BSpinner v-if="ontologyJob.isLoading.value" small type="grow" class="me-2" />
      {{ ontologyJob.isLoading.value ? 'Updating...' : 'Update Ontology Annotations' }}
    </BButton>

    <JobProgressDisplay :job="ontologyJob" idle-message="This may take several minutes..." />

    <BAlert v-if="stale && !blocked" variant="warning" show class="mt-3 mb-0">
      <h6 class="alert-heading">Disease dictionary may be stale</h6>
      <p class="mb-0 small">
        A previous ontology update was blocked and its staged data has expired
        (last fully applied {{ stale.lastApplied ? formatDate(stale.lastApplied) : 'unknown' }}).
        Re-run "Update Ontology Annotations" to refresh; new terms will be auto-applied.
      </p>
    </BAlert>

    <BAlert v-if="blocked" variant="warning" show class="mt-3 mb-0">
      <h6 class="alert-heading d-flex align-items-center gap-2">
        Ontology Update Blocked
        <span class="badge bg-danger">{{ blocked.critical_count }} critical</span>
        <span v-if="blocked.auto_fixable_count > 0" class="badge bg-info">
          {{ blocked.auto_fixable_count }} auto-fixable
        </span>
      </h6>
      <p class="mb-2 small">
        This update splits into two groups. <strong>Critical entities</strong> changed in a way that
        has no automatic remapping, so they need manual review. The
        <strong>auto-fixable remappings</strong> map cleanly to a new version and are applied for
        you. Force Apply proceeds with both.
      </p>

      <div v-if="blocked.critical_entities.length > 0" class="mb-3">
        <div class="d-flex align-items-baseline gap-2">
          <strong class="small">Critical entities</strong>
          <span class="badge bg-danger-subtle text-danger-emphasis">manual review</span>
        </div>
        <p class="text-muted small mb-1">
          {{ blocked.critical_count }} entity-referenced version(s) with no automatic remapping. On
          Force Apply they are kept as inactive compatibility records (so existing curations stay
          valid) and queued in a re-review batch for an assigned curator.
        </p>
        <BTable
          :items="blocked.critical_entities"
          :fields="criticalEntityFields"
          striped
          hover
          small
          responsive
          class="mb-0 mt-1"
        >
          <template #cell(disease_ontology_id_version)="row">
            <OmimVersionLink :version="row.item.disease_ontology_id_version" />
          </template>
        </BTable>
      </div>

      <div v-if="blocked.auto_fixes.length > 0" class="mb-3">
        <BButton
          variant="link"
          size="sm"
          class="p-0 text-decoration-none"
          :aria-expanded="showAutoFixes ? 'true' : 'false'"
          @click="showAutoFixes = !showAutoFixes"
        >
          {{ showAutoFixes ? 'Hide' : 'Show' }}
          {{ blocked.auto_fixable_count }} auto-fixable remapping(s)
        </BButton>
        <p v-if="showAutoFixes" class="text-muted small mb-1 mt-1">
          Same gene and inheritance, matched by ID or disease name. Force Apply remaps these
          automatically — no review needed.
        </p>
        <BTable
          v-if="showAutoFixes"
          :items="blocked.auto_fixes"
          :fields="autoFixFields"
          striped
          small
          responsive
          class="mb-0 mt-1"
        >
          <template #cell(disease_ontology_name)="row">
            {{ row.item.disease_ontology_name || '—' }}
          </template>
          <template #cell(old_version)="row">
            <OmimVersionLink :version="row.item.old_version" />
          </template>
          <template #cell(new_version)="row">
            <OmimVersionLink :version="row.item.new_version" />
          </template>
        </BTable>
      </div>

      <div class="d-flex align-items-center gap-2 flex-wrap">
        <BFormSelect
          v-model="selectedUserId"
          :disabled="forceApplyJob.isLoading.value || loadingUsers"
          size="sm"
          style="max-width: 200px"
        >
          <BFormSelectOption :value="null">
            {{ loadingUsers ? 'Loading...' : 'Assign to (me)' }}
          </BFormSelectOption>
          <BFormSelectOption v-for="u in userOptions" :key="u.value" :value="u.value">
            {{ u.text }}
          </BFormSelectOption>
        </BFormSelect>
        <BButton
          variant="danger"
          size="sm"
          :disabled="forceApplyJob.isLoading.value"
          @click="emitForceApply"
        >
          <BSpinner v-if="forceApplyJob.isLoading.value" small class="me-1" />
          {{ forceApplyJob.isLoading.value ? 'Applying...' : 'Force Apply' }}
        </BButton>
        <BButton
          variant="outline-secondary"
          size="sm"
          :disabled="forceApplyJob.isLoading.value"
          @click="$emit('dismiss-blocked')"
        >
          Dismiss
        </BButton>
      </div>

      <div v-if="forceApplyJob.isLoading.value" class="mt-2">
        <BProgress
          :value="100"
          :max="100"
          :animated="true"
          :striped="true"
          variant="danger"
          height="1rem"
        >
          <template #default>
            Force applying... ({{ forceApplyJob.elapsedTimeDisplay.value }})
          </template>
        </BProgress>
      </div>
    </BAlert>
  </AdminOperationPanel>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { UseAsyncJobReturn } from '@/composables/useAsyncJob';
import { formatDate } from '@/composables/annotations/useAnnotationFormatters';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import JobProgressDisplay from './JobProgressDisplay.vue';
import OmimVersionLink from './OmimVersionLink.vue';

export interface OntologyBlockedState {
  blocked_job_id: string;
  critical_count: number;
  auto_fixable_count: number;
  total_affected: number;
  critical_entities: Array<Record<string, unknown>>;
  auto_fixes: Array<Record<string, unknown>>;
}

export interface UserOption {
  value: number;
  text: string;
}

const props = defineProps<{
  ontologyJob: UseAsyncJobReturn;
  forceApplyJob: UseAsyncJobReturn;
  blocked: OntologyBlockedState | null;
  stale?: { lastApplied: string | null } | null;
  lastUpdated: string | null;
  userOptions: UserOption[];
  loadingUsers: boolean;
}>();

const emit = defineEmits<{
  (e: 'start-ontology'): void;
  (e: 'force-apply', payload: { blocked_job_id: string; assigned_user_id: number | null }): void;
  (e: 'dismiss-blocked'): void;
}>();

const selectedUserId = ref<number | null>(null);
const showAutoFixes = ref(false);

const criticalEntityFields = [
  { key: 'disease_ontology_id_version', label: 'Version', sortable: true },
  { key: 'disease_ontology_name', label: 'Disease', sortable: true },
  { key: 'hgnc_id', label: 'Gene', sortable: true },
  { key: 'hpo_mode_of_inheritance_term', label: 'Inheritance', sortable: false },
];

const autoFixFields = [
  { key: 'disease_ontology_name', label: 'Disease', sortable: true },
  { key: 'old_version', label: 'Old Version' },
  { key: 'new_version', label: 'New Version' },
  { key: 'fix_type', label: 'Match Type' },
];

function emitForceApply(): void {
  if (!props.blocked) return;
  emit('force-apply', {
    blocked_job_id: props.blocked.blocked_job_id,
    assigned_user_id: selectedUserId.value,
  });
}
</script>
