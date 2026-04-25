<!-- views/review/components/StatusEditModal.vue -->
<!--
  Status-edit modal extracted from `Review.vue` during W6 of v11.1
  finish-hardening. Owns the entity-context header, the classification
  form (category + removal flag + comment), and the saving/loading
  spinner glue. The form-data binding stays in the parent's
  `useStatusForm` composable; this component receives it as a v-model
  proxy so the existing reactive flow stays intact.

  Pure presentational shell: no API calls, no `loadStatusData`. The
  parent calls `$ref.show()` and the form composable's loaders before
  the modal opens.
-->
<template>
  <BModal
    :id="modalDescriptor.id"
    :ref="modalDescriptor.id"
    size="lg"
    centered
    ok-title="Submit"
    no-close-on-esc
    no-close-on-backdrop
    header-class="border-bottom-0 pb-0"
    footer-class="border-top-0 pt-0"
    :busy="loading"
    @show="$emit('show')"
    @ok="$emit('ok')"
  >
    <template #title>
      <div class="d-flex align-items-center">
        <i class="bi bi-stoplights me-2 text-secondary" />
        <span class="fw-semibold">Edit Status</span>
      </div>
    </template>

    <template #footer="{ ok, cancel }">
      <div class="w-100 d-flex justify-content-between align-items-center">
        <div class="d-flex align-items-center gap-2 text-muted small">
          <span v-if="isSaving" class="d-flex align-items-center gap-1">
            <BSpinner small variant="secondary" />
            <span>Saving...</span>
          </span>
          <span v-if="formData.status_user_name" class="d-flex align-items-center gap-1">
            <i :class="'bi bi-' + userIcon[formData.status_user_role]" />
            <span>{{ formData.status_user_name }}</span>
            <span class="text-muted">·</span>
            <span>{{ formData.status_date?.substring(0, 10) }}</span>
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

    <!-- Entity context header -->
    <div class="bg-light rounded-3 p-3 mb-4">
      <h6 class="text-muted mb-2 small text-uppercase fw-semibold">
        <i class="bi bi-info-circle me-1" />
        Entity Details
      </h6>
      <div class="d-flex flex-wrap gap-2">
        <EntityBadge
          v-if="formData.entity_id"
          :entity-id="formData.entity_id"
          :link-to="'/Entities/' + formData.entity_id"
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
          :link-to="'/Ontology/' + entityInfo.disease_ontology_id_version.replace(/_.+/g, '')"
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
      <BForm @submit.stop.prevent="$emit('ok')">
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
            v-model="categoryIdProxy"
            :options="normalizedStatusOptions"
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
          <BFormCheckbox id="removeSwitch" v-model="problematicProxy" switch>
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
            v-model="commentProxy"
            rows="3"
            placeholder="Why should this entity's status be changed..."
          />
        </BFormGroup>
      </BForm>
    </BOverlay>
  </BModal>
</template>

<script>
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

export default {
  name: 'StatusEditModal',
  components: {
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
  },
  props: {
    modalDescriptor: {
      type: Object,
      required: true,
    },
    formData: {
      type: Object,
      required: true,
    },
    entityInfo: {
      type: Object,
      required: true,
    },
    statusOptions: {
      type: Array,
      default: () => [],
    },
    loading: { type: Boolean, default: false },
    isSaving: { type: Boolean, default: false },
    userIcon: { type: Object, default: () => ({}) },
  },
  emits: ['show', 'ok'],
  computed: {
    normalizedStatusOptions() {
      if (!this.statusOptions || !Array.isArray(this.statusOptions)) return [];
      return this.statusOptions.map((opt) => ({ value: opt.id, text: opt.label }));
    },
    // The form-data fields hang off a reactive object owned by the
    // parent's `useStatusForm` composable. The composable expects writes
    // from the modal to flow back into the same reactive proxy (matching
    // the legacy `v-model="statusFormData.<field>"` bindings inside
    // Review.vue). Vue's `vue/no-mutating-props` lint rule treats nested
    // prop mutation as a smell, but in this composable-owned-reactive
    // scenario it IS the intended data flow. The disables below are
    // deliberate and scoped to these three setters only.
    categoryIdProxy: {
      get() {
        return this.formData.category_id;
      },
      set(value) {
        // eslint-disable-next-line vue/no-mutating-props
        this.formData.category_id = value;
      },
    },
    problematicProxy: {
      get() {
        return this.formData.problematic;
      },
      set(value) {
        // eslint-disable-next-line vue/no-mutating-props
        this.formData.problematic = value;
      },
    },
    commentProxy: {
      get() {
        return this.formData.comment;
      },
      set(value) {
        // eslint-disable-next-line vue/no-mutating-props
        this.formData.comment = value;
      },
    },
  },
  methods: {
    show() {
      this.$refs[this.modalDescriptor.id]?.show();
    },
    hide() {
      this.$refs[this.modalDescriptor.id]?.hide();
    },
  },
};
</script>
