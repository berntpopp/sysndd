<!-- components/review/EditStatusModal.vue -->
<template>
  <BModal
    :id="modalId"
    :ref="modalId"
    size="lg"
    centered
    ok-title="Submit"
    no-close-on-esc
    no-close-on-backdrop
    header-class="border-bottom-0 pb-0"
    footer-class="border-top-0 pt-0"
    header-close-label="Close"
    :busy="loading"
    @ok="$emit('ok')"
    @hide="$emit('hide', $event)"
  >
    <template #title>
      <div class="d-flex align-items-center">
        <i class="bi bi-stoplights me-2 text-secondary" />
        <span class="fw-semibold">Edit Status</span>
      </div>
    </template>

    <template #footer="{ ok, cancel }">
      <div class="w-100 d-flex justify-content-between align-items-center">
        <div
          class="d-flex align-items-center gap-2 text-muted small"
          data-testid="status-audit-trail"
        >
          <span
            v-if="statusInfo.status_user_name"
            class="d-flex align-items-center gap-1"
          >
            <i :class="'bi bi-' + (userIcon[statusInfo.status_user_role] || 'person')" />
            <span>{{ statusInfo.status_user_name }}</span>
            <span class="text-muted">·</span>
            <span>{{ (statusInfo.status_date || '').substring(0, 10) }}</span>
          </span>
        </div>
        <div class="d-flex gap-2">
          <BButton variant="outline-secondary" @click="cancel()"> Cancel </BButton>
          <BButton variant="primary" @click="ok()">
            <i class="bi bi-check-lg me-1" />
            Save Status
          </BButton>
        </div>
      </div>
    </template>

    <div class="bg-light rounded-3 p-3 mb-4">
      <h6 class="text-muted mb-2 small text-uppercase fw-semibold">
        <i class="bi bi-info-circle me-1" />
        Entity Details
      </h6>
      <div class="d-flex flex-wrap gap-2">
        <EntityBadge
          v-if="statusInfo.entity_id"
          :entity-id="statusInfo.entity_id"
          :link-to="'/Entities/' + statusInfo.entity_id"
          size="sm"
        />
        <GeneBadge
          :symbol="entityInfo.symbol"
          :hgnc-id="entityInfo.hgnc_id"
          :link-to="'/Genes/' + entityInfo.hgnc_id"
          size="sm"
        />
        <DiseaseBadge
          :name="entityInfo.disease_ontology_name"
          :ontology-id="entityInfo.disease_ontology_id_version"
          :link-to="'/Ontology/' + (entityInfo.disease_ontology_id_version || '').replace(/_.+/g, '')"
          :max-length="35"
          size="sm"
        />
        <InheritanceBadge
          :full-name="entityInfo.hpo_mode_of_inheritance_term_name"
          :hpo-term="entityInfo.hpo_mode_of_inheritance_term"
          size="sm"
        />
      </div>
    </div>

    <BOverlay :show="loading" rounded="sm">
      <BForm ref="form" @submit.stop.prevent="$emit('ok')">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-diagram-3 me-2" />
          Classification
        </h6>

        <BFormGroup label="Status Category" label-for="status-select" class="mb-3">
          <template #label>
            <span class="fw-semibold">Status Category</span>
            <BBadge
              id="popover-badge-help-status"
              pill
              href="#"
              variant="info"
              class="ms-2"
              style="cursor: help"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>
          </template>
          <BFormSelect
            v-if="statusOptions && statusOptions.length > 0"
            id="status-select"
            :model-value="statusInfo.category_id"
            :options="normalizedStatusOptions"
            @update:model-value="updateStatusInfo('category_id', $event)"
          >
            <template #first>
              <BFormSelectOption :value="null"> Select status... </BFormSelectOption>
            </template>
          </BFormSelect>
        </BFormGroup>

        <BPopover target="popover-badge-help-status" variant="info" triggers="focus">
          <template #title> Status instructions </template>
          Please refer to the curation manual for details on the categories.
        </BPopover>

        <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
          <i class="bi bi-exclamation-triangle me-2" />
          Entity Flags
        </h6>

        <BFormGroup class="mb-3">
          <template #label>
            <span class="fw-semibold">Removal Flag</span>
            <BBadge
              id="popover-badge-help-removal"
              pill
              href="#"
              variant="info"
              class="ms-2"
              style="cursor: help"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>
          </template>
          <BFormCheckbox
            id="removeSwitch"
            :model-value="statusInfo.problematic"
            switch
            @update:model-value="updateStatusInfo('problematic', Boolean($event))"
          >
            Suggest removal of this entity
          </BFormCheckbox>
        </BFormGroup>

        <BPopover target="popover-badge-help-removal" variant="info" triggers="focus">
          <template #title> Removal instructions </template>
          SysNDD does not forget, meaning that entities will not be deleted but they can be
          deactivated. Deactivated entities will not be displayed on the website. Typically
          duplicate entities should be deactivated especially if there is a more specific
          disease name.
        </BPopover>

        <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
          <i class="bi bi-chat-left-text me-2" />
          Notes
        </h6>

        <BFormGroup label="Comment" label-for="status-textarea-comment" class="mb-0">
          <template #label>
            <span class="fw-semibold">Comment</span>
          </template>
          <BFormTextarea
            id="status-textarea-comment"
            :model-value="statusInfo.comment"
            rows="3"
            placeholder="Why should this entity's status be changed..."
            @update:model-value="updateStatusInfo('comment', String($event ?? ''))"
          />
        </BFormGroup>
      </BForm>
    </BOverlay>
  </BModal>
</template>

<script setup lang="ts">
import { computed, type PropType } from 'vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

export interface StatusInfoShape {
  category_id?: number | null;
  comment?: string | null;
  problematic?: boolean | null;
  status_id?: number | null;
  entity_id?: number | null;
  status_user_name?: string | null;
  status_user_role?: string | null;
  status_date?: string | null;
  status_approved?: number | null;
}

export interface EntityInfoShape {
  entity_id?: number;
  symbol?: string;
  hgnc_id?: string;
  disease_ontology_id_version?: string;
  disease_ontology_name?: string;
  hpo_mode_of_inheritance_term_name?: string;
  hpo_mode_of_inheritance_term?: string;
}

export interface StatusOption {
  id: number | string;
  label: string;
}

const props = defineProps({
  modalId: { type: String, default: 'status-modal' },
  loading: { type: Boolean, default: false },
  statusInfo: {
    type: Object as PropType<StatusInfoShape>,
    required: true,
  },
  entityInfo: {
    type: Object as PropType<EntityInfoShape>,
    required: true,
  },
  statusOptions: {
    type: Array as PropType<StatusOption[]>,
    default: () => [],
  },
  userIcon: {
    type: Object as PropType<Record<string, string>>,
    default: () => ({}),
  },
});

const emit = defineEmits<{
  (e: 'ok'): void;
  (e: 'hide', event: unknown): void;
  (e: 'update:statusInfo', value: StatusInfoShape): void;
}>();

const normalizedStatusOptions = computed(() =>
  props.statusOptions.map((opt) => ({ value: opt.id, text: opt.label }))
);

const updateStatusInfo = (
  field: 'category_id' | 'problematic' | 'comment',
  value: unknown
): void => {
  emit('update:statusInfo', { ...props.statusInfo, [field]: value });
};
</script>
